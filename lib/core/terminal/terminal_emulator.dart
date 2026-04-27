import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 终端输出类型
enum TerminalOutputType {
  stdout,
  stderr,
  system,
}

/// 终端输出项
class TerminalOutput {
  final TerminalOutputType type;
  final String text;
  final DateTime timestamp;

  const TerminalOutput({
    required this.type,
    required this.text,
    required this.timestamp,
  });

  String get typeTag {
    switch (type) {
      case TerminalOutputType.stdout:
        return '';
      case TerminalOutputType.stderr:
        return '! ';
      case TerminalOutputType.system:
        return '> ';
    }
  }
}

/// 终端模拟器
class TerminalEmulator {
  static final TerminalEmulator _instance = TerminalEmulator._internal();
  factory TerminalEmulator() => _instance;
  TerminalEmulator._internal();

  final _outputController = StreamController<TerminalOutput>.broadcast();
  final List<TerminalOutput> _history = [];
  final int _maxHistorySize = AppConstants.maxTerminalHistory;

  Process? _currentProcess;
  String? _workingDirectory;
  bool _isRunning = false;
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  /// 输出流
  Stream<TerminalOutput> get outputStream => _outputController.stream;

  /// 历史记录
  List<TerminalOutput> get history => List.unmodifiable(_history);

  /// 是否运行中
  bool get isRunning => _isRunning;

  /// 当前工作目录
  String? get workingDirectory => _workingDirectory;

  /// 命令历史
  List<String> get commandHistory => List.unmodifiable(_commandHistory);

  /// 初始化
  void init(String? initialDirectory) {
    _workingDirectory = initialDirectory ?? Directory.current.path;
    _addOutput(TerminalOutputType.system, 'Miss IDE Terminal v2.0');
    _addOutput(TerminalOutputType.system, 'Type "help" for available commands.\n');
    logger.i(LogTags.terminal, 'Terminal initialized');
  }

  /// 执行命令
  Future<int> execute(String command, {String? cwd}) async {
    if (command.trim().isEmpty) {
      return 0;
    }

    // 添加到历史
    _commandHistory.add(command);
    if (_commandHistory.length > AppConstants.maxTerminalHistory) {
      _commandHistory.removeAt(0);
    }
    _historyIndex = _commandHistory.length;

    // 显示命令
    _addOutput(TerminalOutputType.system, '\n\$ $command');

    // 检查内置命令
    if (await _executeBuiltin(command)) {
      return 0;
    }

    // 执行系统命令
    return await _executeProcess(command, cwd: cwd);
  }

  /// 执行内置命令
  Future<bool> _executeBuiltin(String command) async {
    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];

