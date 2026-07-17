enum AiMode { auto, fast, balanced, deep }

extension AiModeLabel on AiMode {
  String label({required bool isThai}) => switch (this) {
    AiMode.auto => isThai ? 'อัตโนมัติ' : 'Auto',
    AiMode.fast => isThai ? 'เร็ว' : 'Fast',
    AiMode.balanced => isThai ? 'สมดุล' : 'Balanced',
    AiMode.deep => isThai ? 'วิเคราะห์ลึก' : 'Deep',
  };

  String get wireValue => name;
}

class AiModelOption {
  const AiModelOption({
    required this.mode,
    required this.model,
    required this.description,
  });

  final AiMode mode;
  final String model;
  final String description;
}
