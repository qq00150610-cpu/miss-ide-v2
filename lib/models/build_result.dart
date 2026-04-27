/// 构建结果状态
enum BuildStatus {
  idle('空闲', 'idle'),
  preparing('准备中', 'preparing'),
  building('构建中', 'building'),
  compiling('编译中', 'compiling'),
  success('成功', 'success'),
  failed('失败', 'failed'),
  cancelled('已取消', 'cancelled');

  final String displayName;
  final String id;

  const BuildStatus(this.displayName, this.id);

  bool get isRunning =>
      this == preparing || this == building || this == compiling;

  bool get isFinished => this == success || this == failed || this == cancelled;

  bool get isSuccess => this == success;
}

/// 构建结果
class BuildResult {
  final BuildStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final List<BuildMessage> messages;
  final String? outputPath;
  final String? errorMessage;
  final int? exitCode;
  final BuildMetrics? metrics;

  const BuildResult({
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
    this.messages = const [],
    this.outputPath,
    this.errorMessage,
    this.exitCode,
    this.metrics,
  });

  bool get isSuccess => status == BuildStatus.success;
  bool get isFailed => status == BuildStatus.failed;

  BuildResult copyWith({
    BuildStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    List<BuildMessage>? messages,
    String? outputPath,
    String? errorMessage,
    int? exitCode,
    BuildMetrics? metrics,
  }) {
    return BuildResult(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      messages: messages ?? this.messages,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      exitCode: exitCode ?? this.exitCode,
      metrics: metrics ?? this.metrics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'messages': messages.map((m) => m.toJson()).toList(),
      'outputPath': outputPath,
      'errorMessage': errorMessage,
      'exitCode': exitCode,
      'metrics': metrics?.toJson(),
    };
  }

  factory BuildResult.fromJson(Map<String, dynamic> json) {
    return BuildResult(
      status: BuildStatus.values.firstWhere(
        (e) => e.id == json['status'],
        orElse: () => BuildStatus.idle,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      messages: (json['messages'] as List?)
              ?.map((m) => BuildMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      outputPath: json['outputPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      exitCode: json['exitCode'] as int?,
      metrics: json['metrics'] != null
          ? BuildMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : null,
    );
  }

  factory BuildResult.idle() {
    return BuildResult(
      status: BuildStatus.idle,
      startTime: DateTime.now(),
    );
  }
}

/// 构建消息（编译输出）
class BuildMessage {
  final BuildMessageType type;
  final String message;
  final String? file;
  final int? line;
  final int? column;
  final DateTime timestamp;

  const BuildMessage({
    required this.type,
    required this.message,
    this.file,
    this.line,
    this.column,
    required this.timestamp,
  });

  String get location {
    if (file == null) return '';
    final loc = StringBuffer(file!);
    if (line != null) {
      loc.write(':$line');
      if (column != null) {
        loc.write(':$column');
      }
    }
    return loc.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'file': file,
      'line': line,
      'column': column,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BuildMessage.fromJson(Map<String, dynamic> json) {
    return BuildMessage(
      type: BuildMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BuildMessageType.info,
      ),
      message: json['message'] as String,
      file: json['file'] as String?,
      line: json['line'] as int?,
      column: json['column'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// 构建消息类型
enum BuildMessageType {
  info('信息'),
  warning('警告'),
  error('错误'),
  debug('调试');

  final String displayName;

  const BuildMessageType(this.displayName);
}

/// 构建性能指标
class BuildMetrics {
  final int totalFiles;
  final int compiledFiles;
  final int cachedFiles;
  final int skippedFiles;
  final int totalLinesOfCode;
  final int processedLines;
  final int memoryUsageMB;
  final Duration cpuTime;

  const BuildMetrics({
    this.totalFiles = 0,
    this.compiledFiles = 0,
    this.cachedFiles = 0,
    this.skippedFiles = 0,
    this.totalLinesOfCode = 0,
    this.processedLines = 0,
    this.memoryUsageMB = 0,
    this.cpuTime = Duration.zero,
  });

  double get cacheHitRate {
    final total = compiledFiles + cachedFiles + skippedFiles;
    if (total == 0) return 0;
    return cachedFiles / total;
  }

  Map<String, dynamic> toJson() {
    return {
      'totalFiles': totalFiles,
      'compiledFiles': compiledFiles,
      'cachedFiles': cachedFiles,
      'skippedFiles': skippedFiles,
      'totalLinesOfCode': totalLinesOfCode,
      'processedLines': processedLines,
      'memoryUsageMB': memoryUsageMB,
      'cpuTime': cpuTime.inMilliseconds,
    };
  }

  factory BuildMetrics.fromJson(Map<String, dynamic> json) {
    return BuildMetrics(
      totalFiles: json['totalFiles'] as int? ?? 0,
      compiledFiles: json['compiledFiles'] as int? ?? 0,
      cachedFiles: json['cachedFiles'] as int? ?? 0,
      skippedFiles: json['skippedFiles'] as int? ?? 0,
      totalLinesOfCode: json['totalLinesOfCode'] as int? ?? 0,
      processedLines: json['processedLines'] as int? ?? 0,
      memoryUsageMB: json['memoryUsageMB'] as int? ?? 0,
      cpuTime: Duration(milliseconds: json['cpuTime'] as int? ?? 0),
    );
  }
}

/// 构建任务
class BuildTask {
  final String id;
  final String projectId;
  final BuildTaskType type;
  final List<String> targets;
  final BuildOptions options;
  final BuildResult? result;

  const BuildTask({
    required this.id,
    required this.projectId,
    required this.type,
    this.targets = const [],
    this.options = const BuildOptions(),
    this.result,
  });

  BuildTask copyWith({
    String? id,
    String? projectId,
    BuildTaskType? type,
    List<String>? targets,
    BuildOptions? options,
    BuildResult? result,
  }) {
    return BuildTask(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      type: type ?? this.type,
      targets: targets ?? this.targets,
      options: options ?? this.options,
      result: result ?? this.result,
    );
  }
}

/// 构建任务类型
enum BuildTaskType {
  clean('清理', 'clean'),
  build('构建', 'build'),
  rebuild('重新构建', 'rebuild'),
  assemble('打包', 'assemble'),
  compile('编译', 'compile'),
  run('运行', 'run'),
  debug('调试', 'debug'),
  test('测试', 'test'),
  deploy('部署', 'deploy');

  final String displayName;
  final String id;

  const BuildTaskType(this.displayName, this.id);
}

/// 构建选项
class BuildOptions {
  final bool incremental;
  final bool parallel;
  final bool verbose;
  final bool dryRun;
  final String? variant;
  final String? flavor;
  final Map<String, String> extraArgs;

  const BuildOptions({
    this.incremental = true,
    this.parallel = true,
    this.verbose = false,
    this.dryRun = false,
    this.variant,
    this.flavor,
    this.extraArgs = const {},
  });

  BuildOptions copyWith({
    bool? incremental,
    bool? parallel,
    bool? verbose,
    bool? dryRun,
    String? variant,
    String? flavor,
    Map<String, String>? extraArgs,
  }) {
    return BuildOptions(
      incremental: incremental ?? this.incremental,
      parallel: parallel ?? this.parallel,
      verbose: verbose ?? this.verbose,
      dryRun: dryRun ?? this.dryRun,
      variant: variant ?? this.variant,
      flavor: flavor ?? this.flavor,
      extraArgs: extraArgs ?? this.extraArgs,
    );
  }
}
