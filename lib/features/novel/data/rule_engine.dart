import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Legado 规则引擎
/// 支持 CSS 选择器、tag.index 语法、@提取、##正则替换、&&组合、||备选
class RuleEngine {
  /// 从 HTML 中提取单个文本值
  static String? extractText(String html, String rule, {String? baseUrl}) {
    if (rule.isEmpty) return null;

    // 纯正则规则：##match##replace
    if (rule.startsWith('##')) {
      return _applyPureRegex(html, rule);
    }

    // && 组合
    if (rule.contains('&&')) {
      final parts = rule.split('&&');
      final results = parts.map((p) => extractText(html, p.trim(), baseUrl: baseUrl)).where((r) => r != null && r.isNotEmpty);
      return results.join('\n');
    }

    // || 备选
    if (rule.contains('||')) {
      for (final part in rule.split('||')) {
        final result = extractText(html, part.trim(), baseUrl: baseUrl);
        if (result != null && result.isNotEmpty) return result;
      }
      return null;
    }

    // 分离选择器和提取方法，处理 ## 替换
    final (selector, extraction, regexReplace) = _parseRule(rule);

    // 执行选择器
    final doc = html_parser.parse(html);
    Element? element;

    if (selector.startsWith('tag.')) {
      element = _selectByTag(doc, selector);
    } else if (selector.isNotEmpty) {
      element = doc.querySelector(selector);
    } else {
      element = doc.documentElement;
    }

    if (element == null) return null;

    // 提取值
    var value = _extractValue(element, extraction);

    // 应用正则替换
    if (value != null && regexReplace != null) {
      value = applyReplace(value, regexReplace);
    }

    return value;
  }

  /// 从 HTML 中提取元素列表
  static List<Element> extractAll(String html, String rule) {
    if (rule.isEmpty) return [];

    // 处理 !N 语法（跳过前 N 个）
    var skipCount = 0;
    var cleanRule = rule;
    final skipMatch = RegExp(r'!(\d+)$').firstMatch(rule);
    if (skipMatch != null) {
      skipCount = int.parse(skipMatch.group(1)!);
      cleanRule = rule.substring(0, rule.length - skipMatch.group(0)!.length);
    }

    final doc = html_parser.parse(html);
    List<Element> elements;

    if (cleanRule.startsWith('tag.')) {
      elements = _selectAllByTag(doc, cleanRule);
    } else {
      elements = doc.querySelectorAll(cleanRule);
    }

    if (skipCount > 0 && elements.length > skipCount) {
      return elements.sublist(skipCount);
    }
    return elements;
  }

  /// 从元素中提取值
  static String? extractFromElement(Element element, String rule) {
    if (rule.isEmpty) return element.text.trim();

    // && 组合
    if (rule.contains('&&')) {
      final parts = rule.split('&&');
      final results = parts.map((p) => extractFromElement(element, p.trim())).where((r) => r != null && r.isNotEmpty);
      return results.join('\n');
    }

    final (selector, extraction, regexReplace) = _parseRule(rule);

    Element? target = element;
    if (selector.isNotEmpty) {
      if (selector.startsWith('tag.')) {
        target = _selectByTagFromElement(element, selector);
      } else {
        target = element.querySelector(selector);
      }
    }

    if (target == null) return null;

    var value = _extractValue(target, extraction);
    if (value != null && regexReplace != null) {
      value = applyReplace(value, regexReplace);
    }
    return value;
  }

  /// 解析规则：分离选择器、提取方法、正则替换
  static (String selector, String extraction, String? regexReplace) _parseRule(String rule) {
    // 处理 ## 正则替换部分
    String? regexReplace;
    var cleanRule = rule;

    // 找到 @ 后面的 ## 部分
    final atIndex = cleanRule.indexOf('@');
    if (atIndex > 0) {
      final afterAt = cleanRule.substring(atIndex + 1);
      final hashIndex = afterAt.indexOf('##');
      if (hashIndex >= 0) {
        regexReplace = afterAt.substring(hashIndex);
        cleanRule = cleanRule.substring(0, atIndex + 1 + hashIndex);
      }
    } else {
      // 没有 @，检查是否有 ##
      final hashIndex = cleanRule.indexOf('##');
      if (hashIndex >= 0) {
        regexReplace = cleanRule.substring(hashIndex);
        cleanRule = cleanRule.substring(0, hashIndex);
      }
    }

    // 分离选择器和提取方法
    final atIdx = cleanRule.indexOf('@');
    if (atIdx < 0) {
      return (cleanRule.trim(), 'text', regexReplace);
    }

    final selector = cleanRule.substring(0, atIdx).trim();
    final extraction = cleanRule.substring(atIdx + 1).trim();
    return (selector, extraction.isEmpty ? 'text' : extraction, regexReplace);
  }

