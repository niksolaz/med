import 'dart:convert';
import 'package:http/http.dart' as http;

class DrugInfo {
  final String name;
  final String description;
  final String? source;

  const DrugInfo({
    required this.name,
    required this.description,
    this.source,
  });
}

/// Looks up drug information using the OpenFDA API (free, no key required).
class DrugLookupService {
  static const _baseUrl = 'https://api.fda.gov/drug/ndc.json';

  /// Search for a drug by GTIN.
  Future<DrugInfo?> lookupByGtin(String gtin) async {
    final queries = <String>[];

    if (gtin.length >= 12) {
      queries.add(gtin);
    }
    if (gtin.length >= 14) {
      queries.add(gtin.substring(1));
    }

    for (final query in queries) {
      try {
        final uri = Uri.parse(
          '$_baseUrl?search=product_ndc:"$query"&limit=1',
        );
        final response = await http.get(uri, headers: {
          'Accept': 'application/json',
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            return _parseResult(results.first as Map<String, dynamic>);
          }
        } else if (response.statusCode == 404) {
          continue;
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// Search by product name for manual lookup.
  Future<List<DrugInfo>> searchByName(String name) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?search=brand_name:"$name"+OR+generic_name:"$name"&limit=5',
      );
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null) {
          return results
              .map((r) => _parseResult(r as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      // Ignore
    }
    return [];
  }

  DrugInfo _parseResult(Map<String, dynamic> result) {
    final brandName = result['brand_name'] as String?;
    final genericName = result['generic_name'] as String?;
    final productNdc = result['product_ndc'] as String?;
    final dosageForm = result['dosage_form'] as String?;
    final activeIngredients = result['active_ingredients'] as List?;
    final pharmClass = result['pharm_class'] as List?;

    final name = brandName ?? genericName ?? productNdc ?? 'Unknown';
    final parts = <String>[];

    if (genericName != null && genericName != brandName) {
      parts.add('Generic: $genericName');
    }
    if (activeIngredients != null && activeIngredients.isNotEmpty) {
      final ingredients = activeIngredients
          .map((a) {
            if (a is Map) {
              return (a['name'] ?? a['substance_name'] ?? '').toString();
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (ingredients.isNotEmpty) {
        parts.add('Principio attivo: $ingredients');
      }
    }
    if (dosageForm != null) {
      parts.add('Forma: $dosageForm');
    }
    if (pharmClass != null && pharmClass.isNotEmpty) {
      final classes = pharmClass
          .take(2)
          .map((p) {
            if (p is String) return p;
            if (p is Map) return (p['class_name'] ?? '').toString();
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join('; ');
      if (classes.isNotEmpty) {
        parts.add('Classe: $classes');
      }
    }

    return DrugInfo(
      name: name,
      description: parts.join('\n'),
      source: 'OpenFDA',
    );
  }
}