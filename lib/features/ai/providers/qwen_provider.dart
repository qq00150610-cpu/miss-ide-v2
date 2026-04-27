import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 通义千问 Provider
class QwenProvider implements AIProvider {
  String? _apiKey;
  String _baseUrl = AIConstants.qwenEndpoint;
  final Map<String, UsageStats> _usageStats = {};

  QwenProvider({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setApiKey(String apiKey) => _apiKey = apiKey;
  void setBaseUrl(String baseUrl) => _baseUrl = baseUrl;

  @override
  AIProviderType get providerType => AIProviderType.qwen;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.qwen);

  @override
  Future<bool> isAvailable() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      logger.e(LogTags.ai, 'Qwen availability check failed', error: e);
      return false;
    }
  }

  @override
  Stream<AIResponse> complete(
    CodeCompletionContext context, {
    String? modelId,
    double temperature = 0.3,
    int maxTokens = 2048,
  }) async* {
    final selectedModel = modelId ?? 'qwen-coder-plus';
    
    final prompt = _buildCompletionPrompt(context);
    
    yield* _sendRequest(
      model: selectedModel,
      messages: [
        {'role': 'system', 'content': '你是一个专业的代码助手。请根据代码上下文补全光标位置的代码。只输出补全的代码，不要添加任何解释。'},
        {'role': 'user', 'content': prompt},
      ],
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> explain(
    String code,
    String language, {
    String? modelId,
    double temperature = 0.7,
  }) {
    final selectedModel = modelId ?? 'qwen-plus';
    final prompt = '''请解释以下$language代码的功能和工作原理：

```$language
$code
```

请用简洁清晰的语言解释。''';

    return _sendRequest(
      model: selectedModel,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(
    String code,
    String hint, {
    String? modelId,
    double temperature = 0.5,
  }) {
    final selectedModel = modelId ?? 'qwen-coder-plus';
    final prompt = '''根据以下要求重构代码：
    
要求：$hint

原始代码：
```kotlin
$code
```

请提供重构后的代码，只输出代码不要解释。''';

    return _sendRequest(
      model: selectedModel,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(
    String code, {
    String? style,
    String? modelId,
  }) {
    final selectedModel = modelId ?? 'qwen-plus';
    final prompt = '''为以下代码生成文档注释：

```kotlin
$code
```

请按照KDoc格式生成文档注释。''';

    return _sendRequest(
      model: selectedModel,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.3,
    );
  }

  @override
  Stream<AIResponse> chat(
    String message, {
    List<Map<String, String>>? history,
    String? modelId,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) {
    final selectedModel = modelId ?? 'qwen-plus';
    final messages = <Map<String, String>>[];
    
    if (history != null) {
      messages.addAll(history);
    }
    messages.add({'role': 'user', 'content': message});

    return _sendRequest(
      model: selectedModel,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> analyzeImage(
    List<int> imageBytes,
    String question, {
    String? modelId,
  }) {
    // 通义千问暂不支持图片分析
    yield AIErrorResponse(
      modelId ?? 'qwen',
      '通义千问暂不支持图片分析功能',
      AIErrorCode.unsupportedFeature,
    );
  }

  String _buildCompletionPrompt(CodeCompletionContext context) {
    return '''请根据下面的代码上下文，补全光标█位置的代码。

文件: ${context.fileName}
语言: ${context.language}

```${context.language}
${context.beforeCursor}
█
${context.afterCursor}
```

请直接输出补全的代码：''';
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null) {
      yield AIErrorResponse(model, 'API Key未配置', AIErrorCode.invalidApiKey);
      return;
    }

    final buffer = StringBuffer();
    int inputTokens = 0;
    int outputTokens = 0;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'stream': true,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(AIConstants.streamTimeout);

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        yield AIErrorResponse(
          model,
          error['error']?['message'] ?? 'API请求失败',
          _mapStatusToErrorCode(response.statusCode),
        );
        return;
      }

      // 处理SSE流式响应
      final lines = const LineSplitter().convert(response.body);
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            break;
          }
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?.['delta']?['content'];
            if (content != null && content.toString().isNotEmpty) {
              buffer.write(content);
              outputTokens++;
              yield AITokenResponse(model, content.toString());
            }
          } catch (_) {}
        }
      }

      // 计算输入tokens（简化估算）
      for (final msg in messages) {
        inputTokens += (msg['content']?.length ?? 0) ~/ 4;
      }

      // 更新统计
      _updateUsage(model, inputTokens, outputTokens);

      yield AIDoneResponse(
        model,
        buffer.toString(),
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      );
    } catch (e) {
      logger.e(LogTags.ai, 'Qwen request failed', error: e);
      yield AIErrorResponse(
        model,
        '请求失败: ${e.toString()}',
        e is TimeoutException ? AIErrorCode.timeout : AIErrorCode.connectionError,
      );
    }
  }

  void _updateUsage(String modelId, int input, int output) {
    final stats = _usageStats[modelId] ?? UsageStats(
      modelId: modelId,
      lastUsed: DateTime.now(),
    );
    _usageStats[modelId] = stats.add(input, output, 0);
  }

  AIErrorCode _mapStatusToErrorCode(int statusCode) {
    switch (statusCode) {
      case 401:
        return AIErrorCode.invalidApiKey;
      case 429:
        return AIErrorCode.rateLimited;
      case 400:
        return AIErrorCode.invalidInput;
      default:
        return AIErrorCode.apiError;
    }
  }

  @override
  Map<String, UsageStats> get usageStats => Map.unmodifiable(_usageStats);

  @override
  void resetUsageStats() => _usageStats.clear();

  @override
  void dispose() {
    _usageStats.clear();
  }
}
