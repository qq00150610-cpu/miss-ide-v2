import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  String _selectedAIModel = 'DeepSeek';
  String _apiKey = '';

  final List<Map<String, String>> _aiModels = [
    {'name': 'DeepSeek', 'url': 'https://platform.deepseek.com'},
    {'name': '通义千问', 'url': 'https://dashscope.aliyuncs.com'},
    {'name': '豆包', 'url': 'https://console.volcengine.com/ark'},
    {'name': 'Minimax', 'url': 'https://api.minimax.chat'},
    {'name': '智谱清言', 'url': 'https://open.bigmodel.cn'},
    {'name': 'Gemini', 'url': 'https://makersuite.google.com'},
    {'name': 'GPT-4', 'url': 'https://platform.openai.com'},
    {'name': 'Claude', 'url': 'https://console.anthropic.com'},
    {'name': 'Ollama', 'url': 'http://localhost:11434'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // AI 设置
          _buildSection(
            'AI 服务',
            [
              ListTile(
                leading: const Icon(Icons.smart_toy),
                title: const Text('默认AI模型'),
                subtitle: Text(_selectedAIModel),
                onTap: () => _showModelSelector(),
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('API Key'),
                subtitle: Text(_apiKey.isEmpty ? '未配置' : '已配置'),
                onTap: () => _showApiKeyDialog(),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('模型说明'),
                subtitle: Text('DeepSeek代码能力最强，推荐使用'),
              ),
            ],
          ),
          
          // 外观设置
          _buildSection(
            '外观',
            [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('深色模式'),
                subtitle: const Text('跟随系统设置'),
                value: _darkMode,
                onChanged: (value) {
                  setState(() {
                    _darkMode = value;
                  });
                },
              ),
            ],
          ),
          
          // 构建设置
          _buildSection(
            '构建',
            [
              ListTile(
                leading: const Icon(Icons.android),
                title: const Text('Android SDK'),
                subtitle: const Text('自动管理'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Gradle'),
                subtitle: const Text('v8.4 内置'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ],
          ),
          
          // 关于
          _buildSection(
            '关于',
            [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('版本'),
                subtitle: Text('Miss IDE v2.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Miss IDE',
                  applicationVersion: '2.0.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择AI模型', style: TextStyle(fontSize: 18)),
            ),
            ...(_aiModels.map((model) => ListTile(
              leading: Icon(
                _selectedAIModel == model['name'] 
                  ? Icons.radio_button_checked 
                  : Icons.radio_button_off,
              ),
              title: Text(model['name']!),
              subtitle: Text(model['url']!),
              onTap: () {
                setState(() {
                  _selectedAIModel = model['name']!;
                });
                Navigator.pop(context);
              },
            ))),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$_selectedAIModel API Key'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '输入API Key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {},
            ),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _apiKey = controller.text;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API Key已保存')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
