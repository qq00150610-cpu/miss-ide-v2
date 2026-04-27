import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../models/build_result.dart';
import '../../models/project.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// SDK组件信息
class SDKComponent {
  final String id;
  final String name;
  final int size;
  final bool optional;
  final String downloadUrl;
  final String version;

  const SDKComponent({
    required this.id,
    required this.name,
    required this.size,
    required this.optional,
    required this.downloadUrl,
    required this.version,
  });

  String get sizeDisplay {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// SDK管理器
class SDKManager {
  static final SDKManager _instance = SDKManager._internal();
  factory SDKManager() => _instance;
  SDKManager._internal();

  final Map<String, SDKComponent> _components = {};
  final Map<String, bool> _installedComponents = {};
  String? _sdkPath;
  bool _initialized = false;

  /// SDK组件清单
  static final List<SDKComponent> manifest = [
    // 内置组件
    const SDKComponent(
      id: 'java-17',
      name: 'OpenJDK 17',
      size: 80 * 1024 * 1024,
      optional: false,
      downloadUrl: '',
      version: '17.0.2',
    ),
    const SDKComponent(
      id: 'kotlin-compiler',
      name: 'Kotlin Compiler',
      size: 50 * 1024 * 1024,
      optional: false,
      downloadUrl: '',
      version: '1.9.20',
    ),
    const SDKComponent(
      id: 'android-build-tools',
      name: 'Android Build Tools',
      size: 165 * 1024 * 1024,
      optional: false,
      downloadUrl: '',
      version: '34.0.0',
    ),
    const SDKComponent(
      id: 'gradle-wrapper',
      name: 'Gradle Wrapper',
      size: 5 * 1024 * 1024,
      optional: false,
      downloadUrl: '',
      version: '8.2',
    ),

    // 按需下载组件
    const SDKComponent(
      id: 'android-platform-34',
      name: 'Android Platform 34',
      size: 100 * 1024 * 1024,
      optional: true,
      downloadUrl: '',
      version: '34',
    ),
    const SDKComponent(
      id: 'android-ndk-r26b',
      name: 'Android NDK r26b',
      size: 500 * 1024 * 1024,
      optional: true,
      downloadUrl: '',
      version: 'r26b',
    ),
    const SDKComponent(
      id: 'python-3.11',
      name: 'Python 3.11',
      size: 30 * 1024 * 1024,
      optional: true,
      downloadUrl: '',
      version: '3.11',
    ),
    const SDKComponent(
      id: 'nodejs-20',
      name: 'Node.js 20',
      size: 40 * 1024 * 1024,
      optional: true,
      downloadUrl: '',
      version: '20',
    ),
  ];

  /// 初始化SDK管理器
  Future<void> init(String appDataPath) async {
    if (_initialized) return;

    _sdkPath = path.join(appDataPath, 'sdk-cache');
    
    // 确保SDK目录存在
    final sdkDir = Directory(_sdkPath!);
    if (!await sdkDir.exists()) {
      await sdkDir.create(recursive: true);
    }

    // 加载已安装组件状态
    await _loadInstalledStatus();

    _initialized = true;
    logger.i(LogTags.build, 'SDKManager initialized at: $_sdkPath');
  }

  /// 获取SDK路径
  String get sdkPath => _sdkPath ?? '';

  /// 获取组件路径
  String getComponentPath(String componentId) {
    return path.join(_sdkPath ?? '', componentId);
  }

  /// 检查组件是否已安装
  bool isInstalled(String componentId) {
    return _installedComponents[componentId] ?? false;
  }

  /// 获取所有内置组件
  List<SDKComponent> get builtInComponents {
    return manifest.where((c) => !c.optional).toList();
  }

  /// 获取所有可选组件
  List<SDKComponent> get optionalComponents {
    return manifest.where((c) => c.optional).toList();
  }

  /// 获取需要安装的组件
  Future<List<SDKComponent>> getRequiredComponents(ProjectType type) async {
    final required = <SDKComponent>[];

    // 内置组件始终需要
    required.addAll(builtInComponents);

    // 根据项目类型添加可选组件
    switch (type) {
      case ProjectType.android:
      case ProjectType.flutter:
        if (!isInstalled('android-platform-34')) {
          required.add(manifest.firstWhere((c) => c.id == 'android-platform-34'));
        }
        break;
      case ProjectType.python:
        if (!isInstalled('python-3.11')) {
          required.add(manifest.firstWhere((c) => c.id == 'python-3.11'));
        }
        break;
      case ProjectType.nodejs:
        if (!isInstalled('nodejs-20')) {
          required.add(manifest.firstWhere((c) => c.id == 'nodejs-20'));
        }
        break;
      default:
        break;
    }

    return required;
  }

  /// 安装组件
  Future<bool> installComponent(
    String componentId, {
    void Function(double progress)? onProgress,
  }) async {
    final component = manifest.firstWhere(
      (c) => c.id == componentId,
      orElse: () => throw Exception('Component not found: $componentId'),
    );

    if (component.downloadUrl.isEmpty) {
      // 内置组件，标记为已安装
      _installedComponents[componentId] = true;
      await _saveInstalledStatus();
      logger.i(LogTags.build, 'Built-in component marked as installed: $componentId');
      return true;
    }

    try {
      // 下载并解压组件
      onProgress?.call(0.1);
      
      // TODO: 实现下载逻辑
      // final downloadPath = await _downloadComponent(component, onProgress);
      // await _extractComponent(downloadPath, componentId);
      
      onProgress?.call(1.0);
      
      _installedComponents[componentId] = true;
      await _saveInstalledStatus();
      
      logger.i(LogTags.build, 'Component installed: $componentId');
      return true;
    } catch (e) {
      logger.e(LogTags.build, 'Failed to install component: $componentId', error: e);
      return false;
    }
  }

  /// 卸载组件
  Future<bool> uninstallComponent(String componentId) async {
    if (!isInstalled(componentId)) return true;

    try {
      final componentPath = getComponentPath(componentId);
      final dir = Directory(componentPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }

      _installedComponents[componentId] = false;
      await _saveInstalledStatus();

      logger.i(LogTags.build, 'Component uninstalled: $componentId');
      return true;
    } catch (e) {
      logger.e(LogTags.build, 'Failed to uninstall component: $componentId', error: e);
      return false;
    }
  }

  /// 获取Java路径
  String? getJavaPath() {
    if (!isInstalled('java-17')) return null;
    final javaPath = path.join(getComponentPath('java-17'), 'bin', 'java');
    return Platform.isWindows ? '$javaPath.exe' : javaPath;
  }

  /// 获取Kotlin编译器路径
  String? getKotlincPath() {
    if (!isInstalled('kotlin-compiler')) return null;
    final kotlincPath = path.join(getComponentPath('kotlin-compiler'), 'bin', 'kotlinc');
    return Platform.isWindows ? '$kotlincPath.exe' : kotlincPath;
  }

  /// 获取Gradle路径
  String? getGradlePath() {
    if (!isInstalled('gradle-wrapper')) return null;
    final gradlePath = path.join(getComponentPath('gradle-wrapper'), 'bin', 'gradle');
    return Platform.isWindows ? '$gradlePath.bat' : gradlePath;
  }

  /// 获取Android SDK路径
  String? getAndroidSdkPath() {
    return _sdkPath;
  }

  /// 加载已安装状态
  Future<void> _loadInstalledStatus() async {
    final statusFile = File(path.join(_sdkPath ?? '', 'installed.json'));
    if (await statusFile.exists()) {
      try {
        final content = await statusFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _installedComponents.clear();
        _installedComponents.addAll(
          data.map((k, v) => MapEntry(k, v as bool)),
        );
      } catch (e) {
        logger.e(LogTags.build, 'Failed to load SDK status', error: e);
      }
    }

    // 标记内置组件为已安装
    for (final component in builtInComponents) {
      _installedComponents[component.id] = true;
    }
  }

  /// 保存已安装状态
  Future<void> _saveInstalledStatus() async {
    final statusFile = File(path.join(_sdkPath ?? '', 'installed.json'));
    await statusFile.writeAsString(jsonEncode(_installedComponents));
  }
}

/// 全局SDK管理器实例
final sdkManager = SDKManager();
