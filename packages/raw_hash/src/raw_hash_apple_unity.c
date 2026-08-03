// Apple (macOS/iOS) unity build for the raw_hash native library.
//
// CocoaPods compiles only files inside the pod directory and cannot list the
// shared sources under ../src/vendor directly, so the Apple build pulls the
// whole native tree into ONE translation unit via #include. This mirrors what
// windows/linux/android build through ../src/CMakeLists.txt; same rcheevos +
// libchdr sources, same compile-time options, just amalgamated.
//
// macos/Classes/raw_hash.c and ios/Classes/raw_hash.c each #include this file.
// Header search paths and the DART_SHARED_LIB define are supplied by the
// podspecs (see raw_hash.podspec). All paths below are relative to this file
// (packages/raw_hash/src/).
//
// NOTE: this is the only place the Apple build differs structurally from the
// CMake build. If a future source is added to ../src/CMakeLists.txt, add it
// here too.

// libchdr compile-time options. These match the defaults that
// vendor/libchdr/CMakeLists.txt passes to the chdr-static target; the codec
// sources read them, so they must be set before unity.c is included.
#define WANT_RAW_DATA_SECTOR 1
#define WANT_SUBCODE 1
#define VERIFY_BLOCK_CRC 1

// libchdr + bundled codecs (miniz / lzma / zstd). unity.c sets the MINIZ_NO_*
// trims and includes every libchdr/codec .c with paths relative to itself.
#include "vendor/libchdr/unity.c"

// rcheevos rhash + utilities (the exact list from ../src/CMakeLists.txt).
#include "vendor/rcheevos/src/rhash/hash.c"
#include "vendor/rcheevos/src/rhash/hash_disc.c"
#include "vendor/rcheevos/src/rhash/hash_rom.c"
#include "vendor/rcheevos/src/rhash/hash_zip.c"
#include "vendor/rcheevos/src/rhash/hash_encrypted.c"
#include "vendor/rcheevos/src/rhash/cdreader.c"
#include "vendor/rcheevos/src/rhash/aes.c"
#include "vendor/rcheevos/src/rhash/md5.c"
#include "vendor/rcheevos/src/rc_util.c"
#include "vendor/rcheevos/src/rc_compat.c"

// Local sources: the libchdr-backed CHD cdreader and the FFI entry points.
#include "chd_cdreader.c"
#include "raw_hash_shim.c"
