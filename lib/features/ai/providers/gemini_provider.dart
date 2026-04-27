import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Google Gemini Provider
class GeminiProvider implements AIProvider {
  String? _apiKey;
  String _baseUrl = AIConstants.geminiEndpoint;
  final Map<String, UsageStats> _usageStats = {};

  GeminiProvider({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setApiKey(String apiKey) => _apiKey = apiKey;

  @override
  AIProviderType get providerType => AIProviderType.gemini;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.gemini);

  @override
  Future<bool> isAvailable() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models?key=$_apiKey'),
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
    final selectedModel = modelId ?? 'gemini-1.5-flash';
    
    final prompt = '''你是一个专业的代码助手。请根据代码上下文补全光标位置的代码。
要求：
1. 只输出补全的代码
2. 保持代码风格一致
3. 补全内容要完整可运行

文件: ${context.fileName}
语言: ${context.language}

```${context.language}
${context.beforeCursor}
█
${context.afterCursor}
```

请直接输出补全代码：''';

    yield* _sendRequest(
      model: selectedModel,
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> explain(String code, String language, {String? modelId, double temperature = 0.7}) {
    final prompt = '请解释以下$language代码：\n\n```$language\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gemini-1.5-flash',
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(String code, String hint, {String? modelId, double temperature = 0.5}) {
    final prompt = '根据要求重构代码：\n\n要求：$hint\n\n代码：\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gemini-1.5-flash',
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final prompt = '为代码生成文档注释：\n\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? 'gemini-1.5-flash',
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
    final selectedModel = modelId ?? 'gemini-1.5-flash';
    String prompt = message;
    
    if (history != null && history.isNotEmpty) {
      final historyText = history.map((m) => '${m['role']}: ${m['content']}').join('\n');
      prompt = '对话历史：\n$historyText\n\n当前问题：$message';
    }

    return _sendRequest(
      model: selectedModel,
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Stream<AIResponse> analyzeImage(List<int> imageBytes, String question, {String? modelId}) async* {
    final selectedModel = modelId ?? 'gemini-1.5-flash';
    
    if (_apiKey == null) {
      yield AIErrorResponse(selectedModel, 'API Key未配置', AIErrorCode.invalidApiKey);
      return;
    }

    final buffer = StringBuffer();
    final base64Image = base64Encode(imageBytes);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/models/$selectedModel:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': question},
                {'inline_data': {'mime_type': 'image/png', 'data': base64Image}},
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 4096,
          },
        }),
      ).timeout(AIConstants.streamTimeout);

      if (response.statusCode != 200) {
        yield AIErrorResponse(selectedModel, 'API请求失败', AIErrorCode.apiError);
        return;
      }

      final json = jsonDecode(response.body);
      final candidates = json['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content']?['parts'] as List?;
        if (content != null) {
          for (final part in content) {
            final text = part['text'] as String?;
            if (text != null && text.isNotEmpty) {
              buffer.write(text);
              yield AITokenResponse(selectedModel, text);
            }
          }
        }
      }

      yield AIDoneResponse(selectedModel, buffer.toString());
    } catch (e) {
      logger.e(LogTags.ai, 'Gemini image analysis failed', error: e);
      yield AIErrorResponse(selectedModel, '图片分析失败: ${e.toString()}', AIErrorCode.connectionError);
    }
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    if (_apiKey == null) {
      yield AIErrorResponse(model, 'API Key未配置', AIErrorCode.invalidApiKey);
      return;
    }

    final buffer = StringBuffer();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/models/$model:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ],
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
          },
        }),
      ).timeout(AIConstants.streamTimeout);

      if (response.statusCode != 200) {
        yield AIErrorResponse(model, 'API请求失败: ${response.statusCode}', AIErrorCode.apiError);
        return;
      }

      final json = jsonDecode(response.body);
      
      // 检查错误
      if (json['error'] != null) {
        yield AIErrorResponse(model, json['error']['message'] ?? 'API错误', AIErrorCode.apiError);
        return;
      }

      final candidates = json['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content']?['parts'] as List?;
        if (content != null) {
          for (final part in content) {
            final text = part['text'] as String?;
            if (text != null && text.isNotEmpty) {
              buffer.write(text);
              yield AITokenResponse(model, text);
            }
          }
        }
      }

      // 估算tokens
      final usage = json['usageMetadata'];
      int inputTokens = usage?['promptTokenCount'] ?? prompt.length ~/ 4;
      int outputTokens = usage?['candidatesTokenCount'] ?? buffer.length ~/ 4;

      _updateUsage(model, inputTokens, outputTokens);

      yield AIDoneResponse(model, buffer.toString(), inputTokens: inputTokens, outputTokens: outputTokens);
    } catch (e) {
      logger.e(LogTags.ai, 'Gemini request failed', error: e);
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
