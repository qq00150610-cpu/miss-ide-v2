import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 代码编辑器状态
class EditorState {
  final String? currentFilePath;
  final String? content;
  final int cursorPosition;
  final int selectionStart;
  final int selectionEnd;
  final bool isDirty;
  final String? language;

  const EditorState({
    this.currentFilePath,
    this.content,
    this.cursorPosition = 0,
    this.selectionStart = 0,
    this.selectionEnd = 0,
    this.isDirty = false,
    this.language,
  });

  EditorState copyWith({
    String? currentFilePath,
    String? content,
    int? cursorPosition,
    int? selectionStart,
    int? selectionEnd,
    bool? isDirty,
    String? language,
  }) {
    return EditorState(
      currentFilePath: currentFilePath ?? this.currentFilePath,
      content: content ?? this.content,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
      isDirty: isDirty ?? this.isDirty,
      language: language ?? this.language,
    );
  }
}

/// 代码编辑器控制器
class CodeEditorController extends ChangeNotifier {
  final List<EditorTab> _tabs = [];
  int _currentTabIndex = -1;
  final Map<String, EditorState> _editorStates = {};
  final _undoStack = <_UndoItem>[];
  final _redoStack = <_UndoItem>[];
  static const int _maxUndoSteps = 100;

  /// 所有标签页
  List<EditorTab> get tabs => List.unmodifiable(_tabs);

  /// 当前标签页索引
  int get currentTabIndex => _currentTabIndex;

  /// 当前标签页
  EditorTab? get currentTab =>
      _currentTabIndex >= 0 && _currentTabIndex < _tabs.length
          ? _tabs[_currentTabIndex]
          : null;

  /// 是否有未保存的更改
  bool get hasUnsavedChanges => _editorStates.values.any((s) => s.isDirty);

  /// 能否撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 能否重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 打开文件
  Future<void> openFile(String filePath) async {
    // 检查是否已打开
    final existingIndex = _tabs.indexWhere((t) => t.path == filePath);
    if (existingIndex >= 0) {
      _currentTabIndex = existingIndex;
      notifyListeners();
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        logger.e(LogTags.editor, 'File not found: $filePath');
        return;
      }

      // 检查文件大小
      final stat = await file.stat();
      if (stat.size > AppConstants.maxFileSize) {
        logger.w(LogTags.editor, 'File too large: $filePath (${stat.size} bytes)');
        // 可以提示用户
      }

      final content = await file.readAsString();
      final language = ProgrammingLanguage.fromFileName(filePath);

      final tab = EditorTab(
        path: filePath,
        name: filePath.split('/').last,
        language: language,
      );

      _tabs.add(tab);
      _currentTabIndex = _tabs.length - 1;

      _editorStates[filePath] = EditorState(
        currentFilePath: filePath,
        content: content,
        language: language.displayName,
        isDirty: false,
      );

      _undoStack.clear();
      _redoStack.clear();

      logger.i(LogTags.editor, 'Opened file: $filePath');
      notifyListeners();
    } catch (e) {
      logger.e(LogTags.editor, 'Failed to open file: $filePath', error: e);
    }
  }

  /// 创建新文件
  void createNewFile({String? name, ProgrammingLanguage? language}) {
    final fileName = name ?? 'untitled.${language?.extension ?? 'txt'}';

    final tab = EditorTab(
      path: fileName,
      name: fileName,
      language: language ?? ProgrammingLanguage.unknown,
      isNew: true,
    );

    _tabs.add(tab);
    _currentTabIndex = _tabs.length - 1;

    _editorStates[fileName] = const EditorState(
      content: '',
      isDirty: true,
    );

    notifyListeners();
  }

  /// 关闭标签页
  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];
    _editorStates.remove(tab.path);
    _tabs.removeAt(index);

    if (_currentTabIndex >= _tabs.length) {
      _currentTabIndex = _tabs.length - 1;
    }

    notifyListeners();
  }

  /// 切换到标签页
  void switchToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  /// 更新内容
  void updateContent(String content, {int? cursorPosition}) {
    final tab = currentTab;
    if (tab == null) return;

    final currentState = _editorStates[tab.path] ?? const EditorState();
    
    // 保存撤销信息
    _saveUndoState(tab.path, currentState.content ?? '');

    _editorStates[tab.path] = currentState.copyWith(
      content: content,
      isDirty: true,
      cursorPosition: cursorPosition,
    );

    notifyListeners();
  }

  /// 保存文件
  Future<bool> saveFile({int? tabIndex}) async {
    final targetIndex = tabIndex ?? _currentTabIndex;
    if (targetIndex < 0 || targetIndex >= _tabs.length) return false;

    final tab = _tabs[targetIndex];
    final state = _editorStates[tab.path];
    if (state == null) return false;

    try {
      if (tab.isNew) {
        // 新文件需要保存到磁盘
        // TODO: 实现文件保存对话框
        return false;
      }

      final file = File(tab.path);
      await file.writeAsString(state.content ?? '');

      _editorStates[tab.path] = state.copyWith(isDirty: false);

      logger.i(LogTags.editor, 'Saved file: ${tab.path}');
      notifyListeners();
      return true;
    } catch (e) {
      logger.e(LogTags.editor, 'Failed to save file: ${tab.path}', error: e);
      return false;
    }
  }

  /// 撤销
  void undo() {
    final tab = currentTab;
    if (tab == null || _undoStack.isEmpty) return;

    final currentState = _editorStates[tab.path];
    if (currentState == null) return;

    final undoItem = _undoStack.removeLast();
    
    // 保存当前状态到重做栈
    _redoStack.add(_UndoItem(
      content: currentState.content ?? '',
      cursorPosition: currentState.cursorPosition,
    ));

    _editorStates[tab.path] = currentState.copyWith(
      content: undoItem.content,
      cursorPosition: undoItem.cursorPosition,
    );

    notifyListeners();
  }

  /// 重做
  void redo() {
    final tab = currentTab;
    if (tab == null || _redoStack.isEmpty) return;

    final currentState = _editorStates[tab.path];
    if (currentState == null) return;

    final redoItem = _redoStack.removeLast();
    
    // 保存当前状态到撤销栈
    _undoStack.add(_UndoItem(
      content: currentState.content ?? '',
      cursorPosition: currentState.cursorPosition,
    ));

    _editorStates[tab.path] = currentState.copyWith(
      content: redoItem.content,
      cursorPosition: redoItem.cursorPosition,
    );

    notifyListeners();
  }

  void _saveUndoState(String path, String content) {
    _undoStack.add(_UndoItem(content: content));
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// 获取当前编辑器状态
  EditorState? getCurrentState() {
    final tab = currentTab;
    if (tab == null) return null;
    return _editorStates[tab.path];
  }

  /// 获取指定标签页的状态
  EditorState? getStateForTab(int index) {
    if (index < 0 || index >= _tabs.length) return null;
    return _editorStates[_tabs[index].path];
  }
}

/// 编辑器标签页
class EditorTab {
  final String path;
  final String name;
  final ProgrammingLanguage language;
  final bool isNew;

  const EditorTab({
    required this.path,
    required this.name,
    required this.language,
    this.isNew = false,
  });
}

/// 撤销项
class _UndoItem {
  final String content;
  final int cursorPosition;

  const _UndoItem({
    required this.content,
    this.cursorPosition = 0,
  });
}
