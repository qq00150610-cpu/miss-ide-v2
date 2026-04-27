import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

/// 项目类型
enum ProjectType {
  flutter,
  android,
  kotlin,
  java,
  python,
  nodejs,
  other,
}

/// 项目项
class ProjectItem {
  final String name;
  final String path;
  final ProjectType type;
  final String lastModified;
  
  ProjectItem({
    required this.name,
    required this.path,
    required this.type,
    required this.lastModified,
  });
}

/// 解压进度信息
class ExtractProgress {
  final int current;
  final int total;
  final String currentFile;
  
  ExtractProgress({
    required this.current,
    required this.total,
    required this.currentFile,
  });
  
  double get progress => total > 0 ? current / total : 0;
}

class FileBrowserPage extends StatefulWidget {
  final Function(String)? onProjectOpened;
  
  const FileBrowserPage({
    super.key,
    this.onProjectOpened,
  });

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  List<ProjectItem> _recentProjects = [];
  bool _isLoading = false;
  bool _isExtracting = false;
  double _extractProgress = 0;
  String _extractStatus = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final projects = prefs.getStringList('recent_projects') ?? [];
    setState(() {
      _recentProjects = projects.map((json) {
        final parts = json.split('|||');
        return ProjectItem(
          name: parts[0],
          path: parts[1],
          type: ProjectType.values.firstWhere(
            (t) => t.name == parts[2],
            orElse: () => ProjectType.other,
          ),
          lastModified: parts.length > 3 ? parts[3] : '',
        );
      }).toList();
    });
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final projects = _recentProjects.map((p) => 
      '${p.name}|||${p.path}|||${p.type.name}|||${p.lastModified}'
    ).toList();
    await prefs.setStringList('recent_projects', projects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miss IDE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
          ),
        ],
      ),
      body: Column(
        children: [
          // 解压进度提示
          if (_isExtracting)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '正在解压: $_extractStatus',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _extractProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${(_extractProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          
          // 快捷操作
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildQuickAction(Icons.folder_open, '导入项目', Colors.blue, _importProject),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.archive, '解压压缩包', Colors.purple, _importArchive),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.create_new_folder, '新建项目', Colors.green, _createProject),
              ],
            ),
          ),
          
          // 第二行快捷操作
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickAction(Icons.code, '打开文件', Colors.orange, _openFile),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.folder_copy, '选择目录', Colors.teal, _selectDirectory),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 最近项目
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '最近项目',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_recentProjects.isNotEmpty)
                  TextButton(
                    onPressed: _clearProjects,
                    child: const Text('清空'),
                  ),
              ],
            ),
          ),
          
          // 项目列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentProjects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            const Text('暂无项目'),
                            const SizedBox(height: 8),
                            const Text('点击上方按钮导入或创建项目'),
                            const SizedBox(height: 16),
                            // 支持的格式提示
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(horizontal: 32),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '支持的压缩格式',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      '.zip', '.rar', '.tar', '.tar.gz', '.tgz', '.7z',
                                    ].map((ext) => Chip(
                                      label: Text(ext, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _recentProjects.length,
                        itemBuilder: (context, index) {
                          return _buildProjectCard(_recentProjects[index], index);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('新建项目'),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectItem project, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getProjectColor(project.type).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getProjectIcon(project.type),
            color: _getProjectColor(project.type),
          ),
        ),
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.path,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getProjectColor(project.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    project.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: _getProjectColor(project.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  project.lastModified,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleProjectAction(value, index),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.folder_open), title: Text('打开'), dense: true)),
            const PopupMenuItem(value: 'terminal', child: ListTile(leading: Icon(Icons.terminal), title: Text('终端'), dense: true)),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true)),
            const PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.remove_circle_outline), title: Text('从列表移除'), dense: true)),
          ],
        ),
        onTap: () => _openProject(project),
      ),
    );
  }

  IconData _getProjectIcon(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Icons.flutter_dash;
      case ProjectType.android:
        return Icons.android;
      case ProjectType.kotlin:
        return Icons.code;
      case ProjectType.java:
        return Icons.coffee;
      case ProjectType.python:
        return Icons.code;
      case ProjectType.nodejs:
        return Icons.javascript;
      case ProjectType.other:
        return Icons.folder;
    }
  }

  Color _getProjectColor(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Colors.blue;
      case ProjectType.android:
        return Colors.green;
      case ProjectType.kotlin:
        return Colors.purple;
      case ProjectType.java:
        return Colors.orange;
      case ProjectType.python:
        return Colors.green.shade700;
      case ProjectType.nodejs:
        return Colors.amber.shade700;
      case ProjectType.other:
        return Colors.grey;
    }
  }

  /// 导入压缩包
  Future<void> _importArchive() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'rar', 'tar', 'gz', 'tgz', '7z'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final filePath = result.files.first.path;
      if (filePath == null) return;
      
      // 选择解压目录
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择解压目录',
      );
      
      if (selectedDirectory == null) return;
      
      await _extractArchive(filePath, selectedDirectory);
      
    } catch (e) {
      _showError('导入失败: $e');
    }
  }

  /// 解压压缩包
  Future<void> _extractArchive(String archivePath, String outputDir) async {
    setState(() {
      _isExtracting = true;
      _extractProgress = 0;
      _extractStatus = '准备解压...';
    });
    
    try {
      final file = File(archivePath);
      final bytes = await file.readAsBytes();
      final fileName = p.basenameWithoutExtension(archivePath);
      
      // 创建输出目录
      final outputPath = p.join(outputDir, fileName);
      final outputDirectory = Directory(outputPath);
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }
      
      Archive? archive;
      String archiveType = '';
      
      // 检测压缩格式
      if (archivePath.endsWith('.zip')) {
        archiveType = 'ZIP';
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (archivePath.endsWith('.tar.gz') || archivePath.endsWith('.tgz')) {
        archiveType = 'TAR.GZ';
        // 先解压gzip
        final gzipBytes = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(gzipBytes);
      } else if (archivePath.endsWith('.tar')) {
        archiveType = 'TAR';
        archive = TarDecoder().decodeBytes(bytes);
      } else if (archivePath.endsWith('.rar')) {
        archiveType = 'RAR';
        // RAR格式支持有限，尝试用通用方式
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (archivePath.endsWith('.7z')) {
        archiveType = '7Z';
        // 7z格式支持有限
        archive = ZipDecoder().decodeBytes(bytes);
      } else {
        throw Exception('不支持的压缩格式');
      }
      
      final total = archive.files.length;
      int extracted = 0;
      
      for (final archiveFile in archive.files) {
        final filename = archiveFile.name;
        
        setState(() {
          _extractStatus = filename.length > 30 
              ? '...${filename.substring(filename.length - 30)}' 
              : filename;
          _extractProgress = extracted / total;
        });
        
        if (archiveFile.isFile) {
          final outputFile = File(p.join(outputPath, filename));
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(archiveFile.content as List<int>);
        } else {
          // 创建目录
          final dir = Directory(p.join(outputPath, filename));
          await dir.create(recursive: true);
        }
        
        extracted++;
      }
      
      setState(() {
        _extractProgress = 1.0;
        _extractStatus = '解压完成！';
      });
      
      // 检测项目类型并添加
      final projectType = _detectProjectType(outputPath);
      final project = ProjectItem(
        name: fileName,
        path: outputPath,
        type: projectType,
        lastModified: DateTime.now().toString().substring(0, 10),
      );
      
      setState(() {
        _recentProjects.removeWhere((p) => p.path == outputPath);
        _recentProjects.insert(0, project);
      });
      
      await _saveProjects();
      
      // 延迟关闭进度显示
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isExtracting = false;
      });
      
      _showSuccess('已解压到: $fileName\n格式: $archiveType');
      
    } catch (e) {
      setState(() {
        _isExtracting = false;
      });
      _showError('解压失败: $e');
    }
  }

  Future<void> _importProject() async {
    try {
      // 选择目录
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final dir = Directory(selectedDirectory);
      if (!await dir.exists()) {
        _showError('目录不存在');
        return;
      }

      final projectName = p.basename(selectedDirectory);
      final projectType = _detectProjectType(selectedDirectory);
      final lastModified = await _getLastModified(selectedDirectory);

      final project = ProjectItem(
        name: projectName,
        path: selectedDirectory,
        type: projectType,
        lastModified: lastModified,
      );

      setState(() {
        // 避免重复
        _recentProjects.removeWhere((p) => p.path == selectedDirectory);
        _recentProjects.insert(0, project);
      });

      await _saveProjects();
      _showSuccess('项目已导入: $projectName');
      
      // 直接打开项目
      _openProject(project);
    } catch (e) {
      _showError('导入失败: $e');
    }
  }

  Future<void> _selectDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择工作目录',
      );
      
      if (selectedDirectory == null) return;
      
      _showSuccess('已选择: $selectedDirectory');
      
    } catch (e) {
      _showError('选择失败: $e');
    }
  }

  Future<void> _createProject() async {
    final controller = TextEditingController(text: 'my_project');
    ProjectType selectedType = ProjectType.flutter;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: Colors.green),
              SizedBox(width: 8),
              Text('新建项目'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '项目名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProjectType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: '项目类型',
                  border: OutlineInputBorder(),
                ),
                items: ProjectType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getProjectIcon(type), size: 20),
                        const SizedBox(width: 8),
                        Text(type.name.toUpperCase()),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      // 选择保存位置
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final projectName = controller.text.trim();
      final projectPath = p.join(selectedDirectory, projectName);
      final dir = Directory(projectPath);

      if (await dir.exists()) {
        _showError('目录已存在: $projectName');
        return;
      }

      // 创建项目目录
      await dir.create(recursive: true);

      // 创建基本文件结构
      await _createProjectStructure(projectPath, selectedType);

      final project = ProjectItem(
        name: projectName,
        path: projectPath,
        type: selectedType,
        lastModified: DateTime.now().toString().substring(0, 10),
      );

      setState(() {
        _recentProjects.insert(0, project);
      });

      await _saveProjects();
      _showSuccess('项目已创建: $projectName');
      _openProject(project);
    } catch (e) {
      _showError('创建失败: $e');
    }
  }

  Future<void> _createProjectStructure(String path, ProjectType type) async {
    switch (type) {
      case ProjectType.flutter:
        await _createFlutterProject(path);
        break;
      case ProjectType.android:
        await _createAndroidProject(path);
        break;
      case ProjectType.kotlin:
        await _createKotlinProject(path);
        break;
      case ProjectType.java:
        await _createJavaProject(path);
        break;
      case ProjectType.python:
        await _createPythonProject(path);
        break;
      case ProjectType.nodejs:
        await _createNodeJsProject(path);
        break;
      default:
        await Directory(p.join(path, 'src')).create(recursive: true);
    }
  }

  Future<void> _createFlutterProject(String path) async {
    final mainFile = File(p.join(path, 'lib', 'main.dart'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const Center(child: Text('Hello Flutter!')),
      ),
    );
  }
}
''');
    
    final pubspec = File(p.join(path, 'pubspec.yaml'));
    await pubspec.writeAsString('''
