import 'dart:io';
import 'package:path/path.dart' as path;
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import 'file_operations.dart';

/// 文件浏览器
class FileBrowser {
  static final FileBrowser _instance = FileBrowser._internal();
  factory FileBrowser() => _instance;
  FileBrowser._internal();

  final FileOperations _fileOps = fileOperations;
  String? _currentPath;
  List<FileNode> _nodes = [];
  final List<String> _pathHistory = [];
  int _historyIndex = -1;

  /// 当前路径
  String? get currentPath => _currentPath;

  /// 文件节点列表
  List<FileNode> get nodes => List.unmodifiable(_nodes);

  /// 是否有后退历史
  bool get canGoBack => _historyIndex > 0;

  /// 是否有前进历史
  bool get canGoForward => _historyIndex < _pathHistory.length - 1;

  /// 打开目录
  Future<List<FileNode>> openDirectory(String dirPath) async {
    _currentPath = dirPath;
    
    // 添加到历史
    if (_historyIndex < _pathHistory.length - 1) {
      // 如果在历史中间，清除后面的历史
      _pathHistory.removeRange(_historyIndex + 1, _pathHistory.length);
    }
    _pathHistory.add(dirPath);
    _historyIndex = _pathHistory.length - 1;

    try {
      final entities = await _fileOps.listDirectory(dirPath);
      _nodes = await _buildFileTree(entities, dirPath);
      
      // 排序：目录在前，文件在后，按名称排序
      _nodes.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      logger.i(LogTags.fileManager, 'Opened directory: $dirPath (${_nodes.length} items)');
      return _nodes;
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to open directory: $dirPath', error: e);
      _nodes = [];
      return [];
    }
  }

  /// 后退
  Future<List<FileNode>?> goBack() async {
    if (!canGoBack) return null;
    _historyIndex--;
    return openDirectory(_pathHistory[_historyIndex]);
  }

  /// 前进
  Future<List<FileNode>?> goForward() async {
    if (!canGoForward) return null;
    _historyIndex++;
    return openDirectory(_pathHistory[_historyIndex]);
  }

  /// 返回上级目录
  Future<List<FileNode>?> goUp() async {
    if (_currentPath == null) return null;
    
    final parent = Directory(_currentPath!).parent.path;
    if (parent == _currentPath) return null; // 已经是最顶层
    
    return openDirectory(parent);
  }

  /// 刷新当前目录
  Future<List<FileNode>> refresh() async {
    if (_currentPath == null) return [];
    return openDirectory(_currentPath!);
  }

  /// 构建文件树
  Future<List<FileNode>> _buildFileTree(List<FileSystemEntity> entities, String basePath) async {
    final nodes = <FileNode>[];
    
    for (final entity in entities) {
      final name = path.basename(entity.path);
      
      // 跳过隐藏文件（除非是配置目录）
      if (name.startsWith('.') && !_isImportantHiddenDir(name)) {
        continue;
      }

      final stat = await entity.stat();
      final language = ProgrammingLanguage.fromFileName(name);
      
      nodes.add(FileNode(
        path: entity.path,
        name: name,
        isDirectory: entity is Directory,
        size: stat.size,
        modifiedAt: stat.modified,
        language: language,
      ));
    }

    return nodes;
  }

  /// 是否是重要的隐藏目录
  bool _isImportantHiddenDir(String name) {
    const importantDirs = ['.git', '.idea', '.vscode', '.dart_tool', '.gradle'];
    return importantDirs.contains(name);
  }

  /// 获取目录树（用于侧边栏显示）
  Future<FileTreeNode?> getDirectoryTree(String rootPath, {int maxDepth = 3}) async {
    return _buildTreeNode(rootPath, 0, maxDepth);
  }

  Future<FileTreeNode?> _buildTreeNode(String nodePath, int depth, int maxDepth) async {
    try {
      final stat = await FileStat.stat(nodePath);
      final name = path.basename(nodePath);
      
      if (stat.type == FileSystemEntityType.file) {
        return FileTreeNode(
          path: nodePath,
          name: name,
          isDirectory: false,
          children: const [],
        );
      }

      if (depth >= maxDepth) {
        return FileTreeNode(
          path: nodePath,
          name: name,
          isDirectory: true,
          children: const [],
          hasMore: true,
        );
      }

      final dir = Directory(nodePath);
      final children = <FileTreeNode>[];
      
      await for (final entity in dir.list()) {
        final entityName = path.basename(entity.path);
        
        // 跳过隐藏文件
        if (entityName.startsWith('.')) continue;
        
        final childNode = await _buildTreeNode(entity.path, depth + 1, maxDepth);
        if (childNode != null) {
          children.add(childNode);
        }
      }

      // 排序
      children.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return FileTreeNode(
        path: nodePath,
        name: name,
        isDirectory: true,
        children: children,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取路径面包屑
  List<PathCrumb> getPathBreadcrumbs() {
    if (_currentPath == null) return [];
    
    final parts = _currentPath!.split('/');
    final crumbs = <PathCrumb>[];
    var currentPath = '';
    
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      currentPath = '$currentPath/${parts[i]}';
      crumbs.add(PathCrumb(
        path: currentPath,
        name: parts[i],
        isLast: i == parts.length - 1,
      ));
    }
    
    return crumbs;
  }
}

/// 文件节点
class FileNode {
  final String path;
  final String name;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
  final ProgrammingLanguage? language;

  const FileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
    this.language,
  });

  String get extension {
    if (isDirectory) return '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String get sizeDisplay {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get modifiedDisplay {
    if (modifiedAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(modifiedAt!);
    
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}年前';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}月前';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}

/// 文件树节点（用于侧边栏）
class FileTreeNode {
  final String path;
  final String name;
  final bool isDirectory;
  final List<FileTreeNode> children;
  final bool hasMore;

  const FileTreeNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.children,
    this.hasMore = false,
  });
}

/// 路径面包屑
class PathCrumb {
  final String path;
  final String name;
  final bool isLast;

  const PathCrumb({
    required this.path,
    required this.name,
    required this.isLast,
  });
}

/// 全局实例
final fileBrowser = FileBrowser();
