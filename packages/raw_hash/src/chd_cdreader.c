/* Custom rc_hash cdreader backed by libchdr (CHD support). Phase 0 spike.
 *
 * Implements the rc_hash_cdreader interface (open_track / read_sector /
 * close_track / first_track_sector) over a CHD file. The cooking logic
 * (sector-size detection, header skipping, MSF->LBA) deliberately mirrors
 * rcheevos' own default cue/bin cdreader so the produced hash is identical.
 *
 * Handles two CHD layouts:
 *   - CD CHDs (createcd): tracks described by CHTR/CHT2 metadata, 2352-byte raw
 *     sectors stored in 2448-byte frames (data + subcode).
 *   - DVD CHDs (createdvd): no CD track metadata, a flat run of logical
 *     sectors (2048 bytes), used for PSP UMD and DVD-based PS2.
 */
#include "chd_cdreader.h"

#include "libchdr/chd.h"
#include "libchdr/cdrom.h"   /* CD_FRAME_SIZE, CD_MAX_SECTOR_DATA, CD_TRACK_PADDING, metadata tags */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct chd_track {
  chd_file* chd;

  uint32_t track_first_frame;   /* physical frame in the chd where this track's data begins */
  int      track_first_sector;  /* logical LBA assigned to that first frame */
  int      pregap_sectors;      /* pregap for first_track_sector() */

  int sector_header_size;       /* bytes to skip at the front of each frame: 24/16 (CD) or 0 (DVD) */
  int raw_data_size;            /* user bytes per logical sector (2048) */

  uint32_t frames_per_hunk;
  uint32_t unitbytes;           /* stride of one frame within a hunk (2448 CD, 2048 DVD) */
  uint32_t frame_data_size;     /* meaningful bytes to read from each frame (2352 CD, 2048 DVD) */
  uint8_t* hunk_buffer;
  int      cached_hunk;         /* -1 = none */
} chd_track_t;

typedef struct trackinfo {
  int track;
  int frames;
  int pregap;
  int is_data;
  uint32_t phys_frame;          /* physical start frame in the chd */
} trackinfo;

static int chd_load_hunk(chd_track_t* t, uint32_t hunk) {
  if ((int)hunk == t->cached_hunk)
    return 1;
  if (chd_read(t->chd, hunk, t->hunk_buffer) != CHDERR_NONE)
    return 0;
  t->cached_hunk = (int)hunk;
  return 1;
}

/* read the data portion of one frame (frame_data_size bytes) at an absolute physical frame */
static int chd_read_raw_frame(chd_track_t* t, uint32_t frame, uint8_t* out) {
  uint32_t hunk = frame / t->frames_per_hunk;
  uint32_t off = (frame % t->frames_per_hunk) * t->unitbytes;
  if (!chd_load_hunk(t, hunk))
    return 0;
  memcpy(out, t->hunk_buffer + off, t->frame_data_size);
  return 1;
}

static int chd_get_sector_from_header(const uint8_t header[16]) {
  int minutes = (header[12] >> 4) * 10 + (header[12] & 0x0F);
  int seconds = (header[13] >> 4) * 10 + (header[13] & 0x0F);
  int frames = (header[14] >> 4) * 10 + (header[14] & 0x0F);
  return ((minutes * 60) + seconds) * 75 + frames - 150;
}

