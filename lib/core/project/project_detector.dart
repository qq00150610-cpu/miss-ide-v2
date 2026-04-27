import 'dart:io';
import 'package:path/path.dart' as path;
import '../../models/project.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 项目检测器
class ProjectDetector {
  static final ProjectDetector _instance = ProjectDetector._internal();
  factory ProjectDetector() => _instance;
  ProjectDetector._internal();

  /// 检测项目类型
  ProjectType detect(String projectPath) {
    final dir = Directory(projectPath);
    
    // 检查Flutter
    if (_hasFile(dir, 'pubspec.yaml')) {
      return ProjectType.flutter;
    }
    
    // 检查Android
    if (_hasFile(dir, 'settings.gradle') ||
        _hasFile(dir, 'settings.gradle.kts') ||
        _hasFile(dir, 'build.gradle') ||
        _hasFile(dir, 'build.gradle.kts')) {
      return ProjectType.android;
    }
    
    // 检查iOS
    if (_hasPattern(dir, r'\.xcodeproj$') ||
        _hasPattern(dir, r'\.xcworkspace$')) {
      return ProjectType.ios;
    }
    
    // 检查Node.js
    if (_hasFile(dir, 'package.json')) {
      return ProjectType.nodejs;
    }
    
    // 检查Python
    if (_hasFile(dir, 'requirements.txt') ||
        _hasFile(dir, 'setup.py') ||
        _hasFile(dir, 'pyproject.toml') ||
        _hasFile(dir, 'Pipfile')) {
      return ProjectType.python;
    }
    
    // 检查Java (Maven)
    if (_hasFile(dir, 'pom.xml')) {
      return ProjectType.java;
    }

    // 检查Go
    if (_hasFile(dir, 'go.mod')) {
      return ProjectType.unknown; // 可以扩展为ProjectType.go
    }

    // 检查Rust
    if (_hasFile(dir, 'Cargo.toml')) {
      return ProjectType.unknown; // 可以扩展为ProjectType.rust
    }

    return ProjectType.unknown;
  }

  /// 检查文件是否存在
  bool _hasFile(Directory dir, String fileName) {
    return File(path.join(dir.path, fileName)).existsSync();
  }

  /// 检查是否匹配模式
  bool _hasPattern(Directory dir, String pattern) {
    try {
      final regex = RegExp(pattern);
      return dir.listSync().any((entity) {
        if (entity is File) {
          return regex.hasMatch(entity.path);
        }
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  /// 获取项目信息
  Future<ProjectInfo?> getProjectInfo(String projectPath) async {
    final type = detect(projectPath);
    if (type == ProjectType.unknown) {
      return null;
    }

    final dir = Directory(projectPath);
    final name = path.basename(projectPath);
    
    // 尝试从配置文件读取版本信息
    String? gradleVersion;
    String? kotlinVersion;
    String? javaVersion;

    if (type == ProjectType.android || type == ProjectType.flutter) {
      // 读取build.gradle
      final buildGradle = File(path.join(projectPath, 'build.gradle'));
      if (await buildGradle.exists()) {
        final content = await buildGradle.readAsString();
        gradleVersion = _extractVersion(content, r'gradle[\'":/]+(\d+\.\d+(?:\.\d+)?)');
        kotlinVersion = _extractVersion(content, r'kotlin[\'":/]+(\d+\.\d+(?:\.\d+)?)');
        javaVersion = _extractVersion(content, r'sourceCompatibility[\'":/]+JavaVersion\.VERSION_(\d+)');
      }
    }

    if (type == ProjectType.flutter) {
      final pubspec = File(path.join(projectPath, 'pubspec.yaml'));
      if (await pubspec.exists()) {
        final content = await pubspec.readAsString();
        kotlinVersion = _extractVersion(content, r'sdk:\s*[\'"]>=(\d+\.\d+)');
      }
    }

    // 统计源文件
    final sourceFiles = await _countSourceFiles(dir, type);

    return ProjectInfo(
      name: name,
      path: projectPath,
      type: type,
      gradleVersion: gradleVersion,
      kotlinVersion: kotlinVersion,
      javaVersion: javaVersion,
      sourceFiles: sourceFiles,
    );
  }

  /// 提取版本号
  String? _extractVersion(String content, String pattern) {
    try {
      final regex = RegExp(pattern);
      final match = regex.firstMatch(content);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// 统计源文件数量
  Future<int> _countSourceFiles(Directory dir, ProjectType type) async {
    int count = 0;
    
    final extensions = _getSourceExtensions(type);
    if (extensions.isEmpty) return 0;

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase().replaceFirst('.', '');
          if (extensions.contains(ext)) {
            // 排除build、.dart_tool等目录
            if (!entity.path.contains('/build/') &&
                !entity.path.contains('/.dart_tool/') &&
                !entity.path.contains('/.gradle/') &&
                !entity.path.contains('/node_modules/')) {
              count++;
            }
          }
        }
      }
    } catch (_) {}

    return count;
  }

  /// 获取源文件扩展名
  List<String> _getSourceExtensions(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
      case ProjectType.kotlin:
        return ['kt', 'dart'];
      case ProjectType.android:
        return ['kt', 'java', 'xml', 'gradle'];
      case ProjectType.java:
        return ['java', 'xml'];
      case ProjectType.nodejs:
        return ['js', 'ts', 'json'];
      case ProjectType.python:
        return ['py', 'txt'];
      case ProjectType.ios:
        return ['swift', 'm', 'h', 'plist'];
      default:
        return [];
    }
  }
}

/// 项目信息
class ProjectInfo {
  final String name;
  final String path;
  final ProjectType type;
  final String? gradleVersion;
  final String? kotlinVersion;
  final String? javaVersion;
  final int sourceFiles;

  const ProjectInfo({
    required this.name,
    required this.path,
    required this.type,
    this.gradleVersion,
    this.kotlinVersion,
    this.javaVersion,
    this.sourceFiles = 0,
  });
}

/// 全局实例
final projectDetector = ProjectDetector();