name: my_app
description: A new Flutter project.
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');
  }

  Future<void> _createAndroidProject(String path) async {
    final mainFile = File(p.join(path, 'app', 'src', 'main', 'java', 'com', 'example', 'myapp', 'MainActivity.java'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
package com.example.myapp;

import android.app.Activity;
import android.os.Bundle;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }
}
''');
  }

  Future<void> _createKotlinProject(String path) async {
    final mainFile = File(p.join(path, 'src', 'main.kt'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
fun main() {
    println("Hello, Kotlin!")
}
''');
  }

  Future<void> _createJavaProject(String path) async {
    final mainFile = File(p.join(path, 'src', 'Main.java'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
''');
  }

  Future<void> _createPythonProject(String path) async {
    final mainFile = File(p.join(path, 'main.py'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
#!/usr/bin/env python3
"""
Main application file
"""

def main():
    print("Hello, Python!")

if __name__ == '__main__':
    main()
''');
    
    final requirements = File(p.join(path, 'requirements.txt'));
    await requirements.writeAsString('# Python dependencies\n');
    
    final readme = File(p.join(path, 'README.md'));
    await readme.writeAsString('# Python Project\n');
  }

  Future<void> _createNodeJsProject(String path) async {
    final mainFile = File(p.join(path, 'index.js'));
    await mainFile.parent.create(recursive: true);
    await mainFile.writeAsString('''
/**
 * Main application file
 */

function main() {
  console.log("Hello, Node.js!");
}

main();
''');
    
    final packageJson = File(p.join(path, 'package.json'));
    await packageJson.writeAsString('''
{
  "name": "my-app",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}
''');
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        // TODO: 打开文件到编辑器
        _showSuccess('已选择: ${result.files.first.name}');
      }
    } catch (e) {
      _showError('打开文件失败: $e');
    }
  }

  void _openProject(ProjectItem project) {
    widget.onProjectOpened?.call(project.path);
    _showSuccess('已选择项目: ${project.name}');
  }

  void _handleProjectAction(String action, int index) {
    final project = _recentProjects[index];
    
    switch (action) {
      case 'open':
        _openProject(project);
        break;
      case 'terminal':
        _showSuccess('终端功能开发中...');
        break;
      case 'delete':
        _confirmDeleteProject(index);
        break;
      case 'remove':
        setState(() {
          _recentProjects.removeAt(index);
        });
        _saveProjects();
        _showSuccess('已从列表移除');
        break;
    }
  }

  Future<void> _confirmDeleteProject(int index) async {
    final project = _recentProjects[index];
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除 "${project.name}" 吗？\n\n此操作不可恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        final dir = Directory(project.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        setState(() {
          _recentProjects.removeAt(index);
        });
        await _saveProjects();
        _showSuccess('项目已删除');
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _clearProjects() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空列表'),
        content: const Text('确定要清空所有项目吗？\n\n不会删除实际文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      setState(() {
        _recentProjects.clear();
      });
      await _saveProjects();
    }
  }

  ProjectType _detectProjectType(String path) {
    final dir = Directory(path);
    
    // Flutter检测
    if (File(p.join(path, 'pubspec.yaml')).existsSync()) {
      return ProjectType.flutter;
    }
    
    // Android检测
    if (File(p.join(path, 'app', 'build.gradle')).existsSync() ||
        File(p.join(path, 'build.gradle')).existsSync()) {
      return ProjectType.android;
    }
    
    // Kotlin检测
    if (File(p.join(path, 'build.gradle.kts')).existsSync()) {
      return ProjectType.kotlin;
    }
    
    // Java检测
    if (File(p.join(path, 'pom.xml')).existsSync() ||
        File(p.join(path, 'build.gradle')).existsSync()) {
      return ProjectType.java;
    }
    
    // Python检测
    if (File(p.join(path, 'requirements.txt')).existsSync() ||
        File(p.join(path, 'setup.py')).existsSync() ||
        File(p.join(path, 'pyproject.toml')).existsSync()) {
      return ProjectType.python;
    }
    
    // Node.js检测
    if (File(p.join(path, 'package.json')).existsSync()) {
      return ProjectType.nodejs;
    }
    
    return ProjectType.other;
  }

  Future<String> _getLastModified(String path) async {
    try {
      final dir = Directory(path);
      final entities = await dir.list().toList();
      if (entities.isEmpty) return '';
      
      DateTime? latest;
      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          if (latest == null || stat.modified.isAfter(latest)) {
            latest = stat.modified;
          }
        } catch (_) {}
      }
      
      return latest?.toString().substring(0, 10) ?? '';
    } catch (e) {
      return '';
    }
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
}
