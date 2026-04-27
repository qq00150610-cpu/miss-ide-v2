import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class CodeEditorPage extends StatefulWidget {
  final String? filePath;
  final String? initialContent;
  
  const CodeEditorPage({
    super.key, 
    this.filePath,
    this.initialContent,
  });

  @override
  State<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<CodeEditorPage> {
  final TextEditingController _controller = TextEditingController();
  final List<EditorTab> _tabs = [];
  int _currentTabIndex = 0;
  bool _hasChanges = false;
  String _currentFilePath = '';
  String _currentLanguage = 'Dart';

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _controller.text = widget.initialContent!;
    }
    if (widget.filePath != null) {
      _loadFile(widget.filePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs.isEmpty ? '代码编辑器' : _tabs[_currentTabIndex].fileName),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: _hasChanges ? Colors.orange : null),
            onPressed: _saveCurrentFile,
            tooltip: '保存',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openFile,
            tooltip: '打开文件',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _newFile,
            tooltip: '新建文件',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'undo', child: ListTile(leading: Icon(Icons.undo), title: Text('撤销'))),
              const PopupMenuItem(value: 'redo', child: ListTile(leading: Icon(Icons.redo), title: Text('重做'))),
              const PopupMenuItem(value: 'find', child: ListTile(leading: Icon(Icons.search), title: Text('查找'))),
              const PopupMenuItem(value: 'format', child: ListTile(leading: Icon(Icons.format_align_left), title: Text('格式化'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 文件标签栏
          if (_tabs.isNotEmpty)
            Container(
              height: 36,
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = index == _currentTabIndex;
                  return GestureDetector(
                    onTap: () => _switchTab(index),
                    onLongPress: () => _closeTab(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive 
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: isActive 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(tab.fileName),
                            size: 14,
                            color: _getFileColor(tab.fileName),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: tab.hasChanges ? Colors.orange : null,
                            ),
                          ),
                          if (tab.hasChanges) ...[
                            const SizedBox(width: 4),
                            const Text('*', style: TextStyle(color: Colors.orange)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // 工具栏
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(_currentLanguage, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                Text(_currentFilePath, style: const TextStyle(fontSize: 11)),
                const Spacer(),
                Text('行: ${_getCurrentLine()}', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                Text('列: ${_getCurrentColumn()}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          
          // 代码编辑区
          Expanded(
            child: _tabs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.code,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        const Text('没有打开的文件'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _openFile,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('打开文件'),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: _newFile,
                              icon: const Icon(Icons.add),
                              label: const Text('新建文件'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      onChanged: (_) => _onContentChanged(),
                    ),
                  ),
          ),
          
          // 底部状态栏
          Container(
            height: 24,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (_hasChanges)
                  const Text('未保存', style: TextStyle(fontSize: 11, color: Colors.orange))
                else
                  const Text('已保存', style: TextStyle(fontSize: 11)),
                const Spacer(),
                Text('UTF-8', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Text(_currentLanguage, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onContentChanged() {
    if (!_hasChanges && _tabs.isNotEmpty) {
      setState(() {
        _hasChanges = true;
        _tabs[_currentTabIndex].hasChanges = true;
      });
    }
  }

  int _getCurrentLine() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return 1;
    return text.substring(0, cursorPos).split('\n').length;
  }

  int _getCurrentColumn() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return 1;
    final lines = text.substring(0, cursorPos).split('\n');
    return lines.last.length + 1;
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Icons.code;
      case 'java': return Icons.coffee;
      case 'kt': return Icons.code;
      case 'xml': return Icons.code;
      case 'json': return Icons.data_object;
      case 'yaml':
      case 'yml': return Icons.settings;
      case 'md': return Icons.description;
      case 'html': return Icons.html;
      case 'css': return Icons.style;
      case 'js': return Icons.javascript;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Colors.blue;
      case 'java': return Colors.orange;
      case 'kt': return Colors.purple;
      case 'xml': return Colors.green;
      case 'json': return Colors.amber;
      case 'yaml':
      case 'yml': return Colors.cyan;
      default: return Colors.grey;
    }
  }

  String _getLanguage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return 'Dart';
      case 'java': return 'Java';
      case 'kt': return 'Kotlin';
      case 'xml': return 'XML';
      case 'json': return 'JSON';
      case 'yaml':
      case 'yml': return 'YAML';
      case 'md': return 'Markdown';
      case 'html': return 'HTML';
      case 'css': return 'CSS';
      case 'js': return 'JavaScript';
      case 'ts': return 'TypeScript';
      default: return 'Text';
    }
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            await _loadFile(file.path!);
          }
        }
      }
    } catch (e) {
      _showError('打开文件失败: $e');
    }
  }

  Future<void> _loadFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        _showError('文件不存在: $path');
        return;
      }
      
      final content = await file.readAsString();
      final fileName = path.split('/').last;
      
      // 检查是否已打开
      final existingIndex = _tabs.indexWhere((t) => t.path == path);
      if (existingIndex >= 0) {
        _switchTab(existingIndex);
        return;
      }
      
      setState(() {
        _tabs.add(EditorTab(
          fileName: fileName,
          path: path,
          content: content,
        ));
        _currentTabIndex = _tabs.length - 1;
        _controller.text = content;
        _currentFilePath = path;
        _currentLanguage = _getLanguage(fileName);
        _hasChanges = false;
      });
    } catch (e) {
      _showError('读取文件失败: $e');
    }
  }

  Future<void> _saveCurrentFile() async {
    if (_tabs.isEmpty) return;
    
    final tab = _tabs[_currentTabIndex];
    
    if (tab.path.isEmpty) {
      // 新文件，需要选择保存位置
      await _saveAs();
      return;
    }
    
    try {
      final file = File(tab.path);
      await file.writeAsString(_controller.text);
      
      setState(() {
        _tabs[_currentTabIndex].hasChanges = false;
        _hasChanges = false;
      });
      
      _showSuccess('文件已保存');
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  Future<void> _saveAs() async {
    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: 'untitled.dart',
      );
      
      if (outputPath == null) return;
      
      final file = File(outputPath);
      await file.writeAsString(_controller.text);
      
      final fileName = outputPath.split('/').last;
      
      setState(() {
        _tabs[_currentTabIndex] = EditorTab(
          fileName: fileName,
          path: outputPath,
          content: _controller.text,
        );
        _currentFilePath = outputPath;
        _currentLanguage = _getLanguage(fileName);
        _hasChanges = false;
      });
      
      _showSuccess('文件已保存: $fileName');
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  void _newFile() {
    final controller = TextEditingController(text: 'untitled');
    String selectedType = 'dart';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建文件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '文件名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: '文件类型',
                  border: OutlineInputBorder(),
                ),
                items: ['dart', 'java', 'kt', 'xml', 'json', 'yaml', 'md', 'txt'].map((type) {
                  return DropdownMenuItem(value: type, child: Text('.$type'));
                }).toList(),
                onChanged: (type) {
                  setState(() => selectedType = type!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _createNewFile(controller.text, selectedType);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewFile(String name, String type) {
    if (!name.endsWith('.$type')) {
      name = '$name.$type';
    }
    
    String template = '';
    switch (type) {
      case 'dart':
        template = '''
// $name
// Created at ${DateTime.now()}

void main() {
  // TODO: implement
}
''';
        break;
      case 'java':
        template = '''
// $name
// Created at ${DateTime.now()}

public class ${name.replaceAll('.java', '')} {
    public static void main(String[] args) {
        // TODO: implement
    }
}
''';
        break;
      case 'kt':
        template = '''
// $name
// Created at ${DateTime.now()}

fun main() {
    // TODO: implement
}
''';
        break;
      case 'json':
        template = '{\n  \n}\n';
        break;
      case 'yaml':
        template = '# $name\n# Created at ${DateTime.now()}\n\n';
        break;
      case 'xml':
        template = '''<?xml version="1.0" encoding="utf-8"?>
<resources>

</resources>
''';
        break;
      case 'md':
        template = '# ${name.replaceAll('.md', '')}\n\nCreated at ${DateTime.now()}\n\n';
        break;
    }
    
    setState(() {
      _tabs.add(EditorTab(
        fileName: name,
        path: '',
        content: template,
      ));
      _currentTabIndex = _tabs.length - 1;
      _controller.text = template;
      _currentFilePath = '';
      _currentLanguage = _getLanguage(name);
      _hasChanges = true;
    });
  }

  void _switchTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    
    // 保存当前标签的内容
    if (_tabs.isNotEmpty) {
      _tabs[_currentTabIndex].content = _controller.text;
    }
    
    setState(() {
      _currentTabIndex = index;
      _controller.text = _tabs[index].content;
      _currentFilePath = _tabs[index].path;
      _currentLanguage = _getLanguage(_tabs[index].fileName);
      _hasChanges = _tabs[index].hasChanges;
    });
  }

  void _closeTab(int index) {
    if (_tabs.isEmpty || index < 0 || index >= _tabs.length) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭标签'),
        content: Text('确定要关闭 ${_tabs[index].fileName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _tabs.removeAt(index);
                if (_tabs.isEmpty) {
                  _controller.clear();
                  _currentFilePath = '';
                  _hasChanges = false;
                } else {
                  if (_currentTabIndex >= _tabs.length) {
                    _currentTabIndex = _tabs.length - 1;
                  }
                  _switchTab(_currentTabIndex);
                }
              });
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'undo':
        // TODO: 实现撤销
        break;
      case 'redo':
        // TODO: 实现重做
        break;
      case 'find':
        _showFindDialog();
        break;
      case 'format':
        // TODO: 实现格式化
        break;
    }
  }

  void _showFindDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查找'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入搜索内容',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _findText(controller.text);
            },
            child: const Text('查找'),
          ),
        ],
      ),
    );
  }

  void _findText(String text) {
    if (text.isEmpty) return;
    
    final content = _controller.text;
    final index = content.indexOf(text);
    
    if (index >= 0) {
      _controller.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + text.length,
      );
      _showSuccess('找到: $text');
    } else {
      _showError('未找到: $text');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class EditorTab {
  String fileName;
  String path;
  String content;
  bool hasChanges;

  EditorTab({
    required this.fileName,
    required this.path,
    required this.content,
    this.hasChanges = false,
  });
}
