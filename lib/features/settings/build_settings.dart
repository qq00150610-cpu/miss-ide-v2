import '../../core/build_system/sdk_manager.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';
import '../../utils/secure_storage.dart';

/// 构建设置
class BuildSettings {
  static final BuildSettings _instance = BuildSettings._internal();
  factory BuildSettings() => _instance;
  BuildSettings._internal();

  final SecureStorage _storage = secureStorage;

  // 构建选项
  bool _incrementalBuild = true;
  bool _parallelBuild = true;
  bool _verboseBuild = false;
  bool _autoCleanBeforeBuild = false;

  // Android 选项
  String _androidVariant = 'debug';
  bool _enableR8 = false;
  int _minSdkVersion = 24;
  int _targetSdkVersion = 34;

  // 获取设置
  bool get incrementalBuild => _incrementalBuild;
  bool get parallelBuild => _parallelBuild;
  bool get verboseBuild => _verboseBuild;
  bool get autoCleanBeforeBuild => _autoCleanBeforeBuild;
  String get androidVariant => _androidVariant;
  bool get enableR8 => _enableR8;
  int get minSdkVersion => _minSdkVersion;
  int get targetSdkVersion => _targetSdkVersion;

  /// 加载设置
  Future<void> loadSettings() async {
    try {
      final json = await _storage.getConfig(AppConstants.keyBuildConfig);
      if (json != null) {
        _incrementalBuild = json['incrementalBuild'] as bool? ?? true;
        _parallelBuild = json['parallelBuild'] as bool? ?? true;
        _verboseBuild = json['verboseBuild'] as bool? ?? false;
        _autoCleanBeforeBuild = json['autoCleanBeforeBuild'] as bool? ?? false;
        _androidVariant = json['androidVariant'] as String? ?? 'debug';
        _enableR8 = json['enableR8'] as bool? ?? false;
        _minSdkVersion = json['minSdkVersion'] as int? ?? 24;
        _targetSdkVersion = json['targetSdkVersion'] as int? ?? 34;
      }
      logger.i(LogTags.settings, 'Build settings loaded');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to load build settings', error: e);
    }
  }

  /// 保存设置
  Future<void> saveSettings() async {
    try {
      await _storage.saveConfig(AppConstants.keyBuildConfig, {
        'incrementalBuild': _incrementalBuild,
        'parallelBuild': _parallelBuild,
        'verboseBuild': _verboseBuild,
        'autoCleanBeforeBuild': _autoCleanBeforeBuild,
        'androidVariant': _androidVariant,
        'enableR8': _enableR8,
        'minSdkVersion': _minSdkVersion,
        'targetSdkVersion': _targetSdkVersion,
      });
      logger.i(LogTags.settings, 'Build settings saved');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to save build settings', error: e);
    }
  }

  /// 更新设置
  Future<void> setIncrementalBuild(bool value) async {
    _incrementalBuild = value;
    await saveSettings();
  }

  Future<void> setParallelBuild(bool value) async {
    _parallelBuild = value;
    await saveSettings();
  }

  Future<void> setVerboseBuild(bool value) async {
    _verboseBuild = value;
    await saveSettings();
  }

  Future<void> setAutoCleanBeforeBuild(bool value) async {
    _autoCleanBeforeBuild = value;
    await saveSettings();
  }

  Future<void> setAndroidVariant(String value) async {
    _androidVariant = value;
    await saveSettings();
  }

  Future<void> setEnableR8(bool value) async {
    _enableR8 = value;
    await saveSettings();
  }

  Future<void> setMinSdkVersion(int value) async {
    _minSdkVersion = value;
    await saveSettings();
  }

  Future<void> setTargetSdkVersion(int value) async {
    _targetSdkVersion = value;
    await saveSettings();
  }

  /// 获取SDK信息
  SDKInfo getSDKInfo() {
    return SDKInfo(
      javaInstalled: sdkManager.isInstalled('java-17'),
      kotlinInstalled: sdkManager.isInstalled('kotlin-compiler'),
      gradleInstalled: sdkManager.isInstalled('gradle-wrapper'),
      androidBuildToolsInstalled: sdkManager.isInstalled('android-build-tools'),
      androidPlatformInstalled: sdkManager.isInstalled('android-platform-34'),
      androidNdkInstalled: sdkManager.isInstalled('android-ndk-r26b'),
      pythonInstalled: sdkManager.isInstalled('python-3.11'),
      nodejsInstalled: sdkManager.isInstalled('nodejs-20'),
    );
  }
}

/// SDK 信息
class SDKInfo {
  final bool javaInstalled;
  final bool kotlinInstalled;
  final bool gradleInstalled;
  final bool androidBuildToolsInstalled;
  final bool androidPlatformInstalled;
  final bool androidNdkInstalled;
  final bool pythonInstalled;
  final bool nodejsInstalled;

  const SDKInfo({
    this.javaInstalled = false,
    this.kotlinInstalled = false,
    this.gradleInstalled = false,
    this.androidBuildToolsInstalled = false,
    this.androidPlatformInstalled = false,
    this.androidNdkInstalled = false,
    this.pythonInstalled = false,
    this.nodejsInstalled = false,
  });

  int get installedCount {
    int count = 0;
    if (javaInstalled) count++;
    if (kotlinInstalled) count++;
    if (gradleInstalled) count++;
    if (androidBuildToolsInstalled) count++;
    if (androidPlatformInstalled) count++;
    if (androidNdkInstalled) count++;
    if (pythonInstalled) count++;
    if (nodejsInstalled) count++;
    return count;
  }

  int get totalCount => 8;

  bool get isFullyInstalled => installedCount == totalCount;
}

/// 全局实例
final buildSettings = BuildSettings();
