/// Miss IDE 统一日志系统
/// 提供结构化的日志记录、分级和输出
library miss_logger;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 日志级别
enum LogLevel {
  debug('DEBUG', 0, '🔍'),
  info('INFO', 1, 'ℹ️'),
  warning('WARNING', 2, '⚠️'),
  error('ERROR', 3, '❌'),
  success('SUCCESS', 1, '✅');

  final String label;
  final int priority;
  final String icon;
  const LogLevel(this.label, this.priority, this.icon);
}

/// 日志事件
class LogEvent {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final StackTrace? stackTrace;

  LogEvent({
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formatted {
    final time = timestamp.toString().substring(11, 19);
    return '$time ${level.icon} [${level.label}] [$tag] $message';
  }

  String get plainText {
    final time = timestamp.toString().substring(11, 19);
    return '$time [${level.label}] [$tag] $message';
  }
}

/// Miss IDE 统一日志管理器
class MissLogger {
  // 单例
  static final MissLogger _instance = MissLogger._internal();
  factory MissLogger() => _instance;
  MissLogger._internal();

  // 日志流
  final _logController = StreamController<LogEvent>.broadcast();
  Stream<LogEvent> get logStream => _logController.stream;

  // 存储的日志（内存缓冲区，最多保留 500 条）
  final List<LogEvent> _logs = [];
  static const int _maxLogs = 500;

  // 文件日志
  File? _logFile;
  bool _fileLoggingEnabled = true;

  /// 初始化日志系统
  Future<void> init({bool enableFileLogging = true}) async {
    _fileLoggingEnabled = enableFileLogging;

    if (enableFileLogging) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final logDir = Directory(p.join(docDir.path, 'logs'));
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        final dateStr = DateTime.now().toString().substring(0, 10);
        _logFile = File(p.join(logDir.path, 'miss_ide_$dateStr.log'));

        // 自动清理7天前的日志
        await _cleanOldLogs(logDir);
      } catch (e) {
        debugPrint('MissLogger: 无法初始化文件日志: $e');
        _fileLoggingEnabled = false;
      }
    }

    info('MissLogger', '日志系统初始化完成 (文件日志: ${_fileLoggingEnabled ? "启用" : "禁用"})');
  }

  /// 清理旧日志文件（保留7天）
  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final files = logDir.listSync();
      for (final file in files) {
        if (file is File) {
          final stat = file.statSync();
          if (stat.changed != null && stat.changed!.isBefore(sevenDaysAgo)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // 清理失败不影响主功能
    }
  }

  /// 记录日志
  void _log(LogLevel level, String tag, String message, [StackTrace? stackTrace]) {
    final event = LogEvent(
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );

    // 内存缓存
    _logs.add(event);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // 广播
    _logController.add(event);

    // 控制台输出
    if (kDebugMode) {
      debugPrint(event.formatted);
    }

    // 文件输出
    if (_fileLoggingEnabled && _logFile != null) {
      _logFile!.writeAsStringSync(
        '${event.plainText}\n',
        mode: FileMode.append,
      );
    }
  }

  // ---- 便捷方法 ----

  static void debug(String tag, String message) {
    _instance._log(LogLevel.debug, tag, message);
  }

  static void info(String tag, String message) {
    _instance._log(LogLevel.info, tag, message);
  }

  static void warning(String tag, String message) {
    _instance._log(LogLevel.warning, tag, message);
  }

  static void error(String tag, String message, [StackTrace? stackTrace]) {
    _instance._log(LogLevel.error, tag, message, stackTrace);
  }

  static void success(String tag, String message) {
    _instance._log(LogLevel.success, tag, message);
  }

  /// 获取历史日志
  static List<LogEvent> getLogs({LogLevel? minLevel, String? tag, int? limit}) {
    var result = _instance._logs.toList();

    if (minLevel != null) {
      result = result.where((e) => e.level.priority >= minLevel.priority).toList();
    }
    if (tag != null) {
      result = result.where((e) => e.tag == tag).toList();
    }
    if (limit != null && result.length > limit) {
      result = result.sublist(result.length - limit);
    }

    return result;
  }

  /// 导出日志文本
  static Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Miss IDE 日志导出 ===');
    buffer.writeln('导出时间: ${DateTime.now().toIso8601String()}');
    buffer.writeln('日志条数: ${_instance._logs.length}');
    buffer.writeln('');

    for (final event in _instance._logs) {
      buffer.writeln(event.plainText);
    }

    return buffer.toString();
  }

  /// 获取日志文件路径
  static String? get logFilePath => _instance._logFile?.path;

  /// 获取日志缓冲区大小
  static int get logCount => _instance._logs.length;

  /// 清理内存日志
  static void clearMemoryLogs() {
    _instance._logs.clear();
  }

  /// 关闭日志系统
  void dispose() {
    _logController.close();
  }
}
