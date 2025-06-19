import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../lib/services/matchmaking_service.dart';
import '../lib/services/battle_service.dart';
import '../lib/handlers/websocket_handler.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class GameServer {
  static const int port = 8080;
  static const String host = 'localhost';

  late HttpServer _server;
  late MatchmakingService _matchmakingService;
  late BattleService _battleService;
  late WebSocketHandler _webSocketHandler;

  final Map<String, WebSocketChannel> _connections = {};
  Timer? _heartbeatTimer;

  Future<void> start() async {
    // Инициализация сервисов
    _matchmakingService = MatchmakingService();
    _battleService = BattleService();
    _webSocketHandler = WebSocketHandler(
      connections: _connections,
      matchmakingService: _matchmakingService,
      battleService: _battleService,
    );

    // Настройка маршрутов
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(_createHandler());

    // Запуск сервера
    _server = await io.serve(handler, host, port);

    print('🚀 Сервер "Бойцовский клуб" запущен на http://$host:$port');
    print('🔗 WebSocket endpoint: ws://$host:$port/ws');
    print('📊 Статистика доступна на: http://$host:$port/stats');

    // Запуск периодических задач
    _startHeartbeat();
    _startMatchmakingTick();

    // Обработка сигналов завершения
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n⚠️  Получен сигнал завершения...');
      await shutdown();
      exit(0);
    });
  }

  Future<void> shutdown() async {
    print('🛑 Остановка сервера...');

    // Останавливаем таймеры
    _heartbeatTimer?.cancel();

    // Уведомляем всех клиентов о завершении работы
    final shutdownMessage = {
      'type': 'server_shutdown',
      'message': 'Сервер завершает работу',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    for (final connection in _connections.values) {
      try {
        connection.sink.add(json.encode(shutdownMessage));
        await connection.sink.close();
      } catch (e) {
        print('Ошибка при закрытии соединения: $e');
      }
    }

    // Останавливаем HTTP сервер
    await _server.close(force: true);
    print('✅ Сервер остановлен');
  }

  Handler _createHandler() {
    return (Request request) {
      final path = request.url.path;

      switch (path) {
        case 'ws':
          return webSocketHandler((WebSocketChannel webSocket) {
            final playerId = request.url.queryParameters['playerId'];

            if (playerId == null || playerId.isEmpty) {
              webSocket.sink.add(json.encode({
                'type': 'error',
                'message': 'Не указан playerId',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }));
              webSocket.sink.close();
              return;
            }

            print('📱 Подключился игрок: $playerId');

            // Регистрируем соединение
            _connections[playerId] = webSocket;

            // Отправляем приветственное сообщение
            webSocket.sink.add(json.encode({
              'type': 'welcome',
              'message': 'Добро пожаловать в Бойцовский клуб!',
              'playerId': playerId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }));

            // Обрабатываем сообщения от клиента
            webSocket.stream.listen(
                  (message) {
                try {
                  final data = json.decode(message) as Map<String, dynamic>;
                  _webSocketHandler.handleMessage(playerId, data);
                } catch (e) {
                  print('❌ Ошибка обработки сообщения от $playerId: $e');
                  _sendError(playerId, 'Ошибка обработки сообщения: $e');
                }
              },
              onDone: () {
                _handlePlayerDisconnect(playerId);
              },
              onError: (error) {
                print('❌ Ошибка соединения с $playerId: $error');
                _handlePlayerDisconnect(playerId);
              },
            );
          })(request);
        case 'stats':
          final stats = {
            'server': {
              'status': 'running',
              'startTime': DateTime.now().toIso8601String(),
              'host': host,
              'port': port,
            },
            'connections': {
              'total': _connections.length,
              'players': _connections.keys.toList(),
            },
            'matchmaking': {
              'playersInQueue': _matchmakingService.getQueueSize(),
              'totalMatches': _matchmakingService.getTotalMatches(),
            },
            'battles': {
              'activeBattles': _battleService.getActiveBattlesCount(),
              'totalBattles': _battleService.getTotalBattles(),
            },
          };
          return Response.ok(
            json.encode(stats),
            headers: {'Content-Type': 'application/json'},
          );
        case 'health':
          return Response.ok(json.encode({
            'status': 'healthy',
            'timestamp': DateTime.now().toIso8601String(),
          }));
        default:
          return Response.notFound(json.encode({
            'error': 'Endpoint not found',
            'path': request.url.path,
          }));
      }
    };
  }

  void _handlePlayerDisconnect(String playerId) {
    print('📤 Отключился игрок: $playerId');

    // Удаляем из очереди матчмейкинга
    _matchmakingService.removeFromQueue(playerId);

    // Обрабатываем отключение в активных боях
    _battleService.handlePlayerDisconnect(playerId);

    // Удаляем соединение
    _connections.remove(playerId);

    // Уведомляем других игроков если необходимо
    _webSocketHandler.handlePlayerDisconnect(playerId);
  }

  void _sendError(String playerId, String message) {
    final connection = _connections[playerId];
    if (connection != null) {
      connection.sink.add(json.encode({
        'type': 'error',
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final heartbeatMessage = json.encode({
        'type': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Отправляем heartbeat всем подключенным клиентам
      final disconnectedPlayers = <String>[];

      for (final entry in _connections.entries) {
        try {
          entry.value.sink.add(heartbeatMessage);
        } catch (e) {
          print('❌ Ошибка отправки heartbeat игроку ${entry.key}: $e');
          disconnectedPlayers.add(entry.key);
        }
      }

      // Удаляем отключенных игроков
      for (final playerId in disconnectedPlayers) {
        _handlePlayerDisconnect(playerId);
      }

      if (_connections.isNotEmpty) {
        print('💓 Heartbeat отправлен ${_connections.length} игрокам');
      }
    });
  }

  void _startMatchmakingTick() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        final matches = _matchmakingService.processPendingMatches();

        for (final match in matches) {
          final battle = _battleService.createBattle(
            match.player1Id,
            match.player2Id,
            match.player1Data,
            match.player2Data,
          );

          // Уведомляем игроков о начале боя
          _webSocketHandler.notifyBattleStart(battle);
          print('⚔️  Создан новый бой: ${battle.id} между ${match.player1Id} и ${match.player2Id}');
        }
      } catch (e) {
        print('❌ Ошибка в процессе матчмейкинга: $e');
      }
    });
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  };
}

void main(List<String> args) async {
  final server = GameServer();

  try {
    await server.start();
    await Completer<void>().future;
  } catch (e) {
    print('❌ Критическая ошибка сервера: $e');
    exit(1);
  }
}
