// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/process.dart';
import '../base/version.dart';
import '../convert.dart';
import '../globals.dart' as globals;
import 'java.dart';

// ANDROID_HOME is deprecated.
// See https://developer.android.com/studio/command-line/variables.html#envar
const String kAndroidHome = 'ANDROID_HOME';
const String kAndroidSdkRoot = 'ANDROID_SDK_ROOT';

final RegExp _numberedAndroidPlatformRe = RegExp(r'^android-([0-9]+)$');
final RegExp _sdkVersionRe = RegExp(r'^ro.build.version.sdk=([0-9]+)$');

// Android SDK layout:

// $ANDROID_SDK_ROOT/platform-tools/adb

// $ANDROID_SDK_ROOT/build-tools/19.1.0/aapt, dx, zipalign
// $ANDROID_SDK_ROOT/build-tools/22.0.1/aapt
// $ANDROID_SDK_ROOT/build-tools/23.0.2/aapt
// $ANDROID_SDK_ROOT/build-tools/24.0.0-preview/aapt
// $ANDROID_SDK_ROOT/build-tools/25.0.2/apksigner

// $ANDROID_SDK_ROOT/platforms/android-22/android.jar
// $ANDROID_SDK_ROOT/platforms/android-23/android.jar
// $ANDROID_SDK_ROOT/platforms/android-N/android.jar
class AndroidSdk {
  AndroidSdk(this.directory, {
    Java? java,
  }): _java = java {
    reinitialize();
  }

<<<<<<< HEAD
  static const String javaHomeEnvironmentVariable = 'JAVA_HOME';
  static const String _javaExecutable = 'java';

=======
>>>>>>> e1e47221e86272429674bec4f1bd36acc4fc7b77
  /// The Android SDK root directory.
  final Directory directory;

  final Java? _java;

  List<AndroidSdkVersion> _sdkVersions = <AndroidSdkVersion>[];
  AndroidSdkVersion? _latestVersion;

  /// Whether the `cmdline-tools` directory exists in the Android SDK.
  ///
  /// This is required to use the newest SDK manager which only works with
  /// the newer JDK.
  bool get cmdlineToolsAvailable => directory.childDirectory('cmdline-tools').existsSync();

  /// Whether the `platform-tools` or `cmdline-tools` directory exists in the Android SDK.
  ///
  /// It is possible to have an Android SDK folder that is missing this with
  /// the expectation that it will be downloaded later, e.g. by gradle or the
  /// sdkmanager. The [licensesAvailable] property should be used to determine
  /// whether the licenses are at least possibly accepted.
  bool get platformToolsAvailable => cmdlineToolsAvailable
     || directory.childDirectory('platform-tools').existsSync();

  /// Whether the `licenses` directory exists in the Android SDK.
  ///
  /// The existence of this folder normally indicates that the SDK licenses have
  /// been accepted, e.g. via the sdkmanager, Android Studio, or by copying them
  /// from another workstation such as in CI scenarios. If these files are valid
  /// gradle or the sdkmanager will be able to download and use other parts of
  /// the SDK on demand.
  bool get licensesAvailable => directory.childDirectory('licenses').existsSync();

