import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app/app.dart';
import 'features/ai/ai_service.dart';
import 'features/build/build_service.dart';
import 'core/logger.dart';

Future<void> requestPermissions() async {
  // 请求存储权限
  await [
    Permission.storage,
    Permission.manageExternalStorage,
  ].request();
  
  // 检查是否有管理外部存储权限（Android 11+）
  if (!await Permission.manageExternalStorage.isGranted) {
    // 如果没有，尝试请求
    await Permission.manageExternalStorage.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化统一日志系统
  await MissLogger().init(enableFileLogging: true);
  MissLogger.info('Main', 'Miss IDE v2 启动中...');
  
  // 请求必要权限
  await requestPermissions();
  MissLogger.info('Main', '权限已请求');
  
  // 初始化AI服务
  await aiService.init();
  MissLogger.info('Main', 'AI服务初始化完成');
  
  // 初始化构建服务
  await BuildService.init();
  MissLogger.info('Main', '构建服务初始化完成');
  
  // 初始化主题设置
  await initThemeMode();
  MissLogger.info('Main', '主题初始化完成');
  
  runApp(
    const ProviderScope(
      child: MissIDEApp(),
    ),
  );
  
  MissLogger.info('Main', 'Miss IDE v2 启动完成');
}

