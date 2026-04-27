import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Minimax Provider
class MinimaxProvider implements AIProvider {
  String? _apiKey;
  String? _groupId;
  String _baseUrl = AIConstants.minimaxEndpoint;
  final Map<String, UsageStats> _usageStats = {};

  MinimaxProvider({String? apiKey, String? groupId, String? baseUrl}) {
    _apiKey = apiKey;
    _groupId = groupId;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setCredentials(String apiKey, String groupId) {
    _apiKey = apiKey;
    _groupId = groupId;
  }

  @override
  AIProviderType get providerType => AIProviderType.minimax;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.minimax);

  @override
  Future<bool> isAvailable() async {
    if (_apiKey == null || _groupId == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/text/chatcompletion_v2'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'GroupId': _groupId!,
        },
      ).timeout(const Duration(seconds: 5));
      return response.statusCode != 401;
    } catch (e) {
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
    final selectedModel = modelId ?? 'abab6.5s-chat';
    final prompt = _buildCompletionPrompt(context);

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
  Stream<AIResponse> explain(String code, String language, {String? modelId, double temperature = 0.7}) {
    final prompt = '请解释以下$language代码：\n\n```$language\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'abab6.5-chat',
      messages: [{'role': 'user', 'content': prompt}],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(String code, String hint, {String? modelId, double temperature = 0.5}) {
    final prompt = '根据要求重构代码：\n\n要求：$hint\n\n代码：\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'abab6.5-chat',
      messages: [{'role': 'user', 'content': prompt}],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final prompt = '为代码生成文档注释：\n\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'abab6.5-chat',
      messages: [{'role': 'user', 'content': prompt}],
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
    final selectedModel = modelId ?? 'abab6.5-chat';
    final messages = <Map<String, String>>[];
    if (history != null) messages.addAll(history);
    messages.add({'role': 'user', 'content': message});

    return _sendRequest(
      model: selectedModel,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> analyzeImage(List<int> imageBytes, String question, {String? modelId}) {
    yield AIErrorResponse(modelId ?? 'minimax', 'Minimax暂不支持图片分析', AIErrorCode.unsupportedFeature);
  }

  String _buildCompletionPrompt(CodeCompletionContext context) {
    return '''请补全代码：

文件: ${context.fileName}
语言: ${context.language}

```${context.language}
${context.beforeCursor}
█
${context.afterCursor}
```

请直接输出补全代码：''';
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null || _groupId == null) {
      yield AIErrorResponse(model, 'API Key或Group ID未配置', AIErrorCode.invalidApiKey);
      return;
    }

    final buffer = StringBuffer();
    int inputTokens = 0;
    int outputTokens = 0;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/text/chatcompletion_v2'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'GroupId': _groupId!,
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
        yield AIErrorResponse(model, 'API请求失败: ${response.statusCode}', AIErrorCode.apiError);
        return;
      }

      final lines = const LineSplitter().convert(response.body);
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];
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

      yield AIDoneResponse(model, buffer.toString(), inputTokens: inputTokens, outputTokens: outputTokens);
    } catch (e) {
      logger.e(LogTags.ai, 'Minimax request failed', error: e);
      yield AIErrorResponse(model, '请求失败: ${e.toString()}', AIErrorCode.connectionError);
    }
  }

  void _updateUsage(String modelId, int input, int output) {
    final stats = _usageStats[modelId] ?? UsageStats(modelId: modelId, lastUsed: DateTime.now());
    _usageStats[modelId] = stats.add(input, output, 0);
  }

  @override
  Map<String, UsageStats> get usageStats => Map.unmodifiable(_usageStats);

  @override
  void resetUsageStats() => _usageStats.clear();

  @override
  void dispose() => _usageStats.clear();
}
