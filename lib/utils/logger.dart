import 'dart:async';
import 'package:flutter/foundation.dart';

/// 日志级别
enum LogLevel {
  debug('DEBUG', 0),
  info('INFO', 1),
  warning('WARN', 2),
  error('ERROR', 3);

  final String name;
  final int priority;

  const LogLevel(this.name, this.priority);
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formatted {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final levelStr = level.name.padRight(5);
    final tagStr = '[$tag]'.padRight(20);
    var result = '$time $levelStr $tagStr $message';
    if (error != null) {
      result += '\nError: $error';
    }
    if (stackTrace != null && level == LogLevel.error) {
      result += '\n${stackTrace.toString().split('\n').take(5).join('\n')}';
    }
    return result;
  }
}

/// 日志观察者接口
abstract class LogObserver {
  void onLog(LogEntry entry);
}

/// Miss IDE 日志系统
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  final List<LogObserver> _observers = [];
  final List<LogEntry> _entries = [];
  final int _maxEntries = 1000;

  // 日志文件（仅在Release模式）
  String? _logFilePath;

  /// 设置最小日志级别
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// 添加观察者
  void addObserver(LogObserver observer) {
    _observers.add(observer);
  }

  /// 移除观察者
  void removeObserver(LogObserver observer) {
    _observers.remove(observer);
  }

  /// 记录日志
  void _log(LogLevel level, String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (level.priority < _minLevel.priority) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    // 添加到内存
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }

    // 通知观察者
    for (final observer in _observers) {
      try {
        observer.onLog(entry);
      } catch (e) {
        debugPrint('LogObserver error: $e');
      }
    }

    // 控制台输出
    debugPrint(entry.formatted);
  }

  /// Debug级别日志
  void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Info级别日志
  void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Warning级别日志
  void w(String tag, String message, {Object? error}) {
    _log(LogLevel.warning, tag, message, error: error);
  }

  /// Error级别日志
  void e(String tag, String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);
  }

  /// 获取所有日志
  List<LogEntry> getEntries({LogLevel? minLevel, int? limit}) {
    var entries = _entries;
    if (minLevel != null) {
      entries = entries.where((e) => e.level.priority >= minLevel.priority).toList();
    }
    if (limit != null && limit > 0) {
      entries = entries.takeLast(limit).toList();
    }
    return entries;
  }

  /// 清空日志
  void clear() {
    _entries.clear();
  }

  /// 导出日志
  Future<String> exportLogs() async {
    final buffer = StringBuffer();
    buffer.writeln('Miss IDE v2 Log Export');
    buffer.writeln('Export Time: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    for (final entry in _entries) {
      buffer.writeln(entry.formatted);
    }

    return buffer.toString();
  }
}

/// 全局日志实例
final logger = Logger();

/// 便捷的日志方法
void logDebug(String tag, String message) => logger.d(tag, message);
void logInfo(String tag, String message) => logger.i(tag, message);
void logWarning(String tag, String message, {Object? error}) =>
    logger.w(tag, message, error: error);
void logError(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
    logger.e(tag, message, error: error, stackTrace: stackTrace);

/// 应用各模块的日志标签
class LogTags {
  LogTags._();

  static const String app = 'App';
  static const String editor = 'Editor';
  static const String ai = 'AI';
  static const String build = 'Build';
  static const String terminal = 'Terminal';
  static const String fileManager = 'FileManager';
  static const String project = 'Project';
  static const String settings = 'Settings';
  static const String network = 'Network';
  static const String storage = 'Storage';
}
