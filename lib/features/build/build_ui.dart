import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'build_config.dart';
import 'build_service.dart';
import 'build_progress.dart';
import 'build_history.dart';
import 'signing_manager.dart';

/// 构建配置 Provider
final buildConfigProvider = StateProvider<BuildConfig>((ref) => BuildConfig(
  projectName: 'Miss IDE',
  projectPath: '',
));

/// 签名配置列表 Provider
final signingConfigsProvider = FutureProvider<List<String>>((ref) async {
  return SigningManager.getSigningConfigNames();
});

/// 构建页面
class BuildPage extends ConsumerStatefulWidget {
  const BuildPage({super.key});

  @override
  ConsumerState<BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends ConsumerState<BuildPage> {
  bool _isBuilding = false;
  BuildHistoryItem? _currentBuild;
  String? _selectedSigningConfig;

  @override
  void initState() {
    super.initState();
    _initBuildListener();
  }

  void _initBuildListener() {
    buildService.buildStatusStream.listen((item) {
      if (mounted) {
        setState(() {
          _currentBuild = item;
          _isBuilding = item?.status == BuildStatus.running ||
              item?.status == BuildStatus.pending;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 如果正在构建，显示构建进度界面
    if (_isBuilding && _currentBuild != null) {
      return _buildProgressView(colorScheme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('构建'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '构建历史',
            onPressed: () => _openHistory(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 项目信息
            _buildProjectSection(colorScheme),
            const SizedBox(height: 24),
            
            // 构建配置
            _buildConfigSection(colorScheme),
            const SizedBox(height: 24),
            
            // 签名配置
            _buildSigningSection(colorScheme),
            const SizedBox(height: 32),
            
            // 构建按钮
            _buildBuildButton(colorScheme),
            const SizedBox(height: 16),
            
            // 最近构建状态
            if (_currentBuild != null) _buildRecentBuildCard(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressView(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BuildProgressWidget(
        buildItem: _currentBuild!,
        onCancel: _cancelBuild,
        onClose: _closeProgress,
        onDownloadApk: _downloadApk,
      ),
    );
  }

  Widget _buildProjectSection(ColorScheme colorScheme) {
    final config = ref.watch(buildConfigProvider);
    
    return _buildSection(
      colorScheme,
      title: '项目信息',
      icon: Icons.folder,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: const Text('选择项目目录'),
          subtitle: Text(
            config.projectPath.isEmpty ? '点击选择要构建的项目' : config.projectName,
            style: TextStyle(
              color: config.projectPath.isEmpty 
                  ? colorScheme.primary 
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _selectProjectDirectory,
        ),
        if (config.projectPath.isNotEmpty)
          ListTile(
            title: const Text('项目路径'),
            subtitle: Text(
              config.projectPath.length > 35 
                  ? '...${config.projectPath.substring(config.projectPath.length - 35)}'
                  : config.projectPath,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('项目名称'),
          subtitle: Text(config.projectName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showProjectNameDialog(config),
        ),
      ],
    );
  }
  
  Future<void> _selectProjectDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;
      
      final name = selectedDirectory.split('/').last;
      final config = ref.read(buildConfigProvider);
      ref.read(buildConfigProvider.notifier).state = BuildConfig(
        projectName: name,
        projectPath: selectedDirectory,
        buildType: config.buildType,
        enableProguard: config.enableProguard,
        outputPath: config.outputPath,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已选择项目: $name')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择失败: $e')),
        );
      }
    }
  }

  Widget _buildConfigSection(ColorScheme colorScheme) {
    final config = ref.watch(buildConfigProvider);
    
    return _buildSection(
      colorScheme,
      title: '构建配置',
      icon: Icons.build,
      children: [
        // 构建类型
        ListTile(
          title: const Text('构建类型'),
          subtitle: Text(config.buildType.label),
          trailing: SegmentedButton<BuildType>(
            segments: BuildType.values.map((type) => ButtonSegment(
              value: type,
              label: Text(type.value),
            )).toList(),
            selected: {config.buildType},
            onSelectionChanged: (selected) {
              ref.read(buildConfigProvider.notifier).state = 
                  config.copyWith(buildType: selected.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        
        // Proguard
        SwitchListTile(
          title: const Text('启用 Proguard'),
          subtitle: const Text('代码混淆和优化'),
          value: config.enableProguard,
          onChanged: (value) {
            ref.read(buildConfigProvider.notifier).state = 
                config.copyWith(enableProguard: value);
          },
        ),
        
        // 输出路径
        ListTile(
          title: const Text('输出路径'),
          subtitle: Text(config.outputPath),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showOutputPathDialog(config),
        ),
      ],
    );
  }

  Widget _buildSigningSection(ColorScheme colorScheme) {
    final config = ref.watch(buildConfigProvider);
    
    return _buildSection(
      colorScheme,
      title: '签名配置',
      icon: Icons.vpn_key,
      children: [
        // 签名选择
        ListTile(
          title: const Text('签名配置'),
          subtitle: Text(
            config.signingConfig.isDebug 
                ? 'Debug 签名 (默认)' 
                : config.signingConfig.keyAlias.isNotEmpty 
                    ? config.signingConfig.keyAlias 
                    : '未配置',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showSigningSelector(context),
        ),
        
        // 快速配置
        ExpansionTile(
          title: const Text('签名详情'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                    label: '密钥库路径',
                    value: config.signingConfig.keystorePath,
                    onChanged: (v) => _updateSigningConfig(
                      config.signingConfig.copyWith(keystorePath: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '密钥库密码',
                    value: config.signingConfig.keystorePassword,
                    obscure: true,
                    onChanged: (v) => _updateSigningConfig(
                      config.signingConfig.copyWith(keystorePassword: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '别名',
                    value: config.signingConfig.keyAlias,
                    onChanged: (v) => _updateSigningConfig(
                      config.signingConfig.copyWith(keyAlias: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '别名密码',
                    value: config.signingConfig.keyPassword,
                    obscure: true,
                    onChanged: (v) => _updateSigningConfig(
                      config.signingConfig.copyWith(keyPassword: v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // 生成密钥库
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('生成新密钥库'),
          onTap: () => _showGenerateKeystoreDialog(config),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool obscure = false,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      obscureText: obscure,
      onChanged: onChanged,
    );
  }

  Widget _buildBuildButton(ColorScheme colorScheme) {
    final config = ref.watch(buildConfigProvider);
    
    return FilledButton.icon(
      onPressed: _isBuilding ? null : () => _startBuild(config),
      icon: _isBuilding 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow),
      label: Text(_isBuilding ? '构建中...' : '开始构建'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildRecentBuildCard(ColorScheme colorScheme) {
    final build = _currentBuild!;
    
    Color statusColor;
    switch (build.status) {
      case BuildStatus.success:
        statusColor = Colors.green;
        break;
      case BuildStatus.failure:
        statusColor = Colors.red;
        break;
      case BuildStatus.cancelled:
        statusColor = Colors.orange;
        break;
      default:
        statusColor = colorScheme.primary;
    }

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            build.status == BuildStatus.success 
                ? Icons.check_circle 
                : build.status == BuildStatus.failure
                    ? Icons.error
                    : Icons.sync,
            color: statusColor,
          ),
        ),
        title: Text('最近构建: ${build.projectName}'),
        subtitle: Text(
          '${build.buildType.label} - ${build.status.label}${build.durationString != '--' ? ' (${build.durationString})' : ''}',
        ),
        trailing: build.status == BuildStatus.success && build.apkPath != null
            ? IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadApk(build.apkPath!),
              )
            : null,
      ),
    );
  }

  Widget _buildSection(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  // 各种对话框
  void _showProjectNameDialog(BuildConfig config) {
    final controller = TextEditingController(text: config.projectName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('项目名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(buildConfigProvider.notifier).state = 
                  config.copyWith(projectName: controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showProjectPathDialog(BuildConfig config) {
    final controller = TextEditingController(text: config.projectPath);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('项目路径'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '路径',
            hintText: '留空使用当前应用',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(buildConfigProvider.notifier).state = 
                  config.copyWith(projectPath: controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showOutputPathDialog(BuildConfig config) {
    final controller = TextEditingController(text: config.outputPath);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输出路径'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'APK 输出路径',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(buildConfigProvider.notifier).state = 
                  config.copyWith(outputPath: controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSigningSelector(BuildContext context) async {
    final configNames = await SigningManager.getSigningConfigNames();
    final config = ref.read(buildConfigProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Debug 签名'),
              subtitle: const Text('默认 Android Debug 密钥'),
              selected: config.signingConfig.isDebug,
              onTap: () {
                ref.read(buildConfigProvider.notifier).state = 
                    config.copyWith(signingConfig: SigningConfig.debugDefault);
                Navigator.pop(context);
              },
            ),
            ...configNames.map((name) => ListTile(
              leading: const Icon(Icons.vpn_key),
              title: Text(name),
              onTap: () async {
                final savedConfig = await SigningManager.getSigningConfig(name);
                if (savedConfig != null) {
                  ref.read(buildConfigProvider.notifier).state = 
                      config.copyWith(signingConfig: savedConfig);
                }
                if (mounted) Navigator.pop(context);
              },
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('保存当前配置'),
              onTap: () {
                Navigator.pop(context);
                _showSaveSigningDialog(config);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveSigningDialog(BuildConfig config) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存签名配置'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '配置名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await SigningManager.saveSigningConfig(
                  controller.text, 
                  config.signingConfig,
                );
                ref.invalidate(signingConfigsProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('配置已保存')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showGenerateKeystoreDialog(BuildConfig config) {
    final keystorePathCtrl = TextEditingController(
      text: '/storage/emulated/0/Documents/keystore/release.keystore',
    );
    final passwordCtrl = TextEditingController(text: 'android');
    final aliasCtrl = TextEditingController(text: 'release');
    final keyPasswordCtrl = TextEditingController(text: 'android');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成密钥库'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keystorePathCtrl,
                decoration: const InputDecoration(
                  labelText: '密钥库路径',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(
                  labelText: '密钥库密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aliasCtrl,
                decoration: const InputDecoration(
                  labelText: '别名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: '别名密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final result = await SigningManager.generateKeystore(
                keystorePath: keystorePathCtrl.text,
                keystorePassword: passwordCtrl.text,
                keyAlias: aliasCtrl.text,
                keyPassword: keyPasswordCtrl.text,
              );

              if (mounted) {
                Navigator.pop(context);
                
                if (result != null) {
                  final newConfig = SigningConfig(
                    keystorePath: keystorePathCtrl.text,
                    keystorePassword: passwordCtrl.text,
                    keyAlias: aliasCtrl.text,
                    keyPassword: keyPasswordCtrl.text,
                    isDebug: false,
                  );
                  ref.read(buildConfigProvider.notifier).state = 
                      config.copyWith(signingConfig: newConfig);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密钥库生成成功')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请使用命令行手动生成密钥库')),
                  );
                }
              }
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }

  void _updateSigningConfig(SigningConfig newConfig) {
    final config = ref.read(buildConfigProvider);
    ref.read(buildConfigProvider.notifier).state = 
        config.copyWith(signingConfig: newConfig);
  }

  // 构建相关操作
  Future<void> _startBuild(BuildConfig config) async {
    setState(() {
      _isBuilding = true;
    });

    final result = await buildService.triggerBuild(
      projectName: config.projectName,
      buildType: config.buildType,
    );

    if (mounted && result == null) {
      setState(() {
        _isBuilding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('构建启动失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelBuild() async {
    if (_currentBuild?.buildNumber != null) {
      await buildService.cancelBuild(_currentBuild!.buildNumber);
    }
    setState(() {
      _isBuilding = false;
      _currentBuild = null;
    });
  }

  void _closeProgress() {
    setState(() {
      _isBuilding = false;
      _currentBuild = null;
    });
  }

  Future<void> _downloadApk(String url) async {
    if (url.startsWith('http')) {
      final path = await buildService.downloadApk(url);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('APK 已下载: $path')),
        );
      }
    } else {
      // 本地路径
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('APK 路径: $url\n已复制到剪贴板')),
      );
    }
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BuildHistoryPage(),
      ),
    );
  }
}

/// 构建详情页面（完整屏幕）
class BuildDetailPage extends StatefulWidget {
  const BuildDetailPage({super.key});

  @override
  State<BuildDetailPage> createState() => _BuildDetailPageState();
}

class _BuildDetailPageState extends State<BuildDetailPage> {
  @override
  void initState() {
    super.initState();
    // 监听构建状态
    buildService.buildStatusStream.listen((item) {
      if (mounted && item != null) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBuild = buildService.currentBuild;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('构建详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuildHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: currentBuild != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: BuildProgressWidget(
                buildItem: currentBuild,
                onCancel: () async {
                  await buildService.cancelBuild(currentBuild.buildNumber);
                },
                onClose: () => Navigator.pop(context),
                onDownloadApk: (url) async {
                  final path = await buildService.downloadApk(url);
                  if (mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('APK 已下载: $path')),
                    );
                  }
                },
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction,
                    size: 80,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无构建',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.settings),
                    label: const Text('去配置'),
                  ),
                ],
              ),
            ),
    );
  }
}
