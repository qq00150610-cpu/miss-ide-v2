import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Claude Provider (Anthropic)
class ClaudeProvider implements AIProvider {
  String? _apiKey;
  String _baseUrl = AIConstants.anthropicEndpoint;
  final Map<String, UsageStats> _usageStats = {};
  static const String _apiVersion = '2023-06-01';

  ClaudeProvider({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setApiKey(String apiKey) => _apiKey = apiKey;

  @override
  AIProviderType get providerType => AIProviderType.anthropic;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.anthropic);

  @override
  Future<bool> isAvailable() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages'),  // Claude API check
        headers: {
          'x-api-key': _apiKey!,
          'anthropic-version': _apiVersion,
        },
      ).timeout(const Duration(seconds: 5));
      // 401 means auth works but needs proper request
      return response.statusCode == 400 || response.statusCode == 401;
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
    final selectedModel = modelId ?? 'claude-3-haiku-20240307';
    
    final prompt = '''You are an expert code assistant. Complete the code at the cursor position.

File: ${context.fileName}
Language: ${context.language}

```
${context.beforeCursor}
[COMPLETE HERE]
${context.afterCursor}
```

Provide ONLY the completion code, no explanations:''';

    yield* _sendRequest(
      model: selectedModel,
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> explain(String code, String language, {String? modelId, double temperature = 0.7}) {
    final prompt = 'Explain this $language code:\n\n```$language\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'claude-3-haiku-20240307',
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(String code, String hint, {String? modelId, double temperature = 0.5}) {
    final prompt = 'Refactor this code:\n\nRequirements: $hint\n\nCode:\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'claude-3-haiku-20240307',
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final prompt = 'Generate documentation for this code:\n\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'claude-3-haiku-20240307',
      prompt: prompt,
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
    final selectedModel = modelId ?? 'claude-3-haiku-20240307';
    
    String prompt = message;
    if (history != null && history.isNotEmpty) {
      final historyText = history.map((m) => '${m['role']}: ${m['content']}').join('\n');
      prompt = 'Conversation history:\n$historyText\n\nCurrent: $message';
    }

    return _sendRequest(
      model: selectedModel,
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> analyzeImage(List<int> imageBytes, String question, {String? modelId}) {
    // Claude 3 supports vision
    yield AIErrorResponse(modelId ?? 'claude-3', 'Image analysis not implemented', AIErrorCode.unsupportedFeature);
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null) {
      yield AIErrorResponse(model, 'API Key not configured', AIErrorCode.invalidApiKey);
      return;
    }

    final buffer = StringBuffer();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'x-api-key': _apiKey!,
          'anthropic-version': _apiVersion,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': maxTokens,
          'temperature': temperature,
        }),
      ).timeout(AIConstants.streamTimeout);

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        yield AIErrorResponse(
          model,
          error['error']?['message'] ?? 'API request failed',
          AIErrorCode.apiError,
        );
        return;
      }

      final json = jsonDecode(response.body);
      final content = json['content'] as List?;
      
      if (content != null) {
        for (final block in content) {
          if (block['type'] == 'text') {
            final text = block['text'] as String?;
            if (text != null && text.isNotEmpty) {
              buffer.write(text);
              yield AITokenResponse(model, text);
            }
          }
        }
      }

      // Get usage
      final usage = json['usage'];
      int inputTokens = usage?['input_tokens'] ?? prompt.length ~/ 4;
      int outputTokens = usage?['output_tokens'] ?? buffer.length ~/ 4;

      _updateUsage(model, inputTokens, outputTokens);

      yield AIDoneResponse(model, buffer.toString(), inputTokens: inputTokens, outputTokens: outputTokens);
    } catch (e) {
      logger.e(LogTags.ai, 'Claude request failed', error: e);
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
