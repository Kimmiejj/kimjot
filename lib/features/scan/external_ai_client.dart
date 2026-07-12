import 'dart:convert';
import 'package:http/http.dart' as http;

import '../transactions/transaction_type.dart';
import 'slip_scan_result.dart';

/// External AI client helper.
///
/// This supports two modes:
/// - If environment variable EXTERNAL_AI_PROVIDER is 'openai' and EXTERNAL_AI_KEY is set,
///   we call OpenAI Chat Completions endpoint (v1/chat/completions) with a structured prompt
///   and expect the assistant to return a JSON object containing
///   `{"chosen": number, "confidence": 0..1}`.
/// - Otherwise, if EXTERNAL_AI_URL and EXTERNAL_AI_KEY are provided, we POST {"text":..., "candidates": [...]} to that URL
///   and expect a JSON response `{"chosen": number, "confidence": 0..1}`.
///
/// Configure keys using flutter run --dart-define=EXTERNAL_AI_PROVIDER=openai --dart-define=EXTERNAL_AI_KEY=...
/// or --dart-define=EXTERNAL_AI_URL=https://your-endpoint --dart-define=EXTERNAL_AI_KEY=...
class ExternalAiClient {
  ExternalAiClient._();
  static final ExternalAiClient instance = ExternalAiClient._();

  final _provider = const String.fromEnvironment('EXTERNAL_AI_PROVIDER');
  final _key = const String.fromEnvironment('EXTERNAL_AI_KEY');
  final _url = const String.fromEnvironment('EXTERNAL_AI_URL');

  Future<ExternalSlipAnalysis?> analyzeSlip({
    required SlipScanResult result,
    required List<String> allowedCategoryIds,
  }) async {
    if (_key.isEmpty && _url.isEmpty) {
      return null;
    }

    try {
      if (_provider == 'openai' && _key.isNotEmpty) {
        return await _callOpenAiSlipAnalysis(
          result: result,
          allowedCategoryIds: allowedCategoryIds,
        );
      }
    } catch (_) {
      // Ignore errors and let caller fall back to local heuristics.
    }

    return null;
  }

  Future<ExternalPrediction?> analyzeAmounts({
    required String rawText,
    required List<double> candidates,
  }) async {
    if (_key.isEmpty && _url.isEmpty) {
      // no external AI configured
      return null;
    }

    try {
      if (_provider == 'openai' && _key.isNotEmpty) {
        return await _callOpenAi(rawText: rawText, candidates: candidates);
      }

      if (_url.isNotEmpty && _key.isNotEmpty) {
        final resp = await http.post(
          Uri.parse(_url),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $_key',
          },
          body: jsonEncode({'text': rawText, 'candidates': candidates}),
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final chosen = body['chosen'];
          final confidence = body['confidence'];
          if (chosen is num) {
            return ExternalPrediction(
              chosen.toDouble(),
              (confidence is num) ? confidence.toDouble() : null,
            );
          }
        }
      }
    } catch (e) {
      // ignore errors, caller will fallback to local classifier
    }

