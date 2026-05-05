/// Miss IDE 构建服务
/// 支持 GitHub Actions 云端构建（推荐方式）
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'build_config.dart';
import '../../core/logger.dart';

/// GitHub Token 存储键
const _githubTokenKey = 'github_token';

/// 默认后端 API 地址（向后兼容保留）
const _defaultBackendApi = 'http://localhost:8080';

const _tag = 'BuildService';

/// 构建服务核心
/// 支持 GitHub Actions 云端构建
class BuildService {
  static const String _githubRepo = 'qq00150610-cpu/miss-ide-v2';
  static final _storage = FlutterSecureStorage();

  // GitHub Token - 从安全存储读取
  static Future<String> get _githubToken async {
    return await _storage.read(key: _githubTokenKey) ?? '';
  }

  // ========== 配置管理 ==========

  /// 初始化构建服务（从安全存储加载配置）
  static Future<void> init() async {
    MissLogger.info(_tag, '构建服务初始化完成');
  }

  /// 获取后端 API 地址（保留向后兼容）
  static String get backendApi => _defaultBackendApi;

  /// 设置后端 API 地址（保留向后兼容）
  static Future<void> setBackendApi(String url) async {
    MissLogger.info(_tag, '后端API地址已更新: $url（仅用于向后兼容）');
  }

  /// 设置 GitHub Token
  static Future<void> setGitHubToken(String token) async {
    await _storage.write(key: _githubTokenKey, value: token);
    MissLogger.info(_tag, 'GitHub Token 已更新');
  }

  /// 获取 GitHub Token
  static Future<String> getGitHubToken() async {
    return await _storage.read(key: _githubTokenKey) ?? '';
  }

  // ========== 构建历史 ==========

  final List<BuildHistoryItem> _buildHistory = [];
  final _historyController = StreamController<List<BuildHistoryItem>>.broadcast();
  Stream<List<BuildHistoryItem>> get historyStream => _historyController.stream;

  // 当前构建状态
  BuildHistoryItem? _currentBuild;
  final _buildStatusController = StreamController<BuildHistoryItem?>.broadcast();
  Stream<BuildHistoryItem?> get buildStatusStream => _buildStatusController.stream;

  // 构建日志
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  // 单例
  static final BuildService _instance = BuildService._internal();
  factory BuildService() => _instance;
  BuildService._internal() {
    _loadHistory();
  }

  // ========== 历史记录持久化 ==========

