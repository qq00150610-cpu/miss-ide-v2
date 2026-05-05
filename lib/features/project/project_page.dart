import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logger.dart';

const _tag = 'ProjectPage';

/// 项目页面 - 真实功能版
/// 展示项目文件树、文件内容预览、快速跳转等功能
class ProjectPage extends StatefulWidget {
  final String projectPath;
  final Function(String) onFileSelected;
  final VoidCallback? onClose;

  const ProjectPage({
    super.key,
    required this.projectPath,
    required this.onFileSelected,
    this.onClose,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<FileTreeItem> _rootItems = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // 最近打开的文件
  List<String> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 文件 + 最近打开
    _loadDirectory();
    _loadRecentFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getStringList('recent_files_${widget.projectPath}') ?? [];
    setState(() => _recentFiles = files);
  }

  Future<void> _addRecentFile(String filePath) async {
    _recentFiles.remove(filePath);
    _recentFiles.insert(0, filePath);
    if (_recentFiles.length > 20) _recentFiles.removeLast();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files_${widget.projectPath}', _recentFiles);
    setState(() {});
  }

  /// 加载目录结构
  Future<void> _loadDirectory() async {
    try {
      final items = await _readDirectory(widget.projectPath);
      setState(() {
        _rootItems = items;
        _isLoading = false;
      });
    } catch (e) {
      MissLogger.error(_tag, '加载目录失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 读取目录内容
  Future<List<FileTreeItem>> _readDirectory(String path, {int depth = 0}) async {
    if (depth > 3) return []; // 限制递归深度，避免卡死
    
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
      if (name.startsWith('.') || name == 'build' || name == '.dart_tool') continue;

      List<FileTreeItem> children = [];
      if (entity is Directory) {
        children = await _readDirectory(entity.path, depth: depth + 1);
      }

      items.add(FileTreeItem(
        name: name,
        path: entity.path,
        isDirectory: entity is Directory,
        children: children,
      ));
    }
    return items;
  }

  /// 搜索文件
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  /// 递归搜索文件
  List<FileTreeItem> _searchFiles(List<FileTreeItem> items, String query) {
    final result = <FileTreeItem>[];
    for (var item in items) {
      if (item.isDirectory) {
        final filteredChildren = _searchFiles(item.children, query);
        if (item.name.toLowerCase().contains(query) || filteredChildren.isNotEmpty) {
          result.add(FileTreeItem(
            name: item.name,
            path: item.path,
            isDirectory: true,
            children: filteredChildren,
            isExpanded: true,
          ));
        }
      } else {
        if (item.name.toLowerCase().contains(query)) {
          result.add(item);
        }
      }
    }
    return result;
  }

  /// 打开文件
  void _openFile(String filePath) {
    _addRecentFile(filePath);
    widget.onFileSelected(filePath);
  }

  /// 获取文件图标
  IconData _getFileIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.dart': return Icons.code;
      case '.yaml': case '.yml': return Icons.settings;
      case '.json': return Icons.data_object;
      case '.md': return Icons.article;
      case '.png': case '.jpg': case '.jpeg': case '.gif': case '.svg': return Icons.image;
      case '.txt': return Icons.text_snippet;
      case '.xml': case '.html': case '.css': return Icons.code;
      case '.py': return Icons.code;
      case '.js': return Icons.javascript;
      default: return Icons.insert_drive_file;
    }
  }

  /// 获取文件图标颜色
  Color _getFileColor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.dart': return Colors.blue;
      case '.yaml': case '.yml': return Colors.orange;
      case '.json': return Colors.amber;
      case '.md': return Colors.teal;
      case '.py': return const Color(0xFF3572A5);
      case '.js': return const Color(0xFFF7DF1E);
      case '.png': case '.jpg': case '.jpeg': case '.gif': case '.svg': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Row(
          children: [
            const Icon(Icons.folder, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.basename(widget.projectPath),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // 刷新目录
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDirectory();
            },
            tooltip: '刷新',
          ),
          // 在编辑器中打开
          IconButton(
            icon: const Icon(Icons.code, size: 20),
            onPressed: () => widget.onFileSelected(widget.projectPath),
            tooltip: '在编辑器中打开项目目录',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            tooltip: '关闭',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontSize: 12),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree, size: 14),
                  const SizedBox(width: 4),
                  const Text('文件树'),
                  if (_rootItems.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_countFiles(_rootItems)}',
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 14),
                  const SizedBox(width: 4),
                  const Text('最近打开'),
                  if (_recentFiles.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_recentFiles.length}',
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
            ),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索文件（支持中文）...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
            ),
          ),
          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilesTab(),
                _buildRecentFilesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countFiles(List<FileTreeItem> items) {
    int count = 0;
    for (var item in items) {
      if (!item.isDirectory) count++;
      count += _countFiles(item.children);
    }
    return count;
  }

  /// 文件树标签页
  Widget _buildFilesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _searchQuery.isNotEmpty 
        ? _searchFiles(_rootItems, _searchQuery)
        : _rootItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.folder_off : Icons.search_off,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty ? '空目录' : '未找到文件',
              style: const TextStyle(color: Colors.grey),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '项目路径: ${widget.projectPath}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildTreeItem(items[index], 0),
    );
  }

  /// 构建文件树项
  Widget _buildTreeItem(FileTreeItem item, int level) {
    final indent = level * 16.0;
    final theme = Theme.of(context);

    if (item.isDirectory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                item.isExpanded = !item.isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(
                    item.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    item.isExpanded ? Icons.folder_open : Icons.folder,
                    size: 18,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (item.children.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '(${item.children.length})',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (item.isExpanded && item.children.isNotEmpty)
            ...item.children.map((child) => _buildTreeItem(child, level + 1)),
        ],
      );
    } else {
      return InkWell(
        onTap: () => _openFile(item.path),
        child: Padding(
          padding: EdgeInsets.only(left: indent + 32, top: 3, bottom: 3),
          child: Row(
            children: [
              Icon(
                _getFileIcon(item.name),
                size: 16,
                color: _getFileColor(item.name),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 文件大小提示
              FutureBuilder<String>(
                future: _getFileSize(item.path),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        snapshot.data!,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<String> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        if (size < 1024) return '${size}B';
        if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
        return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
      }
    } catch (_) {}
    return '';
  }

  /// 最近打开的文件标签页
  Widget _buildRecentFilesTab() {
    if (_recentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无最近打开的文件',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              '点击文件树中的文件即可打开',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 快捷操作
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '最近 ${_recentFiles.length} 个文件',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _recentFiles.clear());
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.remove('recent_files_${widget.projectPath}');
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _recentFiles.length,
            itemBuilder: (context, index) {
              final filePath = _recentFiles[index];
              final fileName = p.basename(filePath);
              final relativePath = filePath.startsWith(widget.projectPath)
                  ? filePath.substring(widget.projectPath.length + 1)
                  : filePath;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    _getFileIcon(fileName),
                    size: 20,
                    color: _getFileColor(fileName),
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    relativePath,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() => _recentFiles.removeAt(index));
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setStringList('recent_files_${widget.projectPath}', _recentFiles);
                      });
                    },
                  ),
                  onTap: () => _openFile(filePath),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 文件树项
class FileTreeItem {
  final String name;
  final String path;
  final bool isDirectory;
  List<FileTreeItem> children;
  bool isExpanded;

  FileTreeItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
  });
}
