import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// OpenAI GPT Provider
class OpenAIProvider implements AIProvider {
  String? _apiKey;
  String _baseUrl = AIConstants.openaiEndpoint;
  final Map<String, UsageStats> _usageStats = {};

  OpenAIProvider({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setApiKey(String apiKey) => _apiKey = apiKey;

  @override
  AIProviderType get providerType => AIProviderType.openai;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.openai);

  @override
  Future<bool> isAvailable() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
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
    final selectedModel = modelId ?? 'gpt-3.5-turbo';
    
    final prompt = '''You are a code assistant. Complete the code at the cursor position.

File: ${context.fileName}
Language: ${context.language}

```${context.language}
${context.beforeCursor}
[CURSOR]
${context.afterCursor}
```

Provide only the completion code:''';

    yield* _sendRequest(
      model: selectedModel,
      messages: [{'role': 'user', 'content': prompt}],
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> explain(String code, String language, {String? modelId, double temperature = 0.7}) {
    final prompt = 'Explain this $language code:\n\n```$language\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gpt-3.5-turbo',
      messages: [{'role': 'user', 'content': prompt}],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(String code, String hint, {String? modelId, double temperature = 0.5}) {
    final prompt = 'Refactor this code:\n\nRequirements: $hint\n\nCode:\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gpt-3.5-turbo',
      messages: [{'role': 'user', 'content': prompt}],
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final prompt = 'Generate documentation for this code:\n\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gpt-3.5-turbo',
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
    final selectedModel = modelId ?? 'gpt-3.5-turbo';
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
    yield AIErrorResponse(modelId ?? 'gpt-4', 'GPT-4 vision required for image analysis', AIErrorCode.unsupportedFeature);
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null) {
      yield AIErrorResponse(model, 'API Key not configured', AIErrorCode.invalidApiKey);
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
        yield AIErrorResponse(model, error['error']?['message'] ?? 'API request failed', AIErrorCode.apiError);
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
      logger.e(LogTags.ai, 'OpenAI request failed', error: e);
      yield AIErrorResponse(model, 'Request failed: ${e.toString()}', AIErrorCode.connectionError);
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
