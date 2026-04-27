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
      apiEndpoint: 'https://api.deepseek.com/chat/completions',
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
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedModel = prefs.getString('ai_selected_model') ?? 'DeepSeek';
      _apiKey = prefs.getString('ai_api_key_${_selectedModel}') ?? '';
    } catch (e) {
      debugPrint('AI Service init error: $e');
    }
    _isInitialized = true;
  }

  /// 获取当前选择的模型
  String get selectedModel => _selectedModel;

  /// 获取当前API Key
  String get apiKey => _apiKey;
  
  /// 检查是否已配置
  bool get isConfigured => _apiKey.isNotEmpty;

  /// 获取所有模型名称
  List<String> get modelNames => _models.keys.toList();

  /// 切换模型
  Future<void> setModel(String modelName) async {
    if (!_models.containsKey(modelName)) return;
    _selectedModel = modelName;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_selected_model', modelName);
      _apiKey = prefs.getString('ai_api_key_$modelName') ?? '';
    } catch (e) {
      debugPrint('Set model error: $e');
    }
  }

  /// 保存API Key
  Future<bool> saveApiKey(String apiKey) async {
    try {
      _apiKey = apiKey.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_api_key_$_selectedModel', apiKey.trim());
      debugPrint('API Key saved for $_selectedModel: ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');
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
      return '请先在设置中配置 ${config.name} 的 API Key。\n\n获取地址：${_getKeyUrl(config.name)}';
    }

    try {
      debugPrint('Sending request to ${config.name}...');
      String response;
      
      switch (config.provider) {
        case 'deepseek':
          response = await _chatDeepSeek(config, userMessage, history);
          break;
        case 'qwen':
          response = await _chatQwen(config, userMessage, history);
          break;
        case 'zhipu':
          response = await _chatZhipu(config, userMessage, history);
          break;
        case 'gemini':
          response = await _chatGemini(config, userMessage, history);
          break;
        case 'claude':
          response = await _chatClaude(config, userMessage, history);
          break;
        case 'ollama':
          response = await _chatOllama(config, userMessage, history);
          break;
        case 'openai':
          response = await _chatOpenAI(config, userMessage, history);
          break;
        default:
          response = await _chatDeepSeek(config, userMessage, history);
      }
      
      debugPrint('Response received: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');
      return response;
    } catch (e) {
      debugPrint('Chat error: $e');
      return '请求失败: $e\n\n请检查API Key是否正确';
    }
  }

  String _getKeyUrl(String modelName) {
    const urls = {
      'DeepSeek': 'platform.deepseek.com',
      '通义千问': 'dashscope.aliyuncs.com',
      '豆包': 'console.volcengine.com/ark',
      'Minimax': 'api.minimax.chat',
      '智谱清言': 'open.bigmodel.cn',
      'Gemini': 'makersuite.google.com',
      'GPT-4': 'platform.openai.com',
      'Claude': 'console.anthropic.com',
    };
    return urls[modelName] ?? '';
  }

  /// DeepSeek API
  Future<String> _chatDeepSeek(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': '你是一个专业的编程助手，帮助用户解决代码问题。请用中文回答。'},
      if (history != null) ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      })),
    );

    debugPrint('DeepSeek response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['choices'][0]['message']['content'] ?? '无响应内容';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
    }
  }

  /// OpenAI API
  Future<String> _chatOpenAI(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': '你是一个专业的编程助手。'},
      if (history != null) ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['choices'][0]['message']['content'] ?? '无响应内容';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
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
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'input': {
          'messages': [
            {'role': 'system', 'content': '你是一个专业的编程助手。'},
            {'role': 'user', 'content': userMessage},
          ],
        },
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      // 通义千问返回格式可能是 output.text 或 output.choices
      if (data['output'] != null) {
        return data['output']['text'] ?? 
               data['output']['choices']?[0]?['message']?['content'] ?? 
               '无响应';
      }
      return '响应格式错误: $body';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
    }
  }

  /// 智谱清言API
  Future<String> _chatZhipu(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async {
    final response = await http.post(
      Uri.parse(config.apiEndpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['choices'][0]['message']['content'] ?? '无响应';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
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
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': userMessage}
            ]
          }
        ]
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '无响应';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
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
        'Content-Type': 'application/json; charset=utf-8',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'max_tokens': 2048,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['content'][0]['text'] ?? '无响应';
    } else {
      final body = utf8.decode(response.bodyBytes);
      return 'API错误 (${response.statusCode}): $body';
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
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(jsonEncode({
        'model': config.modelId,
        'messages': [
          {'role': 'user', 'content': userMessage}
        ],
        'stream': false,
      })),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);
      return data['message']['content'] ?? '无响应';
    } else {
      return 'Ollama连接失败，请确保Ollama服务正在运行 (localhost:11434)';
    }
  }
}

// 全局实例
final aiService = AIService();
