import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../models/project.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 依赖解析器
class DependencyResolver {
  static final DependencyResolver _instance = DependencyResolver._internal();
  factory DependencyResolver() => _instance;
  DependencyResolver._internal();

  /// 解析项目依赖
  Future<DependencyInfo> resolve(String projectPath, ProjectType type) async {
    logger.i(LogTags.project, 'Resolving dependencies for: $projectPath');

    switch (type) {
      case ProjectType.flutter:
        return await _resolveFlutter(projectPath);
      case ProjectType.android:
        return await _resolveAndroid(projectPath);
      case ProjectType.nodejs:
        return await _resolveNodeJS(projectPath);
      case ProjectType.python:
        return await _resolvePython(projectPath);
      default:
        return const DependencyInfo(dependencies: [], devDependencies: []);
    }
  }

  /// 解析 Flutter 依赖
  Future<DependencyInfo> _resolveFlutter(String projectPath) async {
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      return const DependencyInfo(dependencies: []);
    }

    try {
      final content = await pubspecFile.readAsString();
      final dependencies = _parseYamlDependencies(content);
      return DependencyInfo(
        dependencies: dependencies,
        source: 'pubspec.yaml',
      );
    } catch (e) {
      logger.e(LogTags.project, 'Failed to parse pubspec.yaml', error: e);
      return const DependencyInfo(dependencies: []);
    }
  }

  /// 解析 Android 依赖
  Future<DependencyInfo> _resolveAndroid(String projectPath) async {
    final buildFile = File(path.join(projectPath, 'app', 'build.gradle'));
    if (!await buildFile.exists()) {
      return const DependencyInfo(dependencies: []);
    }

    try {
      final content = await buildFile.readAsString();
      final dependencies = _parseGradleDependencies(content);
      return DependencyInfo(
        dependencies: dependencies,
        source: 'build.gradle',
      );
    } catch (e) {
      logger.e(LogTags.project, 'Failed to parse build.gradle', error: e);
      return const DependencyInfo(dependencies: []);
    }
  }

  /// 解析 Node.js 依赖
  Future<DependencyInfo> _resolveNodeJS(String projectPath) async {
    final packageFile = File(path.join(projectPath, 'package.json'));
    if (!await packageFile.exists()) {
      return const DependencyInfo(dependencies: []);
    }

    try {
      final content = await packageFile.readAsString();
      final json = jsonDecode(content);
      
      final dependencies = <DependencyPackage>[];
      final devDependencies = <DependencyPackage>[];

      final deps = json['dependencies'] as Map<String, dynamic>?;
      if (deps != null) {
        deps.forEach((name, version) {
          dependencies.add(DependencyPackage(
            name: name,
            version: version.toString(),
          ));
        });
      }

      final devDeps = json['devDependencies'] as Map<String, dynamic>?;
      if (devDeps != null) {
        devDeps.forEach((name, version) {
          devDependencies.add(DependencyPackage(
            name: name,
            version: version.toString(),
          ));
        });
      }

      return DependencyInfo(
        dependencies: dependencies,
        devDependencies: devDependencies,
        source: 'package.json',
      );
    } catch (e) {
      logger.e(LogTags.project, 'Failed to parse package.json', error: e);
      return const DependencyInfo(dependencies: []);
    }
  }

  /// 解析 Python 依赖
  Future<DependencyInfo> _resolvePython(String projectPath) async {
    final requirementsFile = File(path.join(projectPath, 'requirements.txt'));
    if (!await requirementsFile.exists()) {
      return const DependencyInfo(dependencies: []);
    }

    try {
      final content = await requirementsFile.readAsString();
      final dependencies = <DependencyPackage>[];
      
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        
        final parts = trimmed.split(RegExp(r'[=<>~!]'));
        if (parts.isNotEmpty) {
          dependencies.add(DependencyPackage(
            name: parts[0].trim(),
            version: trimmed.contains('==') ? '==${parts[1].trim()}' : 'latest',
          ));
        }
      }

      return DependencyInfo(
        dependencies: dependencies,
        source: 'requirements.txt',
      );
    } catch (e) {
      logger.e(LogTags.project, 'Failed to parse requirements.txt', error: e);
      return const DependencyInfo(dependencies: []);
    }
  }

  /// 解析 YAML 格式的依赖（简化版）
  List<DependencyPackage> _parseYamlDependencies(String content) {
    final dependencies = <DependencyPackage>[];
    final lines = content.split('\n');
    var inDependencies = false;

    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed == 'dependencies:') {
        inDependencies = true;
        continue;
      } else if (trimmed.startsWith('dev_dependencies:') ||
                 trimmed.startsWith('environment:')) {
        inDependencies = false;
      }

      if (inDependencies && trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          var version = parts.sublist(1).join(':').trim();
          
          // 移除引号
          version = version.replaceAll("'", '').replaceAll('"', '');
          
          if (name.isNotEmpty && !name.startsWith('#')) {
            dependencies.add(DependencyPackage(
              name: name,
              version: version.isEmpty ? 'any' : version,
            ));
          }
        }
      }
    }

    return dependencies;
  }

  /// 解析 Gradle 格式的依赖（简化版）
  List<DependencyPackage> _parseGradleDependencies(String content) {
    final dependencies = <DependencyPackage>[];
    final regex = RegExp(r'(implementation|api|compile)\s+[\'"]([^\'":]+):([^\'"@]+):([^\'"@]+)');

    for (final match in regex.allMatches(content)) {
      final group = match.group(2)!;
      final name = match.group(3)!;
      final version = match.group(4)!;
      
      dependencies.add(DependencyPackage(
        name: '$group:$name',
        version: version,
      ));
    }

    return dependencies;
  }

  /// 获取依赖的最新版本
  Future<String?> getLatestVersion(String packageName, String source) async {
    // 可以集成 pub.dev 或 npm 等包管理器的 API
    // 这里返回 null 表示使用锁定版本
    return null;
  }
}

/// 依赖信息
class DependencyInfo {
  final List<DependencyPackage> dependencies;
  final List<DependencyPackage> devDependencies;
  final String? source;

  const DependencyInfo({
    this.dependencies = const [],
    this.devDependencies = const [],
    this.source,
  });

  int get totalCount => dependencies.length + devDependencies.length;
}

/// 依赖包
class DependencyPackage {
  final String name;
  final String version;
  final String? latestVersion;
  final bool isOutdated;

  const DependencyPackage({
    required this.name,
    required this.version,
    this.latestVersion,
  }) : isOutdated = latestVersion != null && latestVersion != version;

  String get displayVersion => latestVersion ?? version;
}

/// 全局实例
final dependencyResolver = DependencyResolver();
