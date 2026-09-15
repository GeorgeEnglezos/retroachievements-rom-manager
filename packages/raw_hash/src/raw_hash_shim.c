/* Thin shim exposing a single clean hashing entry point over rcheevos + libchdr.
 * This is the only symbol surface the Dart FFI bindings target. */
#include "raw_hash.h"

#include "rc_hash.h"
#include "chd_cdreader.h"
#include "zstd.h"

#include <string.h>

static raw_hash_log_callback g_log_callback = NULL;

/* rcheevos verbose/error callbacks have an extra iterator arg; forward the text. */
static void raw_hash_forward_message(const char* message, const rc_hash_iterator_t* iterator) {
  (void)iterator;
  if (g_log_callback && message)
    g_log_callback(message);
}

static int raw_hash_ends_with_ci(const char* s, const char* suffix) {
  size_t ls, lf, i;
  const char* p;
  if (!s || !suffix)
    return 0;
  ls = strlen(s);
  lf = strlen(suffix);
  if (lf > ls)
    return 0;
  p = s + (ls - lf);
  for (i = 0; i < lf; i++) {
    char a = p[i], b = suffix[i];
    if (a >= 'A' && a <= 'Z') a += 32;
    if (b >= 'A' && b <= 'Z') b += 32;
    if (a != b)
      return 0;
  }
  return 1;
}

FFI_PLUGIN_EXPORT void raw_hash_set_log_callback(raw_hash_log_callback callback) {
  g_log_callback = callback;
}

/* Virtual filereader supplied by Dart (for on-the-fly decompressed discs).
 * Process-global like g_log_callback, so it's only safe while hashing is
 * sequential (FetchEngine hashes one file at a time). Concurrent hashing would
 * need this made thread-local, same as the log callback. */
static rc_hash_filereader_t g_vfilereader;
static int g_filereader_set = 0;

FFI_PLUGIN_EXPORT void raw_hash_set_filereader(raw_hash_vr_open open_fn,
                                               raw_hash_vr_seek seek_fn,
                                               raw_hash_vr_tell tell_fn,
                                               raw_hash_vr_read read_fn,
                                               raw_hash_vr_close close_fn) {
  g_vfilereader.open = (rc_hash_filereader_open_file_handler)open_fn;
  g_vfilereader.seek = (rc_hash_filereader_seek_handler)seek_fn;
  g_vfilereader.tell = (rc_hash_filereader_tell_handler)tell_fn;
  g_vfilereader.read = (rc_hash_filereader_read_handler)read_fn;
  g_vfilereader.close = (rc_hash_filereader_close_file_handler)close_fn;
  g_filereader_set = (open_fn != NULL);
}

FFI_PLUGIN_EXPORT int64_t raw_hash_zstd_decompress(uint8_t* dst, size_t dst_cap,
                                                   const uint8_t* src, size_t src_size) {
  size_t r = ZSTD_decompress(dst, dst_cap, src, src_size);
  if (ZSTD_isError(r))
    return -1;
  return (int64_t)r;
}

FFI_PLUGIN_EXPORT int raw_hash_file_vreader(char* out33, uint32_t console_id, const char* path) {
  rc_hash_iterator_t iterator;
  int ok;

  if (!out33 || !path || !g_filereader_set)
    return 0;

  out33[0] = '\0';

  rc_hash_initialize_iterator(&iterator, path, NULL, 0);

  /* set callbacks AFTER init (init resets the iterator) */
  iterator.callbacks.verbose_message = raw_hash_forward_message;
  iterator.callbacks.error_message = raw_hash_forward_message;
  iterator.callbacks.filereader = g_vfilereader;

  ok = rc_hash_generate(out33, console_id, &iterator);

  rc_hash_destroy_iterator(&iterator);

  if (!ok || out33[0] == '\0') {
    out33[0] = '\0';
    return 0;
  }
  return 1;
}

FFI_PLUGIN_EXPORT int raw_hash_file(char* out33, uint32_t console_id, const char* path) {
  rc_hash_iterator_t iterator;
  int ok;

  if (!out33 || !path)
    return 0;

  out33[0] = '\0';

  rc_hash_initialize_iterator(&iterator, path, NULL, 0);

  /* set callbacks AFTER init (init resets the iterator) */
  iterator.callbacks.verbose_message = raw_hash_forward_message;
  iterator.callbacks.error_message = raw_hash_forward_message;

  /* .chd uses the bundled libchdr cdreader; everything else uses the default */
  if (raw_hash_ends_with_ci(path, ".chd"))
    rc_hash_get_chd_cdreader(&iterator.callbacks.cdreader);

  ok = rc_hash_generate(out33, console_id, &iterator);

  rc_hash_destroy_iterator(&iterator);

  if (!ok || out33[0] == '\0') {
    out33[0] = '\0';
    return 0;
  }
  return 1;
}
