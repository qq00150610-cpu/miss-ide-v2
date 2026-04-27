import 'package:flutter/material.dart';

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  final List<ProjectItem> _recentProjects = [
    ProjectItem(
      name: 'my_app',
      path: '/storage/emulated/0/Projects/my_app',
      type: ProjectType.flutter,
      lastModified: '2024-04-26',
    ),
    ProjectItem(
      name: 'example_android',
      path: '/storage/emulated/0/Projects/example_android',
      type: ProjectType.android,
      lastModified: '2024-04-25',
    ),
    ProjectItem(
      name: 'kotlin_demo',
      path: '/storage/emulated/0/Projects/kotlin_demo',
      type: ProjectType.kotlin,
      lastModified: '2024-04-20',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miss IDE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷操作
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildQuickAction(Icons.create_new_folder, '导入项目', Colors.blue),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.add, '新建项目', Colors.green),
                const SizedBox(width: 12),
                _buildQuickAction(Icons.download, '克隆仓库', Colors.orange),
              ],
            ),
          ),
          
          // 最近项目
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '最近项目',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('查看全部'),
                ),
              ],
            ),
          ),
          
          // 项目列表
          Expanded(
            child: _recentProjects.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无项目'),
                        SizedBox(height: 8),
                        Text('点击上方按钮创建或导入项目'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recentProjects.length,
                    itemBuilder: (context, index) {
                      return _buildProjectCard(_recentProjects[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新建项目'),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectItem project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getProjectColor(project.type).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getProjectIcon(project.type),
            color: _getProjectColor(project.type),
          ),
        ),
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.path,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              project.type.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: _getProjectColor(project.type),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              setState(() {
                _recentProjects.remove(project);
              });
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: Text('打开')),
            const PopupMenuItem(value: 'terminal', child: Text('终端')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () {
          // 打开项目
        },
      ),
    );
  }

  IconData _getProjectIcon(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Icons.flutter_dash;
      case ProjectType.android:
        return Icons.android;
      case ProjectType.kotlin:
        return Icons.code;
      case ProjectType.java:
        return Icons.coffee;
    }
  }

  Color _getProjectColor(ProjectType type) {
    switch (type) {
      case ProjectType.flutter:
        return Colors.blue;
      case ProjectType.android:
        return Colors.green;
      case ProjectType.kotlin:
        return Colors.purple;
      case ProjectType.java:
        return Colors.orange;
    }
  }

  void _showNewProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flutter_dash, color: Colors.blue),
              title: const Text('Flutter 项目'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.android, color: Colors.green),
              title: const Text('Android 项目'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.purple),
              title: const Text('Kotlin 项目'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

enum ProjectType { flutter, android, kotlin, java }

class ProjectItem {
  final String name;
  final String path;
  final ProjectType type;
  final String lastModified;

  ProjectItem({
    required this.name,
    required this.path,
    required this.type,
    required this.lastModified,
  });
}
