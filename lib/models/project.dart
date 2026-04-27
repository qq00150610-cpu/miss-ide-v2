import '../utils/constants.dart';

/// 项目信息模型
class Project {
  final String id;
  final String name;
  final String path;
  final ProjectType type;
  final DateTime createdAt;
  final DateTime lastOpenedAt;
  final ProjectConfig config;

  const Project({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.createdAt,
    required this.lastOpenedAt,
    required this.config,
  });

  Project copyWith({
    String? id,
    String? name,
    String? path,
    ProjectType? type,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    ProjectConfig? config,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type.id,
      'createdAt': createdAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'config': config.toJson(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      type: ProjectType.fromId(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      config: ProjectConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }
}

/// 项目配置
class ProjectConfig {
  final String? gradleVersion;
  final String? kotlinVersion;
  final String? flutterVersion;
  final String? javaVersion;
  final String? nodeVersion;
  final String? pythonVersion;
  final int? minSdkVersion;
  final int? targetSdkVersion;
  final List<String> sourceDirs;
  final List<String> assetDirs;
  final Map<String, String> environmentVars;

  const ProjectConfig({
    this.gradleVersion,
    this.kotlinVersion,
    this.flutterVersion,
    this.javaVersion,
    this.nodeVersion,
    this.pythonVersion,
    this.minSdkVersion,
    this.targetSdkVersion,
    this.sourceDirs = const ['lib', 'src'],
    this.assetDirs = const ['assets'],
    this.environmentVars = const {},
  });

  ProjectConfig copyWith({
    String? gradleVersion,
    String? kotlinVersion,
    String? flutterVersion,
    String? javaVersion,
    String? nodeVersion,
    String? pythonVersion,
    int? minSdkVersion,
    int? targetSdkVersion,
    List<String>? sourceDirs,
    List<String>? assetDirs,
    Map<String, String>? environmentVars,
  }) {
    return ProjectConfig(
      gradleVersion: gradleVersion ?? this.gradleVersion,
      kotlinVersion: kotlinVersion ?? this.kotlinVersion,
      flutterVersion: flutterVersion ?? this.flutterVersion,
      javaVersion: javaVersion ?? this.javaVersion,
      nodeVersion: nodeVersion ?? this.nodeVersion,
      pythonVersion: pythonVersion ?? this.pythonVersion,
      minSdkVersion: minSdkVersion ?? this.minSdkVersion,
      targetSdkVersion: targetSdkVersion ?? this.targetSdkVersion,
      sourceDirs: sourceDirs ?? this.sourceDirs,
      assetDirs: assetDirs ?? this.assetDirs,
      environmentVars: environmentVars ?? this.environmentVars,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gradleVersion': gradleVersion,
      'kotlinVersion': kotlinVersion,
      'flutterVersion': flutterVersion,
      'javaVersion': javaVersion,
      'nodeVersion': nodeVersion,
      'pythonVersion': pythonVersion,
      'minSdkVersion': minSdkVersion,
      'targetSdkVersion': targetSdkVersion,
      'sourceDirs': sourceDirs,
      'assetDirs': assetDirs,
      'environmentVars': environmentVars,
    };
  }

  factory ProjectConfig.fromJson(Map<String, dynamic> json) {
    return ProjectConfig(
      gradleVersion: json['gradleVersion'] as String?,
      kotlinVersion: json['kotlinVersion'] as String?,
      flutterVersion: json['flutterVersion'] as String?,
      javaVersion: json['javaVersion'] as String?,
      nodeVersion: json['nodeVersion'] as String?,
      pythonVersion: json['pythonVersion'] as String?,
      minSdkVersion: json['minSdkVersion'] as int?,
      targetSdkVersion: json['targetSdkVersion'] as int?,
      sourceDirs: List<String>.from(json['sourceDirs'] ?? ['lib', 'src']),
      assetDirs: List<String>.from(json['assetDirs'] ?? ['assets']),
      environmentVars: Map<String, String>.from(json['environmentVars'] ?? {}),
    );
  }

  static ProjectConfig defaultForType(ProjectType type) {
    switch (type) {
      case ProjectType.android:
        return const ProjectConfig(
          gradleVersion: '8.2',
          kotlinVersion: '1.9.20',
          javaVersion: '17',
          minSdkVersion: 24,
          targetSdkVersion: 34,
        );
      case ProjectType.flutter:
        return const ProjectConfig(
          flutterVersion: '3.16.0',
          javaVersion: '17',
        );
      case ProjectType.ios:
        return const ProjectConfig();
      case ProjectType.nodejs:
        return const ProjectConfig(nodeVersion: '20');
      case ProjectType.python:
        return const ProjectConfig(pythonVersion: '3.11');
      case ProjectType.java:
        return const ProjectConfig(javaVersion: '17');
      default:
        return const ProjectConfig();
    }
  }
}

/// 文件信息
class FileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
  final ProgrammingLanguage? language;

  const FileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
    this.language,
  });

  String get extension {
    if (isDirectory) return '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  bool get isHidden => name.startsWith('.');

  String get sizeDisplay {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'modifiedAt': modifiedAt?.toIso8601String(),
      'language': language?.name,
    };
  }

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'] as String,
      path: json['path'] as String,
      isDirectory: json['isDirectory'] as bool,
      size: json['size'] as int?,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      language: json['language'] != null
          ? ProgrammingLanguage.values.firstWhere(
              (e) => e.name == json['language'],
              orElse: () => ProgrammingLanguage.unknown,
            )
          : null,
    );
  }
}
