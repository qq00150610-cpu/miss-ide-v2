import '../utils/constants.dart';

/// AI Provider类型枚举
enum AIProviderType {
  // 🇨🇳 国内模型
  qwen('通义千问', 'Qwen', '🇨🇳'),
  deepseek('DeepSeek', 'DeepSeek', '🇨🇳'),
  doubao('豆包', 'Doubao', '🇨🇳'),
  minimax('Minimax', 'Minimax', '🇨🇳'),
  zhipu('智谱清言', 'Zhipu', '🇨🇳'),
  
  // 🌍 国际模型
  openai('OpenAI', 'OpenAI', '🌍'),
  anthropic('Claude', 'Anthropic', '🌍'),
  gemini('Gemini', 'Google', '🌍'),
  ollama('Ollama', 'Ollama', '💻');

  final String displayNameCN;
  final String displayName;
  final String flag;

  const AIProviderType(this.displayNameCN, this.displayName, this.flag);

  String get fullDisplayName => '$flag $displayNameCN';

  bool get isChina => this == qwen || 
                      this == deepseek || 
                      this == doubao || 
                      this == minimax || 
                      this == zhipu;

  bool get isInternational => this == openai || 
                               this == anthropic || 
                               this == gemini;

  bool get isLocal => this == ollama;
}

/// AI模型信息
class AIModel {
  final String id;
  final String name;
  final AIProviderType provider;
  final int maxTokens;
  final bool supportsStreaming;
  final int contextWindow;
  final bool supportsMultimodal;
  final double? pricePer1KInput;
  final double? pricePer1KOutput;
  final List<String> recommendedFor;
  final bool isFree; // 是否有免费额度

  const AIModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.maxTokens,
    required this.supportsStreaming,
    required this.contextWindow,
    this.supportsMultimodal = false,
    this.pricePer1KInput,
    this.pricePer1KOutput,
    this.recommendedFor = const [],
    this.isFree = false,
  });

  String get displayName => name;

  String get contextWindowDisplay {
    if (contextWindow >= 1000000) {
      return '${(contextWindow / 1000000).toStringAsFixed(0)}M';
    } else if (contextWindow >= 1000) {
      return '${(contextWindow / 1000).toStringAsFixed(0)}K';
    }
    return contextWindow.toString();
  }

  String? get priceDisplay {
    if (isFree) return '免费额度';
    if (pricePer1KInput == null || pricePer1KOutput == null) return null;
    return '¥${pricePer1KInput}/1K';
  }

  AIModel copyWith({
    String? id,
    String? name,
    AIProviderType? provider,
    int? maxTokens,
    bool? supportsStreaming,
    int? contextWindow,
    bool? supportsMultimodal,
    double? pricePer1KInput,
    double? pricePer1KOutput,
    List<String>? recommendedFor,
    bool? isFree,
  }) {
    return AIModel(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      maxTokens: maxTokens ?? this.maxTokens,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      contextWindow: contextWindow ?? this.contextWindow,
      supportsMultimodal: supportsMultimodal ?? this.supportsMultimodal,
      pricePer1KInput: pricePer1KInput ?? this.pricePer1KInput,
      pricePer1KOutput: pricePer1KOutput ?? this.pricePer1KOutput,
      recommendedFor: recommendedFor ?? this.recommendedFor,
      isFree: isFree ?? this.isFree,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider.name,
      'maxTokens': maxTokens,
      'supportsStreaming': supportsStreaming,
      'contextWindow': contextWindow,
      'supportsMultimodal': supportsMultimodal,
      'pricePer1KInput': pricePer1KInput,
      'pricePer1KOutput': pricePer1KOutput,
      'recommendedFor': recommendedFor,
      'isFree': isFree,
    };
  }

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: AIProviderType.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AIProviderType.openai,
      ),
      maxTokens: json['maxTokens'] as int,
      supportsStreaming: json['supportsStreaming'] as bool,
      contextWindow: json['contextWindow'] as int,
      supportsMultimodal: json['supportsMultimodal'] as bool? ?? false,
      pricePer1KInput: (json['pricePer1KInput'] as num?)?.toDouble(),
      pricePer1KOutput: (json['pricePer1KOutput'] as num?)?.toDouble(),
      recommendedFor: List<String>.from(json['recommendedFor'] ?? []),
      isFree: json['isFree'] as bool? ?? false,
    );
  }
}

/// AI配置
class AIConfig {
  final bool enabled;
  final AIProviderType defaultProvider;
  final String defaultModelId;
  final bool enableLocalFirst;
  final bool enableAutoFallback;
  final double temperature;
  final int maxTokens;
  final double monthlyBudgetLimit;

