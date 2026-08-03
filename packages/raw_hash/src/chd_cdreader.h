/* Custom rc_hash cdreader backed by libchdr (CHD support). Phase 0 spike. */
#ifndef CHD_CDREADER_H
#define CHD_CDREADER_H

#include "rc_hash.h"

/* Fills `out` with cdreader callbacks that read .chd files via libchdr.
 * Assign into iterator.callbacks.cdreader for .chd paths only. */
void rc_hash_get_chd_cdreader(struct rc_hash_cdreader* out);

#endif /* CHD_CDREADER_H */
