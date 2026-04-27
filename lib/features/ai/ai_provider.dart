import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// AI响应类型
sealed class AIResponse {
  final String modelId;

  const AIResponse(this.modelId);
}

class AITokenResponse extends AIResponse {
  final String text;

  const AITokenResponse(super.modelId, this.text);
}

class AIDoneResponse extends AIResponse {
  final String fullContent;
  final int inputTokens;
  final int outputTokens;
  final double? cost;

  const AIDoneResponse(
    super.modelId,
    this.fullContent, {
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cost,
  });
}

class AIErrorResponse extends AIResponse {
  final String message;
  final AIErrorCode code;

  const AIErrorResponse(
    super.modelId,
    this.message,
    this.code,
  );
}

class AIUsageResponse extends AIResponse {
  final int inputTokens;
  final int outputTokens;
  final double? cost;

  const AIUsageResponse(
    super.modelId, {
    required this.inputTokens,
    required this.outputTokens,
    this.cost,
  });

  int get totalTokens => inputTokens + outputTokens;
}

/// AI错误码
enum AIErrorCode {
  connectionError('连接错误'),
  timeout('请求超时'),
  networkUnavailable('网络不可用'),
  apiError('API错误'),
  invalidApiKey('无效的API Key'),
  rateLimited('请求过于频繁'),
  quotaExceeded('配额超限'),
  modelNotFound('模型不存在'),
  contentFiltered('内容被过滤'),
  invalidInput('无效输入'),
  contextTooLong('上下文过长'),
  unsupportedLanguage('不支持的语言'),
  unsupportedFeature('不支持的功能'),
  serviceUnavailable('服务不可用'),
  maintenance('服务维护中'),
  unknown('未知错误');

  final String displayName;

  const AIErrorCode(this.displayName);
}

/// 代码补全上下文
class CodeCompletionContext {
  final String fileName;
  final String language;
  final String beforeCursor;
  final String afterCursor;
  final List<String> imports;
  final Map<String, String> visibleSymbols;

  const CodeCompletionContext({
    required this.fileName,
    required this.language,
    required this.beforeCursor,
    required this.afterCursor,
    this.imports = const [],
    this.visibleSymbols = const {},
  });

  String get fullCode => '$beforeCursor\n$afterCursor';

  int get cursorLine {
    final lines = beforeCursor.split('\n');
    return lines.length;
  }
}

/// AI任务类型
enum AITaskType {
  codeCompletion('代码补全'),
  codeExplanation('代码解释'),
  codeRefactor('代码重构'),
  bugFix('Bug修复'),
  generateDoc('生成文档'),
  chat('对话'),
  imageAnalysis('图片分析');

  final String displayName;

  const AITaskType(this.displayName);
}

/// AI任务
class AITask {
  final AITaskType type;
  final String prompt;
  final String? code;
  final String? language;
  final Map<String, dynamic>? metadata;

  const AITask({
    required this.type,
    required this.prompt,
    this.code,
    this.language,
    this.metadata,
  });
}

/// 基础AI Provider接口
abstract class AIProvider {
  AIProviderType get providerType;
  String get displayName => providerType.displayName;
  String get displayNameCN => providerType.displayNameCN;
  
  /// 获取支持的模型列表
  List<AIModel> get supportedModels;

  /// 检查服务是否可用
  Future<bool> isAvailable();

  /// 代码补全
  Stream<AIResponse> complete(CodeCompletionContext context, {
    String? modelId,
    double temperature = 0.3,
    int maxTokens = 2048,
  });

  /// 代码解释
  Stream<AIResponse> explain(String code, String language, {
    String? modelId,
    double temperature = 0.7,
  });

  /// 代码重构
  Stream<AIResponse> refactor(String code, String hint, {
    String? modelId,
    double temperature = 0.5,
  });

  /// 生成文档
  Stream<AIResponse> generateDoc(String code, {
    String? style,
    String? modelId,
  });

  /// 对话
  Stream<AIResponse> chat(String message, {
    List<Map<String, String>>? history,
    String? modelId,
    double temperature = 0.7,
    int maxTokens = 2048,
  });

  /// 图片分析
  Stream<AIResponse> analyzeImage(List<int> imageBytes, String question, {
    String? modelId,
  });

  /// 获取使用统计
  Map<String, UsageStats> get usageStats;

  /// 重置使用统计
  void resetUsageStats();

  /// 释放资源
  void dispose();
}

/// Provider管理器
class AIProviderManager {
  final Map<AIProviderType, AIProvider> _providers = {};
  final Map<String, ProviderConfig> _configs = {};

  void registerProvider(AIProvider provider, ProviderConfig config) {
    _providers[provider.providerType] = provider;
    _configs[provider.providerType.name] = config;
  }

  void unregisterProvider(AIProviderType type) {
    _providers.remove(type);
    _configs.remove(type.name);
  }

  AIProvider? getProvider(AIProviderType type) {
    return _providers[type];
  }

  List<AIProvider> get allProviders => _providers.values.toList();

  List<AIProviderType> get configuredProviders {
    return _configs.entries
        .where((e) => e.value.hasApiKey)
        .map((e) => AIProviderType.values.firstWhere(
            (t) => t.name == e.key,
            orElse: () => AIProviderType.openai))
        .toList();
  }

  ProviderConfig? getConfig(AIProviderType type) {
    return _configs[type.name];
  }

  void updateConfig(AIProviderType type, ProviderConfig config) {
    _configs[type.name] = config;
  }
}
