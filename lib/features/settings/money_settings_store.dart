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

  static const _monthlyBudgetKey = 'money_settings.monthly_budget';
  static const _installmentsKey = 'money_settings.installments';

  MoneySettingsSnapshot _snapshot = const MoneySettingsSnapshot.empty();
  bool _loaded = false;

  MoneySettingsSnapshot get snapshot => _snapshot;

  Future<MoneySettingsSnapshot> load() async {
    if (_loaded) return _snapshot;
    final prefs = await SharedPreferences.getInstance();
    _snapshot = MoneySettingsSnapshot(
      monthlyBudget: prefs.getDouble(_monthlyBudgetKey),
      installments: _decodeInstallments(prefs.getString(_installmentsKey)),
    );
    _loaded = true;
    return _snapshot;
  }

  Future<void> saveMonthlyBudget(double? amount) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = amount == null || amount <= 0 ? null : amount;
    if (normalized == null) {
      await prefs.remove(_monthlyBudgetKey);
    } else {
      await prefs.setDouble(_monthlyBudgetKey, normalized);
    }
    _snapshot = MoneySettingsSnapshot(
      monthlyBudget: normalized,
      installments: _snapshot.installments,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveInstallment(InstallmentPlan plan) async {
    final plans = [..._snapshot.installments];
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    await _saveInstallments(plans);
  }

  Future<void> deleteInstallment(String id) async {
    await _saveInstallments(
      _snapshot.installments.where((plan) => plan.id != id).toList(),
    );
  }

  Future<void> markInstallmentPaid(String id) async {
    final plans = _snapshot.installments.map((plan) {
      if (plan.id != id) return plan;
      return plan.copyWith(paidInstallments: plan.paidInstallments + 1);
    }).toList();
    await _saveInstallments(plans);
  }

  Future<void> _saveInstallments(List<InstallmentPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final activePlans = plans.where((plan) => plan.isActive).toList();
    await prefs.setString(
      _installmentsKey,
      jsonEncode(activePlans.map((plan) => plan.toJson()).toList()),
    );
    _snapshot = MoneySettingsSnapshot(
      monthlyBudget: _snapshot.monthlyBudget,
      installments: activePlans,
    );
    _loaded = true;
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
