import 'dart:io';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 文件操作工具
class FileOperations {
  static final FileOperations _instance = FileOperations._internal();
  factory FileOperations() => _instance;
  FileOperations._internal();

  /// 创建文件
  Future<FileOperationResult> createFile(String path, {String? content}) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content ?? '');
      logger.i(LogTags.fileManager, 'Created file: $path');
      return FileOperationResult.success('文件创建成功');
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to create file: $path', error: e);
      return FileOperationResult.failure('创建失败: $e');
    }
  }

  /// 创建目录
  Future<FileOperationResult> createDirectory(String path) async {
    try {
      final dir = Directory(path);
      await dir.create(recursive: true);
      logger.i(LogTags.fileManager, 'Created directory: $path');
      return FileOperationResult.success('目录创建成功');
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to create directory: $path', error: e);
      return FileOperationResult.failure('创建失败: $e');
    }
  }

  /// 删除文件或目录
  Future<FileOperationResult> delete(String path, {bool recursive = false}) async {
    try {
      final type = await FileSystemEntity.type(path);
      
      if (type == FileSystemEntityType.file) {
        await File(path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: recursive);
      } else {
        return FileOperationResult.failure('路径不存在');
      }

      logger.i(LogTags.fileManager, 'Deleted: $path');
      return FileOperationResult.success('删除成功');
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to delete: $path', error: e);
      return FileOperationResult.failure('删除失败: $e');
    }
  }

  /// 重命名
  Future<FileOperationResult> rename(String path, String newName) async {
    try {
      final type = await FileSystemEntity.type(path);
      final parent = Directory(path).parent.path;
      final newPath = '$parent/$newName';

      if (type == FileSystemEntityType.file) {
        await File(path).rename(newPath);
      } else if (type == FileSystemEntityType.directory) {
        await Directory(path).rename(newPath);
      } else {
        return FileOperationResult.failure('路径不存在');
      }

      logger.i(LogTags.fileManager, 'Renamed: $path -> $newPath');
      return FileOperationResult.success('重命名成功', newPath: newPath);
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to rename: $path', error: e);
      return FileOperationResult.failure('重命名失败: $e');
    }
  }

  /// 复制文件
  Future<FileOperationResult> copy(String source, String destination) async {
    try {
      final file = File(source);
      await file.parent.create(recursive: true);
      await file.copy(destination);
      logger.i(LogTags.fileManager, 'Copied: $source -> $destination');
      return FileOperationResult.success('复制成功', newPath: destination);
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to copy: $source', error: e);
      return FileOperationResult.failure('复制失败: $e');
    }
  }

  /// 移动文件/目录
  Future<FileOperationResult> move(String source, String destination) async {
    try {
      await File(source).rename(destination);
      logger.i(LogTags.fileManager, 'Moved: $source -> $destination');
      return FileOperationResult.success('移动成功', newPath: destination);
    } catch (e) {
      // 如果 rename 失败，尝试 copy + delete
      final copyResult = await copy(source, destination);
      if (copyResult.success) {
        await delete(source);
        return FileOperationResult.success('移动成功', newPath: destination);
      }
      logger.e(LogTags.fileManager, 'Failed to move: $source', error: e);
      return FileOperationResult.failure('移动失败: $e');
    }
  }

  /// 读取文件
  Future<String?> readFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to read file: $path', error: e);
      return null;
    }
  }

  /// 写入文件
  Future<FileOperationResult> writeFile(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      logger.i(LogTags.fileManager, 'Wrote file: $path');
      return FileOperationResult.success('保存成功');
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to write file: $path', error: e);
      return FileOperationResult.failure('保存失败: $e');
    }
  }

  /// 列出目录内容
  Future<List<FileSystemEntity>> listDirectory(String path, {bool recursive = false}) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return [];
      }
      return await dir.list(recursive: recursive).toList();
    } catch (e) {
      logger.e(LogTags.fileManager, 'Failed to list directory: $path', error: e);
      return [];
    }
  }

  /// 获取文件信息
  Future<FileStat?> getFileInfo(String path) async {
    try {
      return await FileStat.stat(path);
    } catch (e) {
      return null;
    }
  }

  /// 检查文件是否存在
  Future<bool> exists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  /// 获取文件大小
  Future<int?> getFileSize(String path) async {
    try {
      final stat = await File(path).stat();
      return stat.size;
    } catch (e) {
      return null;
    }
  }

  /// 搜索文件
  Future<List<String>> searchFiles(
    String directory,
    String query, {
    bool caseSensitive = false,
    List<String>? extensions,
  }) async {
    final results = <String>[];
    final dir = Directory(directory);
    
    if (!await dir.exists()) {
      return results;
    }

    final searchQuery = caseSensitive ? query : query.toLowerCase();

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final fileName = entity.path.split('/').last;
        final compareName = caseSensitive ? fileName : fileName.toLowerCase();
        
        if (compareName.contains(searchQuery)) {
          if (extensions != null) {
            final ext = fileName.split('.').last;
            if (extensions.contains(ext)) {
              results.add(entity.path);
            }
          } else {
            results.add(entity.path);
          }
        }
      }
    }

    return results;
  }
}

/// 文件操作结果
class FileOperationResult {
  final bool success;
  final String? message;
  final String? newPath;

  const FileOperationResult._({
    required this.success,
    this.message,
    this.newPath,
  });

  factory FileOperationResult.success(String message, {String? newPath}) {
    return FileOperationResult._(success: true, message: message, newPath: newPath);
  }

  factory FileOperationResult.failure(String message) {
    return FileOperationResult._(success: false, message: message);
  }
}

/// 全局实例
final fileOperations = FileOperations();
