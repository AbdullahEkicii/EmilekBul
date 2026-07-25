class Quest {
  final String id;
  final String type; // 'daily' or 'weekly'
  final int targetProgress;
  final int currentProgress;
  final int rewardTokens;
  final bool isClaimed;
  final DateTime lastUpdated;

  Quest({
    required this.id,
    required this.type,
    required this.targetProgress,
    required this.currentProgress,
    required this.rewardTokens,
    required this.isClaimed,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'target_progress': targetProgress,
      'current_progress': currentProgress,
      'reward_tokens': rewardTokens,
      'is_claimed': isClaimed ? 1 : 0,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory Quest.fromMap(Map<String, dynamic> map) {
    return Quest(
      id: map['id'],
      type: map['type'],
      targetProgress: map['target_progress'],
      currentProgress: map['current_progress'],
      rewardTokens: map['reward_tokens'],
      isClaimed: map['is_claimed'] == 1,
      lastUpdated: DateTime.parse(map['last_updated']),
    );
  }

  Quest copyWith({
    String? id,
    String? type,
    int? targetProgress,
    int? currentProgress,
    int? rewardTokens,
    bool? isClaimed,
    DateTime? lastUpdated,
  }) {
    return Quest(
      id: id ?? this.id,
      type: type ?? this.type,
      targetProgress: targetProgress ?? this.targetProgress,
      currentProgress: currentProgress ?? this.currentProgress,
      rewardTokens: rewardTokens ?? this.rewardTokens,
      isClaimed: isClaimed ?? this.isClaimed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
