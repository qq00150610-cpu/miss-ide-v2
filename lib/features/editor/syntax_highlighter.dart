import 'dart:convert';
import '../../utils/logger.dart';

/// 语法高亮定义
class SyntaxDefinition {
  final String name;
  final String extension;
  final List<SyntaxPattern> patterns;
  final List<String> keywords;
  final String? commentSingle;
  final String? commentStart;
  final String? commentEnd;
  final List<String> stringDelimiters;

  const SyntaxDefinition({
    required this.name,
    required this.extension,
    required this.patterns,
    required this.keywords,
    this.commentSingle,
    this.commentStart,
    this.commentEnd,
    this.stringDelimiters = const ['"', "'", '`'],
  });
}

class SyntaxPattern {
  final RegExp pattern;
  final String tokenType;

  const SyntaxPattern(this.pattern, this.tokenType);
}

/// 语法高亮类型
class SyntaxTokenType {
  static const String keyword = 'keyword';
  static const String string = 'string';
  static const String number = 'number';
  static const String comment = 'comment';
  static const String annotation = 'annotation';
  static const String type = 'type';
  static const String function = 'function';
  static const String variable = 'variable';
  static const String operator = 'operator';
  static const String punctuation = 'punctuation';
  static const String constant = 'constant';
}

/// 语法高亮引擎
class SyntaxHighlighter {
  static final Map<String, SyntaxDefinition> _definitions = {
    'kt': _kotlinSyntax,
    'dart': _dartSyntax,
    'java': _javaSyntax,
    'py': _pythonSyntax,
    'js': _javascriptSyntax,
    'ts': _typescriptSyntax,
    'html': _htmlSyntax,
    'css': _cssSyntax,
    'json': _jsonSyntax,
    'yaml': _yamlSyntax,
    'xml': _xmlSyntax,
    'md': _markdownSyntax,
  };

  /// 获取语法定义
  static SyntaxDefinition? getDefinition(String extension) {
    return _definitions[extension.toLowerCase()];
  }

  /// 词法分析
  static List<SyntaxToken> tokenize(String code, String extension) {
    final definition = getDefinition(extension);
    if (definition == null) {
      return [SyntaxToken(code, SyntaxTokenType.variable)];
    }

    final tokens = <SyntaxToken>[];
    var index = 0;

    while (index < code.length) {
      // 跳过空白
      if (code[index] == ' ' || code[index] == '\t' || code[index] == '\n') {
        var whitespace = '';
        while (index < code.length && 
               (code[index] == ' ' || code[index] == '\t' || code[index] == '\n')) {
          whitespace += code[index++];
        }
        tokens.add(SyntaxToken(whitespace, SyntaxTokenType.variable));
        continue;
      }

      // 注释
      if (definition.commentSingle != null) {
        if (code.substring(index).startsWith(definition.commentSingle!)) {
          var comment = '';
          while (index < code.length && code[index] != '\n') {
            comment += code[index++];
          }
          tokens.add(SyntaxToken(comment, SyntaxTokenType.comment));
          continue;
        }
      }

      // 字符串
      for (final delimiter in definition.stringDelimiters) {
        if (code[index] == delimiter) {
          var str = delimiter;
          index++;
          while (index < code.length && code[index] != delimiter) {
            if (code[index] == '\\' && index + 1 < code.length) {
              str += code[index++];
            }
            str += code[index++];
          }
          if (index < code.length) {
            str += code[index++];
          }
          tokens.add(SyntaxToken(str, SyntaxTokenType.string));
          continue;
        }
      }

      // 数字
      if (RegExp(r'[0-9]').hasMatch(code[index])) {
        var num = '';
        while (index < code.length && RegExp(r'[0-9.]').hasMatch(code[index])) {
          num += code[index++];
        }
        tokens.add(SyntaxToken(num, SyntaxTokenType.number));
        continue;
      }

      // 标识符和关键字
      if (RegExp(r'[a-zA-Z_]').hasMatch(code[index])) {
        var identifier = '';
        while (index < code.length && RegExp(r'[a-zA-Z0-9_]').hasMatch(code[index])) {
          identifier += code[index++];
        }
        
        final type = definition.keywords.contains(identifier)
            ? SyntaxTokenType.keyword
            : SyntaxTokenType.variable;
        tokens.add(SyntaxToken(identifier, type));
        continue;
      }

      // 其他字符
      tokens.add(SyntaxToken(code[index], SyntaxTokenType.punctuation));
      index++;
    }

    return tokens;
  }