  /// 提取元素的值
  static String? _extractValue(Element element, String extraction) {
    switch (extraction) {
      case 'text':
        return element.text.trim();
      case 'html':
        return element.innerHtml;
      case 'ownText':
        return _getOwnText(element);
      case 'textNodes':
        return element.text.trim();
      default:
        // 视为属性名
        return element.attributes[extraction]?.trim();
    }
  }

  /// 获取元素自身的文本（不包含子元素文本）
  static String _getOwnText(Element element) {
    final buffer = StringBuffer();
    for (final node in element.nodes) {
      if (node is Text) {
        buffer.write(node.text);
      }
    }
    return buffer.toString().trim();
  }

  /// tag.xxx.N 语法选择元素
  static Element? _selectByTag(Document doc, String rule) {
    final match = RegExp(r'^tag\.(\w+)\.(-?\d+)$').firstMatch(rule);
    if (match == null) return doc.querySelector(rule);

    final tagName = match.group(1)!;
    final index = int.parse(match.group(2)!);
    final elements = doc.getElementsByTagName(tagName);

    if (elements.isEmpty) return null;
    if (index < 0) {
      final actualIndex = elements.length + index;
      return actualIndex >= 0 ? elements[actualIndex] : null;
    }
    return index < elements.length ? elements[index] : null;
  }

  /// tag.xxx.N 语法选择元素（从指定元素开始）
  static Element? _selectByTagFromElement(Element parent, String rule) {
    final match = RegExp(r'^tag\.(\w+)\.(-?\d+)$').firstMatch(rule);
    if (match == null) return parent.querySelector(rule);

    final tagName = match.group(1)!;
    final index = int.parse(match.group(2)!);
    final elements = parent.getElementsByTagName(tagName);

    if (elements.isEmpty) return null;
    if (index < 0) {
      final actualIndex = elements.length + index;
      return actualIndex >= 0 ? elements[actualIndex] : null;
    }
    return index < elements.length ? elements[index] : null;
  }

  /// tag.xxx.N 语法选择所有元素
  static List<Element> _selectAllByTag(Document doc, String rule) {
    final match = RegExp(r'^tag\.(\w+)$').firstMatch(rule);
    if (match == null) return doc.querySelectorAll(rule);
    return doc.getElementsByTagName(match.group(1)!);
  }

  /// 纯正则规则：##match##replace
  static String? _applyPureRegex(String html, String rule) {
    // 格式: ##regex##replacement
    final parts = rule.substring(2).split('##');
    if (parts.isEmpty) return null;

    final pattern = RegExp(parts[0], dotAll: true);
    final replacement = parts.length > 1 ? parts[1] : '';

    if (replacement.isEmpty) {
      // 仅匹配，返回第一个捕获组或整个匹配
      final match = pattern.firstMatch(html);
      if (match == null) return null;
      return match.group(1) ?? match.group(0);
    }

    // 替换
    return html.replaceAllMapped(pattern, (match) {
      var result = replacement;
      for (var i = 1; i <= match.groupCount; i++) {
        result = result.replaceAll('\$$i', match.group(i) ?? '');
      }
      return result;
    });
  }

  /// 应用正则替换
  static String applyReplace(String text, String regexStr) {
    // 格式: ##regex##replacement 或 ##regex
    final parts = regexStr.substring(2).split('##');
    if (parts.isEmpty || parts[0].isEmpty) return text;

    final pattern = RegExp(parts[0], dotAll: true);
    if (parts.length < 2) {
      // 仅删除匹配内容
      return text.replaceAll(pattern, '');
    }

    final replacement = parts[1];
    return text.replaceAllMapped(pattern, (match) {
      var result = replacement;
      for (var i = 1; i <= match.groupCount; i++) {
        result = result.replaceAll('\$$i', match.group(i) ?? '');
      }
      return result;
    });
  }

  /// 拼接相对 URL 为绝对 URL
  static String resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.isEmpty) return '';
    if (relativeUrl.startsWith('http')) return relativeUrl;

    final uri = Uri.parse(baseUrl);
    if (relativeUrl.startsWith('//')) {
      return '${uri.scheme}:$relativeUrl';
    }
    if (relativeUrl.startsWith('/')) {
      return '${uri.scheme}://${uri.host}$relativeUrl';
    }
    // 相对路径
    final basePath = uri.path.contains('/') ? uri.path.substring(0, uri.path.lastIndexOf('/')) : '';
    return '${uri.scheme}://${uri.host}$basePath/$relativeUrl';
  }
}
