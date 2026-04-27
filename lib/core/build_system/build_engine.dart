import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../../models/build_result.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import 'sdk_manager.dart';

/// 构建引擎 - 核心编译执行器
class BuildEngine {
  static final BuildEngine _instance = BuildEngine._internal();
  factory BuildEngine() => _instance;
  BuildEngine._internal();

  BuildTask? _currentTask;
  BuildResult? _lastResult;
  final _resultController = StreamController<BuildResult>.broadcast();
  final _progressController = StreamController<BuildProgress>.broadcast();
  
  Process? _buildProcess;
  bool _cancelled = false;

  /// 当前任务
  BuildTask? get currentTask => _currentTask;
  
  /// 最后结果
  BuildResult? get lastResult => _lastResult;

  /// 结果流
  Stream<BuildResult> get resultStream => _resultController.stream;

  /// 进度流
  Stream<BuildProgress> get progressStream => _progressController.stream;

  /// 执行构建任务
  Future<BuildResult> build({
    required String projectPath,
    required BuildTaskType taskType,
    List<String> targets = const [],
    BuildOptions options = const BuildOptions(),
  }) async {
    if (_currentTask != null && _currentTask!.result?.status.isRunning == true) {
      throw StateError('Build already in progress');
    }

    _cancelled = false;
    final taskId = '${DateTime.now().millisecondsSinceEpoch}';
    
    _currentTask = BuildTask(
      id: taskId,
      projectId: projectPath,
      type: taskType,
      targets: targets,
      options: options,
    );

    final startTime = DateTime.now();
    var result = BuildResult(
      status: BuildStatus.preparing,
      startTime: startTime,
    );

    _emitResult(result);
    logger.i(LogTags.build, 'Starting build task: ${taskType.displayName}');

    try {
      // 准备阶段
      _progressController.add(BuildProgress(
        phase: '准备',
        progress: 0.0,
        message: '检查环境...',
      ));

      // 根据项目类型执行不同构建
      switch (taskType) {
        case BuildTaskType.clean:
          result = await _clean(projectPath, result);
          break;
        case BuildTaskType.build:
        case BuildTaskType.rebuild:
        case BuildTaskType.assemble:
          result = await _build(projectPath, taskType, options, result);
          break;
        case BuildTaskType.compile:
          result = await _compile(projectPath, options, result);
          break;
        case BuildTaskType.run:
          result = await _run(projectPath, result);
          break;
        default:
          result = result.copyWith(
            status: BuildStatus.failed,
            errorMessage: 'Unsupported task type: $taskType',
          );
      }

      if (_cancelled) {
        result = result.copyWith(status: BuildStatus.cancelled);
      }

      final endTime = DateTime.now();
      result = result.copyWith(
        endTime: endTime,
        duration: endTime.difference(startTime),
      );

      _lastResult = result;
      _emitResult(result);
      
      logger.i(LogTags.build, 'Build completed: ${result.status.displayName} (${result.duration})');
      return result;

    } catch (e) {
      logger.e(LogTags.build, 'Build failed', error: e);
      final errorResult = BuildResult(
        status: BuildStatus.failed,
        startTime: startTime,
        endTime: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
        messages: [
          BuildMessage(
            type: BuildMessageType.error,
            message: e.toString(),
            timestamp: DateTime.now(),
          ),
        ],
      );
      _lastResult = errorResult;
      _emitResult(errorResult);
      return errorResult;
    } finally {
      _currentTask = null;
    }
  }

  /// 取消构建
  Future<void> cancel() async {
    _cancelled = true;
    _buildProcess?.kill();
    logger.i(LogTags.build, 'Build cancelled');
  }

