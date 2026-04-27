import 'package:flutter/material.dart';

class CodeEditorPage extends StatefulWidget {
  const CodeEditorPage({super.key});

  @override
  State<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<CodeEditorPage> {
  final TextEditingController _controller = TextEditingController(text: '''
// Miss IDE v2 - 代码编辑器
// 支持语法高亮、自动补全

void main() {
  print("Hello, Miss IDE!");
}

class Example {
  String name;
  int age;
  
  Example(this.name, this.age);
  
  void sayHello() {
    print("Hello, I'm $name");
  }
}
''');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代码编辑器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已保存')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: () {
              _showBuildDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 文件标签栏
          Container(
            height: 40,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTab('main.dart', true),
                _buildTab('example.dart', false),
              ],
            ),
          ),
          // 代码编辑区
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          // 底部状态栏
          Container(
            height: 24,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Text('main.dart', style: TextStyle(fontSize: 12)),
                const Spacer(),
                const Text('UTF-8', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                const Text('Dart', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String name, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive 
          ? Theme.of(context).colorScheme.surface
          : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isActive 
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(name, style: const TextStyle(fontSize: 12)),
    );
  }

  void _showBuildDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('构建项目'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在编译...'),
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
    
    // 模拟构建
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('构建成功！')),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
