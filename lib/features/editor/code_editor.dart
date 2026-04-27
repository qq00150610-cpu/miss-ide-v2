import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../file_manager/project_directory.dart';

/// 编辑器标签
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

/// 代码语言信息
class CodeLanguage {
  final String name;
  final String extension;
  final IconData icon;
  final Color color;
  final String template;
  
  const CodeLanguage({
    required this.name,
    required this.extension,
    required this.icon,
    required this.color,
    required this.template,
  });
}

class CodeEditorPage extends StatefulWidget {
  final String? filePath;
  final String? initialContent;
  final String? projectPath; // 项目根目录路径
  
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
  final List<EditorTab> _tabs = [];
  int _currentTabIndex = 0;
  bool _hasChanges = false;
  String _currentFilePath = '';
  String _currentLanguage = 'Text';
  final ScrollController _scrollController = ScrollController();
  
  // 目录侧边栏状态
  bool _isDirectoryExpanded = false;
  String? _currentProjectPath;
  
  /// 支持的编程语言
  static const Map<String, CodeLanguage> _languages = {
    // Web
    'html': CodeLanguage(
      name: 'HTML',
      extension: 'html',
      icon: Icons.html,
      color: Colors.orange,
      template: '<!DOCTYPE html>\n<html>\n<head>\n  <meta charset="UTF-8">\n  <title></title>\n</head>\n<body>\n  \n</body>\n</html>',
    ),
    'css': CodeLanguage(
      name: 'CSS',
      extension: 'css',
      icon: Icons.style,
      color: Colors.blue,
      template: '/* @author  @date */\n\nselector {\n  property: value;\n}',
    ),
    'js': CodeLanguage(
      name: 'JavaScript',
      extension: 'js',
      icon: Icons.javascript,
      color: Colors.amber,
      template: '// @author  @date\n\nfunction main() {\n  console.log("Hello, JavaScript!");\n}\n\nmain();',
    ),
    'ts': CodeLanguage(
      name: 'TypeScript',
      extension: 'ts',
      icon: Icons.code,
      color: Colors.blue,
      template: '// @author  @date\n\nfunction main(): void {\n  console.log("Hello, TypeScript!");\n}\n\nmain();',
    ),
    
    // Mobile
    'dart': CodeLanguage(
      name: 'Dart',
      extension: 'dart',
      icon: Icons.flutter_dash,
      color: Colors.blue,
      template: '// @author  @date\n\nvoid main() {\n  print("Hello, Dart!");\n}',
    ),
    'swift': CodeLanguage(
      name: 'Swift',
      extension: 'swift',
      icon: Icons.code,
      color: Colors.orange,
      template: '// @author  @date\n\nimport Foundation\n\nfunc main() {\n    print("Hello, Swift!")\n}\n\nmain()',
    ),
    'kotlin': CodeLanguage(
      name: 'Kotlin',
      extension: 'kt',
      icon: Icons.code,
      color: Colors.purple,
      template: '// @author  @date\n\nfun main() {\n    println("Hello, Kotlin!")\n}',
    ),
    'm': CodeLanguage(
      name: 'Objective-C',
      extension: 'm',
      icon: Icons.code,
      color: Colors.blue,
      template: '// @author  @date\n\n#import <Foundation/Foundation.h>\n\nint main(int argc, const char * argv[]) {\n    @autoreleasepool {\n        NSLog(@"Hello, Objective-C!");\n    }\n    return 0;\n}',
    ),
    'mm': CodeLanguage(
      name: 'Objective-C++',
      extension: 'mm',
      icon: Icons.code,
      color: Colors.blue,
      template: '// @author  @date\n\n#import <Foundation/Foundation.h>\n\nint main(int argc, const char * argv[]) {\n    @autoreleasepool {\n        NSLog(@"Hello, Objective-C++!");\n    }\n    return 0;\n}',
    ),
    
    // Backend
    'java': CodeLanguage(
      name: 'Java',
      extension: 'java',
      icon: Icons.coffee,
      color: Colors.orange,
      template: '// @author  @date\n\npublic class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, Java!");\n    }\n}',
    ),
    'py': CodeLanguage(
      name: 'Python',
      extension: 'py',
      icon: Icons.code,
      color: Colors.green,
      template: '# @author  @date\n\ndef main():\n    print("Hello, Python!")\n\nif __name__ == "__main__":\n    main()',
    ),
    'go': CodeLanguage(
      name: 'Go',
      extension: 'go',
      icon: Icons.code,
      color: Colors.cyan,
      template: '// @author  @date\n\npackage main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, Go!")\n}',
    ),
    'rs': CodeLanguage(
      name: 'Rust',
      extension: 'rs',
      icon: Icons.code,
      color: Colors.deepOrange,
      template: '// @author  @date\n\nfn main() {\n    println!("Hello, Rust!");\n}',
    ),
    'rb': CodeLanguage(
      name: 'Ruby',
      extension: 'rb',
      icon: Icons.code,
      color: Colors.red,
      template: '# @author  @date\n\ndef main\n  puts "Hello, Ruby!"\nend\n\nmain',
    ),
    'php': CodeLanguage(
      name: 'PHP',
      extension: 'php',
      icon: Icons.code,
      color: Colors.indigo,
      template: '<?php\n// @author  @date\n\necho "Hello, PHP!";\n?>',
    ),
    'c': CodeLanguage(
      name: 'C',
      extension: 'c',
      icon: Icons.memory,
      color: Colors.blue,
      template: '// @author  @date\n\n#include <stdio.h>\n\nint main() {\n    printf("Hello, C!\\n");\n    return 0;\n}',
    ),
    'cpp': CodeLanguage(
      name: 'C++',
      extension: 'cpp',
      icon: Icons.memory,
      color: Colors.blue,
      template: '// @author  @date\n\n#include <iostream>\n\nint main() {\n    std::cout << "Hello, C++!" << std::endl;\n    return 0;\n}',
    ),
    'h': CodeLanguage(
      name: 'C/C++ Header',
      extension: 'h',
      icon: Icons.memory,
      color: Colors.blue,
      template: '// @author  @date\n\n#ifndef HEADER_H\n#define HEADER_H\n\n// Header content\n\n#endif // HEADER_H',
    ),
    
    // Shell
    'sh': CodeLanguage(
      name: 'Shell',
      extension: 'sh',
      icon: Icons.terminal,
      color: Colors.green,
      template: '#!/bin/bash\n# @author  @date\n\necho "Hello, Shell!"',
    ),
    'bash': CodeLanguage(
      name: 'Bash',
      extension: 'bash',
      icon: Icons.terminal,
      color: Colors.green,
      template: '#!/bin/bash\n# @author  @date\n\necho "Hello, Bash!"',
    ),
    
    // Database
    'sql': CodeLanguage(
      name: 'SQL',
      extension: 'sql',
      icon: Icons.storage,
      color: Colors.teal,
      template: '-- @author  @date\n\nSELECT * FROM table_name;\n\nINSERT INTO table_name (column1, column2)\nVALUES (value1, value2);',
    ),
    
    // Config
    'json': CodeLanguage(
      name: 'JSON',
      extension: 'json',
      icon: Icons.data_object,
      color: Colors.amber,
      template: '{\n  "name": "",\n  "version": "1.0.0",\n  "@date": ""\n}',
    ),
    'yaml': CodeLanguage(
      name: 'YAML',
      extension: 'yaml',
      icon: Icons.settings,
      color: Colors.cyan,
      template: '# @author  @date\n\nname: \nversion: 1.0.0',
    ),
    'yml': CodeLanguage(
      name: 'YAML',
      extension: 'yml',
      icon: Icons.settings,
      color: Colors.cyan,
      template: '# @author  @date\n\nname: \nversion: 1.0.0',
    ),
    'xml': CodeLanguage(
      name: 'XML',
      extension: 'xml',
      icon: Icons.code,
      color: Colors.green,
      template: '<?xml version="1.0" encoding="UTF-8"?>\n<root>\n  <!-- @date -->\n</root>',
    ),
    'toml': CodeLanguage(
      name: 'TOML',
      extension: 'toml',
      icon: Icons.settings,
      color: Colors.brown,
      template: '# @author  @date\n\n[package]\nname = ""\nversion = "1.0.0"',
    ),
    'ini': CodeLanguage(
      name: 'INI',
      extension: 'ini',
      icon: Icons.settings,
      color: Colors.grey,
      template: '; @author  @date\n\n[Section]\nkey=value',
    ),
    'properties': CodeLanguage(
      name: 'Properties',
      extension: 'properties',
      icon: Icons.settings,
      color: Colors.brown,
      template: '# @author  @date\n\nkey=value',
    ),
    'env': CodeLanguage(
      name: 'Env',
      extension: 'env',
      icon: Icons.settings,
      color: Colors.amber,
      template: '# @author  @date\n\nENV_VAR=value',
    ),
    
    // Protocol
    'proto': CodeLanguage(
      name: 'Protobuf',
      extension: 'proto',
      icon: Icons.description,
      color: Colors.blue,
      template: '// @author  @date\n\nsyntax = "proto3";\n\npackage example;\n\nmessage Person {\n  string name = 1;\n  int32 id = 2;\n}',
    ),
    
    // Markup
    'md': CodeLanguage(
      name: 'Markdown',
      extension: 'md',
      icon: Icons.description,
      color: Colors.blue,
      template: '# @author  @date\n\n## 标题\n\n内容...',
    ),
    'txt': CodeLanguage(
      name: 'Text',
      extension: 'txt',
      icon: Icons.text_fields,
      color: Colors.grey,
      template: '',
    ),
  };

