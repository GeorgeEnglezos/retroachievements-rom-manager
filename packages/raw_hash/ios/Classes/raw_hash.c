// Relative import to be able to reuse the C sources.
// See the comment in ../raw_hash.podspec for more information.
//
// The Apple build compiles the full native library (rcheevos + libchdr +
// bundled codecs) as a single translation unit via the shared unity forwarder.
// Header search paths and the DART_SHARED_LIB define come from the podspec.
#include "../../src/raw_hash_apple_unity.c"