    switch (cmd) {
      case 'help':
        _showHelp();
        return true;

      case 'clear':
      case 'cls':
        _history.clear();
        _addOutput(TerminalOutputType.system, 'Terminal cleared');
        return true;

      case 'pwd':
        _addOutput(TerminalOutputType.stdout, _workingDirectory ?? 'unknown');
        return true;

      case 'cd':
        await _changeDirectory(args.isNotEmpty ? args[0] : '');
        return true;

      case 'ls':
      case 'dir':
        await _listDirectory(args);
        return true;

      case 'cat':
        await _readFile(args);
        return true;

      case 'echo':
        _addOutput(TerminalOutputType.stdout, args.join(' '));
        return true;

      case 'history':
        _showHistory();
        return true;

      case 'msdk':
        await _showSDKInfo();
        return true;

      case 'exit':
      case 'quit':
        _addOutput(TerminalOutputType.system, 'Use back button to exit terminal');
        return true;

      default:
        return false;
    }
  }

  /// 执行进程命令
  Future<int> _executeProcess(String command, {String? cwd}) async {
    // 终止之前的进程
    if (_currentProcess != null && _isRunning) {
      await _currentProcess!.kill();
    }

    _isRunning = true;

    try {
      // 解析命令
      final parts = _parseCommand(command);
      if (parts.isEmpty) {
        _isRunning = false;
        return 1;
      }

      // 启动进程
      _currentProcess = await Process.start(
        parts[0],
        parts.length > 1 ? parts.sublist(1) : [],
        workingDirectory: cwd ?? _workingDirectory,
        environment: Platform.environment,
      );

      // 监听输出
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        _addOutput(TerminalOutputType.stdout, data);
      });

      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        _addOutput(TerminalOutputType.stderr, data);
      });

      // 等待完成
      final exitCode = await _currentProcess!.exitCode;
      _isRunning = false;
      _currentProcess = null;

      _addOutput(TerminalOutputType.system, '\n[Process exited with code $exitCode]');
      return exitCode;

    } catch (e) {
      _isRunning = false;
      _addOutput(TerminalOutputType.error, 'Error: $e');
      return 1;
    }
  }

  /// 解析命令（处理引号和转义）
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

  /// 切换目录
  Future<void> _changeDirectory(String path) async {
    String targetPath;

    if (path.isEmpty) {
      // 返回主目录
      targetPath = Platform.environment['HOME'] ?? 
                   Platform.environment['USERPROFILE'] ?? 
                   '/';
    } else if (path == '..') {
      // 上一级目录
      final current = _workingDirectory ?? '/';
      targetPath = Directory(current).parent.path;
    } else if (path == '.') {
      // 当前目录
      return;
    } else if (path.startsWith('/') || path.contains(':')) {
      // 绝对路径
      targetPath = path;
    } else {
      // 相对路径
      targetPath = '$_workingDirectory/$path';
    }

    final dir = Directory(targetPath);
    if (await dir.exists()) {
      _workingDirectory = dir.path;
    } else {
      _addOutput(TerminalOutputType.error, 'cd: $targetPath: No such directory');
    }
  }

  /// 列出目录
  Future<void> _listDirectory(List<String> args) async {
    final targetPath = args.isNotEmpty ? args[0] : _workingDirectory ?? '.';
    
    try {
      final dir = Directory(targetPath);
      final entities = await dir.list().toList();
      
      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final isDir = entity is Directory;
        
        _addOutput(
          TerminalOutputType.stdout,
          '${isDir ? "d" : "-"} ${name.padRight(30)}',
        );
      }
    } catch (e) {
      _addOutput(TerminalOutputType.error, 'ls: $e');
    }
  }

  /// 读取文件
  Future<void> _readFile(List<String> args) async {
    if (args.isEmpty) {
      _addOutput(TerminalOutputType.error, 'cat: missing file operand');
      return;
    }

    try {
      final file = File(args[0]);
      final content = await file.readAsString();
      _addOutput(TerminalOutputType.stdout, content);
    } catch (e) {
      _addOutput(TerminalOutputType.error, 'cat: $e');
    }
  }

  /// 显示帮助
  void _showHelp() {
    _addOutput(TerminalOutputType.stdout, '''
Available commands:
  help     - Show this help message
  clear    - Clear the terminal
  pwd      - Print working directory
  cd <dir> - Change directory
  ls       - List directory contents
  cat <f>  - Display file contents
  echo <t> - Print text
  history  - Show command history
  msdk     - Show SDK information
  exit     - Exit terminal (use back button)
''');
  }

  /// 显示历史
  void _showHistory() {
    for (var i = 0; i < _commandHistory.length; i++) {
      _addOutput(TerminalOutputType.stdout, '  $i  ${_commandHistory[i]}');
    }
  }

  /// 显示SDK信息
  Future<void> _showSDKInfo() async {
    _addOutput(TerminalOutputType.stdout, '''
Miss IDE SDK Information:
  Java:      ${sdkManager.isInstalled('java-17') ? 'Installed' : 'Not installed'}
  Kotlin:    ${sdkManager.isInstalled('kotlin-compiler') ? 'Installed' : 'Not installed'}
  Gradle:    ${sdkManager.isInstalled('gradle-wrapper') ? 'Installed' : 'Not installed'}
  Android:   ${sdkManager.isInstalled('android-build-tools') ? 'Installed' : 'Not installed'}
''');
  }

  /// 添加输出
  void _addOutput(TerminalOutputType type, String text) {
    // 按行分割
    final lines = text.split('\n');
    for (final line in lines) {
      final output = TerminalOutput(
        type: type,
        text: line,
        timestamp: DateTime.now(),
      );

      _history.add(output);
      
      // 限制历史大小
      while (_history.length > _maxHistorySize) {
        _history.removeAt(0);
      }

      if (!_outputController.isClosed) {
        _outputController.add(output);
      }
    }
  }

  /// 获取上一个命令
  String? getPreviousCommand() {
    if (_commandHistory.isEmpty) return null;
    
    if (_historyIndex > 0) {
      _historyIndex--;
    }
    
    return _commandHistory[_historyIndex];
  }

  /// 获取下一个命令
  String? getNextCommand() {
    if (_commandHistory.isEmpty) return null;
    
    if (_historyIndex < _commandHistory.length - 1) {
      _historyIndex++;
      return _commandHistory[_historyIndex];
    }
    
    _historyIndex = _commandHistory.length;
    return '';
  }

  /// 发送输入到当前进程
  void sendInput(String input) {
    _currentProcess?.stdin.write('$input\n');
  }

  /// 终止当前进程
  Future<void> kill() async {
    if (_currentProcess != null) {
      _currentProcess!.kill();
      _isRunning = false;
      _addOutput(TerminalOutputType.system, '\n[Process terminated]');
    }
  }

  /// 清空历史
  void clearHistory() {
    _history.clear();
  }

  /// 导出历史
  Future<String> exportHistory() async {
    final buffer = StringBuffer();
    buffer.writeln('Miss IDE Terminal History');
    buffer.writeln('Export Time: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final output in _history) {
      buffer.writeln('${output.typeTag}${output.text}');
    }

    return buffer.toString();
  }

  void dispose() {
    _outputController.close();
    _currentProcess?.kill();
  }
}

/// SDK管理器引用（需导入实际模块）
dynamic get sdkManager => throw UnimplementedError('sdkManager should be imported');

/// 全局终端模拟器实例
final terminalEmulator = TerminalEmulator();
