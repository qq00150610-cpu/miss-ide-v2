import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/build_result.dart';
import '../features/ai/ai_service.dart';
import '../features/ai/ai_provider.dart';
import '../features/editor/code_editor.dart';
import '../core/terminal/terminal_emulator.dart';
import '../utils/logger.dart';

/// 项目状态
class ProjectState {
  final List<Project> recentProjects;
  final Project? currentProject;
  final bool isLoading;
  final String? error;

  const ProjectState({
    this.recentProjects = const [],
    this.currentProject,
    this.isLoading = false,
    this.error,
  });

  ProjectState copyWith({
    List<Project>? recentProjects,
    Project? currentProject,
    bool? isLoading,
    String? error,
  }) {
    return ProjectState(
      recentProjects: recentProjects ?? this.recentProjects,
      currentProject: currentProject ?? this.currentProject,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 项目Provider
final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(const ProjectState());

  Future<void> openProject(Project project) async {
    state = state.copyWith(
      currentProject: project,
      isLoading: true,
    );
    logger.i(LogTags.project, 'Opened project: ${project.name}');
  }

  Future<void> closeProject() async {
    state = state.copyWith(
      currentProject: null,
      isLoading: false,
    );
  }

  void addRecentProject(Project project) {
    final recent = [project, ...state.recentProjects.where((p) => p.id != project.id)];
    if (recent.length > 10) {
      recent.removeLast();
    }
    state = state.copyWith(recentProjects: recent);
  }
}

/// 编辑器Provider
final editorProvider = ChangeNotifierProvider<CodeEditorController>((ref) {
  return CodeEditorController();
});

/// 终端状态
class TerminalState {
  final List<TerminalOutput> outputs;
  final bool isRunning;
  final String? workingDirectory;

  const TerminalState({
    this.outputs = const [],
    this.isRunning = false,
    this.workingDirectory,
  });
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>((ref) {
  return TerminalNotifier();
});

class TerminalNotifier extends StateNotifier<TerminalState> {
  final TerminalEmulator _emulator = terminalEmulator;
  StreamSubscription<TerminalOutput>? _subscription;

  TerminalNotifier() : super(const TerminalState()) {
    _init();
  }

  void _init() {
    _emulator.init(null);
    _subscription = _emulator.outputStream.listen((output) {
      state = state.copyWith(
        outputs: [...state.outputs, output],
      );
    });
  }

  Future<void> execute(String command) async {
    await _emulator.execute(command);
    state = state.copyWith(isRunning: _emulator.isRunning);
  }

  void clear() {
    _emulator.clearHistory();
    state = state.copyWith(outputs: []);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 构建状态
class BuildState {
  final BuildStatus status;
  final BuildResult? result;
  final double? progress;
  final String? currentMessage;

  const BuildState({
    this.status = BuildStatus.idle,
    this.result,
    this.progress,
    this.currentMessage,
  });
}

final buildProvider = StateNotifierProvider<BuildNotifier, BuildState>((ref) {
  return BuildNotifier();
});

class BuildNotifier extends StateNotifier<BuildState> {
  BuildNotifier() : super(const BuildState());

  void updateStatus(BuildStatus status) {
    state = state.copyWith(status: status);
  }

  void updateProgress(double progress, String? message) {
    state = state.copyWith(progress: progress, currentMessage: message);
  }

  void setResult(BuildResult result) {
    state = state.copyWith(
      status: result.status,
      result: result,
      progress: result.isSuccess ? 1.0 : null,
    );
  }
}

/// AI状态
class AIState {
  final bool isProcessing;
  final String? currentResponse;
  final List<String> conversationHistory;
  final String? error;

  const AIState({
    this.isProcessing = false,
    this.currentResponse,
    this.conversationHistory = const [],
    this.error,
  });
}

final aiProvider = StateNotifierProvider<AINotifier, AIState>((ref) {
  return AINotifier();
});

class AINotifier extends StateNotifier<AIState> {
  final AIService _service = aiService;

  AINotifier() : super(const AIState());

  Future<void> complete(CodeCompletionContext context) async {
    state = state.copyWith(isProcessing: true, error: null);

    final buffer = StringBuffer();

    await for (final response in _service.complete(context)) {
      if (response is AITokenResponse) {
        buffer.write(response.text);
        state = state.copyWith(currentResponse: buffer.toString());
      } else if (response is AIErrorResponse) {
        state = state.copyWith(error: response.message, isProcessing: false);
        break;
      } else if (response is AIDoneResponse) {
        state = state.copyWith(
          isProcessing: false,
          currentResponse: response.fullContent,
          conversationHistory: [...state.conversationHistory, buffer.toString()],
        );
      }
    }
  }

  Future<void> chat(String message) async {
    state = state.copyWith(isProcessing: true, error: null);

    final buffer = StringBuffer();

    await for (final response in _service.chat(message)) {
      if (response is AITokenResponse) {
        buffer.write(response.text);
        state = state.copyWith(currentResponse: buffer.toString());
      } else if (response is AIErrorResponse) {
        state = state.copyWith(error: response.message, isProcessing: false);
        break;
      } else if (response is AIDoneResponse) {
        state = state.copyWith(
          isProcessing: false,
          currentResponse: response.fullContent,
          conversationHistory: [...state.conversationHistory, buffer.toString()],
        );
      }
    }
  }

  void clearResponse() {
    state = state.copyWith(currentResponse: null);
  }
}

/// 设置状态
class SettingsState {
  final ThemeMode themeMode;
  final double fontSize;
  final bool wordWrap;
  final bool showLineNumbers;
  final bool autoSave;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.fontSize = 14.0,
    this.wordWrap = true,
    this.showLineNumbers = true,
    this.autoSave = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    bool? wordWrap,
    bool? showLineNumbers,
    bool? autoSave,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      wordWrap: wordWrap ?? this.wordWrap,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      autoSave: autoSave ?? this.autoSave,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
  }

  void setWordWrap(bool enabled) {
    state = state.copyWith(wordWrap: enabled);
  }

  void setShowLineNumbers(bool enabled) {
    state = state.copyWith(showLineNumbers: enabled);
  }

  void setAutoSave(bool enabled) {
    state = state.copyWith(autoSave: enabled);
  }
}
