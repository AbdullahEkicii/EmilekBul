class Token {
  final int? id;
  final int amount;
  final DateTime lastUpdated;
  final DateTime? lastDailyReward;

  Token({
    this.id,
    required this.amount,
    required this.lastUpdated,
    this.lastDailyReward,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastDailyReward': lastDailyReward?.toIso8601String(),
    };
  }

  factory Token.fromMap(Map<String, dynamic> map) {
    return Token(
      id: map['id'],
      amount: map['amount'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
      lastDailyReward: map['lastDailyReward'] != null
          ? DateTime.parse(map['lastDailyReward'])
          : null,
    );
  }

  Token copy({
    int? id,
    int? amount,
    DateTime? lastUpdated,
    DateTime? lastDailyReward,
  }) {
    return Token(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastDailyReward: lastDailyReward ?? this.lastDailyReward,
    );
  }
}
