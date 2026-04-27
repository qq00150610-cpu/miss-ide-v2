import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:miss_ide/features/file_manager/project_directory.dart';

class CodeEditorPage extends StatefulWidget {
  final String? filePath;
  final String? initialContent;
  final String? projectPath;

  const CodeEditorPage({
    super.key,
    this.filePath,
    this.initialContent,
    this.projectPath,
  });

  @override
  State<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<CodeEditorPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<EditorTab> _tabs = [];
  int _currentTabIndex = 0;
  bool _hasChanges = false;
  String _currentFilePath = '';
  String _currentLanguage = 'Dart';
  String? _currentProjectPath;
  bool _isDirectoryExpanded = false;
  
  // 自动保存相关
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;

  @override
  void initState() {
    super.initState();
    _currentProjectPath = widget.projectPath;
    if (widget.initialContent != null) {
      _controller.text = widget.initialContent!;
    }
    if (widget.filePath != null) {
      _loadFile(widget.filePath!);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs.isEmpty ? '代码编辑器' : _tabs[_currentTabIndex].fileName),
        leading: _currentProjectPath != null
            ? IconButton(
                icon: Icon(_isDirectoryExpanded ? Icons.menu_open : Icons.menu),
                onPressed: () {
                  setState(() {
                    _isDirectoryExpanded = !_isDirectoryExpanded;
                  });
                },
                tooltip: _isDirectoryExpanded ? '收起目录' : '展开目录',
              )
            : null,
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
              const PopupMenuItem(value: 'find', child: Text('查找')),
              const PopupMenuItem(value: 'selectall', child: Text('全选')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧项目目录
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isDirectoryExpanded && _currentProjectPath != null ? 200 : 0,
            child: _isDirectoryExpanded && _currentProjectPath != null
                ? ProjectDirectoryPanel(
                    projectPath: _currentProjectPath!,
                    onFileSelected: _onFileSelectedFromDirectory,
                  )
                : const SizedBox.shrink(),
          ),
          // 右侧编辑区
          Expanded(
            child: Column(
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
                                if (tab.hasChanges)
                                  const Text(' ●', style: TextStyle(color: Colors.orange, fontSize: 8)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // 工具栏
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Row(
                    children: [
                      Text(_currentLanguage, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _currentFilePath.isEmpty ? '(新建文件)' : _currentFilePath,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('行: ${_getCurrentLine()}', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
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
                              const Icon(Icons.code, size: 64, color: Colors.grey),
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
                      : TextField(
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
    
    // 10秒后自动保存
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 10), () {
      if (_hasChanges && _tabs.isNotEmpty && _tabs[_currentTabIndex].path.isNotEmpty) {
        _autoSave();
      }
    });
  }
  
  Future<void> _autoSave() async {
    if (_isAutoSaving || _tabs.isEmpty) return;
    
    final tab = _tabs[_currentTabIndex];
    if (tab.path.isEmpty || !File(tab.path).existsSync()) return;
    
    _isAutoSaving = true;
    try {
      final file = File(tab.path);
      await file.writeAsString(_controller.text);
      if (mounted) {
        setState(() {
          _tabs[_currentTabIndex].hasChanges = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已自动保存'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('自动保存失败: $e');
    }
    _isAutoSaving = false;
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
      case 'py': return Icons.code;
      case 'js': return Icons.javascript;
      case 'ts': return Icons.code;
      case 'html': return Icons.html;
      case 'css': return Icons.style;
      case 'json': return Icons.data_object;
      case 'yaml':
      case 'yml': return Icons.settings;
      case 'md': return Icons.description;
      case 'xml': return Icons.code;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Colors.blue;
      case 'java': return Colors.orange;
      case 'kt': return Colors.purple;
      case 'py': return Colors.green;
      case 'js': return Colors.yellow;
      case 'ts': return Colors.blue;
      case 'html': return Colors.orange;
      case 'css': return Colors.blue;
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
      case 'py': return 'Python';
      case 'js': return 'JavaScript';
      case 'ts': return 'TypeScript';
      case 'html': return 'HTML';
      case 'css': return 'CSS';
      case 'json': return 'JSON';
      case 'yaml':
      case 'yml': return 'YAML';
      case 'md': return 'Markdown';
      case 'xml': return 'XML';
      case 'sql': return 'SQL';
      case 'sh': return 'Shell';
      case 'c': return 'C';
      case 'cpp': return 'C++';
      case 'go': return 'Go';
      case 'rs': return 'Rust';
      case 'php': return 'PHP';
      case 'rb': return 'Ruby';
      case 'swift': return 'Swift';
      default: return 'Text';
    }
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
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
        _showError('文件不存在');
        return;
      }
      final content = await file.readAsString();
      final fileName = path.split('/').last;
      
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
        if (_tabs.isEmpty) {
          _tabs.add(EditorTab(
            fileName: fileName,
            path: outputPath,
            content: _controller.text,
          ));
          _currentTabIndex = 0;
        } else {
          _tabs[_currentTabIndex] = EditorTab(
            fileName: fileName,
            path: outputPath,
            content: _controller.text,
          );
        }
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
    showDialog(
      context: context,
      builder: (context) {
        String selectedType = 'dart';
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('新建文件'),
            content: DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: '文件类型'),
              items: ['dart', 'java', 'kt', 'py', 'js', 'ts', 'html', 'css', 'json', 'yaml', 'md', 'txt']
                  .map((type) => DropdownMenuItem(value: type, child: Text('.$type')))
                  .toList(),
              onChanged: (type) => setState(() => selectedType = type!),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createNewFile('untitled', selectedType);
                },
                child: const Text('创建'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createNewFile(String name, String type) {
    if (!name.endsWith('.$type')) name = '$name.$type';
    String template = '';
    switch (type) {
      case 'dart':
        template = '// $name\n\nvoid main() {\n  // TODO: implement\n}\n';
        break;
      case 'java':
        template = '// $name\n\npublic class ${name.replaceAll('.java', '')} {\n    public static void main(String[] args) {\n        // TODO: implement\n    }\n}\n';
        break;
      case 'py':
        template = '# $name\n\ndef main():\n    # TODO: implement\n    pass\n\nif __name__ == "__main__":\n    main()\n';
        break;
      case 'js':
        template = '// $name\n\nfunction main() {\n    // TODO: implement\n}\n\nmain();\n';
        break;
      case 'json':
        template = '{\n  \n}\n';
        break;
      case 'yaml':
        template = '# $name\n\n';
        break;
      case 'md':
        template = '# ${name.replaceAll('.md', '')}\n\n';
        break;
      default:
        template = '';
    }
    
    setState(() {
      _tabs.add(EditorTab(fileName: name, path: '', content: template));
      _currentTabIndex = _tabs.length - 1;
      _controller.text = template;
      _currentFilePath = '';
      _currentLanguage = _getLanguage(name);
      _hasChanges = true;
    });
  }

  void _switchTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    if (_tabs.isNotEmpty) _tabs[_currentTabIndex].content = _controller.text;
    
    setState(() {
      _currentTabIndex = index;
      _controller.text = _tabs[index].content;
      _currentFilePath = _tabs[index].path;
      _currentLanguage = _getLanguage(_tabs[index].fileName);
      _hasChanges = _tabs[index].hasChanges;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'find':
        _showFindDialog();
        break;
      case 'selectall':
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
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
          decoration: const InputDecoration(hintText: '输入搜索内容'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
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
    final index = _controller.text.indexOf(text);
    if (index >= 0) {
      _controller.selection = TextSelection(baseOffset: index, extentOffset: index + text.length);
      _showSuccess('已找到');
    } else {
      _showError('未找到');
    }
  }

  void _onFileSelectedFromDirectory(String filePath) {
    _loadFile(filePath);
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
  final String fileName;
  final String path;
  String content;
  bool hasChanges;

  EditorTab({
    required this.fileName,
    required this.path,
    required this.content,
    this.hasChanges = false,
  });
}