  /// 清理
  Future<BuildResult> _clean(String projectPath, BuildResult result) async {
    _progressController.add(BuildProgress(
      phase: '清理',
      progress: 0.3,
      message: '清理构建目录...',
    ));

    try {
      final buildDir = Directory(path.join(projectPath, 'build'));
      if (await buildDir.exists()) {
        await buildDir.delete(recursive: true);
      }

      return result.copyWith(
        status: BuildStatus.success,
        messages: [
          BuildMessage(
            type: BuildMessageType.info,
            message: '清理完成',
            timestamp: DateTime.now(),
          ),
        ],
      );
    } catch (e) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: '清理失败: $e',
      );
    }
  }

  /// 构建
  Future<BuildResult> _build(
    String projectPath,
    BuildTaskType taskType,
    BuildOptions options,
    BuildResult result,
  ) async {
    // 检测项目类型
    final projectType = _detectProjectType(projectPath);
    
    _progressController.add(BuildProgress(
      phase: '编译',
      progress: 0.3,
      message: '检测项目类型: ${projectType.displayName}',
    ));

    switch (projectType) {
      case ProjectType.android:
        return await _buildAndroid(projectPath, taskType, options, result);
      case ProjectType.flutter:
        return await _buildFlutter(projectPath, taskType, options, result);
      case ProjectType.java:
        return await _buildJava(projectPath, options, result);
      case ProjectType.kotlin:
        return await _compileKotlin(projectPath, options, result);
      default:
        return result.copyWith(
          status: BuildStatus.failed,
          errorMessage: '不支持的项目类型: ${projectType.displayName}',
        );
    }
  }

  /// Android构建
  Future<BuildResult> _buildAndroid(
    String projectPath,
    BuildTaskType taskType,
    BuildOptions options,
    BuildResult result,
  ) async {
    final messages = <BuildMessage>[];

    // 检查Gradle
    final gradlePath = sdkManager.getGradlePath();
    if (gradlePath == null) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: 'Gradle未安装',
      );
    }

    // 构建命令
    String buildTask;
    switch (taskType) {
      case BuildTaskType.assemble:
        buildTask = 'assembleDebug';
        break;
      case BuildTaskType.rebuild:
        buildTask = 'clean assembleDebug';
        break;
      default:
        buildTask = 'assembleDebug';
    }

    if (options.verbose) {
      buildTask = '$buildTask --info';
    }

    _progressController.add(BuildProgress(
      phase: 'Gradle构建',
      progress: 0.5,
      message: '执行: gradle $buildTask',
    ));

    try {
      final process = await Process.start(
        gradlePath,
        buildTask.split(' '),
        workingDirectory: projectPath,
        environment: {
          'ANDROID_HOME': sdkManager.getAndroidSdkPath() ?? '',
          'JAVA_HOME': path.dirname(path.dirname(sdkManager.getJavaPath() ?? '')),
        },
      );

      _buildProcess = process;

      // 收集输出
      process.stdout.transform(utf8.decoder).listen((data) {
        messages.add(BuildMessage(
          type: _parseMessageType(data),
          message: data.trim(),
          timestamp: DateTime.now(),
        ));
        _progressController.add(BuildProgress(
          phase: '编译',
          progress: 0.7,
          message: data.trim().split('\n').last,
        ));
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        messages.add(BuildMessage(
          type: BuildMessageType.error,
          message: data.trim(),
          timestamp: DateTime.now(),
        ));
      });

      final exitCode = await process.exitCode;
      _buildProcess = null;

      if (_cancelled) {
        return result.copyWith(status: BuildStatus.cancelled);
      }

      if (exitCode == 0) {
        // 查找APK输出
        String? outputPath;
        final apkDir = Directory(path.join(projectPath, 'app', 'build', 'outputs', 'apk', 'debug'));
        if (await apkDir.exists()) {
          final apks = await apkDir.list().toList();
          if (apks.isNotEmpty) {
            outputPath = apks.first.path;
          }
        }

        return result.copyWith(
          status: BuildStatus.success,
          messages: messages,
          outputPath: outputPath,
          exitCode: exitCode,
        );
      } else {
        return result.copyWith(
          status: BuildStatus.failed,
          messages: messages,
          errorMessage: '构建失败，退出码: $exitCode',
          exitCode: exitCode,
        );
      }
    } catch (e) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: '构建失败: $e',
        messages: messages,
      );
    }
  }

  /// Flutter构建
  Future<BuildResult> _buildFlutter(
    String projectPath,
    BuildTaskType taskType,
    BuildOptions options,
    BuildResult result,
  ) async {
    // 使用Flutter CLI
    try {
      final process = await Process.start(
        'flutter',
        ['build', 'apk', '--debug'],
        workingDirectory: projectPath,
      );

      _buildProcess = process;
      final messages = <BuildMessage>[];

      process.stdout.transform(utf8.decoder).listen((data) {
        messages.add(BuildMessage(
          type: _parseMessageType(data),
          message: data.trim(),
          timestamp: DateTime.now(),
        ));
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        messages.add(BuildMessage(
          type: BuildMessageType.error,
          message: data.trim(),
          timestamp: DateTime.now(),
        ));
      });

      final exitCode = await process.exitCode;
      _buildProcess = null;

      if (exitCode == 0) {
        return result.copyWith(
          status: BuildStatus.success,
          messages: messages,
          outputPath: path.join(projectPath, 'build', 'app', 'outputs', 'flutter-apk', 'app-debug.apk'),
        );
      } else {
        return result.copyWith(
          status: BuildStatus.failed,
          messages: messages,
          errorMessage: 'Flutter构建失败',
          exitCode: exitCode,
        );
      }
    } catch (e) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: 'Flutter构建失败: $e',
      );
    }
  }

  /// Java构建
  Future<BuildResult> _buildJava(
    String projectPath,
    BuildOptions options,
    BuildResult result,
  ) async {
    // 使用javac编译
    try {
      final process = await Process.start(
        'javac',
        ['-d', 'build', 'src/**/*.java'],
        workingDirectory: projectPath,
      );

      final exitCode = await process.exitCode;
      return result.copyWith(
        status: exitCode == 0 ? BuildStatus.success : BuildStatus.failed,
        exitCode: exitCode,
      );
    } catch (e) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: 'Java编译失败: $e',
      );
    }
  }

  /// Kotlin编译
  Future<BuildResult> _compileKotlin(
    String projectPath,
    BuildOptions options,
    BuildResult result,
  ) async {
    final kotlinc = sdkManager.getKotlincPath();
    if (kotlinc == null) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: 'Kotlin编译器未安装',
      );
    }

    try {
      final process = await Process.start(
        kotlinc,
        ['-d', 'build', 'src/**/*.kt'],
        workingDirectory: projectPath,
      );

      final exitCode = await process.exitCode;
      return result.copyWith(
        status: exitCode == 0 ? BuildStatus.success : BuildStatus.failed,
        exitCode: exitCode,
      );
    } catch (e) {
      return result.copyWith(
        status: BuildStatus.failed,
        errorMessage: 'Kotlin编译失败: $e',
      );
    }
  }

  /// 编译
  Future<BuildResult> _compile(
    String projectPath,
    BuildOptions options,
    BuildResult result,
  ) async {
    final projectType = _detectProjectType(projectPath);
    
    switch (projectType) {
      case ProjectType.kotlin:
        return await _compileKotlin(projectPath, options, result);
      case ProjectType.java:
        return await _buildJava(projectPath, options, result);
      default:
        return await _build(projectPath, BuildTaskType.assemble, options, result);
    }
  }

  /// 运行
  Future<BuildResult> _run(String projectPath, BuildResult result) async {
    final projectType = _detectProjectType(projectPath);
    
    switch (projectType) {
      case ProjectType.java:
        try {
          final process = await Process.start(
            'java',
            ['-cp', 'build', 'Main'],
            workingDirectory: projectPath,
          );
          
          process.stdout.transform(utf8.decoder).listen((data) {
            logger.i(LogTags.build, data.trim());
          });
          
          await process.exitCode;
          return result.copyWith(status: BuildStatus.success);
        } catch (e) {
          return result.copyWith(status: BuildStatus.failed, errorMessage: e.toString());
        }
      default:
        return result.copyWith(
          status: BuildStatus.failed,
          errorMessage: '暂不支持运行此类型项目',
        );
    }
  }

  /// 检测项目类型
  ProjectType _detectProjectType(String projectPath) {
    final dir = Directory(projectPath);
    
    // 检查Flutter
    if (File(path.join(projectPath, 'pubspec.yaml')).existsSync()) {
      return ProjectType.flutter;
    }
    
    // 检查Android
    if (File(path.join(projectPath, 'settings.gradle')).existsSync() ||
        File(path.join(projectPath, 'settings.gradle.kts')).existsSync()) {
      return ProjectType.android;
    }
    
    // 检查Java
    if (File(path.join(projectPath, 'pom.xml')).existsSync()) {
      return ProjectType.java;
    }
    
    // 检查Python
    if (File(path.join(projectPath, 'requirements.txt')).existsSync() ||
        File(path.join(projectPath, 'setup.py')).existsSync()) {
      return ProjectType.python;
    }

    return ProjectType.unknown;
  }

  BuildMessageType _parseMessageType(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('error') || lower.contains('failed')) {
      return BuildMessageType.error;
    }
    if (lower.contains('warning') || lower.contains('warn')) {
      return BuildMessageType.warning;
    }
    if (lower.contains('debug')) {
      return BuildMessageType.debug;
    }
    return BuildMessageType.info;
  }

  void _emitResult(BuildResult result) {
    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  void dispose() {
    _resultController.close();
    _progressController.close();
    _buildProcess?.kill();
  }
}

/// 构建进度
class BuildProgress {
  final String phase;
  final double progress;
  final String message;

  const BuildProgress({
    required this.phase,
    required this.progress,
    required this.message,
  });
}

/// 全局构建引擎实例
final buildEngine = BuildEngine();