  @override
  void initState() {
    super.initState();
    _currentProjectPath = widget.projectPath;
    if (widget.initialContent != null) {
      _controller.text = widget.initialContent!;
    }
    if (widget.filePath != null) {
      _loadFile(widget.filePath!);
      // 如果文件路径在某个项目中，自动设置项目路径
      if (_currentProjectPath == null) {
        _currentProjectPath = p.dirname(widget.filePath!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs.isEmpty ? '代码编辑器' : _tabs[_currentTabIndex].fileName),
        leading: Row(
          children: [
            // 目录展开/收起按钮
            if (_currentProjectPath != null)
              IconButton(
                icon: Icon(
                  _isDirectoryExpanded ? Icons.menu_open : Icons.menu,
                  color: _isDirectoryExpanded ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () {
                  setState(() {
                    _isDirectoryExpanded = !_isDirectoryExpanded;
                  });
                },
                tooltip: _isDirectoryExpanded ? '收起目录' : '展开目录',
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: _hasChanges ? Colors.orange : null),
            onPressed: _saveCurrentFile,
            tooltip: '保存',
          ),
          IconButton(
            icon: const Icon(Icons.save_as),
            onPressed: _saveAs,
            tooltip: '另存为',
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
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAll,
            tooltip: '复制全部',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'undo', child: ListTile(leading: Icon(Icons.undo), title: Text('撤销'), dense: true)),
              const PopupMenuItem(value: 'redo', child: ListTile(leading: Icon(Icons.redo), title: Text('重做'), dense: true)),
              const PopupMenuItem(value: 'find', child: ListTile(leading: Icon(Icons.search), title: Text('查找'), dense: true)),
              const PopupMenuItem(value: 'replace', child: ListTile(leading: Icon(Icons.find_replace), title: Text('替换'), dense: true)),
              const PopupMenuItem(value: 'selectall', child: ListTile(leading: Icon(Icons.select_all), title: Text('全选'), dense: true)),
              const PopupMenuItem(value: 'format', child: ListTile(leading: Icon(Icons.format_align_left), title: Text('格式化'), dense: true)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'language', child: ListTile(leading: Icon(Icons.code), title: Text('切换语言'), dense: true)),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧项目目录
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isDirectoryExpanded && _currentProjectPath != null ? 220 : 0,
            child: _isDirectoryExpanded && _currentProjectPath != null
                ? ProjectDirectoryPanel(
                    projectPath: _currentProjectPath!,
                    onFileSelected: _onFileSelectedFromDirectory,
                    isExpanded: _isDirectoryExpanded,
                    onToggle: () {
                      setState(() {
                        _isDirectoryExpanded = !_isDirectoryExpanded;
                      });
                    },
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
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _tabs.length,
                            itemBuilder: (context, index) {
                              final tab = _tabs[index];
                              final isActive = index == _currentTabIndex;
                              return GestureDetector(
                                onTap: () => _switchTab(index),
                                onLongPress: () => _showTabMenu(index),
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
                                        const Text('●', style: TextStyle(color: Colors.orange, fontSize: 8)),
                                      ],
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _closeTab(index),
                                        child: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          
          // 工具栏
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Row(
              children: [
                // 语言选择器
                InkWell(
                  onTap: _showLanguagePicker,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _getLanguageIcon(_currentLanguage),
                          size: 14,
                          color: _getLanguageColor(_currentLanguage),
                        ),
                        const SizedBox(width: 4),
                        Text(_currentLanguage, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 文件路径
                Expanded(
                  child: Text(
                    _currentFilePath.isEmpty ? '(新建文件)' : _currentFilePath,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                // 行列信息
                Text('行: ${_getCurrentLine()}', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                Text('列: ${_getCurrentColumn()}', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
                Text('字符: ${_controller.text.length}', style: const TextStyle(fontSize: 11)),
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
                        const SizedBox(height: 16),
                        // 支持的语言列表
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '支持的编程语言',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildLanguageChip('Dart', Colors.blue),
                                  _buildLanguageChip('Python', Colors.green),
                                  _buildLanguageChip('JavaScript', Colors.amber),
                                  _buildLanguageChip('TypeScript', Colors.blue),
                                  _buildLanguageChip('Java', Colors.orange),
                                  _buildLanguageChip('Go', Colors.cyan),
                                  _buildLanguageChip('Rust', Colors.deepOrange),
                                  _buildLanguageChip('C/C++', Colors.blue),
                                  _buildLanguageChip('Swift', Colors.orange),
                                  _buildLanguageChip('Kotlin', Colors.purple),
                                  _buildLanguageChip('Ruby', Colors.red),
                                  _buildLanguageChip('PHP', Colors.indigo),
                                  _buildLanguageChip('SQL', Colors.teal),
                                  _buildLanguageChip('HTML/CSS', Colors.orange),
                                  _buildLanguageChip('Shell', Colors.green),
                                  _buildLanguageChip('+20 更多', Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 行号栏
                        Container(
                          width: 48,
                          padding: const EdgeInsets.only(top: 16, right: 8),
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              _controller.text.split('\n').length,
                              (index) => Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 编辑区
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            scrollController: _scrollController,
                            maxLines: null,
                            expands: true,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.5,
                              color: Theme.of(context).colorScheme.onSurface,
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
          ),
          
          // 底部状态栏
          Container(
            height: 24,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (_hasChanges)
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      const Text('未保存', style: TextStyle(fontSize: 11, color: Colors.orange)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('已保存', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                    ],
                  ),
                const Spacer(),
                Text('UTF-8', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(
                  _getLanguageIcon(_currentLanguage),
                  size: 12,
                  color: _getLanguageColor(_currentLanguage),
                ),
                const SizedBox(width: 4),
                Text(_currentLanguage, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 从目录面板选择文件的回调
  void _onFileSelectedFromDirectory(String filePath) {
    _loadFile(filePath);
    // 自动展开目录侧边栏
    if (!_isDirectoryExpanded) {
      setState(() {
        _isDirectoryExpanded = true;
      });
    }
  }

  Widget _buildLanguageChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择语言',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView(
                children: _languages.entries.map((entry) {
                  final lang = entry.value;
                  final isSelected = lang.name == _currentLanguage;
                  return ListTile(
                    leading: Icon(lang.icon, color: lang.color),
                    title: Text(lang.name),
                    subtitle: Text('.${lang.extension}'),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      _changeLanguage(lang);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLanguage(CodeLanguage lang) {
    if (_tabs.isEmpty) {
      // 新建文件时应用模板
      _controller.text = lang.template
          .replaceAll('@author', '')
          .replaceAll('@date', DateTime.now().toString().substring(0, 10));
      _currentLanguage = lang.name;
    } else {
      setState(() {
        _currentLanguage = lang.name;
      });
    }
  }

  void _showTabMenu(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('关闭'),
            onTap: () {
              Navigator.pop(context);
              _closeTab(index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close_fullscreen),
            title: const Text('关闭其他'),
            onTap: () {
              Navigator.pop(context);
              _closeOtherTabs(index);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('关闭右侧'),
            onTap: () {
              Navigator.pop(context);
              _closeTabsToRight(index);
            },
          ),
        ],
      ),
    );
  }

  void _closeOtherTabs(int keepIndex) {
    setState(() {
      _tabs.removeWhere((tab) => tab.hasChanges == false);
      if (_tabs.length > 1 && !_tabs[keepIndex].hasChanges) {
        _tabs.removeAt(keepIndex);
      }
      if (_tabs.isEmpty) {
        _hasChanges = false;
        _currentFilePath = '';
        _currentLanguage = 'Text';
        _controller.clear();
      } else {
        _currentTabIndex = _tabs.length - 1;
        _controller.text = _tabs[_currentTabIndex].content;
        _currentFilePath = _tabs[_currentTabIndex].path;
        _currentLanguage = _getLanguage(_tabs[_currentTabIndex].fileName);
        _hasChanges = _tabs[_currentTabIndex].hasChanges;
      }
    });
  }

  void _closeTabsToRight(int fromIndex) {
    setState(() {
      _tabs.removeRange(fromIndex + 1, _tabs.length);
      if (_tabs.isEmpty) {
        _hasChanges = false;
        _currentFilePath = '';
        _currentLanguage = 'Text';
        _controller.clear();
      } else {
        _currentTabIndex = _tabs.length - 1;
        _controller.text = _tabs[_currentTabIndex].content;
        _currentFilePath = _tabs[_currentTabIndex].path;
        _currentLanguage = _getLanguage(_tabs[_currentTabIndex].fileName);
        _hasChanges = _tabs[_currentTabIndex].hasChanges;
      }
    });
  }

  void _onContentChanged() {
    if (_tabs.isEmpty) {
      if (!_hasChanges) {
        setState(() => _hasChanges = true);
      }
      return;
    }
    
    if (!_tabs[_currentTabIndex].hasChanges) {
      setState(() {
        _hasChanges = true;
        _tabs[_currentTabIndex].hasChanges = true;
        _tabs[_currentTabIndex].content = _controller.text;
      });
    } else {
      _tabs[_currentTabIndex].content = _controller.text;
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
    final lang = _languages[ext];
    return lang?.icon ?? Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final lang = _languages[ext];
    return lang?.color ?? Colors.grey;
  }

  IconData _getLanguageIcon(String language) {
    final entry = _languages.entries.firstWhere(
      (e) => e.value.name == language,
      orElse: () => const MapEntry('', CodeLanguage(
        name: 'Text',
        extension: 'txt',
        icon: Icons.text_fields,
        color: Colors.grey,
        template: '',
      )),
    );
    return entry.value.icon;
  }

  Color _getLanguageColor(String language) {
    final entry = _languages.entries.firstWhere(
      (e) => e.value.name == language,
      orElse: () => const MapEntry('', CodeLanguage(
        name: 'Text',
        extension: 'txt',
        icon: Icons.text_fields,
        color: Colors.grey,
        template: '',
      )),
    );
    return entry.value.color;
  }

  String _getLanguage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final lang = _languages[ext];
    return lang?.name ?? 'Text';
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
    if (_tabs.isEmpty) {
      // 如果没有标签但有内容，保存为新文件
      if (_controller.text.isNotEmpty) {
        await _saveAs();
      }
      return;
    }
    
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
        _tabs[_currentTabIndex].content = _controller.text;
      });
      
      _showSuccess('文件已保存');
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  Future<void> _saveAs() async {
    try {
      // 确定文件扩展名
      String suggestedName = 'untitled';
      if (_tabs.isNotEmpty) {
        suggestedName = _tabs[_currentTabIndex].fileName;
      } else {
        final lang = _languages.entries.firstWhere(
          (e) => e.value.name == _currentLanguage,
          orElse: () => const MapEntry('txt', CodeLanguage(
            name: 'Text',
            extension: 'txt',
            icon: Icons.text_fields,
            color: Colors.grey,
            template: '',
          )),
        );
        suggestedName = 'untitled.${lang.value.extension}';
      }
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: suggestedName,
      );
      
      if (outputPath == null) return;
      
      // 确保有扩展名
      if (!outputPath.contains('.')) {
        final lang = _languages.entries.firstWhere(
          (e) => e.value.name == _currentLanguage,
          orElse: () => const MapEntry('txt', CodeLanguage(
            name: 'Text',
            extension: 'txt',
            icon: Icons.text_fields,
            color: Colors.grey,
            template: '',
          )),
        );
        outputPath = '$outputPath.${lang.value.extension}';
      }
      
      final file = File(outputPath);
      await file.writeAsString(_controller.text);
      
      final fileName = outputPath.split('/').last;
      
      if (_tabs.isEmpty) {
        setState(() {
          _tabs.add(EditorTab(
            fileName: fileName,
            path: outputPath!,
            content: _controller.text,
          ));
          _currentTabIndex = 0;
        });
      } else {
        setState(() {
          _tabs[_currentTabIndex] = EditorTab(
            fileName: fileName,
            path: outputPath!,
            content: _controller.text,
          );
        });
      }
      
      setState(() {
        _currentFilePath = outputPath!;
        _currentLanguage = _getLanguage(fileName);
        _hasChanges = false;
      });
      
      _showSuccess('文件已保存: $fileName');
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  void _copyAll() {
    if (_controller.text.isEmpty) {
      _showError('没有内容可复制');
      return;
    }
    
    Clipboard.setData(ClipboardData(text: _controller.text));
    _showSuccess('已复制 ${_controller.text.length} 个字符');
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
                items: _languages.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, size: 16, color: entry.value.color),
                        const SizedBox(width: 8),
                        Text('${entry.value.name} (.${entry.value.extension})'),
                      ],
                    ),
                  );
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
    final lang = _languages[type] ?? _languages['txt']!;
    
    if (!name.contains('.')) {
      name = '$name.${lang.extension}';
    }
    
    String template = lang.template
        .replaceAll('@author', '')
        .replaceAll('@date', DateTime.now().toString().substring(0, 10));
    
    setState(() {
      _tabs.add(EditorTab(
        fileName: name,
        path: '',
        content: template,
      ));
      _currentTabIndex = _tabs.length - 1;
      _controller.text = template;
      _currentFilePath = '';
      _currentLanguage = lang.name;
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
    if (index < 0 || index >= _tabs.length) return;
    
    final tab = _tabs[index];
    
    if (tab.hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('关闭文件'),
          content: Text('${tab.fileName} 有未保存的更改，是否保存？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeTab(index);
              },
              child: const Text('不保存'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                // 切换到该标签保存
                if (index != _currentTabIndex) {
                  _switchTab(index);
                }
                await _saveCurrentFile();
                _removeTab(_tabs.indexWhere((t) => t.path == tab.path));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    } else {
      _removeTab(index);
    }
  }

  void _removeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      
      if (_tabs.isEmpty) {
        _hasChanges = false;
        _currentFilePath = '';
        _currentLanguage = 'Text';
        _controller.clear();
      } else {
        if (_currentTabIndex >= _tabs.length) {
          _currentTabIndex = _tabs.length - 1;
        }
        _controller.text = _tabs[_currentTabIndex].content;
        _currentFilePath = _tabs[_currentTabIndex].path;
        _currentLanguage = _getLanguage(_tabs[_currentTabIndex].fileName);
        _hasChanges = _tabs[_currentTabIndex].hasChanges;
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'undo':
        // Flutter的TextField没有undo，需要通过其他方式实现
        _showInfo('撤销功能');
        break;
      case 'redo':
        _showInfo('重做功能');
        break;
      case 'find':
        _showFindDialog();
        break;
      case 'replace':
        _showReplaceDialog();
        break;
      case 'selectall':
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        break;
      case 'format':
        _showInfo('格式化功能');
        break;
      case 'language':
        _showLanguagePicker();
        break;
    }
  }

  void _showFindDialog() {
    final findController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查找'),
        content: TextField(
          controller: findController,
          decoration: const InputDecoration(
            hintText: '输入要查找的内容',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 实现查找功能
              _findText(findController.text);
            },
            child: const Text('查找下一个'),
          ),
        ],
      ),
    );
  }

  void _showReplaceDialog() {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('替换'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              decoration: const InputDecoration(
                hintText: '查找内容',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: replaceController,
              decoration: const InputDecoration(
                hintText: '替换为',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 替换一个
              _replaceText(findController.text, replaceController.text, replaceAll: false);
            },
            child: const Text('替换'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _replaceText(findController.text, replaceController.text, replaceAll: true);
            },
            child: const Text('全部替换'),
          ),
        ],
      ),
    );
  }

  void _findText(String text) {
    if (text.isEmpty) return;
    
    final index = _controller.text.indexOf(text, _controller.selection.baseOffset);
    if (index >= 0) {
      _controller.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + text.length,
      );
    } else {
      _showInfo('未找到: $text');
    }
  }

  void _replaceText(String find, String replace, {bool replaceAll = false}) {
    if (find.isEmpty) return;
    
    if (replaceAll) {
      final count = _controller.text.split(find).length - 1;
      _controller.text = _controller.text.replaceAll(find, replace);
      _showInfo('已替换 $count 处');
    } else {
      final index = _controller.text.indexOf(find, _controller.selection.baseOffset);
      if (index >= 0) {
        final before = _controller.text.substring(0, index);
        final after = _controller.text.substring(index + find.length);
        _controller.text = '$before$replace$after';
        _controller.selection = TextSelection.collapsed(offset: index + replace.length);
      }
    }
    _onContentChanged();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
