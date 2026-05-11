import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Legado 规则引擎
class RuleEngine {
  static String? extractText(String html, String rule, {String? baseUrl}) {
    if (rule.isEmpty) return null;

    if (rule.startsWith('##')) {
      return _applyPureRegex(html, rule);
    }

    if (rule.contains('&&')) {
      final parts = rule.split('&&');
      final results = parts.map((p) => extractText(html, p.trim(), baseUrl: baseUrl)).where((r) => r != null && r.isNotEmpty);
      return results.join('\n');
    }

    if (rule.contains('||')) {
      for (final part in rule.split('||')) {
        final result = extractText(html, part.trim(), baseUrl: baseUrl);
        if (result != null && result.isNotEmpty) return result;
      }
      return null;
    }

    final (selector, extraction, regexReplace) = _parseRule(rule);

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

    var value = _extractValue(element, extraction);

    if (value != null && regexReplace != null) {
      value = applyReplace(value, regexReplace);
    }

    return value;
  }

  static List<Element> extractAll(String html, String rule) {
    if (rule.isEmpty) return [];

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

  static String? extractFromElement(Element element, String rule) {
    if (rule.isEmpty) return element.text.trim();

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

  static (String selector, String extraction, String? regexReplace) _parseRule(String rule) {
    String? regexReplace;
    var cleanRule = rule;

    final atIndex = cleanRule.indexOf('@');
    if (atIndex > 0) {
      final afterAt = cleanRule.substring(atIndex + 1);
      final hashIndex = afterAt.indexOf('##');
      if (hashIndex >= 0) {
        regexReplace = afterAt.substring(hashIndex);
        cleanRule = cleanRule.substring(0, atIndex + 1 + hashIndex);
      }
    } else {
      final hashIndex = cleanRule.indexOf('##');
      if (hashIndex >= 0) {
        regexReplace = cleanRule.substring(hashIndex);
        cleanRule = cleanRule.substring(0, hashIndex);
      }
    }

    final atIdx = cleanRule.indexOf('@');
    if (atIdx < 0) {
      return (cleanRule.trim(), 'text', regexReplace);
    }

    final selector = cleanRule.substring(0, atIdx).trim();
    final extraction = cleanRule.substring(atIdx + 1).trim();
    return (selector, extraction.isEmpty ? 'text' : extraction, regexReplace);
  }

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
        return element.attributes[extraction]?.trim();
    }
  }

  static String _getOwnText(Element element) {
    final buffer = StringBuffer();
    for (final node in element.nodes) {
      if (node is Text) {
        buffer.write(node.text);
      }
    }
    return buffer.toString().trim();
  }

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

  static List<Element> _selectAllByTag(Document doc, String rule) {
    final match = RegExp(r'^tag\.(\w+)$').firstMatch(rule);
    if (match == null) return doc.querySelectorAll(rule);
    return doc.getElementsByTagName(match.group(1)!);
  }

  static String? _applyPureRegex(String html, String rule) {
    final parts = rule.substring(2).split('##');
    if (parts.isEmpty) return null;

    final pattern = RegExp(parts[0], dotAll: true);
    final replacement = parts.length > 1 ? parts[1] : '';

    if (replacement.isEmpty) {
      final match = pattern.firstMatch(html);
      if (match == null) return null;
      return match.group(1) ?? match.group(0);
    }

    return html.replaceAllMapped(pattern, (match) {
      var result = replacement;
      for (var i = 1; i <= match.groupCount; i++) {
        result = result.replaceAll('\$$i', match.group(i) ?? '');
      }
      return result;
    });
  }

  static String applyReplace(String text, String regexStr) {
    final parts = regexStr.substring(2).split('##');
    if (parts.isEmpty || parts[0].isEmpty) return text;

    final pattern = RegExp(parts[0], dotAll: true);
    if (parts.length < 2) {
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
    final basePath = uri.path.contains('/') ? uri.path.substring(0, uri.path.lastIndexOf('/')) : '';
    return '${uri.scheme}://${uri.host}$basePath/$relativeUrl';
  }
}
