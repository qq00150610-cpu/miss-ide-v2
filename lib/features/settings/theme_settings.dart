import 'package:flutter/material.dart';
import '../../utils/secure_storage.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';

/// 主题设置
class ThemeSettings {
  static final ThemeSettings _instance = ThemeSettings._internal();
  factory ThemeSettings() => _instance;
  ThemeSettings._internal();

  final SecureStorage _storage = secureStorage;

  ThemeMode _themeMode = ThemeMode.system;
  String _fontFamily = 'Roboto';
  double _fontSize = 14.0;
  double _lineHeight = 1.5;
  bool _wordWrap = true;
  bool _showLineNumbers = true;
  bool _highlightCurrentLine = true;
  bool _autoSave = false;
  int _autoSaveInterval = 30; // 秒

  /// 获取设置
  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  bool get wordWrap => _wordWrap;
  bool get showLineNumbers => _showLineNumbers;
  bool get highlightCurrentLine => _highlightCurrentLine;
  bool get autoSave => _autoSave;
  int get autoSaveInterval => _autoSaveInterval;

  /// 加载设置
  Future<void> loadSettings() async {
    try {
      final json = await _storage.getConfig(AppConstants.keyThemeConfig);
      if (json != null) {
        final themeModeIndex = json['themeMode'] as int? ?? 0;
        _themeMode = ThemeMode.values[themeModeIndex];
        _fontFamily = json['fontFamily'] as String? ?? 'Roboto';
        _fontSize = (json['fontSize'] as num?)?.toDouble() ?? 14.0;
        _lineHeight = (json['lineHeight'] as num?)?.toDouble() ?? 1.5;
        _wordWrap = json['wordWrap'] as bool? ?? true;
        _showLineNumbers = json['showLineNumbers'] as bool? ?? true;
        _highlightCurrentLine = json['highlightCurrentLine'] as bool? ?? true;
        _autoSave = json['autoSave'] as bool? ?? false;
        _autoSaveInterval = json['autoSaveInterval'] as int? ?? 30;
      }
      logger.i(LogTags.settings, 'Theme settings loaded');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to load theme settings', error: e);
    }
  }

  /// 保存设置
  Future<void> saveSettings() async {
    try {
      await _storage.saveConfig(AppConstants.keyThemeConfig, {
        'themeMode': _themeMode.index,
        'fontFamily': _fontFamily,
        'fontSize': _fontSize,
        'lineHeight': _lineHeight,
        'wordWrap': _wordWrap,
        'showLineNumbers': _showLineNumbers,
        'highlightCurrentLine': _highlightCurrentLine,
        'autoSave': _autoSave,
        'autoSaveInterval': _autoSaveInterval,
      });
      logger.i(LogTags.settings, 'Theme settings saved');
    } catch (e) {
      logger.e(LogTags.settings, 'Failed to save theme settings', error: e);
    }
  }

  /// 更新设置
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await saveSettings();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    await saveSettings();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(10.0, 24.0);
    await saveSettings();
  }

  Future<void> setLineHeight(double height) async {
    _lineHeight = height.clamp(1.0, 2.5);
    await saveSettings();
  }

  Future<void> setWordWrap(bool enabled) async {
    _wordWrap = enabled;
    await saveSettings();
  }

  Future<void> setShowLineNumbers(bool enabled) async {
    _showLineNumbers = enabled;
    await saveSettings();
  }

  Future<void> setHighlightCurrentLine(bool enabled) async {
    _highlightCurrentLine = enabled;
    await saveSettings();
  }

  Future<void> setAutoSave(bool enabled) async {
    _autoSave = enabled;
    await saveSettings();
  }

  Future<void> setAutoSaveInterval(int seconds) async {
    _autoSaveInterval = seconds.clamp(10, 300);
    await saveSettings();
  }

  /// 获取编辑器文本样式
  TextStyle getEditorTextStyle(Color baseColor) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      height: _lineHeight,
      color: baseColor,
    );
  }

  /// 获取可用字体列表
  List<String> get availableFonts => const [
    'Roboto',
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Ubuntu Mono',
    'Consolas',
  ];

  /// 重置为默认值
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _fontFamily = 'Roboto';
    _fontSize = 14.0;
    _lineHeight = 1.5;
    _wordWrap = true;
    _showLineNumbers = true;
    _highlightCurrentLine = true;
    _autoSave = false;
    _autoSaveInterval = 30;
    await saveSettings();
    logger.i(LogTags.settings, 'Theme settings reset to defaults');
  }
}

/// 全局实例
final themeSettings = ThemeSettings();
