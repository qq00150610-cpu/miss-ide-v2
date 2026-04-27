import 'dart:io';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Shell命令执行器
class ShellExecutor {
  static final ShellExecutor _instance = ShellExecutor._internal();
  factory ShellExecutor() => _instance;
  ShellExecutor._internal();

  /// 执行命令
  Future<ShellResult> execute(
    String command, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    logger.i(LogTags.terminal, 'Executing: $command');

    try {
      final parts = _parseCommand(command);
      if (parts.isEmpty) {
        return ShellResult(
          success: false,
          exitCode: 1,
          stderr: 'Empty command',
        );
      }

      final process = await Process.start(
        parts[0],
        parts.length > 1 ? parts.sublist(1) : [],
        workingDirectory: workingDirectory ?? Directory.current.path,
        environment: environment ?? Platform.environment,
      );

      final stdout = await process.stdout.transform(
        const SystemEncoding().decoder,
      ).join();
      
      final stderr = await process.stderr.transform(
        const SystemEncoding().decoder,
      ).join();

      int exitCode;
      if (timeout != null) {
        exitCode = await process.exitCode.timeout(
          timeout,
          onTimeout: () {
            process.kill();
            return -1;
          },
        );
      } else {
        exitCode = await process.exitCode;
      }

      return ShellResult(
        success: exitCode == 0,
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } catch (e) {
      logger.e(LogTags.terminal, 'Shell execution failed', error: e);
      return ShellResult(
        success: false,
        exitCode: -1,
        stderr: e.toString(),
      );
    }
  }

  /// 执行多个命令
  Future<List<ShellResult>> executeAll(
    List<String> commands, {
    String? workingDirectory,
    bool stopOnError = true,
  }) async {
    final results = <ShellResult>[];

    for (final command in commands) {
      final result = await execute(
        command,
        workingDirectory: workingDirectory,
      );
      results.add(result);

      if (stopOnError && !result.success) {
        break;
      }
    }

    return results;
  }

  /// 解析命令
  List<String> _parseCommand(String command) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuote = false;
    var quoteChar = '';

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuote) {
        inQuote = false;
        quoteChar = '';
      } else if (char == ' ' && !inQuote) {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString());
    }

    return result;
  }

  /// 检查命令是否存在
  Future<bool> commandExists(String command) async {
    final which = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(which, [command]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取PATH中的所有命令
  Future<List<String>> getAvailableCommands() async {
    final pathEnv = Platform.environment['PATH'] ?? '';
    final paths = pathEnv.split(Platform.isWindows ? ';' : ':');
    final commands = <String>{};

    for (final path in paths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File) {
              final name = entity.path.split(Platform.pathSeparator).last;
              if (!name.contains('.')) {
                commands.add(name);
              }
            }
          }
        }
      } catch (_) {}
    }

    return commands.toList()..sort();
  }
}

/// Shell执行结果
class ShellResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;

  const ShellResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  String get combined => stdout.isNotEmpty && stderr.isNotEmpty
      ? '$stdout\n$stderr'
      : stdout.isNotEmpty ? stdout : stderr;
}

/// 命令历史管理器
class CommandHistory {
  static final CommandHistory _instance = CommandHistory._internal();
  factory CommandHistory() => _instance;
  CommandHistory._internal();

  final List<String> _history = [];
  final int _maxSize = AppConstants.maxTerminalHistory;
  int _currentIndex = -1;

  /// 添加命令
  void add(String command) {
    // 避免重复
    if (_history.isNotEmpty && _history.last == command) {
      return;
    }

    _history.add(command);
    
    // 限制大小
    while (_history.length > _maxSize) {
      _history.removeAt(0);
    }

    _currentIndex = _history.length;
  }

  /// 获取上一个命令
  String? getPrevious() {
    if (_history.isEmpty) return null;
    
    if (_currentIndex > 0) {
      _currentIndex--;
    }
    
    return _history[_currentIndex];
  }

  /// 获取下一个命令
  String? getNext() {
    if (_history.isEmpty) return null;
    
    if (_currentIndex < _history.length - 1) {
      _currentIndex++;
      return _history[_currentIndex];
    }
    
    _currentIndex = _history.length;
    return '';
  }

  /// 重置索引
  void resetIndex() {
    _currentIndex = _history.length;
  }

  /// 搜索命令
  List<String> search(String query) {
    return _history
        .where((cmd) => cmd.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// 清空历史
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }

  /// 获取所有历史
  List<String> get all => List.unmodifiable(_history);

  /// 保存历史
  Future<void> save(String path) async {
    final file = File(path);
    await file.writeAsString(_history.join('\n'));
  }

  /// 加载历史
  Future<void> load(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _history.clear();
        _history.addAll(content.split('\n').where((s) => s.isNotEmpty));
        _currentIndex = _history.length;
      }
    } catch (e) {
      logger.w(LogTags.terminal, 'Failed to load command history', error: e);
    }
  }
}

/// 全局实例
final shellExecutor = ShellExecutor();
final commandHistory = CommandHistory();
