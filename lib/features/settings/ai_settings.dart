import '../models/ai_model.dart';
import '../../utils/secure_storage.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';

/// AI 设置管理器
class AISettings {
  static final AISettings _instance = AISettings._internal();
  factory AISettings() => _instance;
  AISettings._internal();

  final SecureStorage _storage = secureStorage;
  AIConfig _config = const AIConfig();
  final Map<AIProviderType, ProviderConfig> _providerConfigs = {};

  /// 获取配置
  AIConfig get config => _config;

  /// 加载配置
  Future<void> loadConfig() async {
    try {
      final json = await _storage.getConfig(AppConstants.keyAiConfig);
      if (json != null) {
        _config = AIConfig.fromJson(json);
      }

      // 加载各Provider配置
      for (final type in AIProviderType.values) {
        final providerConfig = await _loadProviderConfig(type);
        if (providerConfig != null) {
          _providerConfigs[type] = providerConfig;
        }
      }

      logger.i(LogTags.settings, 'AI settings loaded');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to load AI settings', error: e);
    }
  }

  /// 保存配置
  Future<void> saveConfig() async {
    try {
      await _storage.saveConfig(AppConstants.keyAiConfig, _config.toJson());
      logger.i(LogTags.settings, 'AI settings saved');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to save AI settings', error: e);
    }
  }

  /// 更新配置
  Future<void> updateConfig(AIConfig config) async {
    _config = config;
    await saveConfig();
  }

  /// 获取Provider配置
  ProviderConfig? getProviderConfig(AIProviderType type) {
    return _providerConfigs[type];
  }

  /// 更新Provider配置
  Future<void> updateProviderConfig(AIProviderType type, ProviderConfig config) async {
    _providerConfigs[type] = config;
    await _saveProviderConfig(type, config);
  }

  /// 检查Provider是否已配置
  Future<bool> isProviderConfigured(AIProviderType type) async {
    final config = _providerConfigs[type];
    if (config != null && config.hasApiKey) {
      return true;
    }

    // 检查存储中是否有
    return await _storage.hasApiKey(type.name);
  }

  /// 获取已配置的Provider列表
  Future<List<AIProviderType>> getConfiguredProviders() async {
    final configured = <AIProviderType>[];
    for (final type in AIProviderType.values) {
      if (await isProviderConfigured(type)) {
        configured.add(type);
      }
    }
    return configured;
  }

  /// 保存Provider API Key
  Future<void> saveApiKey(AIProviderType type, String apiKey) async {
    await _storage.saveApiKey(type.name, apiKey);
    _providerConfigs[type] = ProviderConfig(apiKey: apiKey);
    logger.i(LogTags.settings, 'API Key saved for: ${type.displayNameCN}');
  }

  /// 获取Provider API Key
  Future<String?> getApiKey(AIProviderType type) async {
    return await _storage.getApiKey(type.name);
  }

  /// 删除Provider API Key
  Future<void> deleteApiKey(AIProviderType type) async {
    await _storage.deleteApiKey(type.name);
    _providerConfigs.remove(type);
    logger.i(LogTags.settings, 'API Key deleted for: ${type.displayNameCN}');
  }

  Future<ProviderConfig?> _loadProviderConfig(AIProviderType type) async {
    final apiKey = await _storage.getApiKey(type.name);
    if (apiKey == null) return null;

    return ProviderConfig(apiKey: apiKey);
  }

  Future<void> _saveProviderConfig(AIProviderType type, ProviderConfig config) async {
    if (config.apiKey != null) {
      await _storage.saveApiKey(type.name, config.apiKey!);
    }
  }

  /// 重置为默认配置
  Future<void> resetToDefaults() async {
    _config = const AIConfig();
    _providerConfigs.clear();
    await saveConfig();
    logger.i(LogTags.settings, 'AI settings reset to defaults');
  }
}

/// 全局实例
final aiSettings = AISettings();
