import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme.dart';
import 'package:miss_ide/features/editor/code_editor.dart';
import 'package:miss_ide/features/ai/ai_chat.dart';
import 'package:miss_ide/features/settings/settings_page.dart';
import 'package:miss_ide/features/file_manager/file_browser.dart';
import 'package:miss_ide/features/build/build.dart';
import 'core/logger.dart';

/// 全局主题模式通知器
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// 初始化主题设置
Future<void> initThemeMode() async {
  const storage = FlutterSecureStorage();
  final savedMode = await storage.read(key: 'theme_mode');
  if (savedMode != null) {
    final index = int.tryParse(savedMode) ?? 0;
    themeModeNotifier.value = ThemeMode.values[index];
  }
}

class MissIDEApp extends StatelessWidget {
  const MissIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'Miss IDE v2',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const MainPage(),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  String? _currentProjectPath;
  String? _currentProjectName;
  String? _currentFilePath;

  void _onProjectSelected(String path, String name) {
    MissLogger.info('App', '打开项目: $name ($path)');
    setState(() {
      _currentProjectPath = path;
      _currentProjectName = name;
      _currentFilePath = null;
      _currentIndex = 1; // 切换到编辑器
    });
  }

  void _onFileSelected(String filePath) {
    MissLogger.info('App', '打开文件: $filePath');
    setState(() {
      _currentFilePath = filePath;
      _currentIndex = 1; // 切换到编辑器
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: 项目列表
          FileBrowserPage(onProjectSelected: _onProjectSelected),
          
          // Tab 1: 编辑器（含项目目录侧边栏）
          _currentProjectPath != null
              ? CodeEditorPage(
                  projectPath: _currentProjectPath,
                  filePath: _currentFilePath,
                )
              : const _NoProjectPlaceholder(),
          
          // Tab 2: 构建
          const BuildPage(),
          
          // Tab 3: AI 助手
          AIChatPage(projectPath: _currentProjectPath),
          
          // Tab 4: 设置
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '项目',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: '编辑',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: '构建',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 未选择项目时的占位页面
class _NoProjectPlaceholder extends StatelessWidget {
  const _NoProjectPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代码编辑器'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '请先选择或创建项目',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方「项目」标签浏览或导入项目',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // 发给主页面消息切换标签
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('请点击底部「项目」标签打开项目')),
                );
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('浏览项目'),
            ),
          ],
        ),
      ),
    );
  }
}
