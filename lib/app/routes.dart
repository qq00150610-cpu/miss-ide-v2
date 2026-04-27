import 'package:flutter/material.dart';

/// Miss IDE 路由配置
class AppRoutes {
  AppRoutes._();

  // 路由名称
  static const String home = '/';
  static const String project = '/project';
  static const String projectDetail = '/project/:id';
  static const String editor = '/editor';
  static const String terminal = '/terminal';
  static const String aiAssistant = '/ai';
  static const String settings = '/settings';
  static const String aiSettings = '/settings/ai';
  static const String buildSettings = '/settings/build';
  static const String themeSettings = '/settings/theme';
  static const String newProject = '/project/new';
  static const String importProject = '/project/import';
}

/// 路由观察者
class RouteObserver {
  static final RouteObserver _instance = RouteObserver._internal();
  factory RouteObserver() => _instance;
  RouteObserver._internal();

  final List<RouteChangeListener> _listeners = [];

  void addListener(RouteChangeListener listener) {
    _listeners.add(listener);
  }

  void removeListener(RouteChangeListener listener) {
    _listeners.remove(listener);
  }

  void notifyListeners(String? from, String to) {
    for (final listener in _listeners) {
      listener.onRouteChange(from, to);
    }
  }
}

abstract class RouteChangeListener {
  void onRouteChange(String? from, String to);
}

/// 导航助手
class NavigatorHelper {
  static void navigateTo(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  static void navigateToReplacement(BuildContext context, String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  static void navigateToAndClearStack(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (route) => false,
    );
  }

  static void goBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  static void goBackWithResult<T>(BuildContext context, T result) {
    Navigator.of(context).pop(result);
  }
}

/// 路由配置
class AppRouteConfig {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // 主页
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const _HomePage(),
          settings: settings,
        );

      // 设置页面
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const _SettingsPage(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const _NotFoundPage(),
          settings: settings,
        );
    }
  }
}

// 占位页面
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home')),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Settings')),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: const Center(
        child: Text('404 - Page not found'),
      ),
    );
  }
}