  static AndroidSdk? locateAndroidSdk() {
    String? findAndroidHomeDir() {
      String? androidHomeDir;
      if (globals.config.containsKey('android-sdk')) {
        androidHomeDir = globals.config.getValue('android-sdk') as String?;
      } else if (globals.platform.environment.containsKey(kAndroidHome)) {
        androidHomeDir = globals.platform.environment[kAndroidHome];
      } else if (globals.platform.environment.containsKey(kAndroidSdkRoot)) {
        androidHomeDir = globals.platform.environment[kAndroidSdkRoot];
      } else if (globals.platform.isLinux) {
        if (globals.fsUtils.homeDirPath != null) {
          androidHomeDir = globals.fs.path.join(
            globals.fsUtils.homeDirPath!,
            'Android',
            'Sdk',
          );
        }
      } else if (globals.platform.isMacOS) {
        if (globals.fsUtils.homeDirPath != null) {
          androidHomeDir = globals.fs.path.join(
            globals.fsUtils.homeDirPath!,
            'Library',
            'Android',
            'sdk',
          );
        }
      } else if (globals.platform.isWindows) {
        if (globals.fsUtils.homeDirPath != null) {
          androidHomeDir = globals.fs.path.join(
            globals.fsUtils.homeDirPath!,
            'AppData',
            'Local',
            'Android',
            'sdk',
          );
        }
      }

      if (androidHomeDir != null) {
        if (validSdkDirectory(androidHomeDir)) {
          return androidHomeDir;
        }
        if (validSdkDirectory(globals.fs.path.join(androidHomeDir, 'sdk'))) {
          return globals.fs.path.join(androidHomeDir, 'sdk');
        }
      }

      // in build-tools/$version/aapt
      final List<File> aaptBins = globals.os.whichAll('aapt');
      for (File aaptBin in aaptBins) {
        // Make sure we're using the aapt from the SDK.
        aaptBin = globals.fs.file(aaptBin.resolveSymbolicLinksSync());
        final String dir = aaptBin.parent.parent.parent.path;
        if (validSdkDirectory(dir)) {
          return dir;
        }
      }

      // in platform-tools/adb
      final List<File> adbBins = globals.os.whichAll('adb');
      for (File adbBin in adbBins) {
        // Make sure we're using the adb from the SDK.
        adbBin = globals.fs.file(adbBin.resolveSymbolicLinksSync());
        final String dir = adbBin.parent.parent.path;
        if (validSdkDirectory(dir)) {
          return dir;
        }
      }

      return null;
    }

    final String? androidHomeDir = findAndroidHomeDir();
    if (androidHomeDir == null) {
      // No dice.
      globals.printTrace('Unable to locate an Android SDK.');
      return null;
    }

    return AndroidSdk(globals.fs.directory(androidHomeDir));
  }

  static bool validSdkDirectory(String dir) {
    return sdkDirectoryHasLicenses(dir) || sdkDirectoryHasPlatformTools(dir);
  }

  static bool sdkDirectoryHasPlatformTools(String dir) {
    return globals.fs.isDirectorySync(globals.fs.path.join(dir, 'platform-tools'));
  }

  static bool sdkDirectoryHasLicenses(String dir) {
    return globals.fs.isDirectorySync(globals.fs.path.join(dir, 'licenses'));
  }

  List<AndroidSdkVersion> get sdkVersions => _sdkVersions;

  AndroidSdkVersion? get latestVersion => _latestVersion;

  late final String? adbPath = getPlatformToolsPath(globals.platform.isWindows ? 'adb.exe' : 'adb');

  String? get emulatorPath => getEmulatorPath();

  String? get avdManagerPath => getAvdManagerPath();

  /// Locate the path for storing AVD emulator images. Returns null if none found.
  String? getAvdPath() {
    final String? avdHome = globals.platform.environment['ANDROID_AVD_HOME'];
    final String? home = globals.platform.environment['HOME'];
    final List<String> searchPaths = <String>[
      if (avdHome != null)
        avdHome,
      if (home != null)
        globals.fs.path.join(home, '.android', 'avd'),
    ];

    if (globals.platform.isWindows) {
      final String? homeDrive = globals.platform.environment['HOMEDRIVE'];
      final String? homePath = globals.platform.environment['HOMEPATH'];

      if (homeDrive != null && homePath != null) {
        // Can't use path.join for HOMEDRIVE/HOMEPATH
        // https://github.com/dart-lang/path/issues/37
        final String home = homeDrive + homePath;
        searchPaths.add(globals.fs.path.join(home, '.android', 'avd'));
      }
    }

    for (final String searchPath in searchPaths) {
      if (globals.fs.directory(searchPath).existsSync()) {
        return searchPath;
      }
    }
    return null;
  }