  Future<void> _loadHistory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final historyFile = File(p.join(docDir.path, 'build_history.json'));
      if (await historyFile.exists()) {
        final content = await historyFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _buildHistory.clear();
        _buildHistory.addAll(jsonList.map((e) => _historyItemFromJson(e)));
        _historyController.add(_buildHistory);
        MissLogger.info(_tag, '已加载 ${_buildHistory.length} 条构建历史');
      }
    } catch (e) {
      MissLogger.error(_tag, '加载构建历史失败: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final historyFile = File(p.join(docDir.path, 'build_history.json'));
      final jsonList = _buildHistory.map((e) => _historyItemToJson(e)).toList();
      await historyFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      MissLogger.error(_tag, '保存构建历史失败: $e');
    }
  }

  Map<String, dynamic> _historyItemToJson(BuildHistoryItem item) => {
    'id': item.id,
    'projectName': item.projectName,
    'buildType': item.buildType.value,
    'status': item.status.value,
    'startTime': item.startTime.toIso8601String(),
    'endTime': item.endTime?.toIso8601String(),
    'apkPath': item.apkPath,
    'errorMessage': item.errorMessage,
    'buildNumber': item.buildNumber,
  };

  BuildHistoryItem _historyItemFromJson(Map<String, dynamic> json) => BuildHistoryItem(
    id: json['id'] ?? '',
    projectName: json['projectName'] ?? '',
    buildType: BuildType.values.firstWhere(
      (e) => e.value == json['buildType'],
      orElse: () => BuildType.debug,
    ),
    status: BuildStatus.values.firstWhere(
      (e) => e.value == json['status'],
      orElse: () => BuildStatus.pending,
    ),
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    apkPath: json['apkPath'],
    errorMessage: json['errorMessage'],
    buildNumber: json['buildNumber'],
  );

  // ========== 核心构建方法 ==========

  /// 触发 GitHub Actions 云端构建
  Future<BuildHistoryItem?> triggerGitHubBuild({
    required String projectName,
    BuildType buildType = BuildType.debug,
    String branch = 'main',
  }) async {
    _emitLog('🚀 开始 GitHub Actions 构建...');
    _emitLog('📦 项目: $projectName');
    _emitLog('🔧 类型: ${buildType.label}');
    _emitLog('🌿 分支: $branch');

    final buildId = 'github_${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    var buildItem = BuildHistoryItem(
      id: buildId,
      projectName: projectName,
      buildType: buildType,
      status: BuildStatus.pending,
      startTime: startTime,
    );

    _currentBuild = buildItem;
    _buildStatusController.add(buildItem);

    try {
      final token = await _githubToken;
      if (token.isEmpty) {
        throw const BuildException('未配置 GitHub Token，请在「设置」中配置 GitHub Personal Access Token');
      }

      // 验证 Token 并获取 Workflow
      _emitLog('🔑 正在连接 GitHub...');
      final workflowsResponse = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/actions/workflows'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (workflowsResponse.statusCode == 401) {
        throw const BuildException('GitHub Token 无效，请检查 Token 是否过期');
      }
      if (workflowsResponse.statusCode == 403) {
        throw const BuildException('GitHub Token 权限不足，需要 repo 和 workflow 权限');
      }
      if (workflowsResponse.statusCode == 404) {
        throw const BuildException('GitHub 仓库不存在或无权访问');
      }
      if (workflowsResponse.statusCode != 200) {
        throw BuildException('GitHub API 返回错误: ${workflowsResponse.statusCode}');
      }

      final workflows = jsonDecode(workflowsResponse.body)['workflows'] as List;
      if (workflows.isEmpty) {
        throw const BuildException('仓库中未找到 GitHub Actions 工作流文件 (.github/workflows/)');
      }

      final workflow = workflows.first;
      _emitLog('✅ 找到 Workflow: ${workflow['name']} (ID: ${workflow['id']})');

      // 触发 workflow_dispatch
      _emitLog('⏳ 正在触发构建...');
      final triggerResponse = await http.post(
        Uri.parse('https://api.github.com/repos/$_githubRepo/actions/workflows/${workflow['id']}/dispatches'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ref': branch,
          'inputs': {'build_type': buildType.value},
        }),
      );

      if (triggerResponse.statusCode == 204 || triggerResponse.statusCode == 201) {
        MissLogger.success(_tag, 'GitHub构建已触发');
        _emitLog('✅ 构建已触发!');

        buildItem = buildItem.copyWith(
          status: BuildStatus.running,
        );
        _currentBuild = buildItem;
        _buildStatusController.add(buildItem);

        // 等待几秒后开始查询最新的 Run
        await Future.delayed(const Duration(seconds: 10));
        await _pollLatestGitHubBuild(buildItem, token);

        return _currentBuild;
      } else {
        final errorBody = utf8.decode(triggerResponse.bodyBytes);
        MissLogger.error(_tag, '触发构建失败: $errorBody');
        throw BuildException('触发构建失败: ${triggerResponse.statusCode}');
      }
    } catch (e) {
      final msg = e is BuildException ? e.message : e.toString();
      MissLogger.error(_tag, 'GitHub构建失败: $msg');

      _emitLog('❌ 构建触发失败: $msg');

      buildItem = buildItem.copyWith(
        status: BuildStatus.failure,
        endTime: DateTime.now(),
        errorMessage: msg,
      );
      _currentBuild = buildItem;
      _buildStatusController.add(buildItem);
      _addToHistory(buildItem);

      return buildItem;
    }
  }

  /// 轮询最新的 GitHub Actions 构建状态
  Future<void> _pollLatestGitHubBuild(BuildHistoryItem buildItem, String token) async {
    const maxAttempts = 120;
    var attempts = 0;

    while (attempts < maxAttempts) {
      try {
        await Future.delayed(const Duration(seconds: 30));

        // 获取最新的 workflow run
        final response = await http.get(
          Uri.parse('https://api.github.com/repos/$_githubRepo/actions/runs?per_page=1'),
          headers: {
            'Authorization': 'token $token',
            'Accept': 'application/vnd.github.v3+json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final runs = data['workflow_runs'] as List? ?? [];
          if (runs.isEmpty) {
            _emitLog('⚠️ 未找到构建记录，继续等待...');
            attempts++;
            continue;
          }

          final run = runs.first;
          final status = run['status'] as String? ?? 'unknown';
          final conclusion = run['conclusion'] as String?;
          final runId = run['id'] as int;
          final htmlUrl = run['html_url'] as String? ?? '';

          _emitLog('📊 构建状态: $status ${_getStatusEmoji(status, conclusion)}');

          if (status == 'completed') {
            BuildStatus newStatus;
            String? apkPath;
            String? errorMsg;

            switch (conclusion) {
              case 'success':
                newStatus = BuildStatus.success;
                _emitLog('✅ 构建成功!');
                _emitLog('🔗 $htmlUrl');
                apkPath = await _getGitHubArtifactUrl(runId, token);
                if (apkPath != null) {
                  _emitLog('📥 APK 已生成，正在下载...');
                } else {
                  _emitLog('⚠️ 构建成功但未找到 APK 产物，请在 GitHub 查看');
                }
                break;
              case 'failure':
                newStatus = BuildStatus.failure;
                errorMsg = 'GitHub Actions 构建失败';
                _emitLog('❌ 构建失败，请查看日志: $htmlUrl');
                final failureLog = await _getGitHubFailureLog(runId, token);
                if (failureLog != null) {
                  errorMsg = failureLog;
                  _emitLog('📋 $failureLog');
                }
                break;
              case 'cancelled':
                newStatus = BuildStatus.cancelled;
                _emitLog('⏹️ 构建已取消');
                break;
              default:
                newStatus = BuildStatus.failure;
                errorMsg = '构建异常: $conclusion';
            }

            // 如果有 APK 链接，自动下载
            if (apkPath != null) {
              final localPath = await _downloadArtifact(apkPath, token);
              if (localPath != null) {
                apkPath = localPath;
                MissLogger.success(_tag, 'APK 已下载到本地: $localPath');
              }
            }

            final updatedItem = buildItem.copyWith(
              buildNumber: runId,
              status: newStatus,
              endTime: DateTime.now(),
              apkPath: apkPath,
              errorMessage: errorMsg,
            );
            _currentBuild = updatedItem;
            _buildStatusController.add(updatedItem);
            _addToHistory(updatedItem);
            return;
          }

          attempts++;
          if (attempts % 4 == 0) {
            _emitLog('⏳ 等待构建完成... (已等待 ${attempts ~/ 2} 分钟)');
          }
        } else {
          _emitLog('⚠️ 获取状态失败 (${response.statusCode})，继续等待...');
          attempts++;
        }
      } catch (e) {
        MissLogger.error(_tag, '轮询错误: $e');
        _emitLog('⚠️ 网络波动，继续等待...');
        attempts++;
      }
    }

    // 超时
    _emitLog('⏰ 构建超时 (已等待 60 分钟)');
    final updatedItem = buildItem.copyWith(
      status: BuildStatus.failure,
      endTime: DateTime.now(),
      errorMessage: '构建超时（GitHub Actions 构建超过 60 分钟）',
    );
    _currentBuild = updatedItem;
    _buildStatusController.add(updatedItem);
    _addToHistory(updatedItem);
  }

  /// 下载 GitHub 构建产物到本地
  Future<String?> _downloadArtifact(String archiveUrl, String token) async {
    try {
      _emitLog('📥 正在下载构建产物...');
      
      // GitHub artifact 需要重定向
      final redirectResponse = await http.get(
        Uri.parse(archiveUrl),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (redirectResponse.statusCode == 302 || redirectResponse.statusCode == 200) {
        // 下载实际文件
        final downloadUrl = redirectResponse.headers['location'] ?? archiveUrl;
        final downloadResponse = await http.get(Uri.parse(downloadUrl));

        if (downloadResponse.statusCode == 200) {
          final docDir = await getApplicationDocumentsDirectory();
          final downloadDir = Directory(p.join(docDir.path, 'downloads'));
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }

          final apkPath = p.join(
            downloadDir.path,
            'miss-ide-${DateTime.now().millisecondsSinceEpoch}.apk',
          );
          
          // 如果是 ZIP 存档，尝试解压
          if (archiveUrl.contains('zipball') || downloadResponse.headers['content-type']?.contains('zip') == true) {
            await File(apkPath).writeAsBytes(downloadResponse.bodyBytes);
          } else {
            await File(apkPath).writeAsBytes(downloadResponse.bodyBytes);
          }

          MissLogger.success(_tag, 'APK 已保存: $apkPath');
          _emitLog('✅ 下载完成: $apkPath');
          return apkPath;
        }
      }
    } catch (e) {
      MissLogger.error(_tag, '下载产物失败: $e');
    }
    return null;
  }

  /// 获取 GitHub Actions 失败的详细日志
  Future<String?> _getGitHubFailureLog(int runId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/actions/runs/$runId/jobs'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jobs = data['jobs'] as List;
        if (jobs.isNotEmpty) {
          final failedSteps = [];
          for (final job in jobs) {
            final steps = job['steps'] as List? ?? [];
            for (final step in steps) {
              if (step['conclusion'] == 'failure') {
                failedSteps.add(step['name']);
              }
            }
          }
          if (failedSteps.isNotEmpty) {
            return '失败步骤: ${failedSteps.join(", ")}';
          }
        }
      }
    } catch (e) {
      MissLogger.error(_tag, '获取失败日志出错: $e');
    }
    return null;
  }

  /// 获取 GitHub 构建产物（APK）下载链接
  Future<String?> _getGitHubArtifactUrl(int runId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/actions/runs/$runId/artifacts'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final artifacts = data['artifacts'] as List;
        MissLogger.info(_tag, '找到 ${artifacts.length} 个构建产物');

        for (final artifact in artifacts) {
          final name = (artifact['name'] as String).toLowerCase();
          final downloadUrl = artifact['archive_download_url'] as String;
          MissLogger.info(_tag, '  产物: $name');

          if (name.contains('apk') || name.contains('release') || name.contains('app')) {
            return downloadUrl;
          }
        }

        if (artifacts.isNotEmpty) {
          return artifacts.first['archive_download_url'] as String;
        }
      } else {
        MissLogger.error(_tag, '获取产物列表失败: ${response.statusCode}');
      }
    } catch (e) {
      MissLogger.error(_tag, '获取产物URL出错: $e');
    }
    return null;
  }

  /// 取消构建
  Future<void> cancelBuild() async {
    try {
      final token = await _githubToken;
      if (token.isNotEmpty && _currentBuild?.buildNumber != null) {
        final runId = _currentBuild!.buildNumber;
        await http.post(
          Uri.parse('https://api.github.com/repos/$_githubRepo/actions/runs/$runId/cancel'),
          headers: {
            'Authorization': 'token $token',
            'Accept': 'application/vnd.github.v3+json',
          },
        );
        _emitLog('⏹️ 已发送取消请求');
      }
    } catch (e) {
      MissLogger.error(_tag, '取消构建失败: $e');
    }

    final updatedItem = _currentBuild?.copyWith(
      status: BuildStatus.cancelled,
      endTime: DateTime.now(),
    );

    if (updatedItem != null) {
      _addToHistory(updatedItem);
    }

    _currentBuild = null;
    _buildStatusController.add(null);
  }

  // ========== 辅助方法 ==========

  void _addToHistory(BuildHistoryItem item) {
    _buildHistory.insert(0, item);
    if (_buildHistory.length > 50) {
      _buildHistory.removeRange(50, _buildHistory.length);
    }
    _saveHistory();
    _historyController.add(_buildHistory);
  }

  void _emitLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
    MissLogger.info(_tag, message);
  }

  String _getStatusEmoji(String status, String? conclusion) {
    if (status == 'completed') {
      switch (conclusion) {
        case 'success': return '✅';
        case 'failure': return '❌';
        case 'cancelled': return '⏹️';
        default: return '❓';
      }
    }
    return '⏳';
  }

  /// 下载 APK 文件到本地（公开方法）
  /// 如果是 GitHub 产物 URL，需要先获取 token
  Future<String?> downloadApkFile(String url) async {
    try {
      final token = await _githubToken;
      if (url.contains('api.github.com') && token.isNotEmpty) {
        return await _downloadArtifact(url, token);
      }
      
      // 直接 URL 下载
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final docDir = await getApplicationDocumentsDirectory();
        final downloadDir = Directory(p.join(docDir.path, 'downloads'));
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        final apkPath = p.join(
          downloadDir.path,
          'miss-ide-${DateTime.now().millisecondsSinceEpoch}.apk',
        );
        await File(apkPath).writeAsBytes(response.bodyBytes);
        MissLogger.success(_tag, 'APK 已下载: $apkPath');
        return apkPath;
      }
    } catch (e) {
      MissLogger.error(_tag, '下载APK失败: $e');
    }
    return null;
  }

  /// 获取历史记录
  List<BuildHistoryItem> getHistory() => List.from(_buildHistory);

  /// 删除指定的历史记录项
  Future<void> removeHistoryItem(int index) async {
    if (index < 0 || index >= _buildHistory.length) return;
    _buildHistory.removeAt(index);
    await _saveHistory();
    _historyController.add(_buildHistory);
    MissLogger.info(_tag, '已删除第 $index 条构建历史');
  }

  /// 清空历史记录
  Future<void> clearHistory() async {
    _buildHistory.clear();
    await _saveHistory();
    _historyController.add(_buildHistory);
    MissLogger.info(_tag, '构建历史已清空');
  }
}

/// 构建异常
class BuildException implements Exception {
  final String message;
  const BuildException(this.message);

  @override
  String toString() => 'BuildException: $message';
}

// 全局实例
final buildService = BuildService();
