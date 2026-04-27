import 'package:flutter/material.dart';

/// Miss IDE 全局常量
class AppConstants {
  AppConstants._();

  // 应用信息
  static const String appName = 'Miss IDE';
  static const String appVersion = '2.0.0';
  static const String appDescription = '移动端智能集成开发环境';

  // 存储键
  static const String keyAiConfig = 'ai_config';
  static const String keyBuildConfig = 'build_config';
  static const String keyThemeConfig = 'theme_config';
  static const String keyRecentProjects = 'recent_projects';
  static const String keyRecentFiles = 'recent_files';
  static const String keyEditorState = 'editor_state';

  // API超时设置
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration streamTimeout = Duration(minutes: 5);

  // 编辑器配置
  static const int maxOpenFiles = 20;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int autocompleteDebounce = 300; // ms

  // 构建配置
  static const int incrementalBuildThreshold = 5; // 秒
  static const int maxBuildCacheSize = 500 * 1024 * 1024; // 500MB

  // AI配置
  static const int maxTokensDefault = 2048;
  static const double temperatureDefault = 0.7;
  static const int maxHistoryMessages = 50;

  // 终端配置
  static const int maxTerminalHistory = 1000;
  static const int terminalBufferSize = 10000;

  // 支持的文件类型
  static const List<String> supportedCodeExtensions = [
    'dart', 'kt', 'java', 'py', 'js', 'ts', 'jsx', 'tsx',
    'c', 'cpp', 'h', 'hpp', 'cs', 'go', 'rs', 'swift',
    'rb', 'php', 'html', 'css', 'scss', 'json', 'yaml', 'xml',
    'sql', 'sh', 'bash', 'md', 'txt'
  ];

  // 项目类型
  static const Map<String, List<String>> projectIndicators = {
    'android': ['build.gradle', 'settings.gradle', 'app/src/main'],
    'flutter': ['pubspec.yaml', 'lib/main.dart'],
    'ios': ['*.xcodeproj', '*.xcworkspace'],
    'nodejs': ['package.json'],
    'python': ['requirements.txt', 'setup.py', 'pyproject.toml'],
    'java': ['pom.xml', 'build.gradle'],
    'gradle': ['settings.gradle.kts', 'build.gradle.kts'],
  };
}

/// 错误码
class ErrorCodes {
  ErrorCodes._();

  static const int success = 0;
  static const int unknown = 1;
  static const int fileNotFound = 2;
  static const int permissionDenied = 3;
  static const int buildFailed = 4;
  static const int aiApiError = 5;
  static const int networkError = 6;
  static const int invalidConfig = 7;
  static const int sdkNotFound = 8;
  static const int compilationError = 9;
}

/// AI模型相关常量
class AIConstants {
  AIConstants._();

  // 国内模型API端点
  static const String qwenEndpoint = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  static const String deepseekEndpoint = 'https://api.deepseek.com/v1';
  static const String doubaoEndpoint = 'https://ark.cn-beijing.volces.com/api/v3';
  static const String minimaxEndpoint = 'https://api.minimax.chat/v1';
  static const String zhipuEndpoint = 'https://open.bigmodel.cn/api/paas/v4';

  // 国际模型API端点
  static const String openaiEndpoint = 'https://api.openai.com/v1';
  static const String anthropicEndpoint = 'https://api.anthropic.com/v1';
  static const String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta';

  // 本地模型
  static const String ollamaEndpoint = 'http://localhost:11434';

  // 默认模型
  static const String defaultModel = 'gemini-1.5-flash';
  static const String defaultCodeModel = 'deepseek-coder';
}

/// 项目类型枚举
enum ProjectType {
  android('Android', 'android'),
  flutter('Flutter', 'flutter'),
  ios('iOS', 'ios'),
  nodejs('Node.js', 'nodejs'),
  python('Python', 'python'),
  java('Java', 'java'),
  gradle('Gradle', 'gradle'),
  kotlin('Kotlin', 'kotlin'),
  unknown('Unknown', 'unknown');

  final String displayName;
  final String id;

  const ProjectType(this.displayName, this.id);

  static ProjectType fromId(String id) {
    return ProjectType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ProjectType.unknown,
    );
  }
}

/// 编程语言枚举
enum ProgrammingLanguage {
  dart('Dart', 'dart', 'Flutter'),
  kotlin('Kotlin', 'kt', 'Android'),
  java('Java', 'java', 'Android'),
  python('Python', 'py', 'Backend'),
  javascript('JavaScript', 'js', 'Web'),
  typescript('TypeScript', 'ts', 'Web'),
  swift('Swift', 'swift', 'iOS'),
  go('Go', 'go', 'Backend'),
  rust('Rust', 'rs', 'System'),
  c('C', 'c', 'System'),
  cpp('C++', 'cpp', 'System'),
  html('HTML', 'html', 'Web'),
  css('CSS', 'css', 'Web'),
  json('JSON', 'json', 'Config'),
  yaml('YAML', 'yaml', 'Config'),
  xml('XML', 'xml', 'Config'),
  sql('SQL', 'sql', 'Database'),
  bash('Bash', 'sh', 'Script'),
  markdown('Markdown', 'md', 'Docs'),
  unknown('Unknown', 'txt', 'Unknown');

  final String displayName;
  final String extension;
  final String category;

  const ProgrammingLanguage(this.displayName, this.extension, this.category);

  static ProgrammingLanguage fromExtension(String ext) {
    return ProgrammingLanguage.values.firstWhere(
      (e) => e.extension == ext.toLowerCase(),
      orElse: () => ProgrammingLanguage.unknown,
    );
  }

  static ProgrammingLanguage fromFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return fromExtension(ext);
  }
}