  Directory get _platformsDir => directory.childDirectory('platforms');

  Iterable<Directory> get _platforms {
    Iterable<Directory> platforms = <Directory>[];
    if (_platformsDir.existsSync()) {
      platforms = _platformsDir
        .listSync()
        .whereType<Directory>();
    }
    return platforms;
  }

  /// Validate the Android SDK. This returns an empty list if there are no
  /// issues; otherwise, it returns a list of issues found.
  List<String> validateSdkWellFormed() {
    if (adbPath == null || !globals.processManager.canRun(adbPath)) {
      return <String>['Android SDK file not found: ${adbPath ?? 'adb'}.'];
    }

    if (sdkVersions.isEmpty || latestVersion == null) {
      final StringBuffer msg = StringBuffer('No valid Android SDK platforms found in ${_platformsDir.path}.');
      if (_platforms.isEmpty) {
        msg.write(' Directory was empty.');
      } else {
        msg.write(' Candidates were:\n');
        msg.write(_platforms
          .map((Directory dir) => '  - ${dir.basename}')
          .join('\n'));
      }
      return <String>[msg.toString()];
    }

    return latestVersion!.validateSdkWellFormed();
  }

  String? getPlatformToolsPath(String binaryName) {
    final File cmdlineToolsBinary = directory.childDirectory('cmdline-tools').childFile(binaryName);
    if (cmdlineToolsBinary.existsSync()) {
      return cmdlineToolsBinary.path;
    }
    final File platformToolBinary = directory.childDirectory('platform-tools').childFile(binaryName);
    if (platformToolBinary.existsSync()) {
      return platformToolBinary.path;
    }
    return null;
  }

  String? getEmulatorPath() {
    final String binaryName = globals.platform.isWindows ? 'emulator.exe' : 'emulator';
    // Emulator now lives inside "emulator" but used to live inside "tools" so
    // try both.
    final List<String> searchFolders = <String>['emulator', 'tools'];
    for (final String folder in searchFolders) {
      final File file = directory.childDirectory(folder).childFile(binaryName);
      if (file.existsSync()) {
        return file.path;
      }
    }
    return null;
  }

  String? getCmdlineToolsPath(String binaryName, {bool skipOldTools = false}) {
    // First look for the latest version of the command-line tools
    final File cmdlineToolsLatestBinary = directory
      .childDirectory('cmdline-tools')
      .childDirectory('latest')
      .childDirectory('bin')
      .childFile(binaryName);
    if (cmdlineToolsLatestBinary.existsSync()) {
      return cmdlineToolsLatestBinary.path;
    }

    // Next look for the highest version of the command-line tools
    final Directory cmdlineToolsDir = directory.childDirectory('cmdline-tools');
    if (cmdlineToolsDir.existsSync()) {
      final List<Version> cmdlineTools = cmdlineToolsDir
        .listSync()
        .whereType<Directory>()
        .map((Directory subDirectory) {
          try {
            return Version.parse(subDirectory.basename);
          } on Exception {
            return null;
          }
        })
        .whereType<Version>()
        .toList();
      cmdlineTools.sort();

      for (final Version cmdlineToolsVersion in cmdlineTools.reversed) {
        final File cmdlineToolsBinary = directory
          .childDirectory('cmdline-tools')
          .childDirectory(cmdlineToolsVersion.toString())
          .childDirectory('bin')
          .childFile(binaryName);
        if (cmdlineToolsBinary.existsSync()) {
          return cmdlineToolsBinary.path;
        }
      }
    }
    if (skipOldTools) {
      return null;
    }

    // Finally fallback to the old SDK tools
    final File toolsBinary = directory.childDirectory('tools').childDirectory('bin').childFile(binaryName);
    if (toolsBinary.existsSync()) {
      return toolsBinary.path;
    }

    return null;
  }

