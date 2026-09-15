#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint raw_hash.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'raw_hash'
  s.version          = '0.0.1'
  s.summary          = 'rcheevos-backed RetroAchievements hasher (FFI).'
  s.description      = <<-DESC
Native RetroAchievements hashing via rcheevos + libchdr, exposed over FFI.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # Classes/ holds a single forwarder that #includes the shared unity build
  # (../src/raw_hash_apple_unity.c), which compiles the full rcheevos + libchdr
  # tree. CocoaPods cannot list those ../src sources directly, so the forwarder
  # pulls them in and the search paths below let the compiler find their
  # headers. This mirrors ../src/CMakeLists.txt for the other platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DART_SHARED_LIB=1',
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '"$(PODS_TARGET_SRCROOT)/../src"',
      '"$(PODS_TARGET_SRCROOT)/../src/vendor/rcheevos/include"',
      '"$(PODS_TARGET_SRCROOT)/../src/vendor/rcheevos/src/rhash"',
      '"$(PODS_TARGET_SRCROOT)/../src/vendor/libchdr/include"',
      '"$(PODS_TARGET_SRCROOT)/../src/vendor/libchdr/deps/zstd-1.5.7"',
    ].join(' '),
  }
  # Vendored C (rcheevos / libchdr / codecs) is not warning-clean; never let a
  # third-party warning fail the app build.
  s.compiler_flags = '-w'
  s.swift_version = '5.0'
end
