import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 增量编译器 - 智能检测变更，只编译必要的文件
class IncrementalCompiler {
  static final IncrementalCompiler _instance = IncrementalCompiler._internal();
  factory IncrementalCompiler() => _instance;
  IncrementalCompiler._internal();

  final Map<String, String> _fileChecksums = {};
  final Map<String, List<String>> _dependencyGraph = {};
  String? _cachePath;
  bool _initialized = false;

  /// 初始化
  Future<void> init(String cachePath) async {
    if (_initialized) return;
    _cachePath = path.join(cachePath, 'incremental-cache');
    
    final dir = Directory(_cachePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 加载缓存的校验和
    await _loadChecksums();

    _initialized = true;
    logger.i(LogTags.build, 'IncrementalCompiler initialized');
  }

  /// 分析需要重新编译的文件
  Future<IncrementalBuildResult> analyzeChanges(
    String projectPath,
    List<String> changedFiles,
  ) async {
    final toCompile = <String>[];
    final toSkip = <String>[];
    final affectedFiles = <String>{};

    for (final filePath in changedFiles) {
      final currentChecksum = await _calculateChecksum(filePath);
      final cachedChecksum = _fileChecksums[filePath];

      if (currentChecksum != cachedChecksum) {
        // 文件有变化，需要编译
        toCompile.add(filePath);
        _fileChecksums[filePath] = currentChecksum;

        // 找出依赖此文件的其他文件
        affectedFiles.addAll(_getAffectedFiles(filePath));
      } else {
        toSkip.add(filePath);
      }
    }

    // 编译所有受影响的文件
    toCompile.addAll(affectedFiles);

    logger.i(LogTags.build, 
      'Incremental analysis: ${toCompile.length} to compile, ${toSkip.length} to skip');

    return IncrementalBuildResult(
      filesToCompile: toCompile.toSet().toList(),
      filesToSkip: toSkip,
      totalFiles: toCompile.length + toSkip.length,
      cacheHitRate: toSkip.length / (toCompile.length + toSkip.length),
    );
  }

  /// 更新文件校验和
  Future<void> updateChecksum(String filePath) async {
    final checksum = await _calculateChecksum(filePath);
    _fileChecksums[filePath] = checksum;
    await _saveChecksums();
  }

  /// 计算文件校验和
  Future<String> _calculateChecksum(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';
      
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (e) {
      logger.w(LogTags.build, 'Failed to calculate checksum for $filePath', error: e);
      return '';
    }
  }

  /// 获取依赖此文件的其他文件
  Set<String> _getAffectedFiles(String filePath) {
    final affected = <String>{};
    
    for (final entry in _dependencyGraph.entries) {
      if (entry.value.contains(filePath)) {
        affected.add(entry.key);
      }
    }
    
    return affected;
  }

  /// 构建依赖图
  Future<void> buildDependencyGraph(String projectPath) async {
    _dependencyGraph.clear();
    
    final dir = Directory(projectPath);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (['.kt', '.java', '.dart'].contains(ext)) {
          await _analyzeDependencies(entity.path);
        }
      }
    }

    logger.i(LogTags.build, 'Built dependency graph with ${_dependencyGraph.length} entries');
  }

  /// 分析单个文件的依赖
  Future<void> _analyzeDependencies(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      final imports = <String>[];

      // 简单的导入检测（可以更精确）
      final importRegex = RegExp(r'import\s+[\'"]([^\'"]+)[\'"]');
      for (final match in importRegex.allMatches(content)) {
        imports.add(match.group(1) ?? '');
      }

      _dependencyGraph[filePath] = imports;
    } catch (e) {
      logger.w(LogTags.build, 'Failed to analyze dependencies for $filePath', error: e);
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    _fileChecksums.clear();
    _dependencyGraph.clear();
    
    if (_cachePath != null) {
      final checksumFile = File(path.join(_cachePath!, 'checksums.json'));
      if (await checksumFile.exists()) {
        await checksumFile.delete();
      }
    }
    
    logger.i(LogTags.build, 'Incremental compiler cache cleared');
  }

  /// 获取缓存统计
  CacheStats getStats() {
    return CacheStats(
      cachedFiles: _fileChecksums.length,
      dependencyEntries: _dependencyGraph.length,
      cachePath: _cachePath,
    );
  }

  /// 加载校验和
  Future<void> _loadChecksums() async {
    if (_cachePath == null) return;
    
    final file = File(path.join(_cachePath!, 'checksums.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = Map<String, String>.from(
          Uri.splitQueryString(content).map((k, v) => MapEntry(k, v)),
        );
        _fileChecksums.clear();
        _fileChecksums.addAll(data);
      } catch (e) {
        logger.w(LogTags.build, 'Failed to load checksums', error: e);
      }
    }
  }

  /// 保存校验和
  Future<void> _saveChecksums() async {
    if (_cachePath == null) return;
    
    final file = File(path.join(_cachePath!, 'checksums.json'));
    final content = _fileChecksums.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    await file.writeAsString(content);
  }
}

/// 增量构建结果
class IncrementalBuildResult {
  final List<String> filesToCompile;
  final List<String> filesToSkip;
  final int totalFiles;
  final double cacheHitRate;

  const IncrementalBuildResult({
    required this.filesToCompile,
    required this.filesToSkip,
    required this.totalFiles,
    required this.cacheHitRate,
  });

  bool get hasChanges => filesToCompile.isNotEmpty;
}

/// 缓存统计
class CacheStats {
  final int cachedFiles;
  final int dependencyEntries;
  final String? cachePath;

  const CacheStats({
    required this.cachedFiles,
    required this.dependencyEntries,
    this.cachePath,
  });
}

/// 全局增量编译器实例
final incrementalCompiler = IncrementalCompiler();
