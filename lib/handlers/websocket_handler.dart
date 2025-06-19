import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/player.dart';
import '../services/matchmaking_service.dart';
import '../services/battle_service.dart';

class WebSocketHandler {
  final Map<String, WebSocketChannel> connections;
  final MatchmakingService matchmakingService;
  final BattleService battleService;
  
  final Map<String, Player> _playerData = {};

  WebSocketHandler({
    required this.connections,
    required this.matchmakingService,
    required this.battleService,
  });

  /// Обработать сообщение от клиента
  void handleMessage(String playerId, Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    if (type == null) {
      _sendError(playerId, 'Тип сообщения не указан');
      return;
    }

    try {
      switch (type) {
        case 'player_connect':
          _handlePlayerConnect(playerId, message);
          break;
        case 'character_data':
          _handleCharacterData(playerId, message);
          break;
        case 'join_matchmaking':
          _handleJoinMatchmaking(playerId, message);
          break;
        case 'leave_matchmaking':
          _handleLeaveMatchmaking(playerId, message);
          break;
        case 'battle_move':
          _handleBattleMove(playerId, message);
          break;
        case 'leave_battle':
          _handleLeaveBattle(playerId, message);
          break;
        case 'heartbeat':
          _handleHeartbeat(playerId, message);
          break;
        case 'server_status_request':
          _handleServerStatusRequest(playerId, message);
          break;
        default:
          _sendError(playerId, 'Неизвестный тип сообщения: $type');
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения $type от $playerId: $e');
      _sendError(playerId, 'Ошибка обработки сообщения: $e');
    }
  }

  /// Подключение игрока
  void _handlePlayerConnect(String playerId, Map<String, dynamic> message) {
    print('👋 Игрок $playerId подключился');
    
    _sendMessage(playerId, {
      'type': 'connection_confirmed',
      'playerId': playerId,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Получение данных персонажа
  void _handleCharacterData(String playerId, Map<String, dynamic> message) {
    try {
      final characterData = message['character'] as Map<String, dynamic>;
      final player = Player.fromJson({
        ...characterData,
        'id': playerId,
      });
      
      _playerData[playerId] = player;
      print('📝 Получены данные персонажа ${player.name} от $playerId');
      
      _sendMessage(playerId, {
        'type': 'character_data_received',
        'success': true,
      });
    } catch (e) {
      _sendError(playerId, 'Ошибка обработки данных персонажа: $e');
    }
  }

  /// Присоединение к матчмейкингу
  void _handleJoinMatchmaking(String playerId, Map<String, dynamic> message) {
    final player = _playerData[playerId];
    if (player == null) {
      _sendError(playerId, 'Данные персонажа не найдены');
      return;
    }

    if (player.inBattle) {
      _sendError(playerId, 'Нельзя искать бой находясь в бою');
      return;
    }

    final success = matchmakingService.addToQueue(player);
    if (success) {
      _sendMessage(playerId, {
        'type': 'matchmaking_joined',
        'success': true,
      });
      
      // Отправляем статус очереди всем игрокам в очереди
      _broadcastQueueStatus();
    } else {
      _sendError(playerId, 'Не удалось присоединиться к очереди');
    }
  }

  /// Выход из матчмейкинга
  void _handleLeaveMatchmaking(String playerId, Map<String, dynamic> message) {
    final success = matchmakingService.removeFromQueue(playerId);
    
    _sendMessage(playerId, {
      'type': 'matchmaking_left',
      'success': success,
    });
    
    // Обновляем статус очереди
    _broadcastQueueStatus();
  }

  /// Ход в бою
  void _handleBattleMove(String playerId, Map<String, dynamic> message) {
    final battleId = message['battleId'] as String?;
    final moveData = message['move'] as Map<String, dynamic>?;
    
    if (battleId == null || moveData == null) {
      _sendError(playerId, 'Некорректные данные хода');
      return;
    }

    try {
      final move = BattleMove.fromJson({
        ...moveData,
        'playerId': playerId,
      });

      final success = battleService.submitMove(battleId, move);
      if (success) {
        // Уведомляем противника о ходе
        final battle = battleService.getBattle(battleId);
        if (battle != null) {
          final opponentId = battle.player1Id == playerId 
              ? battle.player2Id 
              : battle.player1Id;
          
          _sendMessage(opponentId, {
            'type': 'battle_move',
            'data': {
              'battleId': battleId,
              'playerId': playerId,
              'move': move.toJson(),
            },
          });

          // Если бой завершился, отправляем результаты
          if (battle.isFinished) {
            _notifyBattleEnd(battle);
          } else if (battle.battleLog.isNotEmpty) {
            // Отправляем результат последнего раунда
            final lastResult = battle.battleLog.last;
            _sendBattleResult(battle, lastResult);
          }
        }
      } else {
        _sendError(playerId, 'Не удалось выполнить ход');
      }
    } catch (e) {
      _sendError(playerId, 'Ошибка обработки хода: $e');
    }
  }

  /// Выход из боя
  void _handleLeaveBattle(String playerId, Map<String, dynamic> message) {
    final battleId = message['battleId'] as String?;
    
    if (battleId == null) {
      _sendError(playerId, 'ID боя не указан');
      return;
    }

    // Обрабатываем как отключение игрока
    battleService.handlePlayerDisconnect(playerId);
    
    // Уведомляем противника
    final battle = battleService.getBattle(battleId);
    if (battle != null) {
      final opponentId = battle.player1Id == playerId 
          ? battle.player2Id 
          : battle.player1Id;
      
      _sendMessage(opponentId, {
        'type': 'opponent_disconnected',
        'battleId': battleId,
      });
    }
  }

  /// Heartbeat
  void _handleHeartbeat(String playerId, Map<String, dynamic> message) {
    _sendMessage(playerId, {
      'type': 'heartbeat_response',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Запрос статуса сервера
  void _handleServerStatusRequest(String playerId, Map<String, dynamic> message) {
    _sendMessage(playerId, {
      'type': 'server_status',
      'data': {
        'connectedPlayers': connections.length,
        'playersInQueue': matchmakingService.getQueueSize(),
        'activeBattles': battleService.getActiveBattlesCount(),
        'serverTime': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  /// Уведомить о начале боя
  void notifyBattleStart(Battle battle) {
    final battleData = {
      'battleId': battle.id,
      'player1Id': battle.player1Id,
      'player2Id': battle.player2Id,
      'player1Name': battle.player1Name,
      'player2Name': battle.player2Name,
      'player1MaxHealth': battle.player1MaxHealth,
      'player2MaxHealth': battle.player2MaxHealth,
    };

    // Уведомляем обоих игроков
    _sendMessage(battle.player1Id, {
      'type': 'battle_start',
      'data': battleData,
    });

    _sendMessage(battle.player2Id, {
      'type': 'battle_start',
      'data': battleData,
    });

    // Также отправляем сообщение о найденном матче
    _sendMessage(battle.player1Id, {
      'type': 'match_found',
      'data': {
        'opponentId': battle.player2Id,
        'opponentName': battle.player2Name,
        'battleId': battle.id,
      },
    });

    _sendMessage(battle.player2Id, {
      'type': 'match_found',
      'data': {
        'opponentId': battle.player1Id,
        'opponentName': battle.player1Name,
        'battleId': battle.id,
      },
    });

    // Обновляем статус игроков
    if (_playerData[battle.player1Id] != null) {
      _playerData[battle.player1Id] = _playerData[battle.player1Id]!.copyWith(
        inBattle: true,
        battleId: battle.id,
      );
    }
    
    if (_playerData[battle.player2Id] != null) {
      _playerData[battle.player2Id] = _playerData[battle.player2Id]!.copyWith(
        inBattle: true,
        battleId: battle.id,
      );
    }
  }

  /// Отправить результат боя
  void _sendBattleResult(Battle battle, BattleResult result) {
    final message = {
      'type': 'battle_result',
      'data': {
        'battleId': battle.id,
        'result': result.toJson(),
        'player1Health': battle.player1Health,
        'player2Health': battle.player2Health,
      },
    };

    _sendMessage(battle.player1Id, message);
    _sendMessage(battle.player2Id, message);
  }

  /// Уведомить об окончании боя
  void _notifyBattleEnd(Battle battle) {
    final message = {
      'type': 'battle_end',
      'data': {
        'battleId': battle.id,
        'winnerId': battle.winnerId,
        'player1Health': battle.player1Health,
        'player2Health': battle.player2Health,
        'duration': battle.finishedAt != null
            ? battle.finishedAt!.difference(battle.createdAt).inSeconds
            : 0,
      },
    };

    _sendMessage(battle.player1Id, message);
    _sendMessage(battle.player2Id, message);

    // Обновляем статус игроков
    if (_playerData[battle.player1Id] != null) {
      _playerData[battle.player1Id] = _playerData[battle.player1Id]!.copyWith(
        inBattle: false,
        battleId: null,
      );
    }
    
    if (_playerData[battle.player2Id] != null) {
      _playerData[battle.player2Id] = _playerData[battle.player2Id]!.copyWith(
        inBattle: false,
        battleId: null,
      );
    }
  }

  /// Обработать отключение игрока
  void handlePlayerDisconnect(String playerId) {
    // Удаляем из очереди матчмейкинга
    matchmakingService.removeFromQueue(playerId);
    
    // Обрабатываем отключение в боях
    battleService.handlePlayerDisconnect(playerId);
    
    // Удаляем данные игрока
    _playerData.remove(playerId);
    
    // Обновляем статус очереди
    _broadcastQueueStatus();
  }

  /// Отправить статус очереди всем игрокам в очереди
  void _broadcastQueueStatus() {
    final queueSize = matchmakingService.getQueueSize();
    final message = {
      'type': 'matchmaking_status',
      'data': {
        'playersInQueue': queueSize,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };

    // Отправляем всем игрокам в очереди
    for (final player in matchmakingService.getPlayersInQueue()) {
      _sendMessage(player.id, message);
    }
  }

  /// Отправить сообщение игроку
  void _sendMessage(String playerId, Map<String, dynamic> message) {
    final connection = connections[playerId];
    if (connection != null) {
      try {
        message['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        connection.sink.add(json.encode(message));
      } catch (e) {
        print('❌ Ошибка отправки сообщения игроку $playerId: $e');
      }
    }
  }

  /// Отправить ошибку игроку
  void _sendError(String playerId, String errorMessage) {
    _sendMessage(playerId, {
      'type': 'error',
      'message': errorMessage,
    });
  }

  /// Отправить сообщение всем подключенным игрокам
  void broadcast(Map<String, dynamic> message) {
    message['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    final jsonMessage = json.encode(message);
    
    for (final connection in connections.values) {
      try {
        connection.sink.add(jsonMessage);
      } catch (e) {
        print('❌ Ошибка при броадкасте: $e');
      }
    }
  }
}
