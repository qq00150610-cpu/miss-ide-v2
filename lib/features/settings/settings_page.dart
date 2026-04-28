import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ai/ai_service.dart';
import '../build/build_service.dart';
import '../version/version_service.dart';
import '../version/version_history.dart';
import '../version/version_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  String _githubTokenStatus = '未配置';
  String _currentVersion = '加载中...';
  int _releaseCount = 0;
  final _storage = const FlutterSecureStorage();

  final List<Map<String, String>> _aiModels = [
    {'name': 'DeepSeek', 'url': 'https://platform.deepseek.com', 'desc': '代码能力强，推荐'},
    {'name': '通义千问', 'url': 'https://dashscope.aliyuncs.com', 'desc': '阿里云模型'},
    {'name': '豆包', 'url': 'https://console.volcengine.com/ark', 'desc': '字节跳动'},
    {'name': 'Minimax', 'url': 'https://api.minimax.chat', 'desc': '长上下文'},
    {'name': '智谱清言', 'url': 'https://open.bigmodel.cn', 'desc': 'GLM-4'},
    {'name': 'Gemini', 'url': 'https://makersuite.google.com', 'desc': 'Google多模态'},
    {'name': 'GPT-4', 'url': 'https://platform.openai.com', 'desc': 'OpenAI'},
    {'name': 'Claude', 'url': 'https://console.anthropic.com', 'desc': 'Anthropic'},
    {'name': 'Ollama', 'url': 'http://localhost:11434', 'desc': '本地部署'},
  ];

  @override
  void initState() {
    super.initState();
    _initService();
    _loadGitHubTokenStatus();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    await versionService.loadFromPubspec();
    await versionHistoryService.init();
    
    final releases = await versionHistoryService.getReleases();
    
    if (mounted) {
      setState(() {
        _currentVersion = versionService.currentVersion.displayVersion;
        _releaseCount = releases.length;
      });
    }
  }

  Future<void> _loadGitHubTokenStatus() async {
    final token = await _storage.read(key: 'github_token');
    if (mounted) {
      setState(() {
        _githubTokenStatus = token != null && token.isNotEmpty 
            ? '${token.substring(0, 8)}...' 
            : '未配置';
      });
    }
  }

  Future<void> _initService() async {
    await aiService.init();
    setState(() {});
  }

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
                title: const Text('当前模型'),
                subtitle: Text('${aiService.selectedModel} ${aiService.apiKey.isNotEmpty ? "✓已配置" : "✗未配置"}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showModelSelector(),
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('API Key'),
                subtitle: Text(
                  aiService.apiKey.isNotEmpty 
                    ? '${aiService.apiKey.substring(0, 8)}...' 
                    : '点击配置'
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showApiKeyDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text('获取 ${aiService.selectedModel} API Key'),
                subtitle: Text(_getModelUrl(aiService.selectedModel)),
                onTap: () => _launchUrl(_getModelUrl(aiService.selectedModel)),
              ),
            ],
          ),
          
          // 模型列表
          _buildSection(
            '所有模型',
            _aiModels.map((model) => ListTile(
              leading: Icon(
                aiService.selectedModel == model['name'] 
                  ? Icons.radio_button_checked 
                  : Icons.radio_button_off,
                color: aiService.selectedModel == model['name'] 
                  ? Theme.of(context).colorScheme.primary 
                  : null,
              ),
              title: Text(model['name']!),
              subtitle: Text(model['desc']!),
              trailing: aiService.selectedModel == model['name'] && aiService.apiKey.isNotEmpty
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : null,
              onTap: () async {
                await aiService.setModel(model['name']!);
                setState(() {});
              },
            )).toList(),
          ),
          
          // 构建设置
          _buildSection(
            '构建服务',
            [
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('GitHub Token'),
                subtitle: Text(_githubTokenStatus),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showGitHubTokenDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('获取 GitHub Token'),
                subtitle: const Text('GitHub Settings > Developer settings'),
                onTap: () => _launchUrl('https://github.com/settings/tokens?type=beta'),
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
          
          // 关于
          _buildSection(
            '关于',
            [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: Text(_currentVersion),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VersionHistoryPage(),
                    ),
                  ).then((_) => _loadVersionInfo());
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('版本历史'),
                subtitle: Text('$_releaseCount 个发布版本'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VersionHistoryPage(),
                    ),
                  ).then((_) => _loadVersionInfo());
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载历史版本'),
                subtitle: const Text('查看所有 GitHub Releases'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _launchUrl(versionService.releasesPageUrl),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Miss IDE',
                  applicationVersion: versionService.currentVersion.versionString,
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

  String _getModelUrl(String modelName) {
    final model = _aiModels.firstWhere(
      (m) => m['name'] == modelName,
      orElse: () => {'url': ''},
    );
    return model['url'] ?? '';
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
              child: Text('选择AI模型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...(_aiModels.map((model) => ListTile(
              leading: Icon(
                aiService.selectedModel == model['name'] 
                  ? Icons.radio_button_checked 
                  : Icons.radio_button_off,
                color: aiService.selectedModel == model['name'] 
                  ? Theme.of(context).colorScheme.primary 
                  : null,
              ),
              title: Text(model['name']!),
              subtitle: Text(model['desc']!),
              onTap: () async {
                await aiService.setModel(model['name']!);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
            ))),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: aiService.apiKey);
    bool isValidating = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Text('${aiService.selectedModel} API Key'),
              const SizedBox(width: 8),
              if (isValidating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (aiService.apiKey.isNotEmpty)
                Icon(
                  aiService.isApiKeyValid == true ? Icons.check_circle : Icons.info_outline,
                  size: 20,
                  color: aiService.isApiKeyValid == true ? Colors.green : Colors.orange,
                ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '粘贴API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => controller.clear(),
                        )
                      : null,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '获取地址: ${_getModelUrl(aiService.selectedModel)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '提示: API Key 会安全存储在本地，不会上传到服务器',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            OutlinedButton.icon(
              onPressed: isValidating
                  ? null
                  : () async {
                      final key = controller.text.trim();
                      if (key.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入API Key')),
                        );
                        return;
                      }
                      
                      setState(() => isValidating = true);
                      await aiService.saveApiKey(key);
                      setState(() => isValidating = false);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${aiService.selectedModel} API Key 已保存'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        this.setState(() {});
                      }
                    },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存'),
            ),
            FilledButton.icon(
              onPressed: isValidating || controller.text.isEmpty
                  ? null
                  : () async {
                      final key = controller.text.trim();
                      if (key.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入API Key')),
                        );
                        return;
                      }
                      
                      setState(() => isValidating = true);
                      await aiService.saveApiKey(key);
                      final isValid = await aiService.validateApiKey();
                      setState(() => isValidating = false);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isValid 
                                  ? 'API Key 验证成功 ✓' 
                                  : 'API Key 验证失败，请检查是否正确',
                            ),
                            backgroundColor: isValid ? Colors.green : Colors.red,
                          ),
                        );
                        this.setState(() {});
                      }
                    },
              icon: const Icon(Icons.verified, size: 18),
              label: const Text('验证'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGitHubTokenDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '用于触发 GitHub Actions 构建',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '粘贴 GitHub Personal Access Token',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              '需要 repo 和 workflow 权限',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final token = controller.text.trim();
              if (token.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入 GitHub Token')),
                );
                return;
              }
              
              await BuildService.setGitHubToken(token);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GitHub Token 已保存')),
                );
                _loadGitHubTokenStatus();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
