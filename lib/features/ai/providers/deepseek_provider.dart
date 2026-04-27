import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// DeepSeek Provider - 专注代码，性价比最高
class DeepSeekProvider implements AIProvider {
  String? _apiKey;
  String _baseUrl = AIConstants.deepseekEndpoint;
  final Map<String, UsageStats> _usageStats = {};

  DeepSeekProvider({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setApiKey(String apiKey) => _apiKey = apiKey;
  void setBaseUrl(String baseUrl) => _baseUrl = baseUrl;

  @override
  AIProviderType get providerType => AIProviderType.deepseek;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.deepseek);

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
      logger.e(LogTags.ai, 'DeepSeek availability check failed', error: e);
      return false;
    }
  }

  @override
  Stream<AIResponse> complete(
    CodeCompletionContext context, {
    String? modelId,
    double temperature = 0.2,
    int maxTokens = 2048,
  }) async* {
    final selectedModel = modelId ?? 'deepseek-coder';
    
    final prompt = _buildCodeCompletionPrompt(context);
    
    yield* _sendRequest(
      model: selectedModel,
      messages: [
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
    final selectedModel = modelId ?? 'deepseek-chat';
    final prompt = '''分析以下$language代码：

```$language
$code
```

请解释：
1. 代码的主要功能
2. 关键逻辑和算法
3. 可能的改进建议''';

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
    final selectedModel = modelId ?? 'deepseek-coder';
    final prompt = '''根据以下要求重构代码：
    
要求：$hint

原始代码：
```kotlin
$code
```

请提供重构后的代码。''';

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
    final selectedModel = modelId ?? 'deepseek-coder';
    final prompt = '''为以下代码生成专业的文档注释：

```kotlin
$code
```

请包含：
- 函数/类的功能描述
- 参数说明
- 返回值说明
- 使用示例''';

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
    final selectedModel = modelId ?? 'deepseek-chat';
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
    yield AIErrorResponse(
      modelId ?? 'deepseek',
      'DeepSeek暂不支持图片分析',
      AIErrorCode.unsupportedFeature,
    );
  }

  /// 调试模式 - 分析错误
  Stream<AIResponse> debug(String error, String stackTrace, {String? modelId}) {
    final selectedModel = modelId ?? 'deepseek-coder';
    final prompt = '''分析以下错误并提供修复建议：

错误信息：
$error

堆栈跟踪：
```
$stackTrace
```

请提供：
1. 错误原因分析
2. 修复代码
3. 预防措施''';

    return _sendRequest(
      model: selectedModel,
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.5,
    );
  }

  String _buildCodeCompletionPrompt(CodeCompletionContext context) {
    return '''你是一个专业的编程助手。请根据下面的代码上下文，补全光标█位置的代码。

要求：
1. 直接输出补全代码，不需要任何说明
2. 代码要完整、可运行
3. 保持与原有代码一致的命名和风格

文件: ${context.fileName}
语言: ${context.language}

```${context.language}
${context.beforeCursor}
█
${context.afterCursor}
```

补全代码:''';
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

      final lines = const LineSplitter().convert(response.body);
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
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

      for (final msg in messages) {
        inputTokens += (msg['content']?.length ?? 0) ~/ 4;
      }

      _updateUsage(model, inputTokens, outputTokens);

      yield AIDoneResponse(
        model,
        buffer.toString(),
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      );
    } catch (e) {
      logger.e(LogTags.ai, 'DeepSeek request failed', error: e);
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