  String? getAvdManagerPath() => getCmdlineToolsPath(globals.platform.isWindows ? 'avdmanager.bat' : 'avdmanager');

  /// Sets up various paths used internally.
  ///
  /// This method should be called in a case where the tooling may have updated
  /// SDK artifacts, such as after running a gradle build.
  void reinitialize() {
    List<Version> buildTools = <Version>[]; // 19.1.0, 22.0.1, ...

    final Directory buildToolsDir = directory.childDirectory('build-tools');
    if (buildToolsDir.existsSync()) {
      buildTools = buildToolsDir
        .listSync()
        .map((FileSystemEntity entity) {
          try {
            return Version.parse(entity.basename);
          } on Exception {
            return null;
          }
        })
        .whereType<Version>()
        .toList();
    }

    // Match up platforms with the best corresponding build-tools.
    _sdkVersions = _platforms.map<AndroidSdkVersion?>((Directory platformDir) {
      final String platformName = platformDir.basename;
      int platformVersion;

      try {
        final Match? numberedVersion = _numberedAndroidPlatformRe.firstMatch(platformName);
        if (numberedVersion != null) {
          platformVersion = int.parse(numberedVersion.group(1)!);
        } else {
          final String buildProps = platformDir.childFile('build.prop').readAsStringSync();
          final Iterable<Match> versionMatches = const LineSplitter()
              .convert(buildProps)
              .map<RegExpMatch?>(_sdkVersionRe.firstMatch)
              .whereType<Match>();

          if (versionMatches.isEmpty) {
            return null;
          }

          final String? versionString = versionMatches.first.group(1);
          if (versionString == null) {
            return null;
          }
          platformVersion = int.parse(versionString);
        }
      } on Exception {
        return null;
      }

      Version? buildToolsVersion = Version.primary(buildTools.where((Version version) {
        return version.major == platformVersion;
      }).toList());

      buildToolsVersion ??= Version.primary(buildTools);

      if (buildToolsVersion == null) {
        return null;
      }

      return AndroidSdkVersion._(
        this,
        sdkLevel: platformVersion,
        platformName: platformName,
        buildToolsVersion: buildToolsVersion,
        fileSystem: globals.fs,
      );
    }).whereType<AndroidSdkVersion>().toList();

    _sdkVersions.sort();

    _latestVersion = _sdkVersions.isEmpty ? null : _sdkVersions.last;
  }

  /// Returns the filesystem path of the Android SDK manager tool.
  String? get sdkManagerPath {
    final String executable = globals.platform.isWindows
      ? 'sdkmanager.bat'
      : 'sdkmanager';
    final String? path = getCmdlineToolsPath(executable, skipOldTools: true);
    if (path != null) {
      return path;
    }
    return null;
  }

<<<<<<< HEAD
  /// Returns the version of java in the format \d(.\d)+(.\d)+
  /// Returns null if version not found.
  String? getJavaVersion({
    required AndroidStudio? androidStudio,
    required FileSystem fileSystem,
    required OperatingSystemUtils operatingSystemUtils,
    required Platform platform,
    required ProcessUtils processUtils,
  }) {
    final String? javaBinary = findJavaBinary(
      androidStudio: androidStudio,
      fileSystem: fileSystem,
      operatingSystemUtils: operatingSystemUtils,
      platform: platform,
    );
    if (javaBinary == null) {
      globals.printTrace('Could not find java binary to get version.');
      return null;
    }
    final RunResult result = processUtils.runSync(
      <String>[javaBinary, '--version'],
      environment: sdkManagerEnv,
    );
    if (result.exitCode != 0) {
      globals.printTrace(
          'java --version failed: exitCode: ${result.exitCode} stdout: ${result.stdout} stderr: ${result.stderr}');
      return null;
    }
    return parseJavaVersion(result.stdout);
  }

