/* Thin shim exposing a single clean hashing entry point over rcheevos + libchdr.
 * This is the only symbol surface the Dart FFI bindings target. */
#include "raw_hash.h"

#include "rc_hash.h"
#include "chd_cdreader.h"

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
