#ifndef RAW_HASH_H
#define RAW_HASH_H

#include <stdint.h>
#include <stddef.h>

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

// Virtual filereader for compressed disc containers that Dart decompresses on
// the fly (CISO/WBFS/GCZ). Handlers operate on an opaque handle returned by
// `open`; semantics match stdio fopen/fseek/ftell/fread/fclose.
typedef void* (*raw_hash_vr_open)(const char* path_utf8);
typedef void (*raw_hash_vr_seek)(void* handle, int64_t offset, int origin);
typedef int64_t (*raw_hash_vr_tell)(void* handle);
typedef size_t (*raw_hash_vr_read)(void* handle, void* buffer, size_t bytes);
typedef void (*raw_hash_vr_close)(void* handle);

// Registers the virtual filereader used by raw_hash_file_vreader. Pass NULL to
// clear. The pointers must outlive any raw_hash_file_vreader call using them.
FFI_PLUGIN_EXPORT void raw_hash_set_filereader(raw_hash_vr_open open_fn,
                                               raw_hash_vr_seek seek_fn,
                                               raw_hash_vr_tell tell_fn,
                                               raw_hash_vr_read read_fn,
                                               raw_hash_vr_close close_fn);

// Like raw_hash_file, but reads through the registered virtual filereader
// instead of opening `path` directly. raw_hash_set_filereader must be set
// first. Returns 1 on success, 0 on failure.
FFI_PLUGIN_EXPORT int raw_hash_file_vreader(char* out33, uint32_t console_id,
                                            const char* path);

#endif // RAW_HASH_H
