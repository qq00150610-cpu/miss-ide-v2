import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'utils/secure_storage.dart';
import 'utils/logger.dart';
import 'features/ai/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化安全存储
  await secureStorage.init();

  // 初始化日志
  logger.setMinLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
  logger.i(LogTags.app, 'Miss IDE v${AppConstants.appVersion} starting...');

  // 初始化AI服务
  aiService.init();

  runApp(
    const ProviderScope(
      child: MissIDEApp(),
    ),
  );
}
