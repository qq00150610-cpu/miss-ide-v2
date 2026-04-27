import 'dart:async';
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import 'providers/qwen_provider.dart';
import 'providers/deepseek_provider.dart';
import 'providers/doubao_provider.dart';
import 'providers/minimax_provider.dart';
import 'providers/zhipu_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/claude_provider.dart';
import 'providers/ollama_provider.dart';

/// AI服务 - 统一的AI服务接口
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final Map<AIProviderType, AIProvider> _providers = {};
  AIConfig _config = const AIConfig();
  AIProvider? _activeProvider;

  /// 初始化所有Provider
  void init({AIConfig? config}) {
    if (config != null) {
      _config = config;
    }

    // 注册所有Provider
    _providers[AIProviderType.qwen] = QwenProvider();
    _providers[AIProviderType.deepseek] = DeepSeekProvider();
    _providers[AIProviderType.doubao] = DoubaoProvider();
    _providers[AIProviderType.minimax] = MinimaxProvider();
    _providers[AIProviderType.zhipu] = ZhipuProvider();
    _providers[AIProviderType.gemini] = GeminiProvider();
    _providers[AIProviderType.openai] = OpenAIProvider();
    _providers[AIProviderType.anthropic] = ClaudeProvider();
    _providers[AIProviderType.ollama] = OllamaProvider();

    logger.i(LogTags.ai, 'AIService initialized with ${_providers.length} providers');
  }

  /// 配置Provider的API Key
  Future<void> configureProvider(AIProviderType type, String apiKey, {String? baseUrl}) async {
    final provider = _providers[type];
    if (provider == null) return;

    switch (type) {
      case AIProviderType.qwen:
        (provider as QwenProvider).setApiKey(apiKey);
        if (baseUrl != null) provider.setBaseUrl(baseUrl);
        break;
      case AIProviderType.deepseek:
        (provider as DeepSeekProvider).setApiKey(apiKey);
        if (baseUrl != null) provider.setBaseUrl(baseUrl);
        break;
      case AIProviderType.doubao:
        (provider as DoubaoProvider).setApiKey(apiKey);
        break;
      case AIProviderType.gemini:
        (provider as GeminiProvider).setApiKey(apiKey);
        break;
      case AIProviderType.openai:
        (provider as OpenAIProvider).setApiKey(apiKey);
        if (baseUrl != null) (provider).setApiKey(apiKey);
        break;
      case AIProviderType.anthropic:
        (provider as ClaudeProvider).setApiKey(apiKey);
        break;
      case AIProviderType.ollama:
        if (baseUrl != null) (provider as OllamaProvider).setBaseUrl(baseUrl);
        break;
      case AIProviderType.minimax:
      case AIProviderType.zhipu:
        // 这些需要特殊处理
        break;
    }

    logger.i(LogTags.ai, 'Configured provider: $type');
  }

  /// 获取Provider
  AIProvider? getProvider(AIProviderType type) => _providers[type];

  /// 获取当前Provider
  AIProvider? get currentProvider => _activeProvider ?? _providers[_config.defaultProvider];

  /// 设置当前Provider
  void setCurrentProvider(AIProviderType type) {
    _activeProvider = _providers[type];
    logger.i(LogTags.ai, 'Switched to provider: $type');
  }

  /// 获取当前模型
  AIModel? get currentModel {
    final modelId = _config.defaultModelId;
    return AIModelCatalog.getModelById(modelId);
  }

  /// 设置配置
  void updateConfig(AIConfig config) {
    _config = config;
  }

  /// 获取配置
  AIConfig get config => _config;

  /// 检查Provider是否可用
  Future<bool> isProviderAvailable(AIProviderType type) async {
    final provider = _providers[type];
    if (provider == null) return false;
    return provider.isAvailable();
  }

  /// 获取已配置的Provider列表
  Future<List<AIProviderType>> getConfiguredProviders() async {
    final configured = <AIProviderType>[];
    for (final type in _providers.keys) {
      if (await isProviderAvailable(type)) {
        configured.add(type);
      }
    }
    return configured;
  }

  /// 代码补全
  Stream<AIResponse> complete(CodeCompletionContext context, {String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    return provider.complete(
      context,
      modelId: modelId ?? _config.defaultModelId,
      temperature: _config.temperature,
      maxTokens: _config.maxTokens,
    );
  }

  /// 代码解释
  Stream<AIResponse> explain(String code, String language, {String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    return provider.explain(
      code,
      language,
      modelId: modelId ?? _config.defaultModelId,
      temperature: _config.temperature,
    );
  }

  /// 代码重构
  Stream<AIResponse> refactor(String code, String hint, {String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    return provider.refactor(
      code,
      hint,
      modelId: modelId ?? _config.defaultModelId,
      temperature: _config.temperature,
    );
  }

  /// 生成文档
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    return provider.generateDoc(
      code,
      style: style,
      modelId: modelId ?? _config.defaultModelId,
    );
  }

  /// 对话
  Stream<AIResponse> chat(String message, {List<Map<String, String>>? history, String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    return provider.chat(
      message,
      history: history,
      modelId: modelId ?? _config.defaultModelId,
      temperature: _config.temperature,
      maxTokens: _config.maxTokens,
    );
  }

  /// 图片分析
  Stream<AIResponse> analyzeImage(List<int> imageBytes, String question, {String? modelId}) {
    final provider = currentProvider;
    if (provider == null) {
      return Stream.error(AIErrorResponse('none', 'No provider configured', AIErrorCode.serviceUnavailable));
    }

    // 检查是否支持多模态
    final model = AIModelCatalog.getModelById(modelId ?? _config.defaultModelId);
    if (model != null && !model.supportsMultimodal) {
      return Stream.error(AIErrorResponse(
        model.id,
        '当前模型不支持图片分析',
        AIErrorCode.unsupportedFeature,
      ));
    }

    return provider.analyzeImage(
      imageBytes,
      question,
      modelId: modelId ?? _config.defaultModelId,
    );
  }

  /// 获取使用统计
  Map<String, UsageStats> get usageStats {
    final allStats = <String, UsageStats>{};
    for (final provider in _providers.values) {
      allStats.addAll(provider.usageStats);
    }
    return allStats;
  }

  /// 重置使用统计
  void resetUsageStats() {
    for (final provider in _providers.values) {
      provider.resetUsageStats();
    }
  }

  /// 释放资源
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
    logger.i(LogTags.ai, 'AIService disposed');
  }
}

/// 全局AI服务实例
final aiService = AIService();