static int chd_parse_tracks(chd_file* chd, trackinfo* tracks, int max) {
  uint32_t frame_offset = 0;
  int count = 0;
  char meta[256];
  uint32_t resultlen = 0;
  int i;

  for (i = 0; i < max; i++) {
    int track = 0, frames = 0, pregap = 0, postgap = 0;
    char type[32] = {0}, subtype[32] = {0}, pgtype[32] = {0}, pgsub[32] = {0};
    uint32_t padded, rem;

    if (chd_get_metadata(chd, CDROM_TRACK_METADATA2_TAG, i, meta, sizeof(meta),
                         &resultlen, NULL, NULL) == CHDERR_NONE) {
      if (sscanf(meta, CDROM_TRACK_METADATA2_FORMAT, &track, type, subtype,
                 &frames, &pregap, pgtype, pgsub, &postgap) < 5)
        break;
    }
    else if (chd_get_metadata(chd, CDROM_TRACK_METADATA_TAG, i, meta, sizeof(meta),
                              &resultlen, NULL, NULL) == CHDERR_NONE) {
      if (sscanf(meta, CDROM_TRACK_METADATA_FORMAT, &track, type, subtype, &frames) < 4)
        break;
      pregap = 0;
    }
    else if (chd_get_metadata(chd, GDROM_TRACK_METADATA_TAG, i, meta, sizeof(meta),
                              &resultlen, NULL, NULL) == CHDERR_NONE) {
      /* GD-ROM metadata (CHGD tag), same layout as CHT2 but with an extra PAD
       * field between FRAMES and PREGAP.  The pad frames are a logical gap on
       * the disc (between the low- and high-density areas) and are NOT stored
       * in the CHD, so they are parsed but ignored for frame-offset purposes. */
      int pad = 0;
      if (sscanf(meta, GDROM_TRACK_METADATA_FORMAT, &track, type, subtype,
                 &frames, &pad, &pregap, pgtype, pgsub, &postgap) < 5)
        break;
      (void)pad; /* physical CHD storage uses the same CD_TRACK_PADDING rounding */
    }
    else {
      break; /* no more tracks */
    }

    tracks[count].track = track;
    tracks[count].frames = frames;
    tracks[count].pregap = pregap;
    tracks[count].is_data = (strncmp(type, "AUDIO", 5) != 0);
    tracks[count].phys_frame = frame_offset;
    count++;

    /* tracks are stored padded to a CD_TRACK_PADDING-frame boundary in the chd */
    padded = (uint32_t)frames;
    rem = padded % CD_TRACK_PADDING;
    if (rem)
      padded += CD_TRACK_PADDING - rem;
    frame_offset += padded;
  }

  return count;
}

/* DVD CHD (createdvd): no CD track metadata. The whole image is a flat run of
 * logical sectors (unitbytes each, typically 2048) starting at LBA 0. */
static chd_track_t* chd_open_dvd(chd_file* chd, const chd_header* header) {
  chd_track_t* t = (chd_track_t*)calloc(1, sizeof(*t));
  if (!t)
    return NULL;

  t->chd = chd;
  t->unitbytes = header->unitbytes ? header->unitbytes : 2048;
  t->frame_data_size = t->unitbytes;       /* a frame IS one logical sector */
  t->frames_per_hunk = header->hunkbytes / t->unitbytes;
  t->hunk_buffer = (uint8_t*)malloc(header->hunkbytes);
  t->cached_hunk = -1;
  t->track_first_frame = 0;
  t->track_first_sector = 0;
  t->pregap_sectors = 0;
  t->sector_header_size = 0;                /* no sync/header on DVD sectors */
  t->raw_data_size = (int)t->unitbytes;     /* user bytes per sector == sector */

  if (!t->hunk_buffer || t->frames_per_hunk == 0) {
    free(t->hunk_buffer);
    free(t);
    return NULL;
  }
  return t;
}

