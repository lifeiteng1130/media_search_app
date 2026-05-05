import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class HtmlUtil {
  /// 解析 HTML 字符串，返回 Document
  static Document parse(String html) {
    return html_parser.parse(html);
  }

  /// 从 HTML 中提取文本
  static String? extractText(String html, String selector) {
    final doc = parse(html);
    final element = doc.querySelector(selector);
    return element?.text.trim();
  }

  /// 从 HTML 中提取属性值
  static String? extractAttribute(String html, String selector, String attr) {
    final doc = parse(html);
    final element = doc.querySelector(selector);
    return element?.attributes[attr];
  }

  /// 从 HTML 中提取多个元素
  static List<Element> extractAll(String html, String selector) {
    final doc = parse(html);
    return doc.querySelectorAll(selector);
  }
}