  /// Extracts JDK version from the output of java --version.
  @visibleForTesting
  static String? parseJavaVersion(String rawVersionOutput) {
    // The contents that matter come in the format '11.0.18' or '1.8.0_202'.
    final RegExp jdkVersionRegex = RegExp(r'\d+\.\d+(\.\d+(?:_\d+)?)?');
    final Iterable<RegExpMatch> matches =
        jdkVersionRegex.allMatches(rawVersionOutput);
    if (matches.isEmpty) {
      globals.logger.printWarning(_formatJavaVersionWarning(rawVersionOutput));
      return null;
    }
    final String? versionString = matches.first.group(0);
    if (versionString == null || versionString.split('_').isEmpty) {
      globals.logger.printWarning(_formatJavaVersionWarning(rawVersionOutput));
      return null;
    }
    // Trim away _d+ from versions 1.8 and below.
    return versionString.split('_').first;
  }

  /// A value that would be appropriate to use as JAVA_HOME.
  ///
  /// This method considers jdk in the following order:
  /// * the JDK bundled with Android Studio, if one is found;
  /// * the JAVA_HOME in the ambient environment, if set;
  String? get javaHome {
    return findJavaHome(
      androidStudio: globals.androidStudio,
      fileSystem: globals.fs,
      operatingSystemUtils: globals.os,
      platform: globals.platform,
    );
  }


  static String? findJavaHome({
    required AndroidStudio? androidStudio,
    required FileSystem fileSystem,
    required OperatingSystemUtils operatingSystemUtils,
    required Platform platform,
  }) {
    if (androidStudio?.javaPath != null) {
      globals.printTrace("Using Android Studio's java.");
      return androidStudio!.javaPath!;
    }

    final String? javaHomeEnv = platform.environment[javaHomeEnvironmentVariable];
    if (javaHomeEnv != null) {
      globals.printTrace('Using JAVA_HOME from environment valuables.');
      return javaHomeEnv;
    }
    return null;
  }

  /// Finds the java binary that is used for all operations across the tool.
  ///
  /// This comes from [findJavaHome] if that method returns non-null;
  /// otherwise, it gets from searching PATH.
  // TODO(andrewkolos): To prevent confusion when debugging Android-related
  // issues (see https://github.com/flutter/flutter/issues/122609 for an example),
  // this logic should be consistently followed by any Java-dependent operation
  // across the  the tool (building Android apps, interacting with the Android SDK, etc.).
  // Currently, this consistency is fragile since the logic used for building
  // Android apps exists independently of this method.
  // See https://github.com/flutter/flutter/issues/124252.
  static String? findJavaBinary({
    required AndroidStudio? androidStudio,
    required FileSystem fileSystem,
    required OperatingSystemUtils operatingSystemUtils,
    required Platform platform,
  }) {
    final String? javaHome = findJavaHome(
      androidStudio: androidStudio,
      fileSystem: fileSystem,
      operatingSystemUtils: operatingSystemUtils,
      platform: platform,
    );

    if (javaHome != null) {
      return fileSystem.path.join(javaHome, 'bin', 'java');
    }

    // Fallback to PATH based lookup.
    final String? pathJava = operatingSystemUtils.which(_javaExecutable)?.path;
    if (pathJava != null) {
      globals.printTrace('Using java from PATH.');
    } else {
      globals.printTrace('Could not find java path.');
    }
    return pathJava;
  }

  // Returns a user visible String that says the tool failed to parse
  // the version of java along with the output.
  static String _formatJavaVersionWarning(String javaVersionRaw) {
    return 'Could not parse java version from: \n'
        '$javaVersionRaw \n'
        'If there is a version please look for an existing bug '
        'https://github.com/flutter/flutter/issues/'
        ' and if one does not exist file a new issue.';
  }

  Map<String, String>? _sdkManagerEnv;

