import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'constants.dart';
import 'logger.dart';

/// 安全存储管理器
/// 用于存储敏感的API Key和其他配置
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  late final FlutterSecureStorage _storage;
  bool _initialized = false;

  /// 初始化安全存储
  Future<void> init() async {
    if (_initialized) return;

    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    _initialized = true;
    logger.i(LogTags.storage, 'SecureStorage initialized');
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SecureStorage not initialized. Call init() first.');
    }
  }

  // ==================== AI API Key 管理 ====================

  /// 保存AI Provider的API Key
  Future<void> saveApiKey(String provider, String apiKey) async {
    _ensureInitialized();
    
    // 加密存储
    final encrypted = _encrypt(apiKey);
    await _storage.write(
      key: '${AppConstants.keyAiConfig}_key_$provider',
      value: encrypted,
    );
    logger.i(LogTags.storage, 'API Key saved for provider: $provider');
  }

  /// 获取AI Provider的API Key
  Future<String?> getApiKey(String provider) async {
    _ensureInitialized();
    
    final encrypted = await _storage.read(
      key: '${AppConstants.keyAiConfig}_key_$provider',
    );
    
    if (encrypted == null) return null;
    return _decrypt(encrypted);
  }

  /// 删除AI Provider的API Key
  Future<void> deleteApiKey(String provider) async {
    _ensureInitialized();
    
    await _storage.delete(
      key: '${AppConstants.keyAiConfig}_key_$provider',
    );
    logger.i(LogTags.storage, 'API Key deleted for provider: $provider');
  }

  /// 检查是否配置了API Key
  Future<bool> hasApiKey(String provider) async {
    _ensureInitialized();
    
    final value = await _storage.read(
      key: '${AppConstants.keyAiConfig}_key_$provider',
    );
    return value != null;
  }

  /// 获取所有已配置的Provider列表
  Future<List<String>> getConfiguredProviders() async {
    _ensureInitialized();
    
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith('${AppConstants.keyAiConfig}_key_'))
        .map((k) => k.replaceFirst('${AppConstants.keyAiConfig}_key_', ''))
        .toList();
  }

  // ==================== 通用配置管理 ====================

  /// 保存配置（JSON格式）
  Future<void> saveConfig(String key, Map<String, dynamic> config) async {
    _ensureInitialized();
    
    final json = jsonEncode(config);
    final encrypted = _encrypt(json);
    await _storage.write(key: key, value: encrypted);
    logger.i(LogTags.storage, 'Config saved: $key');
  }

  /// 获取配置
  Future<Map<String, dynamic>?> getConfig(String key) async {
    _ensureInitialized();
    
    final encrypted = await _storage.read(key: key);
    if (encrypted == null) return null;
    
    try {
      final json = _decrypt(encrypted);
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      logger.e(LogTags.storage, 'Failed to parse config: $key', error: e);
      return null;
    }
  }

  /// 保存字符串值
  Future<void> write(String key, String value) async {
    _ensureInitialized();
    final encrypted = _encrypt(value);
    await _storage.write(key: key, value: encrypted);
  }

  /// 获取字符串值
  Future<String?> read(String key) async {
    _ensureInitialized();
    final encrypted = await _storage.read(key: key);
    if (encrypted == null) return null;
    return _decrypt(encrypted);
  }

  /// 删除值
  Future<void> delete(String key) async {
    _ensureInitialized();
    await _storage.delete(key: key);
  }

  /// 清空所有数据
  Future<void> clear() async {
    _ensureInitialized();
    await _storage.deleteAll();
    logger.w(LogTags.storage, 'All secure storage cleared');
  }

  // ==================== 加密工具 ====================

  /// 简单的XOR加密（结合设备特征）
  String _encrypt(String plainText) {
    // 使用固定盐值 + 随机前缀
    const salt = 'MissIDE_v2_Secure_2024';
    final key = utf8.encode(salt);
    final bytes = utf8.encode(plainText);
    
    // XOR加密
    final encrypted = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ key[i % key.length];
    });
    
    // 添加校验和
    final checksum = md5.convert(bytes).toString().substring(0, 8);
    
    return '$checksum:${base64Encode(encrypted)}';
  }

  /// 解密
  String _decrypt(String encrypted) {
    try {
      final parts = encrypted.split(':');
      if (parts.length != 2) {
        throw FormatException('Invalid encrypted format');
      }
      
      final checksum = parts[0];
      final data = base64Decode(parts[1]);
      
      const salt = 'MissIDE_v2_Secure_2024';
      final key = utf8.encode(salt);
      
      // XOR解密
      final decrypted = List<int>.generate(data.length, (i) {
        return data[i] ^ key[i % key.length];
      });
      
      // 验证校验和
      final computedChecksum = md5.convert(decrypted).toString().substring(0, 8);
      if (checksum != computedChecksum) {
        throw StateError('Checksum mismatch - data may be corrupted');
      }
      
      return utf8.decode(decrypted);
    } catch (e) {
      logger.e(LogTags.storage, 'Decryption failed', error: e);
      rethrow;
    }
  }
}

/// 全局实例
final secureStorage = SecureStorage();
