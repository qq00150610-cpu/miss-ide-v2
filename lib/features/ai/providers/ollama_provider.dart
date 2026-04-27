import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../models/ai_model.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// Ollama 本地模型 Provider
class OllamaProvider implements AIProvider {
  String _baseUrl = AIConstants.ollamaEndpoint;
  final Map<String, UsageStats> _usageStats = {};
  List<String> _installedModels = [];

  OllamaProvider({String? baseUrl}) {
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  void setBaseUrl(String baseUrl) => _baseUrl = baseUrl;

  @override
  AIProviderType get providerType => AIProviderType.ollama;

  @override
  List<AIModel> get supportedModels => AIModelCatalog.getModelsForProvider(AIProviderType.ollama);

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // 更新已安装的模型列表
        final json = jsonDecode(response.body);
        _installedModels = (json['models'] as List?)
            ?.map((m) => m['name'] as String)
            .toList() ?? [];
        return true;
      }
      return false;
    } catch (e) {
      logger.e(LogTags.ai, 'Ollama availability check failed', error: e);
      return false;
    }
  }

  /// 获取已安装的模型列表
  Future<List<String>> getInstalledModels() async {
    if (_installedModels.isEmpty) {
      await isAvailable();
    }
    return _installedModels;
  }

  /// 拉取模型
  Future<bool> pullModel(String modelName, {void Function(String)? onProgress}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );
      
      if (response.statusCode == 200) {
        // 处理流式响应
        final lines = const LineSplitter().convert(response.body);
        for (final line in lines) {
          try {
            final json = jsonDecode(line);
            final status = json['status'] as String?;
            if (status != null && onProgress != null) {
              onProgress(status);
            }
          } catch (_) {}
        }
        await isAvailable(); // 刷新模型列表
        return true;
      }
      return false;
    } catch (e) {
      logger.e(LogTags.ai, 'Ollama pull model failed', error: e);
      return false;
    }
  }

  /// 删除模型
  Future<bool> deleteModel(String modelName) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );
      
      if (response.statusCode == 200) {
        _installedModels.remove(modelName);
        return true;
      }
      return false;
    } catch (e) {
      logger.e(LogTags.ai, 'Ollama delete model failed', error: e);
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
    final selectedModel = modelId ?? (_installedModels.isNotEmpty ? _installedModels.first : 'codellama:7b');
    
    final prompt = '''Complete the code at the cursor position:

File: ${context.fileName}
Language: ${context.language}

```
${context.beforeCursor}
[CURSOR]
${context.afterCursor}
```

Provide ONLY the completion:''';

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
      model: modelId ?? (_installedModels.isNotEmpty ? _installedModels.first : 'codellama:7b'),
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> refactor(String code, String hint, {String? modelId, double temperature = 0.5}) {
    final prompt = 'Refactor this code:\n\nRequirements: $hint\n\nCode:\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? (_installedModels.isNotEmpty ? _installedModels.first : 'codellama:7b'),
      prompt: prompt,
      temperature: temperature,
    );
  }

  @override
  Stream<AIResponse> generateDoc(String code, {String? style, String? modelId}) {
    final prompt = 'Generate documentation for this code:\n\n```kotlin\n$code\n```';
    return _sendRequest(
      model: modelId ?? (_installedModels.isNotEmpty ? _installedModels.first : 'codellama:7b'),
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
    final selectedModel = modelId ?? (_installedModels.isNotEmpty ? _installedModels.first : 'codellama:7b');
    
    // Ollama使用特定的prompt格式
    String prompt = message;
    if (history != null && history.isNotEmpty) {
      final historyText = history.map((m) => '${m['role']}: ${m['content']}').join('\n');
      prompt = 'Context:\n$historyText\n\n$message';
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
    // Ollama vision models support image analysis
    yield AIErrorResponse(modelId ?? 'ollama', 'Vision models not implemented', AIErrorCode.unsupportedFeature);
  }

  Stream<AIResponse> _sendRequest({
    required String model,
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    final buffer = StringBuffer();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': true,
          'options': {
            'temperature': temperature,
            'num_predict': maxTokens,
          },
        }),
      ).timeout(AIConstants.streamTimeout);

      if (response.statusCode != 200) {
        yield AIErrorResponse(model, 'Ollama request failed: ${response.statusCode}', AIErrorCode.apiError);
        return;
      }

      final lines = const LineSplitter().convert(response.body);
      for (final line in lines) {
        try {
          final json = jsonDecode(line);
          final responseText = json['response'] as String?;
          if (responseText != null && responseText.isNotEmpty) {
            buffer.write(responseText);
            yield AITokenResponse(model, responseText);
          }
          
          // 检查是否完成
          if (json['done'] == true) {
            break;
          }
        } catch (_) {}
      }

      _updateUsage(model, prompt.length ~/ 4, buffer.length ~/ 4);

      yield AIDoneResponse(model, buffer.toString());
    } catch (e) {
      logger.e(LogTags.ai, 'Ollama request failed', error: e);
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