static void* chd_open_track(const char* path, uint32_t track) {
  chd_file* chd = NULL;
  const chd_header* header;
  trackinfo tracks[CD_MAX_TRACKS];
  trackinfo* sel = NULL;
  chd_track_t* t;
  uint8_t frame[CD_FRAME_SIZE]; /* must hold a full raw frame including subcode */
  int n, i;

  if (chd_open(path, CHD_OPEN_READ, NULL, &chd) != CHDERR_NONE)
    return NULL;

  header = chd_get_header(chd);
  n = chd_parse_tracks(chd, tracks, CD_MAX_TRACKS);

  /* No CD track metadata -> treat as a DVD CHD (PSP UMD, DVD-based PS2, ...). */
  if (n == 0)
    return chd_open_dvd(chd, header);

  /* resolve the requested track (1-based) or a special selector */
  switch (track) {
    case RC_HASH_CDTRACK_FIRST_DATA:
      for (i = 0; i < n; i++) { if (tracks[i].is_data) { sel = &tracks[i]; break; } }
      break;
    case RC_HASH_CDTRACK_LAST:
      sel = &tracks[n - 1];
      break;
    case RC_HASH_CDTRACK_LARGEST:
      sel = &tracks[0];
      for (i = 1; i < n; i++) { if (tracks[i].frames > sel->frames) sel = &tracks[i]; }
      break;
    default:
      for (i = 0; i < n; i++) { if ((uint32_t)tracks[i].track == track) { sel = &tracks[i]; break; } }
      break;
  }
  if (!sel)
    sel = &tracks[0];

  t = (chd_track_t*)calloc(1, sizeof(*t));
  if (!t) { chd_close(chd); return NULL; }

  t->chd = chd;
  t->unitbytes = header->unitbytes ? header->unitbytes : CD_FRAME_SIZE;
  t->frame_data_size = CD_MAX_SECTOR_DATA;  /* read the 2352-byte sector, ignore 96B subcode */
  t->frames_per_hunk = header->hunkbytes / t->unitbytes;
  t->hunk_buffer = (uint8_t*)malloc(header->hunkbytes);
  t->cached_hunk = -1;
  t->track_first_frame = sel->phys_frame;
  t->pregap_sectors = 0; /* virtual lead-in is not stored; metadata pregap is informational */
  t->raw_data_size = 2048;

  if (!t->hunk_buffer || t->frames_per_hunk == 0) { chd_close(chd); free(t->hunk_buffer); free(t); return NULL; }

  /* Determine sector layout by inspecting the volume descriptor at LBA 16,
   * exactly as rcheevos' default reader does. CHD always stores full 2352 raw. */
  if (chd_read_raw_frame(t, t->track_first_frame + 16, frame)) {
    static const uint8_t sync_pattern[] = {
      0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00
    };
    if (memcmp(frame, sync_pattern, 12) == 0) {
      t->sector_header_size = (memcmp(&frame[25], "CD001", 5) == 0) ? 24 : 16;
      t->track_first_sector = chd_get_sector_from_header(frame) - 16;
    }
    else {
      /* unexpected (cooked chd?), assume 2048 user data, no header */
      t->sector_header_size = 0;
      t->track_first_sector = 0;
    }
  }

  return t;
}

static size_t chd_read_sector(void* track_handle, uint32_t sector, void* buffer, size_t requested_bytes) {
  chd_track_t* t = (chd_track_t*)track_handle;
  uint8_t* out = (uint8_t*)buffer;
  uint8_t frame[CD_FRAME_SIZE]; /* must hold a full raw frame including subcode */
  size_t total = 0;
  uint32_t rel;
  int avail;

  if (!t || sector < (uint32_t)t->track_first_sector)
    return 0;

  rel = sector - (uint32_t)t->track_first_sector;
  avail = (int)t->frame_data_size - t->sector_header_size; /* user bytes available per frame */

  /* full cooked-sector chunks */
  while (requested_bytes > (size_t)t->raw_data_size) {
    if (!chd_read_raw_frame(t, t->track_first_frame + rel, frame))
      return total;
    memcpy(out, frame + t->sector_header_size, t->raw_data_size);
    total += t->raw_data_size;
    out += t->raw_data_size;
    requested_bytes -= t->raw_data_size;
    rel++;
  }

  /* trailing partial read from a single sector's user data */
  if (requested_bytes > 0) {
    size_t n = requested_bytes;
    if (n > (size_t)avail)
      n = (size_t)avail;
    if (!chd_read_raw_frame(t, t->track_first_frame + rel, frame))
      return total;
    memcpy(out, frame + t->sector_header_size, n);
    total += n;
  }

  return total;
}

static uint32_t chd_first_track_sector(void* track_handle) {
  chd_track_t* t = (chd_track_t*)track_handle;
  if (t)
    return (uint32_t)(t->track_first_sector + t->pregap_sectors);
  return 0;
}

static void chd_close_track(void* track_handle) {
  chd_track_t* t = (chd_track_t*)track_handle;
  if (t) {
    if (t->hunk_buffer)
      free(t->hunk_buffer);
    if (t->chd)
      chd_close(t->chd);
    free(t);
  }
}

void rc_hash_get_chd_cdreader(struct rc_hash_cdreader* out) {
  out->open_track = chd_open_track;
  out->read_sector = chd_read_sector;
  out->close_track = chd_close_track;
  out->first_track_sector = chd_first_track_sector;
  out->open_track_iterator = NULL;
}
