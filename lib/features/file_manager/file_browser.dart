import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'project_directory.dart';

class FileBrowserPage extends StatefulWidget {
  final void Function(String path, String name)? onProjectSelected;

  const FileBrowserPage({super.key, this.onProjectSelected});

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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProjects),
        ],
      ),
      body: Column(
        children: [
          // 快捷操作
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildQuickAction(Icons.folder_open, '导入目录', Colors.blue, _importFromDirectory),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.archive, '导入压缩包', Colors.green, _importFromArchive),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.create_new_folder, '新建项目', Colors.orange, _createProject),
              ],
            ),
          ),
          // 最近项目
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('最近项目', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_recentProjects.isNotEmpty)
                  TextButton(onPressed: _clearProjects, child: const Text('清空')),
              ],
            ),
          ),
          // 项目列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentProjects.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('暂无项目'),
                            SizedBox(height: 8),
                            Text('点击上方按钮导入或创建项目'),
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
              Text(label, style: TextStyle(fontSize: 12, color: color)),
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
          child: Icon(_getProjectIcon(project.type), color: _getProjectColor(project.type)),
        ),
        title: Text(project.name),
        subtitle: Text(project.path, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleProjectAction(value, index),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: Text('打开')),
            const PopupMenuItem(value: 'tree', child: Text('查看文件树')),
            const PopupMenuItem(value: 'remove', child: Text('移除')),
          ],
        ),
        onTap: () => _openProject(project),
      ),
    );
  }

  IconData _getProjectIcon(ProjectType type) {
    switch (type) {
      case ProjectType.flutter: return Icons.flutter_dash;
      case ProjectType.android: return Icons.android;
      case ProjectType.python: return Icons.code;
      case ProjectType.nodejs: return Icons.javascript;
      default: return Icons.folder;
    }
  }

  Color _getProjectColor(ProjectType type) {
    switch (type) {
      case ProjectType.flutter: return Colors.blue;
      case ProjectType.android: return Colors.green;
      case ProjectType.python: return Colors.green;
      case ProjectType.nodejs: return Colors.yellow;
      default: return Colors.grey;
    }
  }

  Future<void> _importFromDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final projectName = p.basename(selectedDirectory);
      final projectType = _detectProjectType(selectedDirectory);

      final project = ProjectItem(
        name: projectName,
        path: selectedDirectory,
        type: projectType,
        lastModified: DateTime.now().toString().substring(0, 10),
      );

      setState(() {
        _recentProjects.removeWhere((p) => p.path == selectedDirectory);
        _recentProjects.insert(0, project);
      });

      await _saveProjects();
      _showSuccess('项目已导入: $projectName');
      
      // 显示文件树
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => FileTreeDialog(
            projectPath: selectedDirectory,
            projectName: projectName,
          ),
        );
      }
    } catch (e) {
      _showError('导入失败: $e');
    }
  }

  Future<void> _importFromArchive() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'rar', 'tar', 'gz', 'tgz', '7z'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final filePath = result.files.first.path;
      if (filePath == null) return;
      
      // 选择解压目录
      String? outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir == null) return;
      
      final fileName = result.files.first.name;
      final projectName = fileName.replaceAll(RegExp(r'\.(zip|rar|tar|gz|tgz|7z)$'), '');
      final projectPath = p.join(outputDir, projectName);
      
      setState(() => _isLoading = true);
      
      // 解压zip文件
      if (filePath.endsWith('.zip')) {
        await _extractZip(filePath, projectPath);
      } else {
        _showError('暂不支持此格式，请使用zip');
        return;
      }
      
      final projectType = _detectProjectType(projectPath);
      final project = ProjectItem(
        name: projectName,
        path: projectPath,
        type: projectType,
        lastModified: DateTime.now().toString().substring(0, 10),
      );

      setState(() {
        _recentProjects.insert(0, project);
        _isLoading = false;
      });

      await _saveProjects();
      _showSuccess('项目已解压导入: $projectName');
      
      // 显示文件树
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => FileTreeDialog(
            projectPath: projectPath,
            projectName: projectName,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('解压失败: $e');
    }
  }

  Future<void> _extractZip(String zipPath, String outputPath) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    for (final file in archive) {
      final filePath = p.join(outputPath, file.name);
      if (file.isFile) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(filePath).createSync(recursive: true);
      }
    }
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController(text: 'my_project');
    String selectedType = 'flutter';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '项目名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: '项目类型', border: OutlineInputBorder()),
                items: ['flutter', 'android', 'python', 'nodejs'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type.toUpperCase()));
                }).toList(),
                onChanged: (type) => setState(() => selectedType = type!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('创建')),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final projectName = nameController.text.trim();
      final projectPath = p.join(selectedDirectory, projectName);
      final dir = Directory(projectPath);

      if (await dir.exists()) {
        _showError('目录已存在');
        return;
      }

      await dir.create(recursive: true);
      await _createProjectFiles(projectPath, selectedType);

      final project = ProjectItem(
        name: projectName,
        path: projectPath,
        type: ProjectType.values.firstWhere((t) => t.name == selectedType, orElse: () => ProjectType.flutter),
        lastModified: DateTime.now().toString().substring(0, 10),
      );

      setState(() => _recentProjects.insert(0, project));
      await _saveProjects();
      _showSuccess('项目已创建: $projectName');
    } catch (e) {
      _showError('创建失败: $e');
    }
  }

  Future<void> _createProjectFiles(String path, String type) async {
    switch (type) {
      case 'flutter':
        await File(p.join(path, 'lib', 'main.dart')).create(recursive: true);
        await File(p.join(path, 'pubspec.yaml')).create(recursive: true);
        break;
      case 'python':
        await File(p.join(path, 'main.py')).create(recursive: true);
        await File(p.join(path, 'requirements.txt')).create(recursive: true);
        break;
      case 'nodejs':
        await File(p.join(path, 'index.js')).create(recursive: true);
        await File(p.join(path, 'package.json')).create(recursive: true);
        break;
    }
  }

  void _openProject(ProjectItem project) {
    // 调用回调，传递项目路径和名称
    widget.onProjectSelected?.call(project.path, project.name);
    _showSuccess('已打开: ${project.name}');
  }

  void _handleProjectAction(String action, int index) {
    switch (action) {
      case 'open':
        _openProject(_recentProjects[index]);
        break;
      case 'tree':
        showDialog(
          context: context,
          builder: (context) => FileTreeDialog(
            projectPath: _recentProjects[index].path,
            projectName: _recentProjects[index].name,
          ),
        );
        break;
      case 'remove':
        setState(() => _recentProjects.removeAt(index));
        _saveProjects();
        break;
    }
  }

  Future<void> _clearProjects() async {
    setState(() => _recentProjects.clear());
    await _saveProjects();
  }

  ProjectType _detectProjectType(String path) {
    if (File(p.join(path, 'pubspec.yaml')).existsSync()) return ProjectType.flutter;
    if (File(p.join(path, 'build.gradle')).existsSync()) return ProjectType.android;
    if (File(p.join(path, 'requirements.txt')).existsSync() || 
        Directory(path).listSync().any((f) => f.path.endsWith('.py'))) return ProjectType.python;
    if (File(p.join(path, 'package.json')).existsSync()) return ProjectType.nodejs;
    return ProjectType.other;
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

enum ProjectType { flutter, android, python, nodejs, other }

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
