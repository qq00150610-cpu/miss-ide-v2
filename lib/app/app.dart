import 'package:flutter/material.dart';
import 'theme.dart';

/// Miss IDE 应用
class MissIDEApp extends StatelessWidget {
  const MissIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miss IDE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MissIDEHomePage(),
    );
  }
}

/// Miss IDE 主页面
class MissIDEHomePage extends StatefulWidget {
  const MissIDEHomePage({super.key});

  @override
  State<MissIDEHomePage> createState() => _MissIDEHomePageState();
}

class _MissIDEHomePageState extends State<MissIDEHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边导航
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.code, size: 32, color: Colors.blue),
                  Text('Miss', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('项目'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_outlined),
                selectedIcon: Icon(Icons.edit),
                label: Text('编辑'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: Text('终端'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: Text('AI助手'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 主内容区
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const ProjectListView();
      case 1:
        return const EditorView();
      case 2:
        return const TerminalView();
      case 3:
        return const AIAssistantView();
      case 4:
        return const SettingsView();
      default:
        return const ProjectListView();
    }
  }
}

/// 项目列表视图
class ProjectListView extends StatelessWidget {
  const ProjectListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: '新建项目',
            onPressed: () => _showNewProjectDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '导入项目',
            onPressed: () => _importProject(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 快速操作区
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _QuickActionCard(
                  icon: Icons.android,
                  title: 'Android',
                  subtitle: 'Kotlin/Java',
                  color: Colors.green,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _QuickActionCard(
                  icon: Icons.flutter_dash,
                  title: 'Flutter',
                  subtitle: 'Dart',
                  color: Colors.blue,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _QuickActionCard(
                  icon: Icons.terminal,
                  title: 'Java',
                  subtitle: 'Console',
                  color: Colors.orange,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _QuickActionCard(
                  icon: Icons.code,
                  title: 'Python',
                  subtitle: 'Script',
                  color: Colors.yellow.shade700,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Divider(),
          // 最近项目
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                Text(
                  '最近项目',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.folder, color: Colors.blue),
                    ),
                    title: Text('MyProject_$index'),
                    subtitle: Text(
                      '/path/to/project_$index • 最后打开: 2小时前',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showNewProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '项目名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '项目类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'android', child: Text('Android')),
                DropdownMenuItem(value: 'flutter', child: Text('Flutter')),
                DropdownMenuItem(value: 'java', child: Text('Java')),
                DropdownMenuItem(value: 'python', child: Text('Python')),
              ],
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _importProject(BuildContext context) {
    // TODO: 实现项目导入
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 编辑器视图
class EditorView extends StatelessWidget {
  const EditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '运行',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '调试',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 文件标签栏
          Container(
            height: 40,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                _FileTab(name: 'MainActivity.kt', isActive: true),
                _FileTab(name: 'build.gradle', isActive: false),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // 编辑器区域
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(
                child: Text('打开或创建文件开始编辑'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  final String name;
  final bool isActive;

  const _FileTab({required this.name, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).colorScheme.surface : null,
        border: Border(
          bottom: BorderSide(
            color: isActive ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              color: isActive ? null : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {},
            child: const Icon(Icons.close, size: 14),
          ),
        ],
      ),
    );
  }
}

/// 终端视图
class TerminalView extends StatelessWidget {
  const TerminalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('终端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: '停止',
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Text(
                    'Miss IDE Terminal v2.0',
                    style: TextStyle(color: Colors.green.shade400, fontFamily: 'monospace'),
                  ),
                  const Text(
                    'Type "help" for available commands.\n',
                    style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                  ),
                  const Text(
                    '\$ flutter build apk',
                    style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  ),
                  const Text(
                    'Running "flutter pub get"...',
                    style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            // 命令输入区
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text('\$ ', style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (value) {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI助手视图
class AIAssistantView extends StatelessWidget {
  const AIAssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          // 模型选择
          DropdownButton<String>(
            value: 'gemini',
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Gemini 1.5')),
              DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek Coder')),
              DropdownMenuItem(value: 'qwen', child: Text('通义千问')),
            ],
            onChanged: (value) {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 功能按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AIFeatureChip(label: '代码补全', icon: Icons.auto_fix_high, onTap: () {}),
                _AIFeatureChip(label: '代码解释', icon: Icons.help_outline, onTap: () {}),
                _AIFeatureChip(label: '代码重构', icon: Icons.refresh, onTap: () {}),
                _AIFeatureChip(label: '生成文档', icon: Icons.description, onTap: () {}),
                _AIFeatureChip(label: 'Bug修复', icon: Icons.bug_report, onTap: () {}),
              ],
            ),
          ),
          const Divider(),
          // 对话区
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChatBubble(
                  isUser: false,
                  message: '你好！我是Miss IDE的AI助手。我可以帮助你完成代码补全、代码解释、Bug修复等任务。请选择上方功能或直接输入问题。',
                ),
              ],
            ),
          ),
          // 输入区
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '输入你的问题...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AIFeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AIFeatureChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String message;

  const _ChatBubble({required this.isUser, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser ? Theme.of(context).colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }
}

/// 设置视图
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'AI 设置',
            children: [
              ListTile(
                leading: const Icon(Icons.smart_toy),
                title: const Text('默认AI模型'),
                subtitle: const Text('Gemini 1.5 Flash'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('API Key配置'),
                subtitle: const Text('已配置 2 个模型'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
          _SettingsSection(
            title: '编辑器',
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('字体大小'),
                subtitle: const Text('14'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              SwitchListTile(
                secondary: const Icon(Icons.wrap_text),
                title: const Text('自动换行'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                secondary: const Icon(Icons.format_list_numbered),
                title: const Text('显示行号'),
                value: true,
                onChanged: (value) {},
              ),
            ],
          ),
          _SettingsSection(
            title: '构建',
            children: [
              ListTile(
                leading: const Icon(Icons.android),
                title: const Text('Android SDK'),
                subtitle: const Text('已安装'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.java),
                title: const Text('Java JDK'),
                subtitle: const Text('OpenJDK 17'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: const Text('2.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
