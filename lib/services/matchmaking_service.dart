import 'dart:math';
import '../models/player.dart';
import '../models/match.dart';

class MatchmakingService {
  final Map<String, Player> _playersInQueue = {};
  final Map<String, Match> _pendingMatches = {};
  final List<Match> _completedMatches = [];

  final Random _random = Random();
  int _totalMatches = 0;

  /// Добавить игрока в очередь
  bool addToQueue(Player player) {
    if (_playersInQueue.containsKey(player.id)) {
      return false; // Игрок уже в очереди
    }

    if (player.inBattle) {
      return false; // Игрок уже в бою
    }

    _playersInQueue[player.id] = player.copyWith(lastActive: DateTime.now());
    print('➕ Игрок ${player.name} добавлен в очередь (всего в очереди: ${_playersInQueue.length})');
    return true;
  }

  /// Удалить игрока из очереди
  bool removeFromQueue(String playerId) {
    final removed = _playersInQueue.remove(playerId);
    if (removed != null) {
      print('➖ Игрок ${removed.name} удален из очереди');
      return true;
    }
    return false;
  }

  /// Получить размер очереди
  int getQueueSize() {
    return _playersInQueue.length;
  }

  /// Получить общее количество матчей
  int getTotalMatches() {
    return _totalMatches;
  }

  /// Получить игроков в очереди
  List<Player> getPlayersInQueue() {
    return _playersInQueue.values.toList();
  }

  /// Обработать ожидающие матчи
  List<Match> processPendingMatches() {
    final newMatches = <Match>[];

    // Удаляем неактивных игроков (не было активности более 2 минут)
    _removeInactivePlayers();

    // Создаем новые матчи если в очереди есть минимум 2 игрока
    while (_playersInQueue.length >= 2) {
      final match = _createMatch();
      if (match != null) {
        newMatches.add(match);
        _pendingMatches[match.id] = match;
        _totalMatches++;
      } else {
        break; // Не удалось создать матч
      }
    }

    return newMatches;
  }

  /// Создать матч между двумя игроками
  Match? _createMatch() {
    if (_playersInQueue.length < 2) return null;

    final players = _playersInQueue.values.toList();

    // Простой алгоритм: берем первых двух игроков
    // В более сложной версии можно учитывать уровень, рейтинг и т.д.
    final player1 = players[0];
    final player2 = players[1];

    // Проверяем совместимость игроков
    if (!_arePlayersCompatible(player1, player2)) {
      // Если игроки не совместимы, пробуем других
      if (players.length > 2) {
        final player3 = players[2];
        if (_arePlayersCompatible(player1, player3)) {
          return _createMatchBetween(player1, player3);
        } else if (_arePlayersCompatible(player2, player3)) {
          return _createMatchBetween(player2, player3);
        }
      }
      return null;
    }

    return _createMatchBetween(player1, player2);
  }

  /// Создать матч между конкретными игроками
  Match _createMatchBetween(Player player1, Player player2) {
    // Удаляем игроков из очереди
    _playersInQueue.remove(player1.id);
    _playersInQueue.remove(player2.id);

    // Создаем матч
    final matchId = _generateMatchId();
    final match = Match(
      id: matchId,
      player1Id: player1.id,
      player2Id: player2.id,
      player1Data: player1,
      player2Data: player2,
    );

    print('🎮 Создан матч: ${player1.name} vs ${player2.name} (ID: $matchId)');
    return match;
  }

  /// Проверить совместимость игроков
  bool _arePlayersCompatible(Player player1, Player player2) {
    // Простые правила совместимости:

    // 1. Разница в уровнях не более 3
    const maxLevelDifference = 3;
    if ((player1.level - player2.level).abs() > maxLevelDifference) {
      return false;
    }

    // 2. Оба игрока должны быть не в бою
    if (player1.inBattle || player2.inBattle) {
      return false;
    }

    // 3. Нельзя играть самому с собой (дополнительная проверка)
    if (player1.id == player2.id) {
      return false;
    }

    return true;
  }

