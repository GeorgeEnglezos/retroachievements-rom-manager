#ifndef RAW_HASH_H
#define RAW_HASH_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

// Log callback: receives rcheevos verbose/error messages (UTF-8, NUL-terminated).
typedef void (*raw_hash_log_callback)(const char* message);

// Registers a callback for rcheevos verbose/error messages. Pass NULL to clear.
FFI_PLUGIN_EXPORT void raw_hash_set_log_callback(raw_hash_log_callback callback);

// Computes the RetroAchievements hash for `path` using rcheevos.
//
// `out33` must point to a buffer of at least 33 bytes; on success it receives
// the 32-char lowercase hex hash plus a NUL terminator. `console_id` is an RA
// console id. `.chd` files are handled via the bundled libchdr cdreader; all
// other formats use rcheevos' default reader.
//
// Returns 1 on success, 0 on failure.
FFI_PLUGIN_EXPORT int raw_hash_file(char* out33, uint32_t console_id, const char* path);

#endif // RAW_HASH_H
