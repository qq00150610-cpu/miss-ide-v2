import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  List<ProjectItem> _recentProjects = [];
  bool _isLoading = false;

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
            orElse: () => ProjectType.flutter,
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
          // 快捷操作
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildQuickAction(Icons.folder_open, '导入项目', Colors.blue, _importProject),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.create_new_folder, '新建项目', Colors.green, _createProject),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.code, '打开文件', Colors.orange, _openFile),
              ],
            ),
          ),
          
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
            const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.folder_open), title: Text('打开'))),
            const PopupMenuItem(value: 'terminal', child: ListTile(leading: Icon(Icons.terminal), title: Text('终端'))),
            const PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.remove_circle_outline), title: Text('从列表移除'))),
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
      case ProjectType.other:
        return Colors.grey;
    }
  }

  Future<void> _importProject() async {
    try {
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

  Future<void> _createProject() async {
    final controller = TextEditingController(text: 'my_project');
    ProjectType selectedType = ProjectType.flutter;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '项目名称',
                  border: OutlineInputBorder(),
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
      default:
        // 创建基本目录
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
    
    // 创建 pubspec.yaml
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

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        // TODO: 打开文件到编辑器
        _showSuccess('已选择: ${result.files.first.name}');
      }
    } catch (e) {
      _showError('打开文件失败: $e');
    }
  }

  void _openProject(ProjectItem project) {
    // TODO: 实现项目浏览器，列出目录中的文件
    _showSuccess('已选择项目: ${project.name}');
  }

  void _handleProjectAction(String action, int index) {
    switch (action) {
      case 'open':
        _openProject(_recentProjects[index]);
        break;
      case 'terminal':
        // TODO: 打开终端
        _showSuccess('终端功能开发中...');
        break;
      case 'remove':
        setState(() {
          _recentProjects.removeAt(index);
        });
        _saveProjects();
        break;
    }
  }

  Future<void> _clearProjects() async {
    setState(() {
      _recentProjects.clear();
    });
    await _saveProjects();
  }

  ProjectType _detectProjectType(String path) {
    final dir = Directory(path);
    
    // 检查 Flutter 项目
    if (File(p.join(path, 'pubspec.yaml')).existsSync()) {
      return ProjectType.flutter;
    }
    
    // 检查 Android 项目
    if (File(p.join(path, 'build.gradle')).existsSync() ||
        File(p.join(path, 'app', 'build.gradle')).existsSync()) {
      return ProjectType.android;
    }
    
    // 检查 Kotlin 项目
    if (Directory(p.join(path, 'src')).listSync().any((f) => f.path.endsWith('.kt'))) {
      return ProjectType.kotlin;
    }
    
    // 检查 Java 项目
    if (Directory(p.join(path, 'src')).listSync().any((f) => f.path.endsWith('.java'))) {
      return ProjectType.java;
    }
    
    return ProjectType.other;
  }

  Future<String> _getLastModified(String path) async {
    try {
      final stat = await FileStat.stat(path);
      return stat.modified.toString().substring(0, 10);
    } catch (_) {
      return DateTime.now().toString().substring(0, 10);
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

enum ProjectType { flutter, android, kotlin, java, other }

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