    return null;
  }

  Future<ExternalPrediction?> _callOpenAi({
    required String rawText,
    required List<double> candidates,
  }) async {
    final openAiUrl = 'https://api.openai.com/v1/chat/completions';
    final model = const String.fromEnvironment(
      'OPENAI_MODEL',
      defaultValue: 'gpt-3.5-turbo',
    );

    final system =
        '''You are an assistant that extracts the correct payment amount from OCR text.
Return a JSON object only, like {"chosen": 396.0, "confidence": 0.92} where "chosen" is the numeric amount chosen from the candidates list and "confidence" is a number between 0 and 1.
If none of the candidates seem correct, return {"chosen": null, "confidence": 0.0}.
''';

    final user =
        '''OCR_TEXT:\n$rawText\n\nCANDIDATES:\n${candidates.join(', ')}\n\nChoose which candidate is the correct payment amount and return the JSON object as described.''';

    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.0,
      'max_tokens': 300,
    };

    final resp = await http.post(
      Uri.parse(openAiUrl),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $_key',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return null;
    final text = (choices.first['message']?['content'])?.toString();
    if (text == null) return null;

    // Attempt to parse JSON object from assistant text
    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final chosen = parsed['chosen'];
      final confidence = parsed['confidence'];
      if (chosen is num) {
        return ExternalPrediction(
          chosen.toDouble(),
          (confidence is num) ? confidence.toDouble() : null,
        );
      }
      return ExternalPrediction(
        null,
        (confidence is num) ? confidence.toDouble() : null,
      );
    } catch (_) {
      // Try to extract numbers with regex as fallback
      final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(text);
      if (match != null) {
        final numStr = match.group(1)!;
        final val = double.tryParse(numStr);
        return ExternalPrediction(val, null);
      }
    }

    return null;
  }

  Future<ExternalSlipAnalysis?> _callOpenAiSlipAnalysis({
    required SlipScanResult result,
    required List<String> allowedCategoryIds,
  }) async {
    final openAiUrl = 'https://api.openai.com/v1/chat/completions';
    final model = const String.fromEnvironment(
      'OPENAI_MODEL',
      defaultValue: 'gpt-3.5-turbo',
    );

    final system = '''You classify transaction slips from OCR text.
Return JSON only with this shape:
{"type":"expense|internal_transfer","categoryId":"one of the allowed category ids","note":"short optional note or null","confidence":0.0}
Rules:
- Choose exactly one categoryId from the allowed list.
- Never classify an OCR slip as income. Income must be entered manually by the user.
- Use "internal_transfer" when the sender and recipient appear to be the same person moving money between their own accounts.
- Keep note short and factual. Prefer merchant/place names. Do not put sender or recipient person names in the note.
- If uncertain, still choose the best option and lower confidence.
''';

    final user =
        '''OCR_TEXT:
${result.rawText}

EXTRACTED_FIELDS:
- bankName: ${result.bankName ?? 'null'}
- amount: ${result.amount?.toStringAsFixed(2) ?? 'null'}
- dateText: ${result.dateText ?? 'null'}
- timeText: ${result.timeText ?? 'null'}
- recipient: ${result.recipient ?? 'null'}
- sender: ${result.sender ?? 'null'}
- reference: ${result.reference ?? 'null'}

ALLOWED_CATEGORY_IDS:
${allowedCategoryIds.join(', ')}

Return the JSON object only.''';

    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      'temperature': 0.0,
      'max_tokens': 300,
    };

    final resp = await http.post(
      Uri.parse(openAiUrl),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $_key',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return null;
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return null;
    }

    final text = (choices.first['message']?['content'])?.toString();
    if (text == null) {
      return null;
    }

    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final typeValue = parsed['type']?.toString().trim().toLowerCase();
      final categoryId = parsed['categoryId']?.toString().trim();
      final note = parsed['note']?.toString().trim();
      final confidence = parsed['confidence'];

      final type = switch (typeValue) {
        'income' => TransactionType.income,
        'expense' => TransactionType.expense,
        'internal_transfer' => TransactionType.internalTransfer,
        _ => null,
      };

      if (type == null ||
          categoryId == null ||
          categoryId.isEmpty ||
          !allowedCategoryIds.contains(categoryId)) {
        return null;
      }

      return ExternalSlipAnalysis(
        type: type,
        categoryId: categoryId,
        note: (note == null || note.isEmpty || note == 'null') ? null : note,
        confidence: confidence is num ? confidence.toDouble() : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class ExternalPrediction {
  ExternalPrediction(this.chosenAmount, this.confidence);
  final double? chosenAmount;
  final double? confidence;
}

class ExternalSlipAnalysis {
  const ExternalSlipAnalysis({
    required this.type,
    required this.categoryId,
    this.note,
    this.confidence,
  });

  final TransactionType type;
  final String categoryId;
  final String? note;
  final double? confidence;
}