  const AIConfig({
    this.enabled = true,
    this.defaultProvider = AIProviderType.gemini,
    this.defaultModelId = 'gemini-1.5-flash',
    this.enableLocalFirst = true,
    this.enableAutoFallback = true,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.monthlyBudgetLimit = 100.0,
  });

  AIConfig copyWith({
    bool? enabled,
    AIProviderType? defaultProvider,
    String? defaultModelId,
    bool? enableLocalFirst,
    bool? enableAutoFallback,
    double? temperature,
    int? maxTokens,
    double? monthlyBudgetLimit,
  }) {
    return AIConfig(
      enabled: enabled ?? this.enabled,
      defaultProvider: defaultProvider ?? this.defaultProvider,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      enableLocalFirst: enableLocalFirst ?? this.enableLocalFirst,
      enableAutoFallback: enableAutoFallback ?? this.enableAutoFallback,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      monthlyBudgetLimit: monthlyBudgetLimit ?? this.monthlyBudgetLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'defaultProvider': defaultProvider.name,
      'defaultModelId': defaultModelId,
      'enableLocalFirst': enableLocalFirst,
      'enableAutoFallback': enableAutoFallback,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'monthlyBudgetLimit': monthlyBudgetLimit,
    };
  }

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      enabled: json['enabled'] as bool? ?? true,
      defaultProvider: AIProviderType.values.firstWhere(
        (e) => e.name == json['defaultProvider'],
        orElse: () => AIProviderType.gemini,
      ),
      defaultModelId: json['defaultModelId'] as String? ?? 'gemini-1.5-flash',
      enableLocalFirst: json['enableLocalFirst'] as bool? ?? true,
      enableAutoFallback: json['enableAutoFallback'] as bool? ?? true,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 2048,
      monthlyBudgetLimit: (json['monthlyBudgetLimit'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

/// Provider配置
class ProviderConfig {
  final String? apiKey;
  final String? apiSecret;
  final String? baseUrl;
  final bool enabled;
  final String? defaultModel;

  const ProviderConfig({
    this.apiKey,
    this.apiSecret,
    this.baseUrl,
    this.enabled = true,
    this.defaultModel,
  });

  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  ProviderConfig copyWith({
    String? apiKey,
    String? apiSecret,
    String? baseUrl,
    bool? enabled,
    String? defaultModel,
  }) {
    return ProviderConfig(
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      defaultModel: defaultModel ?? this.defaultModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'baseUrl': baseUrl,
      'enabled': enabled,
      'defaultModel': defaultModel,
    };
  }

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      apiKey: json['apiKey'] as String?,
      apiSecret: json['apiSecret'] as String?,
      baseUrl: json['baseUrl'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      defaultModel: json['defaultModel'] as String?,
    );
  }
}

/// 使用统计
class UsageStats {
  final String modelId;
  final int inputTokens;
  final int outputTokens;
  final double cost;
  final DateTime lastUsed;

  const UsageStats({
    required this.modelId,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cost = 0.0,
    required this.lastUsed,
  });

  int get totalTokens => inputTokens + outputTokens;

  UsageStats add(int input, int output, double addCost) {
    return UsageStats(
      modelId: modelId,
      inputTokens: inputTokens + input,
      outputTokens: outputTokens + output,
      cost: cost + addCost,
      lastUsed: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelId': modelId,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'cost': cost,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      modelId: json['modelId'] as String,
      inputTokens: json['inputTokens'] as int? ?? 0,
      outputTokens: json['outputTokens'] as int? ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );
  }
}

/// 预定义的模型列表
class AIModelCatalog {
  AIModelCatalog._();

  // 🇨🇳 国内模型
  static final List<AIModel> chineseModels = [
    // 通义千问
    const AIModel(
      id: 'qwen-coder-plus',
      name: '通义Coder Plus',
      provider: AIProviderType.qwen,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      pricePer1KInput: 0.04,
      pricePer1KOutput: 0.04,
      recommendedFor: ['代码补全', '代码重构', '代码解释'],
    ),
    const AIModel(
      id: 'qwen-plus',
      name: '通义千问Plus',
      provider: AIProviderType.qwen,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      pricePer1KInput: 0.04,
      pricePer1KOutput: 0.04,
      recommendedFor: ['代码解释', '对话', '文档生成'],
    ),
    const AIModel(
      id: 'qwen-coder-turbo',
      name: '通义Coder Turbo',
      provider: AIProviderType.qwen,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 8000,
      pricePer1KInput: 0.008,
      pricePer1KOutput: 0.008,
      recommendedFor: ['快速补全'],
    ),
    const AIModel(
      id: 'qwen-turbo',
      name: '通义千问Turbo',
      provider: AIProviderType.qwen,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 8000,
      pricePer1KInput: 0.008,
      pricePer1KOutput: 0.008,
      recommendedFor: ['快速响应', '简单任务'],
    ),

    // DeepSeek
    const AIModel(
      id: 'deepseek-coder',
      name: 'DeepSeek Coder',
      provider: AIProviderType.deepseek,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 16000,
      pricePer1KInput: 0.0014,
      pricePer1KOutput: 0.002,
      recommendedFor: ['代码补全', '代码重构', 'Bug修复'],
    ),
    const AIModel(
      id: 'deepseek-chat',
      name: 'DeepSeek Chat',
      provider: AIProviderType.deepseek,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 32000,
      pricePer1KInput: 0.0014,
      pricePer1KOutput: 0.002,
      recommendedFor: ['代码解释', '对话', '技术问题'],
    ),

    // 豆包
    const AIModel(
      id: 'doubao-pro-32k',
      name: '豆包Pro 32K',
      provider: AIProviderType.doubao,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 32000,
      pricePer1KInput: 0.003,
      pricePer1KOutput: 0.003,
      recommendedFor: ['代码解释', '对话', '代码生成'],
    ),
    const AIModel(
      id: 'doubao-pro-4k',
      name: '豆包Pro 4K',
      provider: AIProviderType.doubao,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 4000,
      pricePer1KInput: 0.001,
      pricePer1KOutput: 0.001,
      recommendedFor: ['快速补全', '简单问答'],
    ),
    const AIModel(
      id: 'doubao-lite-32k',
      name: '豆包Lite 32K',
      provider: AIProviderType.doubao,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 32000,
      pricePer1KInput: 0.001,
      pricePer1KOutput: 0.001,
      recommendedFor: ['轻量任务', '成本优化'],
    ),

    // Minimax
    const AIModel(
      id: 'abab6.5-chat',
      name: 'ABAB 6.5',
      provider: AIProviderType.minimax,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 245000,
      pricePer1KInput: 0.01,
      pricePer1KOutput: 0.01,
      recommendedFor: ['长代码分析', '多文件理解'],
    ),
    const AIModel(
      id: 'abab6.5s-chat',
      name: 'ABAB 6.5S',
      provider: AIProviderType.minimax,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 24000,
      pricePer1KInput: 0.005,
      pricePer1KOutput: 0.005,
      recommendedFor: ['快速补全', '实时响应'],
    ),

    // 智谱清言
    const AIModel(
      id: 'glm-4-plus',
      name: 'GLM-4 Plus',
      provider: AIProviderType.zhipu,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      pricePer1KInput: 0.1,
      pricePer1KOutput: 0.1,
      recommendedFor: ['复杂代码分析', '架构设计'],
    ),
    const AIModel(
      id: 'glm-4',
      name: 'GLM-4',
      provider: AIProviderType.zhipu,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      pricePer1KInput: 0.1,
      pricePer1KOutput: 0.1,
      recommendedFor: ['代码补全', '代码解释'],
    ),
    const AIModel(
      id: 'glm-4-flash',
      name: 'GLM-4 Flash',
      provider: AIProviderType.zhipu,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      pricePer1KInput: 0.001,
      pricePer1KOutput: 0.001,
      recommendedFor: ['快速响应', '成本优化'],
    ),
  ];

  // 🌍 国际模型
  static final List<AIModel> internationalModels = [
    // OpenAI
    const AIModel(
      id: 'gpt-4-turbo',
      name: 'GPT-4 Turbo',
      provider: AIProviderType.openai,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 128000,
      supportsMultimodal: true,
      pricePer1KInput: 0.01,
      pricePer1KOutput: 0.03,
      recommendedFor: ['代码补全', '代码解释', '重构'],
    ),
    const AIModel(
      id: 'gpt-4',
      name: 'GPT-4',
      provider: AIProviderType.openai,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 8192,
      supportsMultimodal: true,
      pricePer1KInput: 0.03,
      pricePer1KOutput: 0.06,
      recommendedFor: ['复杂重构', '架构建议'],
    ),
    const AIModel(
      id: 'gpt-3.5-turbo',
      name: 'GPT-3.5 Turbo',
      provider: AIProviderType.openai,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 16385,
      pricePer1KInput: 0.0005,
      pricePer1KOutput: 0.0015,
      recommendedFor: ['快速补全', '简单解释'],
    ),

    // Claude
    const AIModel(
      id: 'claude-3-5-sonnet-20240620',
      name: 'Claude 3.5 Sonnet',
      provider: AIProviderType.anthropic,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 200000,
      supportsMultimodal: true,
      pricePer1KInput: 0.003,
      pricePer1KOutput: 0.015,
      recommendedFor: ['代码补全', '代码解释', '重构'],
    ),
    const AIModel(
      id: 'claude-3-opus-20240229',
      name: 'Claude 3 Opus',
      provider: AIProviderType.anthropic,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 200000,
      supportsMultimodal: true,
      pricePer1KInput: 0.015,
      pricePer1KOutput: 0.075,
      recommendedFor: ['复杂分析', '架构设计'],
    ),
    const AIModel(
      id: 'claude-3-haiku-20240307',
      name: 'Claude 3 Haiku',
      provider: AIProviderType.anthropic,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 200000,
      supportsMultimodal: true,
      pricePer1KInput: 0.00025,
      pricePer1KOutput: 0.00125,
      recommendedFor: ['快速响应', '成本优化'],
    ),

    // Gemini
    const AIModel(
      id: 'gemini-1.5-pro',
      name: 'Gemini 1.5 Pro',
      provider: AIProviderType.gemini,
      maxTokens: 8192,
      supportsStreaming: true,
      contextWindow: 1000000,
      supportsMultimodal: true,
      pricePer1KInput: 0.00125,
      pricePer1KOutput: 0.005,
      recommendedFor: ['长代码分析', '多模态', '代码解释', '架构设计'],
    ),
    const AIModel(
      id: 'gemini-1.5-flash',
      name: 'Gemini 1.5 Flash',
      provider: AIProviderType.gemini,
      maxTokens: 8192,
      supportsStreaming: true,
      contextWindow: 1000000,
      supportsMultimodal: true,
      pricePer1KInput: 0.000075,
      pricePer1KOutput: 0.0003,
      recommendedFor: ['快速补全', '日常对话', '成本优化'],
      isFree: true,
    ),
    const AIModel(
      id: 'gemini-1.0-pro',
      name: 'Gemini 1.0 Pro',
      provider: AIProviderType.gemini,
      maxTokens: 4096,
      supportsStreaming: true,
      contextWindow: 32000,
      supportsMultimodal: true,
      pricePer1KInput: 0.0005,
      pricePer1KOutput: 0.0015,
      recommendedFor: ['基础代码任务'],
    ),
  ];

  // 💻 本地模型
  static final List<AIModel> localModels = [
    const AIModel(
      id: 'codellama:7b',
      name: 'CodeLlama 7B',
      provider: AIProviderType.ollama,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 8000,
      recommendedFor: ['代码补全', '离线开发'],
      isFree: true,
    ),
    const AIModel(
      id: 'qwen2.5-coder:7b',
      name: 'Qwen2.5 Coder 7B',
      provider: AIProviderType.ollama,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 8000,
      recommendedFor: ['代码补全', '离线开发'],
      isFree: true,
    ),
    const AIModel(
      id: 'deepseek-coder:6.7b',
      name: 'DeepSeek Coder 6.7B',
      provider: AIProviderType.ollama,
      maxTokens: 2048,
      supportsStreaming: true,
      contextWindow: 8000,
      recommendedFor: ['代码补全', '离线开发'],
      isFree: true,
    ),
  ];

  /// 获取所有模型
  static List<AIModel> get allModels => [
    ...chineseModels,
    ...internationalModels,
    ...localModels,
  ];

  /// 根据Provider获取模型
  static List<AIModel> getModelsForProvider(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.qwen:
        return chineseModels.where((m) => m.provider == AIProviderType.qwen).toList();
      case AIProviderType.deepseek:
        return chineseModels.where((m) => m.provider == AIProviderType.deepseek).toList();
      case AIProviderType.doubao:
        return chineseModels.where((m) => m.provider == AIProviderType.doubao).toList();
      case AIProviderType.minimax:
        return chineseModels.where((m) => m.provider == AIProviderType.minimax).toList();
      case AIProviderType.zhipu:
        return chineseModels.where((m) => m.provider == AIProviderType.zhipu).toList();
      case AIProviderType.openai:
        return internationalModels.where((m) => m.provider == AIProviderType.openai).toList();
      case AIProviderType.anthropic:
        return internationalModels.where((m) => m.provider == AIProviderType.anthropic).toList();
      case AIProviderType.gemini:
        return internationalModels.where((m) => m.provider == AIProviderType.gemini).toList();
      case AIProviderType.ollama:
        return localModels;
    }
  }

  /// 根据ID获取模型
  static AIModel? getModelById(String id) {
    try {
      return allModels.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取推荐用于代码补全的模型
  static List<AIModel> get codeCompletionModels => allModels
      .where((m) => m.recommendedFor.contains('代码补全'))
      .toList()
    ..sort((a, b) {
      // 免费模型优先
      if (a.isFree && !b.isFree) return -1;
      if (!a.isFree && b.isFree) return 1;
      // 然后按价格
      if (a.pricePer1KInput != null && b.pricePer1KInput != null) {
        return a.pricePer1KInput!.compareTo(b.pricePer1KInput!);
      }
      return 0;
    });

  /// 获取支持多模态的模型
  static List<AIModel> get multimodalModels => allModels
      .where((m) => m.supportsMultimodal)
      .toList();
}
