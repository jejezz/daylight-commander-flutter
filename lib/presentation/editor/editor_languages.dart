import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cmake.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/groovy.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/languages/perl.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/protobuf.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';

/// 확장자 → 문법 키. 문법이 따로 없는 형식은 가장 가까운 것으로 대신한다
/// (toml→ini, env→properties 등). 표에 없으면 강조 없는 'plaintext'.
const _extensionToLanguage = {
  'dart': 'dart',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'swift': 'swift',
  'c': 'c',
  'h': 'c',
  'cpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'cs': 'csharp',
  'go': 'go',
  'rs': 'rust',
  'py': 'python',
  'js': 'javascript',
  'mjs': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'php': 'php',
  'rb': 'ruby',
  'lua': 'lua',
  'pl': 'perl',
  'groovy': 'groovy',
  'scala': 'scala',
  'proto': 'protobuf',
  'graphql': 'graphql',
  'gradle': 'gradle',
  'cmake': 'cmake',
  'mk': 'makefile',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'bat': 'dos',
  'cmd': 'dos',
  'ps1': 'powershell',
  'html': 'xml',
  'htm': 'xml',
  'xml': 'xml',
  'svg': 'xml',
  'plist': 'xml',
  'css': 'css',
  'scss': 'scss',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'toml': 'ini',
  'ini': 'ini',
  'conf': 'ini',
  'cfg': 'ini',
  'properties': 'properties',
  'env': 'properties',
  'sql': 'sql',
  'md': 'markdown',
  'markdown': 'markdown',
  'diff': 'diff',
  'patch': 'diff',
};

/// 확장자가 없거나 이름 자체가 형식을 말해 주는 파일.
const _fileNameToLanguage = {
  'dockerfile': 'dockerfile',
  'makefile': 'makefile',
  'cmakelists.txt': 'cmake',
  '.gitignore': 'plaintext',
  '.editorconfig': 'ini',
  '.env': 'properties',
  'nginx.conf': 'nginx',
};

final _modes = <String, Mode>{
  'json': langJson,
  'xml': langXml,
  'yaml': langYaml,
  'css': langCss,
  'scss': langScss,
  'java': langJava,
  'kotlin': langKotlin,
  'swift': langSwift,
  'c': langC,
  'cpp': langCpp,
  'csharp': langCsharp,
  'go': langGo,
  'rust': langRust,
  'python': langPython,
  'javascript': langJavascript,
  'typescript': langTypescript,
  'php': langPhp,
  'ruby': langRuby,
  'bash': langBash,
  'powershell': langPowershell,
  'dos': langDos,
  'sql': langSql,
  'ini': langIni,
  'properties': langProperties,
  'markdown': langMarkdown,
  'dockerfile': langDockerfile,
  'makefile': langMakefile,
  'cmake': langCmake,
  'gradle': langGradle,
  'plaintext': langPlaintext,
  'lua': langLua,
  'perl': langPerl,
  'diff': langDiff,
  'nginx': langNginx,
  'protobuf': langProtobuf,
  'graphql': langGraphql,
  'groovy': langGroovy,
  'scala': langScala,
  'dart': langDart,
};

/// [fileName]에 맞는 문법 키. 모르면 'plaintext'.
String editorLanguageFor(String fileName) {
  final lower = fileName.toLowerCase();
  final byName = _fileNameToLanguage[lower];
  if (byName != null) return byName;
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) return 'plaintext';
  return _extensionToLanguage[lower.substring(dot + 1)] ?? 'plaintext';
}

/// 문법 키의 re_highlight 규칙. 모르는 키는 'plaintext'.
Mode editorModeFor(String language) => _modes[language] ?? _modes['plaintext']!;

/// 마크다운이면 미리보기를 쓸 수 있다.
bool isMarkdownLanguage(String language) => language == 'markdown';

const _cStyle = ('//', '/*', '*/');
const _hash = ('#', null, null);
const _commentStyles = <String, (String?, String?, String?)>{
  'dart': _cStyle,
  'java': _cStyle,
  'kotlin': _cStyle,
  'swift': _cStyle,
  'c': _cStyle,
  'cpp': _cStyle,
  'csharp': _cStyle,
  'go': _cStyle,
  'rust': _cStyle,
  'javascript': _cStyle,
  'typescript': _cStyle,
  'php': _cStyle,
  'scala': _cStyle,
  'groovy': _cStyle,
  'gradle': _cStyle,
  'scss': _cStyle,
  'protobuf': _cStyle,
  'css': (null, '/*', '*/'),
  'python': _hash,
  'ruby': _hash,
  'bash': _hash,
  'yaml': _hash,
  'properties': _hash,
  'dockerfile': _hash,
  'makefile': _hash,
  'cmake': _hash,
  'perl': _hash,
  'nginx': _hash,
  'powershell': _hash,
  'graphql': _hash,
  'ini': (';', null, null),
  'sql': ('--', '/*', '*/'),
  'lua': ('--', '--[[', ']]'),
  'dos': ('REM ', null, null),
  'xml': (null, '<!--', '-->'),
  'markdown': (null, '<!--', '-->'),
};

/// 주석 토글(Ctrl/Cmd+/)이 쓰는 규칙. 주석이 없는 형식(plaintext, json 등)은 null.
CodeCommentFormatter? editorCommentFormatterFor(String language) {
  final style = _commentStyles[language];
  if (style == null) return null;
  return DefaultCodeCommentFormatter(
    singleLinePrefix: style.$1,
    multiLinePrefix: style.$2,
    multiLineSuffix: style.$3,
  );
}
