import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 文件/目录项数据模型
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
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<String>? expandedPaths;

  const ProjectDirectoryPanel({
    super.key,
    required this.projectPath,
    required this.onFileSelected,
    required this.isExpanded,
    required this.onToggle,
    this.expandedPaths,
  });

  @override
  State<ProjectDirectoryPanel> createState() => _ProjectDirectoryPanelState();
}

class _ProjectDirectoryPanelState extends State<ProjectDirectoryPanel> {
  List<FileTreeItem> _fileTree = [];
  Set<String> _expandedPaths = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
    if (widget.expandedPaths != null) {
      _expandedPaths.addAll(widget.expandedPaths!);
    }
  }

  @override
  void didUpdateWidget(ProjectDirectoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath) {
      _loadDirectory();
    }
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);
    
    try {
      final items = await _buildFileTree(widget.projectPath);
      setState(() {
        _fileTree = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fileTree = [];
        _isLoading = false;
      });
    }
  }

  Future<List<FileTreeItem>> _buildFileTree(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final items = <FileTreeItem>[];
    
    try {
      final entities = await dir.list().toList();
      
      // 排序：文件夹在前，文件在后，再按名称排序
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

      for (final entity in entities) {
        final name = p.basename(entity.path);
        
        // 跳过隐藏文件和目录
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          items.add(FileTreeItem(
            name: name,
            path: entity.path,
            isDirectory: true,
            isExpanded: _expandedPaths.contains(entity.path),
          ));
        } else if (entity is File) {
          items.add(FileTreeItem(
            name: name,
            path: entity.path,
            isDirectory: false,
          ));
        }
      }
    } catch (e) {
      // 权限错误等
    }
    
    return items;
  }

  Future<void> _loadChildren(FileTreeItem item) async {
    if (item.children.isNotEmpty) return;
    
    final children = await _buildFileTree(item.path);
    
    setState(() {
      final index = _fileTree.indexWhere((f) => f.path == item.path);
      if (index >= 0) {
        // 直接修改引用会导致UI不更新，需要重新构建
        _refreshTree();
      }
    });
  }

  void _refreshTree() {
    // 简单刷新整个树
    _loadDirectory();
  }

  void _toggleExpand(FileTreeItem item) {
    setState(() {
      item.isExpanded = !item.isExpanded;
      if (item.isExpanded) {
        _expandedPaths.add(item.path);
      } else {
        _expandedPaths.remove(item.path);
      }
    });
    
    if (item.isExpanded && item.children.isEmpty) {
      _loadChildren(item);
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    
    // 代码文件
    if (['dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'rb', 'go', 'rs', 'java', 'kt', 'swift'].contains(ext)) {
      return Icons.code;
    }
    
    // Web
    if (['html', 'htm', 'css', 'scss', 'sass', 'less'].contains(ext)) {
      return Icons.web;
    }
    
    // 配置
    if (['json', 'yaml', 'yml', 'toml', 'xml', 'ini', 'env', 'properties'].contains(ext)) {
      return Icons.settings;
    }
    
    // 文档
    if (['md', 'txt', 'doc', 'docx', 'pdf'].contains(ext)) {
      return Icons.description;
    }
    
    // 图片
    if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'webp'].contains(ext)) {
      return Icons.image;
    }
    
    // 压缩包
    if (['zip', 'rar', 'tar', 'gz', '7z'].contains(ext)) {
      return Icons.archive;
    }
    
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName, bool isDirectory) {
    if (isDirectory) return Colors.amber.shade700;
    
    final ext = fileName.split('.').last.toLowerCase();
    
    // 代码文件
    if (['dart'].contains(ext)) return Colors.blue;
    if (['js', 'ts', 'jsx', 'tsx'].contains(ext)) return Colors.amber;
    if (['py'].contains(ext)) return Colors.green;
    if (['java'].contains(ext)) return Colors.orange;
    if (['kt', 'swift'].contains(ext)) return Colors.purple;
    if (['go'].contains(ext)) return Colors.cyan;
    if (['rs'].contains(ext)) return Colors.deepOrange;
    
    // Web
    if (['html', 'htm'].contains(ext)) return Colors.orange;
    if (['css', 'scss', 'sass', 'less'].contains(ext)) return Colors.blue;
    
    // 配置
    if (['json'].contains(ext)) return Colors.amber;
    if (['yaml', 'yml'].contains(ext)) return Colors.cyan;
    if (['xml'].contains(ext)) return Colors.green;
    
    // 文档
    if (['md'].contains(ext)) return Colors.blue;
    
    return Colors.grey;
  }

  Widget _buildTreeItem(FileTreeItem item, {int depth = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (item.isDirectory) {
              _toggleExpand(item);
            } else {
              widget.onFileSelected(item.path);
            }
          },
          child: Container(
            height: 28,
            padding: EdgeInsets.only(left: 8.0 + depth * 16.0, right: 8.0),
            child: Row(
              children: [
                if (item.isDirectory)
                  Icon(
                    item.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 4),
                Icon(
                  item.isDirectory
                      ? (item.isExpanded ? Icons.folder_open : Icons.folder)
                      : _getFileIcon(item.name),
                  size: 16,
                  color: _getFileColor(item.name, item.isDirectory),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (item.isDirectory && item.isExpanded)
          FutureBuilder<List<FileTreeItem>>(
            future: _buildFileTree(item.path),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Column(
                children: snapshot.data!.map((child) {
                  return _buildTreeItem(
                    FileTreeItem(
                      name: child.name,
                      path: child.path,
                      isDirectory: child.isDirectory,
                      children: child.children,
                      isExpanded: _expandedPaths.contains(child.path),
                    ),
                    depth: depth + 1,
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          // 标题栏
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.basename(widget.projectPath),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: _loadDirectory,
                  tooltip: '刷新',
                ),
              ],
            ),
          ),
          
          // 目录内容
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _fileTree.isEmpty
                    ? Center(
                        child: Text(
                          '空目录',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        children: _fileTree.map((item) {
                          return _buildTreeItem(item);
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 文件树对话框（用于导入后显示）
class FileTreeDialog extends StatefulWidget {
  final String projectPath;
  final String projectName;

  const FileTreeDialog({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  @override
  State<FileTreeDialog> createState() => _FileTreeDialogState();
}

class _FileTreeDialogState extends State<FileTreeDialog> {
  List<FileTreeItem> _fileTree = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoading = true);
    
    try {
      final items = await _buildFileTree(widget.projectPath, 0, 3);
      setState(() {
        _fileTree = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fileTree = [];
        _isLoading = false;
      });
    }
  }

  Future<List<FileTreeItem>> _buildFileTree(String path, int currentDepth, int maxDepth) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final items = <FileTreeItem>[];
    
    try {
      final entities = await dir.list().toList();
      
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

      int count = 0;
      for (final entity in entities) {
        if (count >= 50) break; // 限制显示数量
        
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          List<FileTreeItem> children = [];
          if (currentDepth < maxDepth) {
            children = await _buildFileTree(entity.path, currentDepth + 1, maxDepth);
          }
          
          items.add(FileTreeItem(
            name: name,
            path: entity.path,
            isDirectory: true,
            children: children,
            isExpanded: currentDepth < 1,
          ));
          count++;
        } else if (entity is File) {
          items.add(FileTreeItem(
            name: name,
            path: entity.path,
            isDirectory: false,
          ));
          count++;
        }
      }
    } catch (e) {
      // 权限错误等
    }
    
    return items;
  }

  IconData _getFileIcon(String fileName, bool isDirectory) {
    if (isDirectory) return Icons.folder;
    
    final ext = fileName.split('.').last.toLowerCase();
    
    if (['dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'rb', 'go', 'rs', 'java', 'kt', 'swift'].contains(ext)) {
      return Icons.code;
    }
    if (['html', 'htm', 'css', 'scss', 'sass', 'less'].contains(ext)) {
      return Icons.web;
    }
    if (['json', 'yaml', 'yml', 'toml', 'xml', 'ini', 'env', 'properties'].contains(ext)) {
      return Icons.settings;
    }
    if (['md', 'txt', 'doc', 'docx', 'pdf'].contains(ext)) {
      return Icons.description;
    }
    if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'ico', 'webp'].contains(ext)) {
      return Icons.image;
    }
    if (['zip', 'rar', 'tar', 'gz', '7z'].contains(ext)) {
      return Icons.archive;
    }
    
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName, bool isDirectory) {
    if (isDirectory) return Colors.amber.shade700;
    
    final ext = fileName.split('.').last.toLowerCase();
    
    if (['dart'].contains(ext)) return Colors.blue;
    if (['js', 'ts', 'jsx', 'tsx'].contains(ext)) return Colors.amber;
    if (['py'].contains(ext)) return Colors.green;
    if (['java'].contains(ext)) return Colors.orange;
    if (['kt', 'swift'].contains(ext)) return Colors.purple;
    if (['go'].contains(ext)) return Colors.cyan;
    if (['rs'].contains(ext)) return Colors.deepOrange;
    if (['html', 'htm'].contains(ext)) return Colors.orange;
    if (['css', 'scss', 'sass', 'less'].contains(ext)) return Colors.blue;
    if (['json'].contains(ext)) return Colors.amber;
    if (['yaml', 'yml'].contains(ext)) return Colors.cyan;
    if (['xml'].contains(ext)) return Colors.green;
    if (['md'].contains(ext)) return Colors.blue;
    
    return Colors.grey;
  }

  Widget _buildTreeItem(FileTreeItem item, {int depth = 0}) {
    final indent = 16.0 + depth * 16.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: item.isDirectory ? () {
            setState(() {
              item.isExpanded = !item.isExpanded;
            });
          } : null,
          child: Container(
            height: 28,
            padding: EdgeInsets.only(left: indent, right: 8),
            child: Row(
              children: [
                if (item.isDirectory)
                  Icon(
                    item.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 4),
                Icon(
                  item.isDirectory
                      ? (item.isExpanded ? Icons.folder_open : Icons.folder)
                      : _getFileIcon(item.name, false),
                  size: 16,
                  color: _getFileColor(item.name, item.isDirectory),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (item.isDirectory && item.isExpanded && item.children.isNotEmpty)
          Column(
            children: item.children.map((child) {
              return _buildTreeItem(
                FileTreeItem(
                  name: child.name,
                  path: child.path,
                  isDirectory: child.isDirectory,
                  children: child.children,
                  isExpanded: child.isExpanded,
                ),
                depth: depth + 1,
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 450,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.folder_special,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '项目已导入',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        widget.projectPath,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const Divider(),
            
            // 文件树
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _fileTree.isEmpty
                          ? Center(
                              child: Text(
                                '空目录',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView(
                              children: _fileTree.map((item) {
                                return _buildTreeItem(item);
                              }).toList(),
                            ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '打开编辑器后，可在左侧查看完整项目结构',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
