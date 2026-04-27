import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'package:miss_ide/features/editor/code_editor.dart';
import 'package:miss_ide/features/ai/ai_chat.dart';
import 'package:miss_ide/features/settings/settings_page.dart';
import 'package:miss_ide/features/file_manager/file_browser.dart';
import 'package:miss_ide/features/build/build.dart';

class MissIDEApp extends StatelessWidget {
  const MissIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miss IDE v2',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const MainPage(),
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
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      FileBrowserPage(onProjectSelected: _onProjectSelected),
      CodeEditorPage(projectPath: _currentProjectPath),
      const BuildPage(),
      AIChatPage(projectPath: _currentProjectPath),  // 传递项目路径
      const SettingsPage(),
    ];
  }

  void _onProjectSelected(String path, String name) {
    setState(() {
      _currentProjectPath = path;
      _currentProjectName = name;
      _currentIndex = 1; // 切换到编辑器页面
      // 重建编辑器页面以更新项目路径
      _pages[1] = CodeEditorPage(projectPath: path);
      // 重建AI聊天页面以传递新的项目路径
      _pages[3] = AIChatPage(projectPath: path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
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
