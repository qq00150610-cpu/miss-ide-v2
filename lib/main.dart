import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/ai/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化AI服务
  await aiService.init();
  
  runApp(
    const ProviderScope(
      child: MissIDEApp(),
    ),
  );
}
