import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI消息
class AIMessage {
  final String role;
  final String content;
  AIMessage({required this.role, required this.content});
  
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// AI模型配置
class AIModelConfig {
  final String name;
  final String provider;
  final String apiEndpoint;
  final String modelId;
  
  AIModelConfig({
    required this.name,
    required this.provider,
    required this.apiEndpoint,
    required this.modelId,
  });
}

/// AI服务 - 支持多模型
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  String _selectedModel = 'DeepSeek';
  String _apiKey = '';
  bool _isInitialized = false;

  final Map<String, AIModelConfig> _models = {
    'DeepSeek': AIModelConfig(
      name: 'DeepSeek',
      provider: 'deepseek',
      apiEndpoint: 'https://api.deepseek.com/v1/chat/completions',
      modelId: 'deepseek-chat',
    ),
    '通义千问': AIModelConfig(
      name: '通义千问',
      provider: 'qwen',
      apiEndpoint: 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
      modelId: 'qwen-turbo',
    ),
    '豆包': AIModelConfig(
      name: '豆包',
      provider: 'doubao',
      apiEndpoint: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      modelId: 'doubao-pro-32k',
    ),
    'Minimax': AIModelConfig(
      name: 'Minimax',
      provider: 'minimax',
      apiEndpoint: 'https://api.minimax.chat/v1/chat/completions_v2',
      modelId: 'abab6.5-chat',
    ),
    '智谱清言': AIModelConfig(
      name: '智谱清言',
      provider: 'zhipu',
      apiEndpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      modelId: 'glm-4',
    ),
    'Gemini': AIModelConfig(
      name: 'Gemini',
      provider: 'google',
      apiEndpoint: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent',
      modelId: 'gemini-pro',
    ),
    'GPT-4': AIModelConfig(
      name: 'GPT-4',
      provider: 'openai',
      apiEndpoint: 'https://api.openai.com/v1/chat/completions',
      modelId: 'gpt-4-turbo-preview',
    ),
    'Claude': AIModelConfig(
      name: 'Claude',
      provider: 'anthropic',
      apiEndpoint: 'https://api.anthropic.com/v1/messages',
      modelId: 'claude-3-sonnet-20240229',
    ),
    'Ollama': AIModelConfig(
      name: 'Ollama',
      provider: 'ollama',
      apiEndpoint: 'http://localhost:11434/api/chat',
      modelId: 'llama2',
    ),
  };

  /// 初始化
  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedModel = prefs.getString('ai_selected_model') ?? 'DeepSeek';
    _apiKey = prefs.getString('ai_api_key_${_selectedModel}') ?? '';
    _isInitialized = true;
  }

  /// 获取当前选择的模型
  String get selectedModel => _selectedModel;

  /// 获取当前API Key
  String get apiKey => _apiKey;

  /// 获取所有模型名称
  List<String> get modelNames => _models.keys.toList();

  /// 切换模型
  Future<void> setModel(String modelName) async {
    if (!_models.containsKey(modelName)) return;
    _selectedModel = modelName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_selected_model', modelName);
    // 加载该模型的API Key
    _apiKey = prefs.getString('ai_api_key_$modelName') ?? '';
  }

  /// 保存API Key
  Future<bool> saveApiKey(String apiKey) async {
    try {
      _apiKey = apiKey;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_api_key_$_selectedModel', apiKey);
      debugPrint('API Key saved for $_selectedModel');
      return true;
    } catch (e) {
      debugPrint('Failed to save API Key: $e');
      return false;
    }
  }

  /// 发送消息并获取AI响应
  Future<String> chat(String userMessage, {List<AIMessage>? history}) async {
    final config = _models[_selectedModel];
    if (config == null) {
      return '错误：未知的模型配置';
    }

    if (_apiKey.isEmpty && config.provider != 'ollama') {
      return '请先在设置中配置 ${config.name} 的 API Key';
    }

    try {
      switch (config.provider) {
        case 'deepseek':
        case 'openai':
          return await _chatOpenAIStyle(config, userMessage, history);
        case 'qwen':
          return await _chatQwen(config, userMessage, history);
        case 'zhipu':
          return await _chatZhipu(config, userMessage, history);
        case 'gemini':
          return await _chatGemini(config, userMessage, history);
        case 'claude':
          return await _chatClaude(config, userMessage, history);
        case 'ollama':
          return await _chatOllama(config, userMessage, history);
        default:
          return await _chatOpenAIStyle(config, userMessage, history);
      }
    } catch (e) {
      return '请求失败: $e';
    }
  }

  /// OpenAI风格API调用 (DeepSeek, OpenAI, Minimax等)
  Future<String> _chatOpenAIStyle(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': '你是一个专业的编程助手，帮助用户解决代码问题。'},
      if (history != null) ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': config.modelId,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? '无响应内容';
    } else {
      return 'API错误 (${response.statusCode}): ${response.body}';
    }
  }

  /// 通义千问API
  Future<String> _chatQwen(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': config.modelId,
        'input': {
          'messages': [
            {'role': 'system', 'content': '你是一个专业的编程助手。'},
            {'role': 'user', 'content': userMessage},
          ],
        },
        'parameters': {},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['output']['text'] ?? data['output']['choices'][0]['message']['content'] ?? '无响应';
    } else {
      return 'API错误: ${response.body}';
    }
  }

  /// 智谱清言API
  Future<String> _chatZhipu(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final messages = [
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': config.modelId,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ?? '无响应';
    } else {
      return 'API错误: ${response.body}';
    }
  }

  /// Gemini API
  Future<String> _chatGemini(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final url = '${config.apiEndpoint}?key=$_apiKey';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': userMessage}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '无响应';
    } else {
      return 'API错误: ${response.body}';
    }
  }

  /// Claude API
  Future<String> _chatClaude(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': config.modelId,
        'max_tokens': 2048,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? '无响应';
    } else {
      return 'API错误: ${response.body}';
    }
  }

  /// Ollama本地API
  Future<String> _chatOllama(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': config.modelId,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message']['content'] ?? '无响应';
    } else {
      return 'Ollama连接失败，请确保Ollama服务正在运行';
    }
  }
}

// 全局实例
final aiService = AIService();
