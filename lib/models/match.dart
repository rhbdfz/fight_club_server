import 'player.dart';

enum MatchStatus {
  pending,    // Ожидание начала
  active,     // Идет бой
  finished,   // Завершен
  cancelled,  // Отменен
}

class Match {
  final String id;
  final String player1Id;
  final String player2Id;
  final Player player1Data;
  final Player player2Data;
  final DateTime createdAt;
  final MatchStatus status;
  final String? winnerId;
  final DateTime? finishedAt;

  Match({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.player1Data,
    required this.player2Data,
    DateTime? createdAt,
    this.status = MatchStatus.pending,
    this.winnerId,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Match copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    Player? player1Data,
    Player? player2Data,
    DateTime? createdAt,
    MatchStatus? status,
    String? winnerId,
    DateTime? finishedAt,
  }) {
    return Match(
      id: id ?? this.id,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      player1Data: player1Data ?? this.player1Data,
      player2Data: player2Data ?? this.player2Data,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1Data': player1Data.toJson(),
      'player2Data': player2Data.toJson(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.index,
      'winnerId': winnerId,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
    };
  }

  static Match fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'],
      player1Id: json['player1Id'],
      player2Id: json['player2Id'],
      player1Data: Player.fromJson(json['player1Data']),
      player2Data: Player.fromJson(json['player2Data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      status: MatchStatus.values[json['status']],
      winnerId: json['winnerId'],
      finishedAt: json['finishedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['finishedAt'])
          : null,
    );
  }

  @override
  String toString() {
    return 'Match(id: $id, players: $player1Id vs $player2Id, status: $status)';
  }
}