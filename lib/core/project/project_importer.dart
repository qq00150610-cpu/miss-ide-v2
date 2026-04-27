import 'dart:io';
import 'package:path/path.dart' as path;
import '../../models/project.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import 'project_detector.dart';

/// 项目导入器
class ProjectImporter {
  static final ProjectImporter _instance = ProjectImporter._internal();
  factory ProjectImporter() => _instance;
  ProjectImporter._internal();

  /// 导入项目
  Future<ImportResult> importProject(String projectPath) async {
    logger.i(LogTags.project, 'Importing project from: $projectPath');

    try {
      final dir = Directory(projectPath);
      if (!await dir.exists()) {
        return ImportResult(
          success: false,
          error: 'Directory does not exist',
        );
      }

      // 检测项目类型
      final type = projectDetector.detect(projectPath);
      if (type == ProjectType.unknown) {
        return ImportResult(
          success: false,
          error: 'Unknown project type',
        );
      }

      // 获取项目信息
      final projectInfo = await projectDetector.getProjectInfo(projectPath);
      if (projectInfo == null) {
        return ImportResult(
          success: false,
          error: 'Failed to read project info',
        );
      }

      // 验证项目结构
      final validation = await _validateProject(projectPath, type);
      if (!validation.isValid) {
        return ImportResult(
          success: false,
          error: validation.error,
          warnings: validation.warnings,
        );
      }

      // 创建Project对象
      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: projectInfo.name,
        path: projectPath,
        type: type,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
        config: ProjectConfig.defaultForType(type),
      );

      return ImportResult(
        success: true,
        project: project,
        warnings: validation.warnings,
      );

    } catch (e) {
      logger.e(LogTags.project, 'Project import failed', error: e);
      return ImportResult(
        success: false,
        error: 'Import failed: $e',
      );
    }
  }

  /// 验证项目结构
  Future<ValidationResult> _validateProject(String projectPath, ProjectType type) async {
    final warnings = <String>[];

    switch (type) {
      case ProjectType.flutter:
        if (!await File(path.join(projectPath, 'lib')).exists()) {
          return ValidationResult(
            isValid: false,
            error: 'Flutter project must have a lib directory',
          );
        }
        if (!await File(path.join(projectPath, 'lib', 'main.dart')).exists()) {
          warnings.add('main.dart not found in lib directory');
        }
        break;

      case ProjectType.android:
        if (!await File(path.join(projectPath, 'app', 'src', 'main')).exists()) {
          return ValidationResult(
            isValid: false,
            error: 'Android project must have app/src/main directory',
          );
        }
        break;

      case ProjectType.nodejs:
        if (!await File(path.join(projectPath, 'package.json')).exists()) {
          return ValidationResult(
            isValid: false,
            error: 'Node.js project must have package.json',
          );
        }
        break;

      default:
        break;
    }

    return ValidationResult(
      isValid: true,
      warnings: warnings,
    );
  }

  /// 创建新项目
  Future<Project?> createProject({
    required String name,
    required ProjectType type,
    required String parentPath,
  }) async {
    final projectPath = path.join(parentPath, name);
    final dir = Directory(projectPath);

    if (await dir.exists()) {
      logger.e(LogTags.project, 'Project directory already exists: $projectPath');
      return null;
    }

    logger.i(LogTags.project, 'Creating new project: $name ($type)');

    try {
      await dir.create(recursive: true);

      // 根据类型创建基础结构
      switch (type) {
        case ProjectType.flutter:
          await _createFlutterStructure(projectPath);
          break;
        case ProjectType.android:
          await _createAndroidStructure(projectPath);
          break;
        case ProjectType.kotlin:
          await _createKotlinStructure(projectPath);
          break;
        case ProjectType.java:
          await _createJavaStructure(projectPath);
          break;
        case ProjectType.nodejs:
          await _createNodejsStructure(projectPath);
          break;
        case ProjectType.python:
          await _createPythonStructure(projectPath);
          break;
        default:
          break;
      }

      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        path: projectPath,
        type: type,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
        config: ProjectConfig.defaultForType(type),
      );

      return project;

    } catch (e) {
      logger.e(LogTags.project, 'Project creation failed', error: e);
      // 清理已创建的目录
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return null;
    }
  }

  /// 创建Flutter项目结构
  Future<void> _createFlutterStructure(String projectPath) async {
    await Directory(path.join(projectPath, 'lib')).create();
    await Directory(path.join(projectPath, 'test')).create();
    await Directory(path.join(projectPath, 'android', 'app', 'src', 'main')).create(recursive: true);

    await File(path.join(projectPath, 'pubspec.yaml')).writeAsString('''
name: $projectPath
description: A new Flutter project.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
''');

    await File(path.join(projectPath, 'lib', 'main.dart')).writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Hello, Miss IDE!'),
        ),
      ),
    );
  }
}
''');
  }

  /// 创建Android项目结构
  Future<void> _createAndroidStructure(String projectPath) async {
    await Directory(path.join(projectPath, 'app', 'src', 'main', 'java')).create(recursive: true);
    await Directory(path.join(projectPath, 'app', 'src', 'main', 'res')).create(recursive: true);

    await File(path.join(projectPath, 'settings.gradle')).writeAsString('''
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AppName"
include(":app")
''');

    await File(path.join(projectPath, 'build.gradle')).writeAsString('''
plugins {
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.20" apply false
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
''');

    await File(path.join(projectPath, 'app', 'build.gradle')).writeAsString('''
plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
}

android {
    namespace "com.example.app"
    compileSdk 34

    defaultConfig {
        applicationId "com.example.app"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation "androidx.core:core-ktx:1.12.0"
    implementation "androidx.appcompat:appcompat:1.6.1"
}
''');
  }

  /// 创建Kotlin项目结构
  Future<void> _createKotlinStructure(String projectPath) async {
    await Directory(path.join(projectPath, 'src')).create(recursive: true);

    await File(path.join(projectPath, 'main.kt')).writeAsString('''
fun main() {
    println("Hello, Miss IDE!")
}
''');
  }

  /// 创建Java项目结构
  Future<void> _createJavaStructure(String projectPath) async {
    await Directory(path.join(projectPath, 'src')).create(recursive: true);

    await File(path.join(projectPath, 'src', 'Main.java')).writeAsString('''
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Miss IDE!");
    }
}
''');
  }

  /// 创建Node.js项目结构
  Future<void> _createNodejsStructure(String projectPath) async {
    await File(path.join(projectPath, 'package.json')).writeAsString('''
{
  "name": "${path.basename(projectPath)}",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {}
}
''');

    await File(path.join(projectPath, 'index.js')).writeAsString('''
console.log("Hello, Miss IDE!");
''');
  }

  /// 创建Python项目结构
  Future<void> _createPythonStructure(String projectPath) async {
    await Directory(path.join(projectPath, 'src')).create(recursive: true);

    await File(path.join(projectPath, 'main.py')).writeAsString('''
def main():
    print("Hello, Miss IDE!")

if __name__ == "__main__":
    main()
''');

    await File(path.join(projectPath, 'requirements.txt')).writeAsString('''
# Add your dependencies here
''');
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final Project? project;
  final String? error;
  final List<String> warnings;

  const ImportResult({
    required this.success,
    this.project,
    this.error,
    this.warnings = const [],
  });
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final String? error;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.error,
    this.warnings = const [],
  });
}

/// 全局实例
final projectImporter = ProjectImporter();
