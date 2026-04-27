import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 模型路由器 - 根据任务类型和配置自动选择最优模型
class ModelRouter {
  final Map<AIProviderType, AIProvider> _providers;
  final AIConfig _config;

  ModelRouter({
    required Map<AIProviderType, AIProvider> providers,
    required AIConfig config,
  })  : _providers = providers,
        _config = config;

  /// 选择最优模型
  Future<ModelSelection> selectOptimalModel(AITaskType taskType) async {
    // 根据任务类型获取候选模型列表
    final candidates = _getCandidatesForTask(taskType);

    for (final modelId in candidates) {
      final model = AIModelCatalog.getModelById(modelId);
      if (model == null) continue;

      final provider = _providers[model.provider];
      if (provider == null) continue;

      // 检查Provider是否可用
      if (await provider.isAvailable()) {
        return ModelSelection(
          provider: provider,
          model: model,
          reason: _getSelectionReason(taskType, model),
        );
      }
    }

    // 如果没有可用的模型，返回默认配置
    final defaultModel = AIModelCatalog.getModelById(_config.defaultModelId);
    final defaultProvider = _providers[_config.defaultProvider];

    return ModelSelection(
      provider: defaultProvider,
      model: defaultModel,
      reason: '默认配置',
      isFallback: true,
    );
  }

  /// 获取任务类型的候选模型列表
  List<String> _getCandidatesForTask(AITaskType taskType) {
    switch (taskType) {
      case AITaskType.codeCompletion:
        // 代码补全优先：免费模型 > 便宜模型 > 代码专长模型
        return [
          'gemini-1.5-flash',  // 免费额度大
          'deepseek-coder',     // 性价比高
          'qwen-coder-turbo',   // 阿里代码模型
          'gpt-3.5-turbo',      // OpenAI
          'claude-3-haiku-20240307',  // Anthropic轻量版
        ];

      case AITaskType.codeExplanation:
        return [
          'claude-3-5-sonnet-20240620',  // Claude解释能力强
          'gemini-1.5-flash',
          'qwen-plus',
          'gpt-3.5-turbo',
        ];

      case AITaskType.codeRefactor:
        return [
          'gpt-4-turbo',
          'claude-3-5-sonnet-20240620',
          'qwen-coder-plus',
          'deepseek-coder',
        ];

      case AITaskType.bugFix:
        return [
          'deepseek-coder',     // DeepSeek调试能力强
          'claude-3-5-sonnet-20240620',
          'gpt-4-turbo',
          'qwen-coder-plus',
        ];

      case AITaskType.generateDoc:
        return [
          'gemini-1.5-flash',
          'qwen-plus',
          'gpt-3.5-turbo',
          'deepseek-chat',
        ];

      case AITaskType.chat:
        return [
          'gemini-1.5-flash',
          'qwen-plus',
          'gpt-3.5-turbo',
          'doubao-pro-32k',
        ];

      case AITaskType.imageAnalysis:
        return [
          'gemini-1.5-flash',  // Gemini多模态能力强且免费
          'gemini-1.5-pro',
          'claude-3-5-sonnet-20240620',
        ];
    }
  }

  /// 获取选择原因
  String _getSelectionReason(AITaskType taskType, AIModel model) {
    final reasons = <String>[];

    if (model.isFree) {
      reasons.add('免费使用');
    } else if (model.pricePer1KInput != null && model.pricePer1KInput! < 0.005) {
      reasons.add('成本低廉');
    }

    if (model.recommendedFor.contains(_getTaskName(taskType))) {
      reasons.add('专长任务');
    }

    if (model.contextWindow >= 100000) {
      reasons.add('长上下文');
    }

    return reasons.isNotEmpty ? reasons.join(' · ') : '可用模型';
  }

  String _getTaskName(AITaskType taskType) {
    switch (taskType) {
      case AITaskType.codeCompletion:
        return '代码补全';
      case AITaskType.codeExplanation:
        return '代码解释';
      case AITaskType.codeRefactor:
        return '代码重构';
      case AITaskType.bugFix:
        return 'Bug修复';
      case AITaskType.generateDoc:
        return '文档生成';
      case AITaskType.chat:
        return '对话';
      case AITaskType.imageAnalysis:
        return '图片分析';
    }
  }
}

/// 模型选择结果
class ModelSelection {
  final AIProvider? provider;
  final AIModel? model;
  final String reason;
  final bool isFallback;

  const ModelSelection({
    required this.provider,
    required this.model,
    required this.reason,
    this.isFallback = false,
  });

  @override
  String toString() {
    return 'ModelSelection(provider: ${provider?.providerType}, model: ${model?.id}, reason: $reason, fallback: $isFallback)';
  }
}

/// 故障转移管理器
class FailoverManager {
  final ModelRouter _router;

  FailoverManager({required ModelRouter router}) : _router = router;

  /// 带自动降级的执行
  Stream<AIResponse> executeWithFailover(
    AITask task,
    List<String> fallbackModels,
  ) async* {
    for (int i = 0; i <= fallbackModels.length; i++) {
      final modelId = i == 0 ? null : fallbackModels[i - 1];
      
      try {
        final selection = await _router.selectOptimalModel(task.type);
        
        // 尝试使用选中的模型
        final provider = selection.provider;
        if (provider == null) continue;

        // 根据任务类型执行
        Stream<AIResponse> stream;
        switch (task.type) {
          case AITaskType.codeCompletion:
            stream = provider.complete(
              CodeCompletionContext(
                fileName: task.metadata?['fileName'] ?? 'unknown',
                language: task.metadata?['language'] ?? 'kotlin',
                beforeCursor: task.metadata?['beforeCursor'] ?? '',
                afterCursor: task.metadata?['afterCursor'] ?? '',
              ),
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.codeExplanation:
            stream = provider.explain(
              task.code ?? '',
              task.language ?? 'kotlin',
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.codeRefactor:
            stream = provider.refactor(
              task.code ?? '',
              task.prompt,
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.generateDoc:
            stream = provider.generateDoc(
              task.code ?? '',
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.chat:
            stream = provider.chat(
              task.prompt,
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.bugFix:
            stream = provider.chat(
              task.prompt,
              modelId: modelId ?? selection.model?.id,
            );
            break;
          case AITaskType.imageAnalysis:
            stream = provider.analyzeImage(
              task.metadata?['imageBytes'] ?? [],
              task.prompt,
              modelId: modelId ?? selection.model?.id,
            );
            break;
        }

        // 监听响应
        await for (final response in stream) {
          if (response is AIErrorResponse) {
            // 如果是错误，继续尝试下一个模型
            if (i < fallbackModels.length - 1) {
              logger.w(LogTags.ai, 'Model ${modelId ?? selection.model?.id} failed, trying fallback');
              break;
            }
          }
          yield response;
        }
        
        // 如果成功执行，退出
        return;
      } catch (e) {
        logger.e(LogTags.ai, 'Model execution error', error: e);
        if (i >= fallbackModels.length) {
          yield AIErrorResponse(
            'none',
            '所有模型均不可用',
            AIErrorCode.serviceUnavailable,
          );
        }
      }
    }
  }
}
