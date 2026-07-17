import '../ai/ai_settings_store.dart';
import '../transactions/transaction_type.dart';
import 'external_ai_client.dart';
import 'slip_scan_result.dart';
import 'slip_transaction_resolver.dart';

typedef AlbumSyncAiAnalyzer =
    Future<ExternalSlipAnalysis?> Function(
      SlipScanResult result,
      String imagePath,
    );

class AlbumSyncAiResolution {
  const AlbumSyncAiResolution({
    required this.result,
    required this.decision,
    required this.usedAi,
  });

  final SlipScanResult result;
  final SlipTransactionDecision? decision;
  final bool usedAi;
}

Future<AlbumSyncAiResolution> analyzeAlbumSyncSlip({
  required SlipScanResult result,
  required String imagePath,
  AlbumSyncAiAnalyzer? analyzeWithAi,
}) async {
  final localDecision = resolveBestEffortSlipDecision(result);
  if (localDecision?.type == TransactionType.internalTransfer &&
      result.amount != null &&
      result.amount! > 0) {
    return AlbumSyncAiResolution(
      result: result,
      decision: localDecision,
      usedAi: false,
    );
  }

  ExternalSlipAnalysis? ai;
  try {
    ai = await (analyzeWithAi ?? _analyzeWithConfiguredAi)(result, imagePath);
  } catch (_) {
    ai = null;
  }

  if (ai == null) {
    return AlbumSyncAiResolution(
      result: result,
      decision: localDecision,
      usedAi: false,
    );
  }

  final mergedResult = _mergeAiFields(result, ai);
  return AlbumSyncAiResolution(
    result: mergedResult,
    decision: resolveSlipDecisionAfterAi(
      originalResult: result,
      enhancedResult: mergedResult,
      aiType: ai.type,
      aiCategoryId: ai.categoryId,
      aiNote: ai.note,
    ),
    usedAi: true,
  );
}

Future<ExternalSlipAnalysis?> _analyzeWithConfiguredAi(
  SlipScanResult result,
  String imagePath,
) async {
  await AiSettingsStore.instance.load();
  final includeImage =
      imagePath.isNotEmpty && AiSettingsStore.instance.slipVisionConsent;
  return ExternalAiClient.instance.analyzeSlip(
    result: result,
    allowedCategoryIds: kSlipAnalysisCategoryIds,
    imagePath: imagePath,
    includeImage: includeImage,
  );
}

SlipScanResult _mergeAiFields(SlipScanResult result, ExternalSlipAnalysis ai) {
  final aiAmount = ai.amount;
  final useAiAmount =
      aiAmount != null &&
      aiAmount > 0 &&
      (result.amount == null ||
          ai.confidence == null ||
          ai.confidence! >= 0.65);
  return result.copyWith(
    amount: useAiAmount ? aiAmount : result.amount,
    amountConfidence: useAiAmount
        ? ai.confidence ?? result.amountConfidence
        : result.amountConfidence,
    dateText: _preferAi(ai.dateText, result.dateText),
    timeText: _preferAi(ai.timeText, result.timeText),
    sender: _preferAi(ai.sender, result.sender),
    recipient: _preferAi(ai.recipient, result.recipient),
    reference: _preferAi(ai.reference, result.reference),
  );
}

String? _preferAi(String? aiValue, String? localValue) {
  final trimmed = aiValue?.trim();
  return trimmed == null || trimmed.isEmpty ? localValue : trimmed;
}