  /// Returns an environment with the Java folder added to PATH for use in calling
  /// Java-based Android SDK commands such as sdkmanager and avdmanager.
  Map<String, String> get sdkManagerEnv {
    if (_sdkManagerEnv == null) {
      // If we can locate Java, then add it to the path used to run the Android SDK manager.
      _sdkManagerEnv = <String, String>{};
      final String? javaBinary = findJavaBinary(
        androidStudio: globals.androidStudio,
        fileSystem: globals.fs,
        operatingSystemUtils: globals.os,
        platform: globals.platform,
      );
      if (javaBinary != null && globals.platform.environment['PATH'] != null) {
        _sdkManagerEnv!['PATH'] = globals.fs.path.dirname(javaBinary) +
                                  globals.os.pathVarSeparator +
                                  globals.platform.environment['PATH']!;
      }
    }
    return _sdkManagerEnv!;
  }

=======
>>>>>>> e1e47221e86272429674bec4f1bd36acc4fc7b77
  /// Returns the version of the Android SDK manager tool or null if not found.
  String? get sdkManagerVersion {
    if (sdkManagerPath == null || !globals.processManager.canRun(sdkManagerPath)) {
      throwToolExit(
        'Android sdkmanager not found. Update to the latest Android SDK and ensure that '
        'the cmdline-tools are installed to resolve this.'
      );
    }
    final RunResult result = globals.processUtils.runSync(
      <String>[sdkManagerPath!, '--version'],
      environment: _java?.environment,
    );
    if (result.exitCode != 0) {
      globals.printTrace('sdkmanager --version failed: exitCode: ${result.exitCode} stdout: ${result.stdout} stderr: ${result.stderr}');
      return null;
    }
    return result.stdout.trim();
  }

  @override
  String toString() => 'AndroidSdk: $directory';
}

class AndroidSdkVersion implements Comparable<AndroidSdkVersion> {
  AndroidSdkVersion._(
    this.sdk, {
    required this.sdkLevel,
    required this.platformName,
    required this.buildToolsVersion,
    required FileSystem fileSystem,
  }) : _fileSystem = fileSystem;

  final AndroidSdk sdk;
  final int sdkLevel;
  final String platformName;
  final Version buildToolsVersion;

  final FileSystem _fileSystem;

  String get buildToolsVersionName => buildToolsVersion.toString();

  String get androidJarPath => getPlatformsPath('android.jar');

  /// Return the path to the android application package tool.
  ///
  /// This is used to dump the xml in order to launch built android applications.
  ///
  /// See also:
  ///   * [AndroidApk.fromApk], which depends on this to determine application identifiers.
  String get aaptPath => getBuildToolsPath('aapt');

  List<String> validateSdkWellFormed() {
    final String? existsAndroidJarPath = _exists(androidJarPath);
    if (existsAndroidJarPath != null) {
      return <String>[existsAndroidJarPath];
    }

    final String? canRunAaptPath = _canRun(aaptPath);
    if (canRunAaptPath != null) {
      return <String>[canRunAaptPath];
    }

    return <String>[];
  }

  String getPlatformsPath(String itemName) {
    return sdk.directory.childDirectory('platforms').childDirectory(platformName).childFile(itemName).path;
  }

  String getBuildToolsPath(String binaryName) {
    return sdk.directory.childDirectory('build-tools').childDirectory(buildToolsVersionName).childFile(binaryName).path;
  }

  @override
  int compareTo(AndroidSdkVersion other) => sdkLevel - other.sdkLevel;

  @override
  String toString() => '[${sdk.directory}, SDK version $sdkLevel, build-tools $buildToolsVersionName]';

  String? _exists(String path) {
    if (!_fileSystem.isFileSync(path)) {
      return 'Android SDK file not found: $path.';
    }
    return null;
  }

  String? _canRun(String path) {
    if (!globals.processManager.canRun(path)) {
      return 'Android SDK file not found: $path.';
    }
    return null;
  }
}
