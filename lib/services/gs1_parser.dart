/// Parses GS1 Application Identifier data from barcode strings.
/// Handles both GS-separated (ASCII 29) and concatenated formats.
class Gs1Parser {
  // GS1 Application Identifiers we care about
  static const _aiGtin = '01';
  static const _aiExpiry = '17';
  static const _aiLot = '10';
  static const _aiSerial = '21';

  /// AI definitions: key = AI string, value = (label, fixedLength or null for variable)
  static const _aiDefs = {
    '01': ('GTIN', 14),
    '17': ('Expiry', 6),
    '10': ('Lot', null), // variable, up to 20
    '21': ('Serial', null), // variable, up to 20
  };

  final Map<String, String> _fields = {};

  /// Parse a raw barcode string and return a map of AI -> value.
  /// Input examples:
  ///   "01012345678901281726123110ABC123421XYZ"
  ///   "01\u001d01234567890128\u001d17\u001d261231\u001d10\u001dABC1234\u001d21\u001dXYZ"
  Map<String, String> parse(String raw) {
    _fields.clear();

    // Replace GS separators (ASCII 29) with a marker we can split on
    // but also handle non-separated formats by walking the string.
    final clean = raw.replaceAll(String.fromCharCode(29), '\x1d');
    _parseWithSeparators(clean);

    return Map.unmodifiable(_fields);
  }

  void _parseWithSeparators(String raw) {
    int i = 0;
    while (i < raw.length - 1) {
      final ai = raw.substring(i, i + 2);
      final def = _aiDefs[ai];

      if (def == null) {
        // Unknown AI — skip 2 chars and try to resync
        i += 2;
        continue;
      }

      i += 2; // move past the AI
      final fixedLen = def.$2;

      String value;
      if (fixedLen != null) {
        if (i + fixedLen > raw.length) break;
        value = raw.substring(i, i + fixedLen);
        i += fixedLen;
      } else {
        // Variable length: read until next GS separator or next AI
        final nextSep = raw.indexOf('\x1d', i);
        if (nextSep != -1 && nextSep < raw.length) {
          value = raw.substring(i, nextSep);
          i = nextSep + 1; // skip the separator
        } else {
          // No separator — read until next known AI pattern or end
          int end = raw.length;
          for (final candidateAi in _aiDefs.keys) {
            final pos = raw.indexOf(candidateAi, i);
            if (pos != -1 && pos < end) {
              end = pos;
            }
          }
          value = raw.substring(i, end);
          i = end;
        }
      }

      _fields[ai] = value;
    }
  }

  /// Convenience getters
  String? get gtin => _fields[_aiGtin];
  String? get lot => _fields[_aiLot];
  String? get serial => _fields[_aiSerial];

  /// Parse expiry date from AI 17 (YYMMDD format)
  DateTime? get expiryDate {
    final raw = _fields[_aiExpiry];
    if (raw == null || raw.length != 6) return null;

    final yy = int.tryParse(raw.substring(0, 2));
    final mm = int.tryParse(raw.substring(2, 4));
    final dd = int.tryParse(raw.substring(4, 6));

    if (yy == null || mm == null || dd == null) return null;

    // YY -> 20YY (good until 2099)
    return DateTime(2000 + yy, mm, dd);
  }

  /// Human-readable summary of all parsed fields
  Map<String, String> get allFields => Map.unmodifiable(_fields);
}