  // Kotlin 语法定义
  static const _kotlinSyntax = SyntaxDefinition(
    name: 'Kotlin',
    extension: 'kt',
    keywords: [
      'fun', 'val', 'var', 'class', 'interface', 'object', 'package', 'import',
      'if', 'else', 'when', 'for', 'while', 'do', 'return', 'break', 'continue',
      'try', 'catch', 'finally', 'throw', 'is', 'as', 'in', '!in', 'true', 'false', 'null',
      'override', 'open', 'abstract', 'final', 'private', 'protected', 'public', 'internal',
      'suspend', 'inline', 'noinline', 'crossinline', 'reified', 'operator', 'infix',
      'data', 'sealed', 'enum', 'companion', 'init', 'constructor', 'by', 'lazy',
      'lateinit', 'typealias', 'annotation', 'enum class', 'sealed class',
    ],
    commentSingle: '//',
    stringDelimiters: ['"', "'", '"""'],
  );

  // Dart 语法定义
  static const _dartSyntax = SyntaxDefinition(
    name: 'Dart',
    extension: 'dart',
    keywords: [
      'class', 'interface', 'enum', 'mixin', 'extension', 'typedef',
      'var', 'final', 'const', 'late', 'required', 'static', 'abstract',
      'void', 'dynamic', 'Object', 'Never', 'Null', 'Future', 'Stream',
      'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue',
      'return', 'throw', 'try', 'catch', 'finally',
      'import', 'export', 'part', 'library', 'hide', 'show', 'deferred',
      'async', 'await', 'yield', 'sync', 'factory', 'get', 'set', 'operator',
      'new', 'this', 'super', 'true', 'false', 'null',
      'is', 'as', 'in', 'assert', 'mixin', 'on',
    ],
    commentSingle: '//',
    stringDelimiters: ['"', "'", "'''"],
  );

  // Java 语法定义
  static const _javaSyntax = SyntaxDefinition(
    name: 'Java',
    extension: 'java',
    keywords: [
      'class', 'interface', 'enum', 'extends', 'implements',
      'public', 'private', 'protected', 'static', 'final', 'abstract', 'synchronized', 'volatile', 'transient', 'native',
      'void', 'byte', 'short', 'int', 'long', 'float', 'double', 'char', 'boolean',
      'if', 'else', 'switch', 'case', 'default', 'for', 'while', 'do', 'break', 'continue',
      'return', 'throw', 'try', 'catch', 'finally',
      'import', 'package', 'new', 'this', 'super', 'true', 'false', 'null',
      'instanceof', 'assert', 'enum',
    ],
    commentSingle: '//',
    stringDelimiters: ['"', "'"],
  );

  // Python 语法定义
  static const _pythonSyntax = SyntaxDefinition(
    name: 'Python',
    extension: 'py',
    keywords: [
      'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue',
      'def', 'del', 'elif', 'else', 'except', 'False', 'finally', 'for',
      'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'None',
      'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'True', 'try',
      'while', 'with', 'yield',
    ],
    commentSingle: '#',
    stringDelimiters: ['"', "'", '"""'],
  );

  // JavaScript 语法定义
  static const _javascriptSyntax = SyntaxDefinition(
    name: 'JavaScript',
    extension: 'js',
    keywords: [
      'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
      'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
      'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
      'let', 'new', 'null', 'return', 'static', 'super', 'switch', 'this',
      'throw', 'true', 'try', 'typeof', 'undefined', 'var', 'void', 'while',
      'with', 'yield', 'async', 'await', 'of', 'get', 'set',
    ],
    commentSingle: '//',
    stringDelimiters: ['"', "'", '`'],
  );

  // TypeScript 语法定义
  static const _typescriptSyntax = SyntaxDefinition(
    name: 'TypeScript',
    extension: 'ts',
    keywords: [
      'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
      'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'false',
      'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
      'let', 'new', 'null', 'return', 'static', 'super', 'switch', 'this',
      'throw', 'true', 'try', 'typeof', 'undefined', 'var', 'void', 'while',
      'with', 'yield', 'async', 'await', 'of', 'get', 'set',
      'type', 'interface', 'abstract', 'implements', 'extends', 'public', 'private', 'protected',
    ],
    commentSingle: '//',
    stringDelimiters: ['"', "'", '`'],
  );

