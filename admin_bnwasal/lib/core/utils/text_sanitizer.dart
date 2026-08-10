import 'package:characters/characters.dart';

String sanitizeText(String? text) {
  if (text == null || text.isEmpty) return '';
  final sb = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final codeUnit = text.codeUnitAt(i);
    if (codeUnit < 0xD800 || codeUnit > 0xDFFF) {
      sb.writeCharCode(codeUnit);
    } else if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      if (i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          sb.writeCharCode(codeUnit);
          sb.writeCharCode(next);
          i++;
        }
      }
    }
  }
  return sb.toString();
}

String safeFirstChar(String? name, [String fallback = '?']) {
  if (name == null || name.trim().isEmpty) return fallback;
  final sanitized = sanitizeText(name.trim());
  if (sanitized.isEmpty) return fallback;
  try {
    return sanitized.characters.take(1).toString();
  } catch (_) {
    return fallback;
  }
}
