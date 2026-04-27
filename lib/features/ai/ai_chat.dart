import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';

class AIChatPage extends StatefulWidget {
  final Function(String)? onNavigateToEditor;
  final Function(String, String)? onNavigateToFileBrowser;
  
  const AIChatPage({
    super.key,
    this.onNavigateToEditor,
    this.onNavigateToFileBrowser,
  });

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _showQuickActions = true;
  
  // 待保存的代码
  String? _pendingCode;
  String? _pendingLanguage;

  @override
  void initState() {
    super.initState();
    _initService();
    // 设置AI回调
    aiService.onCodeGenerated = _onCodeGenerated;
  }

  Future<void> _initService() async {
    await aiService.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeGenerated(String language, String code) {
    setState(() {
      _pendingCode = code;
      _pendingLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.smart_toy, size: 24),
            const SizedBox(width: 8),
            Text('AI 助手 - ${aiService.selectedModel}'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showQuickActions ? Icons.shortcut : Icons.expand_more),
            onPressed: () => setState(() => _showQuickActions = !_showQuickActions),
            tooltip: '快捷操作',
          ),
          PopupMenuButton<String>(
            initialValue: aiService.selectedModel,
            onSelected: (model) async {
              await aiService.setModel(model);
              if (mounted) setState(() {});
            },
            itemBuilder: (context) => aiService.modelNames.map((model) {
              return PopupMenuItem(
                value: model,
                child: Row(
                  children: [
                    if (model == aiService.selectedModel)
                      const Icon(Icons.check, size: 16, color: Colors.green),
                    if (model == aiService.selectedModel)
                      const SizedBox(width: 8),
                    Text(model),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // API Key状态提示
          if (aiService.apiKey.isEmpty && aiService.selectedModel != 'Ollama')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请先在设置中配置 ${aiService.selectedModel} 的 API Key',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showApiKeyDialog(),
                    child: const Text('配置'),
                  ),
                ],
              ),
            ),
          
          // 快捷操作按钮
          if (_showQuickActions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionChip(
                      icon: Icons.create_new_folder,
                      label: '创建项目',
                      color: Colors.blue,
                      onTap: _onCreateProject,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      icon: Icons.code,
                      label: '生成代码',
                      color: Colors.green,
                      onTap: _onGenerateCode,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      icon: Icons.help_outline,
                      label: '解释代码',
                      color: Colors.purple,
                      onTap: _onExplainCode,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      icon: Icons.bug_report,
                      label: '调试代码',
                      color: Colors.red,
                      onTap: _onDebugCode,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      icon: Icons.translate,
                      label: '代码转换',
                      color: Colors.orange,
                      onTap: _onConvertCode,
                    ),
                  ],
                ),
              ),
            ),
          
          // 待保存代码提示
          if (_pendingCode != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.code, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '检测到生成的 $_pendingLanguage 代码，是否保存到文件？',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _savePendingCode,
                    child: const Text('保存'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _pendingCode = null;
                      _pendingLanguage = null;
                    }),
                    child: const Text('忽略'),
                  ),
                ],
              ),
            ),
          
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI 编程助手',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '当前模型: ${aiService.selectedModel}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        // 快捷操作示例
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildSuggestionChip('帮我创建一个Flutter项目'),
                            _buildSuggestionChip('写一个快速排序算法'),
                            _buildSuggestionChip('解释一下这段代码'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showApiKeyDialog(),
                          icon: const Icon(Icons.key),
                          label: const Text('配置 API Key'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          
          // 加载指示器
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('AI正在思考...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          
          // 输入区域
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 代码粘贴区（可折叠）
                if (_pastedCode != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.code, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '待解释代码 (${_pastedCode!.length} 字符)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _pastedCode = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '输入代码问题，或使用快捷操作...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: _pasteFromClipboard,
                            tooltip: '粘贴代码',
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _pastedCode;

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() => _pastedCode = data.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已粘贴代码，可以输入问题让AI解释')),
        );
      }
    }
  }

  void _onCreateProject() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CreateProjectSheet(
        onProjectCreated: (name, template) async {
          Navigator.pop(context);
          await _createProject(name, template);
        },
      ),
    );
  }

  Future<void> _createProject(String name, String template) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final projectPath = p.join(selectedDirectory, name);
      
      _addMessage(ChatMessage(
        text: '正在为您创建 $name 项目...',
        isUser: false,
        time: _getCurrentTime(),
      ));

      String result;
      if (aiService.isConfigured) {
        result = await aiService.generateProjectWithAI(projectPath, '创建一个$name的$template项目');
      } else {
        result = await aiService.createProject(projectPath, template);
      }

      _addMessage(ChatMessage(
        text: result,
        isUser: false,
        time: _getCurrentTime(),
      ));
    } catch (e) {
      _addMessage(ChatMessage(
        text: '创建失败: $e',
        isUser: false,
        time: _getCurrentTime(),
      ));
    }
  }

  void _onGenerateCode() {
    _showQuickActionDialog(
      title: '生成代码',
      hintText: '描述你想要生成的代码功能...',
      exampleHints: [
        '写一个Python的快速排序算法',
        '创建一个Flutter登录页面',
        '用Java实现一个链表',
      ],
      onSubmit: (description) async {
        String language = 'dart';
        if (description.toLowerCase().contains('python')) language = 'python';
        if (description.toLowerCase().contains('java')) language = 'java';
        if (description.toLowerCase().contains('javascript') || description.toLowerCase().contains('js')) language = 'javascript';
        if (description.toLowerCase().contains('go')) language = 'go';
        if (description.toLowerCase().contains('rust')) language = 'rust';
        
        final response = await aiService.generateCode(language, description);
        _addMessage(ChatMessage(
          text: response,
          isUser: false,
          time: _getCurrentTime(),
        ));
      },
    );
  }

  void _onExplainCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解释代码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请粘贴要解释的代码，然后发送即可'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _pasteFromClipboard();
              },
              icon: const Icon(Icons.paste),
              label: const Text('粘贴代码'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _onDebugCode() {
    _showQuickActionDialog(
      title: '调试代码',
      hintText: '粘贴代码并描述遇到的问题...',
      exampleHints: [
        '这段代码报错了，帮我看看',
        '代码运行结果不对',
        '性能有问题吗？',
      ],
      onSubmit: (description) async {
        final code = _pastedCode ?? '';
        final prompt = '''请帮我调试以下代码：

代码：
```
$code
```

问题描述：$description

请分析问题原因并提供修复方案。''';
        
        final response = await aiService.chat(prompt);
        _addMessage(ChatMessage(
          text: response,
          isUser: false,
          time: _getCurrentTime(),
        ));
      },
    );
  }

  void _onConvertCode() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ConvertCodeSheet(
        onConvert: (fromLang, toLang, code) async {
          Navigator.pop(context);
          final prompt = '''请将以下$fromLang代码转换为$toLang代码：

```
$code
```

只返回转换后的代码，并简要说明主要改动。''';
          
          final response = await aiService.chat(prompt);
          _addMessage(ChatMessage(
            text: response,
            isUser: false,
            time: _getCurrentTime(),
          ));
        },
      ),
    );
  }

  void _showQuickActionDialog({
    required String title,
    required String hintText,
    required List<String> exampleHints,
    required Function(String) onSubmit,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: exampleHints.map((hint) {
                return ActionChip(
                  label: Text(hint, style: const TextStyle(fontSize: 10)),
                  onPressed: () {
                    controller.text = hint;
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              onSubmit(controller.text.trim());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _savePendingCode() async {
    if (_pendingCode == null) return;
    
    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存代码文件',
        fileName: 'generated_code.${_getExtension(_pendingLanguage ?? 'txt')}',
      );
      
      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(_pendingCode!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已保存到: ${outputPath.split('/').last}'),
              action: SnackBarAction(
                label: '打开',
                onPressed: () {
                  // 可以导航到编辑器
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
    
    setState(() {
      _pendingCode = null;
      _pendingLanguage = null;
    });
  }

  String _getExtension(String language) {
    const extensions = {
      'dart': 'dart',
      'python': 'py',
      'java': 'java',
      'javascript': 'js',
      'go': 'go',
      'rust': 'rs',
      'c': 'c',
      'cpp': 'cpp',
      'ruby': 'rb',
      'swift': 'swift',
      'kotlin': 'kt',
      'typescript': 'ts',
    };
    return extensions[language.toLowerCase()] ?? 'txt';
  }

  String _getCurrentTime() {
    return DateTime.now().toString().substring(11, 16);
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _sendMessage() async {
    String text = _messageController.text.trim();
    
    // 如果有待解释的代码
    if (_pastedCode != null && text.isNotEmpty) {
      text = '$text\n\n```\n$_pastedCode\n```';
      setState(() => _pastedCode = null);
    }
    
    if (text.isEmpty || _isLoading) return;

    // 添加用户消息
    _addMessage(ChatMessage(
      text: text,
      isUser: true,
      time: _getCurrentTime(),
    ));

    _messageController.clear();
    setState(() => _isLoading = true);

    try {
      // 识别意图
      final intent = aiService.recognizeIntent(text);
      String response;
      List<String> createdFiles = [];
      
      switch (intent.type) {
        case AIIntentType.createProject:
          // 创建项目
          response = '好的，我来帮您创建项目...\n\n';
          final name = intent.params['name'] ?? 'my_project';
          final template = intent.params['template'] ?? 'flutter';
          
          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
          if (selectedDirectory == null) {
            response = '已取消';
            break;
          }
          
          final projectPath = p.join(selectedDirectory, name);
          if (aiService.isConfigured) {
            response += await aiService.generateProjectWithAI(projectPath, text);
          } else {
            response += await aiService.createProject(projectPath, template);
          }
          break;
          
        case AIIntentType.generateCode:
          response = await aiService.generateCode(
            intent.params['language'] ?? 'dart',
            text,
          );
          // 自动检测并保存代码文件
          createdFiles = await _autoSaveCodeFromResponse(response, text);
          if (createdFiles.isNotEmpty) {
            response += '\n\n---\n✅ 已自动保存 ${createdFiles.length} 个文件';
          }
          break;
          
        case AIIntentType.explainCode:
          // 尝试提取代码块
          final codeMatch = RegExp(r'```[\s\S]*?```').firstMatch(text);
          if (codeMatch != null) {
            final code = codeMatch.group(0)!.replaceAll('```', '').trim();
            response = await aiService.explainCode(code);
          } else {
            response = '请提供要解释的代码，可以直接粘贴代码后发送';
          }
          break;
          
        default:
          response = await aiService.chat(text);
          // 检查响应中是否包含代码块，自动保存
          createdFiles = await _autoSaveCodeFromResponse(response, text);
          if (createdFiles.isNotEmpty) {
            response += '\n\n---\n✅ 已自动保存 ${createdFiles.length} 个文件';
          }
      }
      
      if (mounted) {
        _addMessage(ChatMessage(
          text: response,
          isUser: false,
          time: _getCurrentTime(),
        ));
      }
    } catch (e) {
      if (mounted) {
        _addMessage(ChatMessage(
          text: '请求出错: $e',
          isUser: false,
          time: _getCurrentTime(),
        ));
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 从AI响应中自动提取并保存代码
  Future<List<String>> _autoSaveCodeFromResponse(String response, String userPrompt) async {
    final createdFiles = <String>[];
    
    // 匹配代码块：```language\n代码\n```
    final codeBlockPattern = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
    final matches = codeBlockPattern.allMatches(response);
    
    if (matches.isEmpty) return createdFiles;
    
    // 获取保存目录
    String? saveDir = await FilePicker.platform.getDirectoryPath();
    if (saveDir == null) return createdFiles;
    
    // 从用户提示中推断项目/文件名
    String baseName = 'generated';
    if (userPrompt.contains('创建') || userPrompt.contains('生成')) {
      // 尝试提取项目名
      final nameMatch = RegExp(r'(?:创建|生成|写一个|帮我)[\s]*([a-zA-Z_\u4e00-\u9fa5]+)').firstMatch(userPrompt);
      if (nameMatch != null) {
        baseName = nameMatch.group(1)!.replaceAll(RegExp(r'[^\w]'), '_');
      }
    }
    
    int fileIndex = 1;
    for (final match in matches) {
      final language = match.group(1)?.trim() ?? 'txt';
      final code = match.group(2)?.trim() ?? '';
      
      if (code.isEmpty) continue;
      
      // 根据语言确定文件扩展名
      final extension = _getExtensionFromLanguage(language);
      
      // 尝试从代码中提取文件名
      String fileName = '$baseName$fileIndex$extension';
      
      // 检查代码中是否有文件名注释
      final fileNameMatch = RegExp(r'(?:文件名|filename|file)[:\s]*([a-zA-Z0-9_\-\.]+)').firstMatch(code);
      if (fileNameMatch != null) {
        fileName = fileNameMatch.group(1)!;
      }
      
      // 保存文件
      final filePath = p.join(saveDir, fileName);
      final file = File(filePath);
      
      try {
        await file.writeAsString(code);
        createdFiles.add(filePath);
        fileIndex++;
      } catch (e) {
        // 保存失败，继续下一个
      }
    }
    
    return createdFiles;
  }
  
  /// 根据语言获取文件扩展名
  String _getExtensionFromLanguage(String language) {
    const extensions = {
      'dart': '.dart',
      'python': '.py',
      'java': '.java',
      'javascript': '.js',
      'js': '.js',
      'typescript': '.ts',
      'ts': '.ts',
      'kotlin': '.kt',
      'swift': '.swift',
      'go': '.go',
      'rust': '.rs',
      'c': '.c',
      'cpp': '.cpp',
      'c++': '.cpp',
      'csharp': '.cs',
      'c#': '.cs',
      'html': '.html',
      'css': '.css',
      'scss': '.scss',
      'json': '.json',
      'xml': '.xml',
      'yaml': '.yaml',
      'yml': '.yml',
      'sql': '.sql',
      'shell': '.sh',
      'bash': '.sh',
      'markdown': '.md',
      'md': '.md',
    };
    return extensions[language.toLowerCase()] ?? '.txt';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: aiService.apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${aiService.selectedModel} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '输入API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '获取API Key:',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getKeyUrl(aiService.selectedModel),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
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
              final key = controller.text.trim();
              if (key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入API Key')),
                );
                return;
              }
              
              final success = await aiService.saveApiKey(key);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key已保存')),
                );
                setState(() {});
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  String _getKeyUrl(String model) {
    const urls = {
      'DeepSeek': 'platform.deepseek.com',
      '通义千问': 'dashscope.aliyuncs.com',
      '豆包': 'console.volcengine.com/ark',
      'Minimax': 'api.minimax.chat',
      '智谱清言': 'open.bigmodel.cn',
      'Gemini': 'makersuite.google.com',
      'GPT-4': 'platform.openai.com',
      'Claude': 'console.anthropic.com',
    };
    return urls[model] ?? '';
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser 
        ? Alignment.centerRight 
        : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: message.isUser
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 检测并高亮代码块
            _buildMessageContent(message.text),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!message.isUser && message.text.contains('```'))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () => _copyCodeFromMessage(message.text),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '复制代码',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(String text) {
    // 检测代码块
    final codePattern = RegExp(r'```(\w*)\n?([\s\S]*?)```');
    final matches = codePattern.allMatches(text);
    
    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    
    // 分割并构建混合内容
    final List<InlineSpan> spans = [];
    int lastEnd = 0;
    
    for (final match in matches) {
      // 添加匹配前的文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      
      // 添加代码块
      final code = match.group(2)?.trim() ?? '';
      final language = match.group(1) ?? '';
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    language,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ));
      
      lastEnd = match.end;
    }
    
    // 添加剩余文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    
    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 14),
    );
  }

  void _copyCodeFromMessage(String text) {
    final codePattern = RegExp(r'```\w*\n?([\s\S]*?)```');
    final match = codePattern.firstMatch(text);
    if (match != null) {
      final code = match.group(1)?.trim() ?? '';
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('代码已复制到剪贴板')),
      );
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

/// 创建项目底部弹窗
class _CreateProjectSheet extends StatefulWidget {
  final Function(String name, String template) onProjectCreated;
  
  const _CreateProjectSheet({required this.onProjectCreated});

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _nameController = TextEditingController(text: 'my_project');
  String _selectedTemplate = 'flutter';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.create_new_folder, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '创建项目',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '项目名称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.folder),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '选择模板',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTemplateChip('flutter', 'Flutter', Icons.flutter_dash, Colors.blue),
              _buildTemplateChip('python', 'Python', Icons.code, Colors.green),
              _buildTemplateChip('nodejs', 'Node.js', Icons.javascript, Colors.amber),
              _buildTemplateChip('android', 'Android', Icons.android, Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入项目名称')),
                  );
                  return;
                }
                widget.onProjectCreated(name, _selectedTemplate);
              },
              icon: const Icon(Icons.add),
              label: const Text('创建项目'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedTemplate == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() => _selectedTemplate = value);
      },
    );
  }
}

/// 代码转换底部弹窗
class _ConvertCodeSheet extends StatefulWidget {
  final Function(String fromLang, String toLang, String code) onConvert;
  
  const _ConvertCodeSheet({required this.onConvert});

  @override
  State<_ConvertCodeSheet> createState() => _ConvertCodeSheetState();
}

class _ConvertCodeSheetState extends State<_ConvertCodeSheet> {
  String _fromLang = 'Python';
  String _toLang = 'Dart';

  final List<String> _languages = [
    'Python', 'Dart', 'Java', 'JavaScript', 'TypeScript',
    'Go', 'Rust', 'C', 'C++', 'Swift', 'Kotlin', 'Ruby',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '代码转换',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _fromLang,
                  decoration: const InputDecoration(
                    labelText: '源语言',
                    border: OutlineInputBorder(),
                  ),
                  items: _languages.map((lang) {
                    return DropdownMenuItem(value: lang, child: Text(lang));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _fromLang = value!);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.primary),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _toLang,
                  decoration: const InputDecoration(
                    labelText: '目标语言',
                    border: OutlineInputBorder(),
                  ),
                  items: _languages.map((lang) {
                    return DropdownMenuItem(value: lang, child: Text(lang));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _toLang = value!);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '请在聊天框中粘贴要转换的代码',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                widget.onConvert(_fromLang, _toLang, '');
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('开始转换'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