  // HTML 语法定义
  static const _htmlSyntax = SyntaxDefinition(
    name: 'HTML',
    extension: 'html',
    keywords: [
      'html', 'head', 'body', 'div', 'span', 'p', 'a', 'img', 'ul', 'ol', 'li',
      'table', 'tr', 'td', 'th', 'form', 'input', 'button', 'select', 'option',
      'textarea', 'label', 'script', 'style', 'link', 'meta', 'title',
      'header', 'footer', 'nav', 'main', 'section', 'article', 'aside',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br', 'hr', 'strong', 'em',
    ],
    patterns: [
      SyntaxPattern(RegExp(r'<\/?[\w\s="/.:\-]+>'), SyntaxTokenType.annotation),
      SyntaxPattern(RegExp(r'class="[^"]*"'), SyntaxTokenType.variable),
      SyntaxPattern(RegExp(r'id="[^"]*"'), SyntaxTokenType.variable),
    ],
    commentSingle: null,
    commentStart: '<!--',
    commentEnd: '-->',
    stringDelimiters: ['"', "'"],
  );

  // CSS 语法定义
  static const _cssSyntax = SyntaxDefinition(
    name: 'CSS',
    extension: 'css',
    keywords: [
      'color', 'background', 'background-color', 'font', 'font-size', 'font-family',
      'margin', 'padding', 'border', 'width', 'height', 'display', 'position',
      'top', 'left', 'right', 'bottom', 'flex', 'grid', 'float', 'clear',
      'text-align', 'line-height', 'vertical-align', 'overflow', 'z-index',
    ],
    patterns: [
      SyntaxPattern(RegExp(r'#[0-9a-fA-F]{3,8}'), SyntaxTokenType.number),
      SyntaxPattern(RegExp(r'\d+px|\d+em|\d+rem|\d+%'), SyntaxTokenType.number),
    ],
    commentSingle: null,
    commentStart: '/*',
    commentEnd: '*/',
    stringDelimiters: ['"', "'"],
  );

  // JSON 语法定义
  static const _jsonSyntax = SyntaxDefinition(
    name: 'JSON',
    extension: 'json',
    keywords: ['true', 'false', 'null'],
    patterns: [
      SyntaxPattern(RegExp(r'"[^"]*"(\s*:)?'), SyntaxTokenType.string),
      SyntaxPattern(RegExp(r'-?\d+\.?\d*'), SyntaxTokenType.number),
    ],
    stringDelimiters: ['"'],
  );

  // YAML 语法定义
  static const _yamlSyntax = SyntaxDefinition(
    name: 'YAML',
    extension: 'yaml',
    keywords: ['true', 'false', 'null', 'yes', 'no', 'on', 'off'],
    patterns: [
      SyntaxPattern(RegExp(r'^[\w-]+:'), SyntaxTokenType.variable),
      SyntaxPattern(RegExp(r'^\s*-'), SyntaxTokenType.keyword),
    ],
    commentSingle: '#',
  );

  // XML 语法定义
  static const _xmlSyntax = SyntaxDefinition(
    name: 'XML',
    extension: 'xml',
    keywords: [],
    patterns: [
      SyntaxPattern(RegExp(r'<\/?[\w\s="/.:\-]+>'), SyntaxTokenType.annotation),
    ],
    commentSingle: null,
    commentStart: '<!--',
    commentEnd: '-->',
    stringDelimiters: ['"', "'"],
  );

  // Markdown 语法定义
  static const _markdownSyntax = SyntaxDefinition(
    name: 'Markdown',
    extension: 'md',
    keywords: [],
    patterns: [
      SyntaxPattern(RegExp(r'^#{1,6}\s+.+$', multiLine: true), SyntaxTokenType.keyword),
      SyntaxPattern(RegExp(r'\*\*[^*]+\*\*'), SyntaxTokenType.annotation),
      SyntaxPattern(RegExp(r'\*[^*]+\*'), SyntaxTokenType.function),
      SyntaxPattern(RegExp(r'`[^`]+`'), SyntaxTokenType.string),
      SyntaxPattern(RegExp(r'^\s*[-*+]\s+', multiLine: true), SyntaxTokenType.keyword),
    ],
    commentSingle: null,
    commentStart: '<!--',
    commentEnd: '-->',
  );
}

/// 语法标记
class SyntaxToken {
  final String text;
  final String type;

  const SyntaxToken(this.text, this.type);

  @override
  String toString() => 'Token($type: $text)';
}