  /// Удалить неактивных игроков
  void _removeInactivePlayers() {
    final now = DateTime.now();
    const inactivityThreshold = Duration(minutes: 2);

    final inactivePlayers = _playersInQueue.entries
        .where((entry) => now.difference(entry.value.lastActive) > inactivityThreshold)
        .map((entry) => entry.key)
        .toList();

    for (final playerId in inactivePlayers) {
      final player = _playersInQueue.remove(playerId);
      if (player != null) {
        print('⏰ Игрок ${player.name} удален из очереди за неактивность');
      }
    }
  }

  /// Получить матч по ID
  Match? getMatch(String matchId) {
    return _pendingMatches[matchId];
  }

  /// Завершить матч
  void finishMatch(String matchId, String? winnerId) {
    final match = _pendingMatches.remove(matchId);
    if (match != null) {
      final finishedMatch = match.copyWith(
        status: MatchStatus.finished,
        winnerId: winnerId,
        finishedAt: DateTime.now(),
      );
      _completedMatches.add(finishedMatch);

      print('🏁 Матч завершен: ${match.player1Data.name} vs ${match.player2Data.name}, '
          'победитель: ${winnerId ?? "ничья"}');
    }
  }

  /// Отменить матч
  void cancelMatch(String matchId, String reason) {
    final match = _pendingMatches.remove(matchId);
    if (match != null) {
      final cancelledMatch = match.copyWith(
        status: MatchStatus.cancelled,
        finishedAt: DateTime.now(),
      );
      _completedMatches.add(cancelledMatch);

      print('❌ Матч отменен: ${match.player1Data.name} vs ${match.player2Data.name}, '
          'причина: $reason');
    }
  }

  /// Обновить данные игрока в очереди
  bool updatePlayerInQueue(String playerId, Player updatedPlayer) {
    if (_playersInQueue.containsKey(playerId)) {
      _playersInQueue[playerId] = updatedPlayer.copyWith(lastActive: DateTime.now());
      return true;
    }
    return false;
  }

  /// Найти игрока в очереди
  Player? findPlayerInQueue(String playerId) {
    return _playersInQueue[playerId];
  }

  /// Получить статистику матчмейкинга
  Map<String, dynamic> getStatistics() {
    final queueLevels = <int, int>{};
    for (final player in _playersInQueue.values) {
      queueLevels[player.level] = (queueLevels[player.level] ?? 0) + 1;
    }

    return {
      'playersInQueue': _playersInQueue.length,
      'pendingMatches': _pendingMatches.length,
      'completedMatches': _completedMatches.length,
      'totalMatches': _totalMatches,
      'queueLevelDistribution': queueLevels,
      'averageWaitTime': _calculateAverageWaitTime(),
    };
  }

  /// Вычислить среднее время ожидания
  double _calculateAverageWaitTime() {
    if (_playersInQueue.isEmpty) return 0.0;

    final now = DateTime.now();
    final totalWaitTime = _playersInQueue.values
        .map((player) => now.difference(player.lastActive).inSeconds)
        .reduce((a, b) => a + b);

    return totalWaitTime / _playersInQueue.length;
  }

  /// Генерировать уникальный ID матча
  String _generateMatchId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(10000).toString().padLeft(4, '0');
    return 'match_${timestamp}_$randomPart';
  }

  /// Получить список завершенных матчей
  List<Match> getCompletedMatches({int limit = 100}) {
    final matches = _completedMatches.reversed.toList();
    return matches.take(limit).toList();
  }

  /// Очистить старые завершенные матчи
  void cleanupOldMatches() {
    final now = DateTime.now();
    const keepDuration = Duration(hours: 24);

    _completedMatches.removeWhere((match) {
      return match.finishedAt != null &&
          now.difference(match.finishedAt!) > keepDuration;
    });
  }

  /// Сбросить все данные (для тестирования)
  void reset() {
    _playersInQueue.clear();
    _pendingMatches.clear();
    _completedMatches.clear();
    _totalMatches = 0;
  }
}