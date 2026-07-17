import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoneySettingsSnapshot {
  const MoneySettingsSnapshot({
    required this.monthlyBudget,
    required this.installments,
  });

  const MoneySettingsSnapshot.empty()
    : monthlyBudget = null,
      installments = const [];

  final double? monthlyBudget;
  final List<InstallmentPlan> installments;

  List<InstallmentPlan> dueInstallmentsFor(DateTime month) {
    return installments
        .where((plan) => plan.isDueInMonth(month))
        .toList(growable: false);
  }
}

class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.title,
    required this.amount,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.startMonth,
    required this.dueDay,
  });

  final String id;
  final String title;
  final double amount;
  final int totalInstallments;
  final int paidInstallments;
  final DateTime startMonth;
  final int dueDay;

  int get remainingInstallments =>
      (totalInstallments - paidInstallments).clamp(0, totalInstallments);

  bool get isActive => remainingInstallments > 0;

  DateTime? nextDueDateFrom(DateTime month) {
    if (!isActive || !_startsBeforeOrAt(month)) return null;
    final safeDay = dueDay.clamp(1, _daysInMonth(month.year, month.month));
    return DateTime(month.year, month.month, safeDay);
  }

  bool isDueInMonth(DateTime month) {
    return nextDueDateFrom(month) != null;
  }

  InstallmentPlan copyWith({
    String? title,
    double? amount,
    int? totalInstallments,
    int? paidInstallments,
    DateTime? startMonth,
    int? dueDay,
  }) {
    return InstallmentPlan(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      startMonth: startMonth ?? this.startMonth,
      dueDay: dueDay ?? this.dueDay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'totalInstallments': totalInstallments,
      'paidInstallments': paidInstallments,
      'startMonth': startMonth.toIso8601String(),
      'dueDay': dueDay,
    };
  }

  static InstallmentPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString().trim();
    final title = raw['title']?.toString().trim();
    final amount = (raw['amount'] as num?)?.toDouble();
    final total = (raw['totalInstallments'] as num?)?.toInt();
    final paid = (raw['paidInstallments'] as num?)?.toInt() ?? 0;
    final dueDay = (raw['dueDay'] as num?)?.toInt() ?? 1;
    final startText = raw['startMonth']?.toString();
    final startMonth = startText == null ? null : DateTime.tryParse(startText);

    if (id == null ||
        id.isEmpty ||
        title == null ||
        title.isEmpty ||
        amount == null ||
        amount <= 0 ||
        total == null ||
        total <= 0 ||
        startMonth == null) {
      return null;
    }

    return InstallmentPlan(
      id: id,
      title: title,
      amount: amount,
      totalInstallments: total,
      paidInstallments: paid.clamp(0, total),
      startMonth: DateTime(startMonth.year, startMonth.month),
      dueDay: dueDay.clamp(1, 31),
    );
  }

  bool _startsBeforeOrAt(DateTime month) {
    final target = DateTime(month.year, month.month);
    return !startMonth.isAfter(target);
  }
}

class MoneySettingsStore extends ChangeNotifier {
  MoneySettingsStore._();

  static final MoneySettingsStore instance = MoneySettingsStore._();

  static const _monthlyBudgetKeyPrefix = 'money_settings.monthly_budget.';
  static const _installmentsKeyPrefix = 'money_settings.installments.';

  final Map<String, MoneySettingsSnapshot> _snapshotsByUser = {};

  MoneySettingsSnapshot snapshotFor(String userId) =>
      _snapshotsByUser[userId] ?? const MoneySettingsSnapshot.empty();

  Future<MoneySettingsSnapshot> load(String userId) async {
    final cached = _snapshotsByUser[userId];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final snapshot = MoneySettingsSnapshot(
      monthlyBudget: prefs.getDouble('$_monthlyBudgetKeyPrefix$userId'),
      installments: _decodeInstallments(
        prefs.getString('$_installmentsKeyPrefix$userId'),
      ),
    );
    _snapshotsByUser[userId] = snapshot;
    return snapshot;
  }

  Future<void> saveMonthlyBudget(String userId, double? amount) async {
    await load(userId);
    final prefs = await SharedPreferences.getInstance();
    final normalized = amount == null || amount <= 0 ? null : amount;
    final key = '$_monthlyBudgetKeyPrefix$userId';
    if (normalized == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, normalized);
    }
    _snapshotsByUser[userId] = MoneySettingsSnapshot(
      monthlyBudget: normalized,
      installments: snapshotFor(userId).installments,
    );
    notifyListeners();
  }

  Future<void> saveInstallment(String userId, InstallmentPlan plan) async {
    await load(userId);
    final plans = [...snapshotFor(userId).installments];
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    await _saveInstallments(userId, plans);
  }

  Future<void> deleteInstallment(String userId, String id) async {
    await load(userId);
    await _saveInstallments(
      userId,
      snapshotFor(userId).installments.where((plan) => plan.id != id).toList(),
    );
  }

  Future<void> markInstallmentPaid(String userId, String id) async {
    await load(userId);
    final plans = snapshotFor(userId).installments.map((plan) {
      if (plan.id != id) return plan;
      return plan.copyWith(paidInstallments: plan.paidInstallments + 1);
    }).toList();
    await _saveInstallments(userId, plans);
  }

  Future<void> _saveInstallments(
    String userId,
    List<InstallmentPlan> plans,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final activePlans = plans.where((plan) => plan.isActive).toList();
    await prefs.setString(
      '$_installmentsKeyPrefix$userId',
      jsonEncode(activePlans.map((plan) => plan.toJson()).toList()),
    );
    _snapshotsByUser[userId] = MoneySettingsSnapshot(
      monthlyBudget: snapshotFor(userId).monthlyBudget,
      installments: activePlans,
    );
    notifyListeners();
  }

  List<InstallmentPlan> _decodeInstallments(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(InstallmentPlan.fromJson)
          .whereType<InstallmentPlan>()
          .where((plan) => plan.isActive)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}
