# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(raw_hash_library VERSION 0.0.1 LANGUAGES C)

set(RC "${CMAKE_CURRENT_SOURCE_DIR}/vendor/rcheevos")

# Build libchdr (+ bundled miniz/lzma/zstd) as static; never as a shared lib.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/vendor/libchdr" "${CMAKE_CURRENT_BINARY_DIR}/libchdr" EXCLUDE_FROM_ALL)

add_library(raw_hash SHARED
  "raw_hash_shim.c"
  "chd_cdreader.c"
  "${RC}/src/rhash/hash.c"
  "${RC}/src/rhash/hash_disc.c"
  "${RC}/src/rhash/hash_rom.c"
  "${RC}/src/rhash/hash_zip.c"
  "${RC}/src/rhash/hash_encrypted.c"
  "${RC}/src/rhash/cdreader.c"
  "${RC}/src/rhash/aes.c"
  "${RC}/src/rhash/md5.c"
  "${RC}/src/rc_util.c"
  "${RC}/src/rc_compat.c"
)

set_target_properties(raw_hash PROPERTIES
  PUBLIC_HEADER raw_hash.h
  OUTPUT_NAME "raw_hash"
)

target_include_directories(raw_hash PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${RC}/include"
  "${RC}/src/rhash"
  "${CMAKE_CURRENT_SOURCE_DIR}/vendor/libchdr/include"
)

target_compile_definitions(raw_hash PUBLIC DART_SHARED_LIB)
if(MSVC)
  target_compile_definitions(raw_hash PRIVATE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS)
endif()

target_link_libraries(raw_hash PRIVATE chdr-static)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(raw_hash PRIVATE "-Wl,-z,max-page-size=16384")
endif()
