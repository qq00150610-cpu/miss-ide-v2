import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 文件树项
class FileTreeItem {
  final String name;
  final String path;
  final bool isDirectory;
  final List<FileTreeItem> children;
  bool isExpanded;

  FileTreeItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
  });
}

/// 项目目录面板
class ProjectDirectoryPanel extends StatefulWidget {
  final String projectPath;
  final Function(String) onFileSelected;

  const ProjectDirectoryPanel({
    super.key,
    required this.projectPath,
    required this.onFileSelected,
  });

  @override
  State<ProjectDirectoryPanel> createState() => _ProjectDirectoryPanelState();
}

class _ProjectDirectoryPanelState extends State<ProjectDirectoryPanel> {
  List<FileTreeItem>? _rootItems;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    try {
      final items = await _readDirectory(widget.projectPath);
      setState(() {
        _rootItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<FileTreeItem>> _readDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final entities = await dir.list().toList();
    entities.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      return p.basename(a.path).compareTo(p.basename(b.path));
    });

    final items = <FileTreeItem>[];
    for (var entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      items.add(FileTreeItem(
        name: name,
        path: entity.path,
        isDirectory: entity is Directory,
        children: entity is Directory ? [] : const [],
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.basename(widget.projectPath),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _loadDirectory();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          // 文件树
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rootItems == null || _rootItems!.isEmpty
                    ? const Center(child: Text('空目录', style: TextStyle(fontSize: 12)))
                    : ListView.builder(
                        itemCount: _rootItems!.length,
                        itemBuilder: (context, index) {
                          return _buildTreeItem(_rootItems![index], 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeItem(FileTreeItem item, int level) {
    final indent = level * 16.0;

    if (item.isDirectory) {
      return ExpansionTile(
        tilePadding: EdgeInsets.only(left: indent, right: 8),
        leading: Icon(
          item.isExpanded ? Icons.folder_open : Icons.folder,
          size: 18,
          color: Colors.amber,
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 12),
        ),
        onExpansionChanged: (expanded) async {
          if (expanded && item.children.isEmpty) {
            final children = await _readDirectory(item.path);
            setState(() {
              item.children.clear();
              item.children.addAll(children);
              item.isExpanded = true;
            });
          }
        },
        children: item.children.map((child) => _buildTreeItem(child, level + 1)).toList(),
      );
    } else {
      return InkWell(
        onTap: () => widget.onFileSelected(item.path),
        child: Padding(
          padding: EdgeInsets.only(left: indent + 28, top: 8, bottom: 8, right: 8),
          child: Row(
            children: [
              Icon(_getFileIcon(item.name), size: 16, color: _getFileColor(item.name)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Icons.code;
      case 'java': return Icons.coffee;
      case 'kt': return Icons.code;
      case 'py': return Icons.code;
      case 'js': return Icons.javascript;
      case 'html': return Icons.html;
      case 'css': return Icons.style;
      case 'json': return Icons.data_object;
      case 'yaml':
      case 'yml': return Icons.settings;
      case 'md': return Icons.description;
      case 'xml': return Icons.code;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif': return Icons.image;
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
      case 'json': return Colors.amber;
      case 'yaml':
      case 'yml': return Colors.cyan;
      default: return Colors.grey;
    }
  }
}

/// 文件树对话框
class FileTreeDialog extends StatelessWidget {
  final String projectPath;
  final String projectName;

  const FileTreeDialog({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  Future<List<FileTreeItem>> _readDirectory(String path, int maxDepth) async {
    final dir = Directory(path);
    if (!await dir.exists() || maxDepth <= 0) return [];

    final entities = await dir.list().toList();
    entities.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      return p.basename(a.path).compareTo(p.basename(b.path));
    });

    final items = <FileTreeItem>[];
    for (var entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      items.add(FileTreeItem(
        name: name,
        path: entity.path,
        isDirectory: entity is Directory,
        children: entity is Directory ? await _readDirectory(entity.path, maxDepth - 1) : [],
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.folder_open),
          const SizedBox(width: 8),
          Expanded(child: Text(projectName, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: FutureBuilder<List<FileTreeItem>>(
          future: _readDirectory(projectPath, 3),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return _buildTreeItem(snapshot.data![index], 0);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildTreeItem(FileTreeItem item, int level) {
    final indent = level * 16.0;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: item.isDirectory
          ? ExpansionTile(
              leading: const Icon(Icons.folder, size: 18, color: Colors.amber),
              title: Text(item.name, style: const TextStyle(fontSize: 12)),
              children: item.children.map((c) => _buildTreeItem(c, level + 1)).toList(),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(item.name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
    );
  }
}
