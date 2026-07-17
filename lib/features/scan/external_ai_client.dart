import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../ai/ai_models.dart';
import '../ai/ai_settings_store.dart';
import '../transactions/transaction_type.dart';
import 'slip_scan_result.dart';

/// Authenticated client for the Kimjod AI backend.
///
/// No Gemini credential is ever shipped in the application. Configure only
/// the public backend origin with `--dart-define=AI_BACKEND_URL=https://...`.
class ExternalAiClient {
  ExternalAiClient._();

  static final ExternalAiClient instance = ExternalAiClient._();

  static const _requestTimeout = Duration(seconds: 35);

  String get _backendUrl => AiSettingsStore.instance.backendUrl;
  bool get isConfigured => _backendUrl.isNotEmpty;

  Future<AiBackendStatus> checkStatus() async {
    if (!isConfigured) return AiBackendStatus.notConfigured;
    try {
      final response = await http
          .get(
            Uri.parse('${_backendUrl.replaceAll(RegExp(r'/+$'), '')}/health'),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AiBackendStatus.unreachable;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['provider'] != 'gemini') {
        return AiBackendStatus.unreachable;
      }
      if (body['status'] == 'ready') {
        return AiBackendStatus.ready;
      }
      return AiBackendStatus.missingApiKey;
    } catch (_) {
      return AiBackendStatus.unreachable;
    }
  }

  Future<ExternalSlipAnalysis?> analyzeSlip({
    required SlipScanResult result,
    required List<String> allowedCategoryIds,
    String? imagePath,
    bool includeImage = false,
  }) async {
    final body = <String, Object?>{
      'rawText': _trimForAi(result.rawText, 8000),
      'allowedCategoryIds': allowedCategoryIds,
      'mode': AiSettingsStore.instance.mode.wireValue,
      'extracted': <String, Object?>{
        'bankName': result.bankName,
        'amount': result.amount,
        'dateText': result.dateText,
        'timeText': result.timeText,
        'recipient': result.recipient,
        'sender': result.sender,
        'reference': result.reference,
      },
    };

    if (includeImage && imagePath != null) {
      final image = await _smallEnoughImage(imagePath);
      if (image != null) body['imageBase64'] = image;
    }

    final json = await _postJson('/v1/slip/analyze', body);
    if (json == null) return null;

    final type = switch (json['type']?.toString()) {
      'income' => TransactionType.income,
      'internal_transfer' ||
      'internalTransfer' => TransactionType.internalTransfer,
      'expense' => TransactionType.expense,
      _ => null,
    };
    final categoryId = json['categoryId']?.toString().trim();
    if (type == null ||
        categoryId == null ||
        !allowedCategoryIds.contains(categoryId)) {
      return null;
    }

    return ExternalSlipAnalysis(
      type: type,
      categoryId: categoryId,
      note: _nullableString(json['note']),
      confidence: (json['confidence'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      dateText: _nullableString(json['dateText']),
      timeText: _nullableString(json['timeText']),
      sender: _nullableString(json['sender']),
      recipient: _nullableString(json['recipient']),
      reference: _nullableString(json['reference']),
    );
  }

  Future<ExternalPrediction?> analyzeAmounts({
    required String rawText,
    required List<double> candidates,
  }) async {
    final json = await _postJson('/v1/slip/amount', <String, Object?>{
      'rawText': _trimForAi(rawText, 6000),
      'candidates': candidates.take(24).toList(growable: false),
      'mode': AiSettingsStore.instance.mode.wireValue,
    });
    if (json == null) return null;

    return ExternalPrediction(
      (json['chosen'] as num?)?.toDouble(),
      (json['confidence'] as num?)?.toDouble(),
    );
  }

  Future<VoiceTransactionDraft?> parseVoice(String transcript) async {
    final drafts = await parseVoiceTransactions(transcript);
    return drafts.isEmpty ? null : drafts.first;
  }

  Future<List<VoiceTransactionDraft>> parseVoiceTransactions(
    String transcript,
  ) async {
    final json = await _postJson('/v1/voice/transaction', <String, Object?>{
      'transcript': _trimForAi(transcript, 1500),
      'mode': AiSettingsStore.instance.mode.wireValue,
      'timezone': DateTime.now().timeZoneName,
      'now': DateTime.now().toIso8601String(),
    });
    if (json == null) return const [];

    final rawTransactions = json['transactions'];
    final items = rawTransactions is List ? rawTransactions : <Object?>[json];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) => _voiceDraftFromJson(item, transcript))
        .whereType<VoiceTransactionDraft>()
        .take(20)
        .toList(growable: false);
  }

