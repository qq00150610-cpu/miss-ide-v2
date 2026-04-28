import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

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

/// 项目结构模板
class ProjectTemplate {
  final String name;
  final String description;
  final Map<String, String> files; // path -> content
  
  ProjectTemplate({
    required this.name,
    required this.description,
    required this.files,
  });
}

/// AI意图识别结果
class AIIntent {
  final AIIntentType type;
  final Map<String, dynamic> params;
  
  AIIntent({required this.type, required this.params});
}

enum AIIntentType {
  createProject,
  generateCode,
  explainCode,
  chat,
  unknown,
}

/// AI服务 - 支持多模型
/// 已修复：API Key 存储和验证功能
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  String _selectedModel = 'DeepSeek';
  String _apiKey = '';
  bool _isInitialized = false;
  bool _isValidating = false;
  bool? _isApiKeyValid;
  
  // AI回调函数
  Function(String)? onProjectCreated;
  Function(String, String)? onCodeGenerated;
  Function(bool)? onApiKeyValidated;

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

  /// 项目模板库
  final Map<String, ProjectTemplate> _projectTemplates = {
    'flutter': ProjectTemplate(
      name: 'Flutter App',
      description: '创建一个基本的Flutter应用',
      files: {
        'lib/main.dart': '''import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const Center(child: Text('Hello Flutter!')),
      ),
    );
  }
}
''',
        'pubspec.yaml': '''name: my_app
description: A new Flutter project.
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''',
      },
    ),
    'python': ProjectTemplate(
      name: 'Python Project',
      description: '创建一个Python项目',
      files: {
        'main.py': '''#!/usr/bin/env python3
"""
Main application file
"""

def main():
    print("Hello, Python!")

if __name__ == '__main__':
    main()
''',
        'requirements.txt': '',
        'README.md': '# Python Project\n',
      },
    ),
    'nodejs': ProjectTemplate(
      name: 'Node.js Project',
      description: '创建一个Node.js项目',
      files: {
        'index.js': '''/**
 * Main application file
 */

function main() {
  console.log("Hello, Node.js!");
}

main();
''',
        'package.json': '''{
  "name": "my-app",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}
''',
      },
    ),
  };

  /// 初始化
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedModel = prefs.getString('ai_selected_model') ?? 'DeepSeek';
      // 修复：确保正确加载当前模型的 API Key
      _apiKey = prefs.getString('ai_api_key_$_selectedModel') ?? '';
      debugPrint('AI Service initialized. Model: $_selectedModel, has API Key: ${_apiKey.isNotEmpty}');
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
  
  /// API Key 是否正在验证
  bool get isValidating => _isValidating;
  
  /// API Key 是否有效
  bool? get isApiKeyValid => _isApiKeyValid;

  /// 获取所有模型名称
  List<String> get modelNames => _models.keys.toList();
  
  /// 获取模型配置
  AIModelConfig? getModelConfig(String modelName) => _models[modelName];

  /// 获取所有项目模板名称
  List<String> get templateNames => _projectTemplates.keys.toList();

  /// 切换模型
  Future<void> setModel(String modelName) async {
    if (!_models.containsKey(modelName)) return;
    
    final previousModel = _selectedModel;
    _selectedModel = modelName;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_selected_model', modelName);
      // 修复：加载新模型的 API Key
      _apiKey = prefs.getString('ai_api_key_$modelName') ?? '';
      // 重置验证状态
      _isApiKeyValid = null;
      debugPrint('Switched to model: $modelName, has API Key: ${_apiKey.isNotEmpty}');
    } catch (e) {
      debugPrint('Set model error: $e');
      _selectedModel = previousModel;
    }
  }

  /// 保存API Key
  Future<bool> saveApiKey(String apiKey) async {
    try {
      _apiKey = apiKey.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_api_key_$_selectedModel', apiKey.trim());
      debugPrint('API Key saved for $_selectedModel');
      
      // 验证 API Key
      validateApiKey();
      
      return true;
    } catch (e) {
      debugPrint('Failed to save API Key: $e');
      return false;
    }
  }

  /// 验证 API Key 是否有效
  Future<bool> validateApiKey() async {
    if (_apiKey.isEmpty) {
      _isApiKeyValid = false;
      onApiKeyValidated?.call(false);
      return false;
    }
    
    if (_isValidating) return _isApiKeyValid ?? false;
    
    _isValidating = true;
    _isApiKeyValid = null;
    
    try {
      final config = _models[_selectedModel];
      if (config == null || config.provider == 'ollama') {
        _isValidating = false;
        _isApiKeyValid = true; // Ollama 不需要 API Key
        onApiKeyValidated?.call(true);
        return true;
      }
      
      bool isValid = false;
      
      switch (config.provider) {
        case 'deepseek':
        case 'openai':
          isValid = await _validateOpenAICompatibleApi(config);
          break;
        case 'qwen':
          isValid = await _validateQwenApi(config);
          break;
        case 'zhipu':
          isValid = await _validateZhipuApi(config);
          break;
        case 'google':
          isValid = await _validateGeminiApi(config);
          break;
        case 'anthropic':
          isValid = await _validateClaudeApi(config);
          break;
        default:
          isValid = true;
      }
      
      _isApiKeyValid = isValid;
      onApiKeyValidated?.call(isValid);
      debugPrint('API Key validation result for $_selectedModel: $isValid');
      
    } catch (e) {
      debugPrint('API Key validation error: $e');
      _isApiKeyValid = false;
      onApiKeyValidated?.call(false);
    } finally {
      _isValidating = false;
    }
    
    return _isApiKeyValid ?? false;
  }
  
  /// 验证 OpenAI 兼容 API
  Future<bool> _validateOpenAICompatibleApi(AIModelConfig config) async {
    try {
      final response = await http.post(
        Uri.parse(config.apiEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: utf8.encode(jsonEncode({
          'model': config.modelId,
          'messages': [{'role': 'user', 'content': 'hi'}],
          'max_tokens': 5,
        })),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      // 网络错误时，不标记为无效，而是保持未验证状态
      debugPrint('Network error during validation: $e');
      return false;
    }
  }
  
  /// 验证通义千问 API
  Future<bool> _validateQwenApi(AIModelConfig config) async {
    try {
      final response = await http.post(
        Uri.parse(config.apiEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: utf8.encode(jsonEncode({
          'model': config.modelId,
          'input': {'messages': [{'role': 'user', 'content': 'hi'}]},
        })),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// 验证智谱 API
  Future<bool> _validateZhipuApi(AIModelConfig config) async {
    return _validateOpenAICompatibleApi(config);
  }
  
  /// 验证 Gemini API
  Future<bool> _validateGeminiApi(AIModelConfig config) async {
    try {
      final url = '${config.apiEndpoint}?key=$_apiKey';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: utf8.encode(jsonEncode({
          'contents': [{'parts': [{'text': 'hi'}]}]
        })),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// 验证 Claude API
  Future<bool> _validateClaudeApi(AIModelConfig config) async {
    try {
      final response = await http.post(
        Uri.parse(config.apiEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: utf8.encode(jsonEncode({
          'model': config.modelId,
          'max_tokens': 10,
          'messages': [{'role': 'user', 'content': 'hi'}],
        })),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 识别用户意图
  AIIntent recognizeIntent(String message) {
    final lowerMessage = message.toLowerCase();
    
    // 创建项目意图
    if (lowerMessage.contains('创建') && 
        (lowerMessage.contains('项目') || lowerMessage.contains('工程'))) {
      String template = 'flutter';
      if (lowerMessage.contains('python')) template = 'python';
      if (lowerMessage.contains('node') || lowerMessage.contains('nodejs')) template = 'nodejs';
      
      // 尝试提取项目名称
      String projectName = 'my_project';
      final nameMatch = RegExp(r'(?:叫|名称|名字为?|名为)([^，,。\s]+)').firstMatch(message);
      if (nameMatch != null) {
        projectName = nameMatch.group(1) ?? 'my_project';
      }
      
      return AIIntent(
        type: AIIntentType.createProject,
        params: {'template': template, 'name': projectName},
      );
    }
    
    // 生成代码意图
    if (lowerMessage.contains('生成') && 
        (lowerMessage.contains('代码') || lowerMessage.contains('写'))) {
      String language = 'dart';
      if (lowerMessage.contains('python') || lowerMessage.contains('.py')) language = 'python';
      if (lowerMessage.contains('java')) language = 'java';
      if (lowerMessage.contains('javascript') || lowerMessage.contains('.js')) language = 'javascript';
      if (lowerMessage.contains('go') || lowerMessage.contains('.go')) language = 'go';
      
      return AIIntent(
        type: AIIntentType.generateCode,
        params: {'language': language, 'description': message},
      );
    }
    
    // 解释代码意图
    if (lowerMessage.contains('解释') || 
        lowerMessage.contains('说明') ||
        lowerMessage.contains('看懂')) {
      if (lowerMessage.contains('代码')) {
        return AIIntent(
          type: AIIntentType.explainCode,
          params: {},
        );
      }
    }
    
    return AIIntent(type: AIIntentType.chat, params: {});
  }

  /// 创建项目
  Future<String> createProject(String projectPath, String templateName) async {
    final template = _projectTemplates[templateName];
    if (template == null) {
      return '未找到模板: $templateName';
    }
    
    try {
      // 创建项目目录
      final dir = Directory(projectPath);
      if (await dir.exists()) {
        return '目录已存在: $projectPath';
      }
      
      await dir.create(recursive: true);
      
      // 创建所有文件
      for (final entry in template.files.entries) {
        final filePath = p.join(projectPath, entry.key);
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
      }
      
      // 回调通知
      onProjectCreated?.call(projectPath);
      
      return '项目已创建: $projectPath\n\n模板: ${template.name}\n文件数: ${template.files.length}';
    } catch (e) {
      return '创建失败: $e';
    }
  }

  /// 使用AI生成项目
  Future<String> generateProjectWithAI(String projectPath, String description) async {
    if (!isConfigured) {
      return '请先配置AI API Key';
    }
    
    try {
      // 向AI询问项目结构
      final prompt = '''请为以下项目生成代码结构：
      
描述: $description

请生成一个完整的项目结构，包括所有必要的文件。
回复格式要求：
1. 首先说明项目类型和建议的文件结构
2. 然后列出每个文件的完整内容
3. 使用以下标记格式：

【文件: 文件路径】
文件内容...
【文件结束】

请确保代码可以直接使用。''';
      
      final response = await chat(prompt);
      
      // 解析AI响应并创建文件
      final filePattern = RegExp(r'【文件:\s*(.+?)】(.*?)【文件结束】', dotAll: true);
      final matches = filePattern.allMatches(response);
      
      if (matches.isEmpty) {
        // 没有找到文件格式，返回原始响应
        return response;
      }
      
      // 创建项目目录
      final dir = Directory(projectPath);
      await dir.create(recursive: true);
      
      // 创建每个文件
      for (final match in matches) {
        final filePath = match.group(1)?.trim() ?? '';
        final content = match.group(2)?.trim() ?? '';
        
        if (filePath.isNotEmpty && content.isNotEmpty) {
          final fullPath = p.join(projectPath, filePath);
          final file = File(fullPath);
          await file.parent.create(recursive: true);
          await file.writeAsString(content);
        }
      }
      
      // 回调通知
      onProjectCreated?.call(projectPath);
      
      return '项目已创建: $projectPath\n\n共生成 ${matches.length} 个文件';
    } catch (e) {
      return '生成失败: $e';
    }
  }

  /// 使用AI生成代码
  Future<String> generateCode(String language, String description) async {
    if (!isConfigured) {
      return '请先配置AI API Key';
    }
    
    try {
      final prompt = '''请生成一段 $language 代码：

需求: $description

请生成完整可用的代码，并简要说明使用方法。''';
      
      final response = await chat(prompt);
      
      // 如果AI生成了代码，触发回调
      if (response.contains('```')) {
        onCodeGenerated?.call(language, response);
      }
      
      return response;
    } catch (e) {
      return '生成失败: $e';
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
      
      debugPrint('Response received');
      return response;
    } catch (e) {
      debugPrint('Chat error: $e');
      final errorStr = e.toString().toLowerCase();
      
      // 区分不同类型的错误，提供更准确的提示
      if (errorStr.contains('socketexception') || 
          errorStr.contains('failed host lookup') ||
          errorStr.contains('no address associated with hostname') ||
          errorStr.contains('dns') ||
          errorStr.contains('lookup failed')) {
        return '⚠️ 网络DNS解析失败\n\n'
            '无法连接到 ${config.name} 的服务器\n\n'
            '可能原因:\n'
            '1. 网络DNS服务器无法解析域名\n'
            '2. 当前网络存在限制或阻断\n'
            '3. 如果使用VPN/代理，请检查设置\n\n'
            '💡 建议:\n'
            '• 切换到手机数据或其他WiFi网络\n'
            '• 尝试使用其他模型（DeepSeek、Qwen、Kimi等）\n'
            '• 联系网络管理员解除限制\n\n'
            '错误详情: $e';
      } else if (errorStr.contains('timed out') || errorStr.contains('timeout')) {
        return '⏱️ 请求超时\n\n'
            '服务器响应时间过长\n\n'
            '可能原因:\n'
            '1. 网络连接不稳定\n'
            '2. 服务器负载过高\n'
            '3. 网络环境较差\n\n'
            '💡 建议:\n'
            '• 检查网络连接后重试\n'
            '• 稍后再试\n'
            '• 尝试使用其他模型';
      } else if (errorStr.contains('connection refused') || 
                 errorStr.contains('connection failed') ||
                 errorStr.contains('connection error')) {
        return '🔌 连接失败\n\n'
            '无法连接到服务器\n\n'
            '可能原因:\n'
            '1. 网络环境受限\n'
            '2. 服务器暂时不可用\n'
            '3. 防火墙或代理阻止了请求\n\n'
            '💡 建议:\n'
            '• 检查网络设置\n'
            '• 尝试使用其他模型（DeepSeek、Qwen等）';
      } else if (errorStr.contains('401') || 
                 errorStr.contains('unauthorized') ||
                 errorStr.contains('invalid api key')) {
        return '🔑 API Key 认证失败\n\n'
            '请检查 API Key 是否正确配置\n\n'
            '可能原因:\n'
            '1. API Key 填写错误\n'
            '2. API Key 已过期或被禁用\n'
            '3. 账户余额不足\n\n'
            '💡 建议:\n'
            '• 前往设置重新配置 API Key\n'
            '• 确认 Key 没有多余空格\n'
            '• 检查服务商账户状态\n\n'
            '获取地址: ${_getKeyUrl(config.name)}';
      } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
        return '🚫 访问被拒绝\n\n'
            '服务器拒绝了这个请求\n\n'
            '可能原因:\n'
            '1. 账户权限不足\n'
            '2. 服务区域限制\n'
            '3. API Key 没有该接口权限\n\n'
            '💡 建议:\n'
            '• 检查账户权限和余额\n'
            '• 尝试使用其他模型';
      } else {
        return '❌ 请求失败\n\n'
            '发生了未知错误\n\n'
            '错误信息: $e\n\n'
            '💡 建议:\n'
            '• 检查网络连接\n'
            '• 尝试使用其他模型（DeepSeek、Qwen、Kimi）\n'
            '• 查看 API Key 设置是否正确';
      }
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
        'max_tokens': 4096,
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
        'max_tokens': 4096,
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
        'max_tokens': 4096,
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

  /// 流式聊天 - 逐字返回响应
  Stream<String> chatStream(String userMessage, {List<AIMessage>? history}) async* {
    final config = _models[_selectedModel];
    if (config == null) {
      yield '错误：未知的模型配置';
      return;
    }

    if (_apiKey.isEmpty && config.provider != 'ollama') {
      yield '请先配置 API Key';
      return;
    }

    try {
      debugPrint('Starting stream request to ${config.name}...');
      
      // 根据不同的提供商使用不同的流式方法
      switch (config.provider) {
        case 'deepseek':
        case 'openai':
          yield* _streamOpenAICompatible(config, userMessage, history);
          break;
        case 'zhipu':
          yield* _streamZhipu(config, userMessage, history);
          break;
        default:
          // 不支持流式的模型，使用普通方法并逐字返回
          final response = await chat(userMessage, history: history);
          for (int i = 0; i < response.length; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            yield response.substring(0, i + 1);
          }
      }
    } catch (e) {
      debugPrint('Stream error: $e');
      yield '请求失败: $e';
    }
  }

  /// OpenAI 兼容 API 流式请求
  Stream<String> _streamOpenAICompatible(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async* {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': '你是一个专业的编程助手，帮助用户解决代码问题。请用中文回答。'},
      if (history != null) ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final request = http.Request('POST', Uri.parse(config.apiEndpoint));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.bodyBytes = utf8.encode(jsonEncode({
      'model': config.modelId,
      'messages': messages,
      'stream': true,
      'temperature': 0.7,
      'max_tokens': 4096,
    }));

    final response = await http.Client().send(request);
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];
            if (content != null) {
              yield content;
            }
          } catch (e) {
            // 解析错误，忽略
          }
        }
      }
    }
  }

  /// 智谱 API 流式请求
  Stream<String> _streamZhipu(
    AIModelConfig config,
    String userMessage,
    List<AIMessage>? history,
  ) async* {
    final request = http.Request('POST', Uri.parse(config.apiEndpoint));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.bodyBytes = utf8.encode(jsonEncode({
      'model': config.modelId,
      'messages': [
        {'role': 'user', 'content': userMessage}
      ],
      'stream': true,
    }));

    final response = await http.Client().send(request);
    
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];
            if (content != null) {
              yield content;
            }
          } catch (e) {
            // 解析错误，忽略
          }
        }
      }
    }
  }

  /// AI 编辑代码
  Future<String> editCode(String code, String instruction, {String language = ''}) async {
    final prompt = '''请根据以下指令修改代码：

语言: ${language.isEmpty ? '自动检测' : language}

原始代码:
```
$code
```

修改指令: $instruction

请只返回修改后的完整代码，不要添加任何解释。''';

    return await chat(prompt);
  }

  /// AI 解释代码
  Future<String> explainCode(String code, {String language = ''}) async {
    final prompt = '''请解释以下代码的功能和工作原理：

语言: ${language.isEmpty ? '自动检测' : language}

```
$code
```

请用简洁易懂的语言解释，包括：
1. 代码的主要功能
2. 关键代码段的作用
3. 代码的运行流程''';

    return await chat(prompt);
  }

  /// AI 重构代码
  Future<String> refactorCode(String code, {String language = ''}) async {
    final prompt = '''请重构以下代码，使其更加清晰、高效、易维护：

语言: ${language.isEmpty ? '自动检测' : language}

```
$code
```

重构要求：
1. 提高代码可读性
2. 优化性能
3. 遵循最佳实践
4. 保持原有功能不变

请只返回重构后的代码，不要添加解释。''';

    return await chat(prompt);
  }

  /// AI 修复代码
  Future<String> fixCode(String code, {String? error, String language = ''}) async {
    final prompt = '''请修复以下代码中的问题：

语言: ${language.isEmpty ? '自动检测' : language}

代码:
```
$code
```

${error != null ? '错误信息:\n$error' : ''}

请：
1. 找出所有问题
2. 修复这些问题
3. 确保代码能正常编译和运行

请只返回修复后的代码，不要添加解释。''';

    return await chat(prompt);
  }
}

// 全局实例
final aiService = AIService();
