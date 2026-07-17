import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'transaction_type.dart';

class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final TransactionType type;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
  };

  static CustomCategory? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim();
    final name = value['name']?.toString().trim();
    final typeName = value['type']?.toString();
    final type = TransactionType.values.where((item) => item.name == typeName);
    if (id == null || id.isEmpty || name == null || name.isEmpty || type.isEmpty) {
      return null;
    }
    return CustomCategory(id: id, name: name, type: type.first);
  }
}

class CustomCategoryStore extends ChangeNotifier {
  CustomCategoryStore._();

  static final instance = CustomCategoryStore._();
  static const _keyPrefix = 'custom_categories.';

  final Map<String, List<CustomCategory>> _byUser = {};

  List<CustomCategory> categoriesFor(String userId, TransactionType type) {
    return (_byUser[userId] ?? const [])
        .where((category) => category.type == type)
        .toList(growable: false);
  }

  Future<List<CustomCategory>> load(String userId) async {
    if (_byUser.containsKey(userId)) return _byUser[userId]!;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_keyPrefix$userId');
    final categories = <CustomCategory>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          categories.addAll(
            decoded.map(CustomCategory.fromJson).whereType<CustomCategory>(),
          );
        }
      } catch (_) {
        // Keep malformed local settings from blocking transaction entry.
      }
    }
    _byUser[userId] = categories;
    return categories;
  }

  Future<CustomCategory> add({
    required String userId,
    required String name,
    required TransactionType type,
  }) async {
    await load(userId);
    final trimmed = name.trim();
    final existing = _byUser[userId]!.where(
      (item) => item.type == type && item.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;
    final category = CustomCategory(
      id: 'custom_${type.name}_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      type: type,
    );
    _byUser[userId] = [..._byUser[userId]!, category];
    await _save(userId);
    notifyListeners();
    return category;
  }

  Future<void> delete(String userId, String categoryId) async {
    await load(userId);
    _byUser[userId] = _byUser[userId]!
        .where((item) => item.id != categoryId)
        .toList(growable: false);
    await _save(userId);
    notifyListeners();
  }

  Future<void> _save(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$userId',
      jsonEncode(_byUser[userId]!.map((item) => item.toJson()).toList()),
    );
  }
}