  VoiceTransactionDraft? _voiceDraftFromJson(
    Map<String, dynamic> json,
    String transcript,
  ) {
    final amount = (json['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return null;
    final type = switch (json['type']?.toString()) {
      'income' => TransactionType.income,
      'internal_transfer' ||
      'internalTransfer' => TransactionType.internalTransfer,
      _ => TransactionType.expense,
    };

    return VoiceTransactionDraft(
      amount: amount,
      type: type,
      categoryId: json['categoryId']?.toString() ?? 'other',
      categoryName: json['categoryName']?.toString() ?? 'Other',
      note: _nullableString(json['note']),
      transactionDate:
          DateTime.tryParse(json['transactionDate']?.toString() ?? '') ??
          DateTime.now(),
      transcript: transcript,
    );
  }

  Future<String?> transcribeVoice(
    String audioPath, {
    required String language,
  }) async {
    if (!isConfigured) return null;
    try {
      final file = File(audioPath);
      final length = await file.length();
      if (length <= 0 || length > 4 * 1024 * 1024) return null;
      final json = await _postJson('/v1/voice/transcribe', <String, Object?>{
        'audioBase64': base64Encode(await file.readAsBytes()),
        'mimeType': 'audio/mp4',
        'language': language,
      });
      return _nullableString(json?['transcript']);
    } catch (_) {
      return null;
    }
  }

  Future<FinancialAiInsight?> analyzeFinances({
    required Map<String, Object?> summary,
    required AiMode mode,
  }) async {
    final json = await _postJson('/v1/analysis', <String, Object?>{
      'summary': summary,
      'mode': mode.wireValue,
      'language': 'th',
    });
    if (json == null) return null;

    return FinancialAiInsight(
      headline: json['headline']?.toString() ?? 'Financial snapshot',
      strengths: _stringList(json['strengths']),
      risks: _stringList(json['risks']),
      recommendations: _stringList(json['recommendations']),
      suggestedMonthlyCut:
          (json['suggestedMonthlyCut'] as num?)?.toDouble() ?? 0,
      model: json['model']?.toString() ?? 'auto',
      cached: json['cached'] == true,
    );
  }

  Future<FinancialChatReply?> chat({
    required String message,
    required List<FinancialChatMessage> history,
    required Map<String, Object?> context,
  }) async {
    final json = await _postJson('/v1/chat', <String, Object?>{
      'message': _trimForAi(message, 2000),
      'history': history
          .take(12)
          .map(
            (item) => <String, String>{
              'role': item.isUser ? 'user' : 'assistant',
              'content': _trimForAi(item.content, 2000),
            },
          )
          .toList(growable: false),
      'context': context,
      'mode': AiSettingsStore.instance.mode.wireValue,
    });
    if (json == null) return null;

    final answer = _nullableString(json['answer']);
    if (answer == null) return null;
    return FinancialChatReply(
      answer: answer,
      suggestions: _stringList(json['suggestions']).take(3).toList(),
      model: json['model']?.toString() ?? 'auto',
    );
  }

  Future<Map<String, dynamic>?> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    if (!isConfigured) return null;
    await AiSettingsStore.instance.load();
    if (!AiSettingsStore.instance.aiConsent) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final token = await user.getIdToken();
      final response = await http
          .post(
            Uri.parse('${_backendUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
            headers: <String, String>{
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _smallEnoughImage(String path) async {
    try {
      final file = File(path);
      final length = await file.length();
      if (length <= 0 || length > 4 * 1024 * 1024) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }
}

enum AiBackendStatus { notConfigured, ready, missingApiKey, unreachable }

class ExternalPrediction {
  const ExternalPrediction(this.chosenAmount, this.confidence);

  final double? chosenAmount;
  final double? confidence;
}

class ExternalSlipAnalysis {
  const ExternalSlipAnalysis({
    required this.type,
    required this.categoryId,
    this.note,
    this.confidence,
    this.amount,
    this.dateText,
    this.timeText,
    this.sender,
    this.recipient,
    this.reference,
  });

  final TransactionType type;
  final String categoryId;
  final String? note;
  final double? confidence;
  final double? amount;
  final String? dateText;
  final String? timeText;
  final String? sender;
  final String? recipient;
  final String? reference;
}

class VoiceTransactionDraft {
  const VoiceTransactionDraft({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    required this.transcript,
    this.note,
  });

  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final String transcript;
  final String? note;
}

class FinancialAiInsight {
  const FinancialAiInsight({
    required this.headline,
    required this.strengths,
    required this.risks,
    required this.recommendations,
    required this.suggestedMonthlyCut,
    required this.model,
    required this.cached,
  });

  final String headline;
  final List<String> strengths;
  final List<String> risks;
  final List<String> recommendations;
  final double suggestedMonthlyCut;
  final String model;
  final bool cached;
}

class FinancialChatMessage {
  const FinancialChatMessage({required this.content, required this.isUser});

  final String content;
  final bool isUser;
}

class FinancialChatReply {
  const FinancialChatReply({
    required this.answer,
    required this.suggestions,
    required this.model,
  });

  final String answer;
  final List<String> suggestions;
  final String model;
}

String _trimForAi(String value, int maxLength) {
  final trimmed = value.trim();
  return trimmed.length <= maxLength
      ? trimmed
      : trimmed.substring(0, maxLength);
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .take(5)
      .toList(growable: false);
}
