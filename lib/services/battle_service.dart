import 'dart:math';
import '../models/player.dart';
import '../models/match.dart';

enum BattlePhase {
  waiting,
  selectAction,
  executing,
  finished,
}

enum AttackZone {
  head,
  body,
  belt,
  legs,
}

enum DefenseZone {
  headBody,
  bodyBelt,
  beltLegs,
  headLegs,
}

enum BattleAction {
  attack,
  defend,
  useItem,
  flee,
}

class BattleMove {
  final String playerId;
  final BattleAction action;
  final AttackZone? attackZone;
  final DefenseZone? defenseZone;
  final String? itemId;
  final DateTime timestamp;

  BattleMove({
    required this.playerId,
    required this.action,
    this.attackZone,
    this.defenseZone,
    this.itemId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'action': action.index,
      'attackZone': attackZone?.index,
      'defenseZone': defenseZone?.index,
      'itemId': itemId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  static BattleMove fromJson(Map<String, dynamic> json) {
    return BattleMove(
      playerId: json['playerId'],
      action: BattleAction.values[json['action']],
      attackZone: json['attackZone'] != null 
          ? AttackZone.values[json['attackZone']] 
          : null,
      defenseZone: json['defenseZone'] != null 
          ? DefenseZone.values[json['defenseZone']] 
          : null,
      itemId: json['itemId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

class BattleResult {
  final String attackerName;
  final String defenderName;
  final int damage;
  final bool isCritical;
  final bool isBlocked;
  final bool isDodged;
  final AttackZone attackZone;
  final DefenseZone? defenseZone;
  final String description;

  BattleResult({
    required this.attackerName,
    required this.defenderName,
    required this.damage,
    required this.isCritical,
    required this.isBlocked,
    required this.isDodged,
    required this.attackZone,
    this.defenseZone,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'attackerName': attackerName,
      'defenderName': defenderName,
      'damage': damage,
      'isCritical': isCritical,
      'isBlocked': isBlocked,
      'isDodged': isDodged,
      'attackZone': attackZone.index,
      'defenseZone': defenseZone?.index,
      'description': description,
    };
  }
}

class Battle {
  final String id;
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;
  final Player player1Data;
  final Player player2Data;
  
  int player1Health;
  int player2Health;
  final int player1MaxHealth;
  final int player2MaxHealth;
  
  BattlePhase phase;
  int currentRound;
  String currentPlayerTurn;
  
  BattleMove? player1Move;
  BattleMove? player2Move;
  
  final List<BattleResult> battleLog;
  String? winnerId;
  final DateTime createdAt;
  DateTime? finishedAt;
  DateTime? lastActionTime;

  Battle({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
    required this.player1Data,
    required this.player2Data,
    DateTime? createdAt,
  }) : player1Health = player1Data.maxHealth,
       player2Health = player2Data.maxHealth,
       player1MaxHealth = player1Data.maxHealth,
       player2MaxHealth = player2Data.maxHealth,
       phase = BattlePhase.selectAction,
       currentRound = 1,
       currentPlayerTurn = player1Id, // Первый ход всегда у игрока 1
       battleLog = [],
       createdAt = createdAt ?? DateTime.now(),
       lastActionTime = DateTime.now();

  bool get isFinished => phase == BattlePhase.finished;
  bool get bothMovesReady => player1Move != null && player2Move != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player1Id': player1Id,
      'player2Id': player2Id,
      'player1Name': player1Name,
      'player2Name': player2Name,
      'player1Health': player1Health,
      'player2Health': player2Health,
      'player1MaxHealth': player1MaxHealth,
      'player2MaxHealth': player2MaxHealth,
      'phase': phase.index,
      'currentRound': currentRound,
      'currentPlayerTurn': currentPlayerTurn,
      'battleLog': battleLog.map((result) => result.toJson()).toList(),
      'winnerId': winnerId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
    };
  }
}

class BattleService {
  final Map<String, Battle> _activeBattles = {};
  final List<Battle> _completedBattles = [];
  final Random _random = Random();
  int _totalBattles = 0;

  /// Создать новый бой
  Battle createBattle(String player1Id, String player2Id, Player player1Data, Player player2Data) {
    final battleId = _generateBattleId();
    
    final battle = Battle(
      id: battleId,
      player1Id: player1Id,
      player2Id: player2Id,
      player1Name: player1Data.name,
      player2Name: player2Data.name,
      player1Data: player1Data,
      player2Data: player2Data,
    );

    _activeBattles[battleId] = battle;
    _totalBattles++;

    print('⚔️  Создан бой: ${player1Data.name} vs ${player2Data.name} (ID: $battleId)');
    return battle;
  }

  /// Получить бой по ID
  Battle? getBattle(String battleId) {
    return _activeBattles[battleId];
  }

  /// Подать ход в бою
  bool submitMove(String battleId, BattleMove move) {
    final battle = _activeBattles[battleId];
    if (battle == null || battle.isFinished) return false;

    // Проверяем, что это ход правильного игрока
    if (move.playerId != battle.currentPlayerTurn) return false;

    // Сохраняем ход
    if (move.playerId == battle.player1Id) {
      battle.player1Move = move;
    } else if (move.playerId == battle.player2Id) {
      battle.player2Move = move;
    } else {
      return false;
    }

    battle.lastActionTime = DateTime.now();

    // Если оба хода готовы, выполняем раунд
    if (battle.bothMovesReady) {
      _executeRound(battle);
    }

    return true;
  }

  /// Выполнить раунд боя
  void _executeRound(Battle battle) {
    if (!battle.bothMovesReady) return;

    battle.phase = BattlePhase.executing;

    final move1 = battle.player1Move!;
    final move2 = battle.player2Move!;

    // Выполняем бой согласно правилам БК
    _processCombat(battle, move1, move2);

    // Проверяем условия окончания боя
    if (battle.player1Health <= 0 || battle.player2Health <= 0) {
      _finishBattle(battle);
    } else {
      // Следующий раунд
      battle.currentRound++;
      battle.player1Move = null;
      battle.player2Move = null;
      battle.phase = BattlePhase.selectAction;
      
      // Меняем очередность хода
      battle.currentPlayerTurn = battle.currentPlayerTurn == battle.player1Id 
          ? battle.player2Id 
          : battle.player1Id;
    }
  }

  /// Обработать бой между двумя ходами
  void _processCombat(Battle battle, BattleMove move1, BattleMove move2) {
    // Оба игрока атакуют друг друга
    if (move1.action == BattleAction.attack && move2.action == BattleAction.attack) {
      // Игрок 1 атакует игрока 2
      final result1 = _calculateAttack(
        battle.player1Data,
        battle.player2Data,
        move1.attackZone!,
        move2.defenseZone!,
      );
      
      if (result1.damage > 0) {
        battle.player2Health -= result1.damage;
        if (battle.player2Health < 0) battle.player2Health = 0;
      }
      
      battle.battleLog.add(result1);

      // Игрок 2 атакует игрока 1 (если не убит)
      if (battle.player2Health > 0) {
        final result2 = _calculateAttack(
          battle.player2Data,
          battle.player1Data,
          move2.attackZone!,
          move1.defenseZone!,
        );
        
        if (result2.damage > 0) {
          battle.player1Health -= result2.damage;
          if (battle.player1Health < 0) battle.player1Health = 0;
        }
        
        battle.battleLog.add(result2);
      }
    }
  }

  /// Вычислить результат атаки по правилам БК
  BattleResult _calculateAttack(Player attacker, Player defender, AttackZone attackZone, DefenseZone defenseZone) {
    // 1. Проверяем блок
    bool isBlocked = _isZoneBlocked(attackZone, defenseZone);
    
    // 2. Если заблокировано, проверяем прорыв блока
    if (isBlocked) {
      // Шанс прорыва блока зависит от антиуворота атакующего
      int blockBreakChance = attacker.antiDodgeModifier;
      if (_random.nextInt(100) >= blockBreakChance) {
        // Блок успешен
        return BattleResult(
          attackerName: attacker.name,
          defenderName: defender.name,
          damage: 0,
          isCritical: false,
          isBlocked: true,
          isDodged: false,
          attackZone: attackZone,
          defenseZone: defenseZone,
          description: '${attacker.name} атакует ${_getAttackZoneName(attackZone)}, но ${defender.name} блокирует удар!',
        );
      }
    }

    // 3. Проверяем уворот
    bool isDodged = false;
    if (!isBlocked) {
      int dodgeChance = defender.dodgeModifier;
      int antiDodgeModifier = attacker.antiDodgeModifier;
      int finalDodgeChance = (dodgeChance - antiDodgeModifier).clamp(0, 95);
      
      if (_random.nextInt(100) < finalDodgeChance) {
        isDodged = true;
        return BattleResult(
          attackerName: attacker.name,
          defenderName: defender.name,
          damage: 0,
          isCritical: false,
          isBlocked: false,
          isDodged: true,
          attackZone: attackZone,
          defenseZone: defenseZone,
          description: '${attacker.name} атакует ${_getAttackZoneName(attackZone)}, но ${defender.name} уворачивается!',
        );
      }
    }

    // 4. Проверяем критический удар
    bool isCritical = false;
    int critChance = attacker.criticalHitModifier;
    int critDefense = defender.criticalDefenseModifier;
    int finalCritChance = (critChance - critDefense).clamp(0, 50);
    
    if (_random.nextInt(100) < finalCritChance) {
      isCritical = true;
    }

    // 5. Вычисляем урон
    int baseDamage = attacker.totalDamage;
    
    // Модификатор критического удара
    if (isCritical) {
      baseDamage = (baseDamage * 1.5).round();
    }

    // Модификатор зоны атаки
    double zoneModifier = _getZoneDamageModifier(attackZone);
    baseDamage = (baseDamage * zoneModifier).round();

    // Вычитаем защиту
    int finalDamage = baseDamage - defender.totalArmor - defender.damageDefense.round();
    finalDamage = finalDamage.clamp(1, 9999); // Минимум 1 урона

    String description = _generateAttackDescription(
      attacker.name,
      defender.name,
      attackZone,
      finalDamage,
      isCritical,
      isBlocked,
      isDodged,
    );

    return BattleResult(
      attackerName: attacker.name,
      defenderName: defender.name,
      damage: finalDamage,
      isCritical: isCritical,
      isBlocked: isBlocked,
      isDodged: isDodged,
      attackZone: attackZone,
      defenseZone: defenseZone,
      description: description,
    );
  }

  /// Проверить, заблокирована ли зона
  bool _isZoneBlocked(AttackZone attackZone, DefenseZone defenseZone) {
    switch (defenseZone) {
      case DefenseZone.headBody:
        return attackZone == AttackZone.head || attackZone == AttackZone.body;
      case DefenseZone.bodyBelt:
        return attackZone == AttackZone.body || attackZone == AttackZone.belt;
      case DefenseZone.beltLegs:
        return attackZone == AttackZone.belt || attackZone == AttackZone.legs;
      case DefenseZone.headLegs:
        return attackZone == AttackZone.head || attackZone == AttackZone.legs;
    }
  }

  /// Получить модификатор урона для зоны
  double _getZoneDamageModifier(AttackZone zone) {
    switch (zone) {
      case AttackZone.head:
        return 1.3; // +30% урона в голову
      case AttackZone.body:
        return 1.0; // Базовый урон
      case AttackZone.belt:
        return 0.9; // -10% урона в пояс
      case AttackZone.legs:
        return 0.8; // -20% урона в ноги
    }
  }

  /// Получить название зоны атаки
  String _getAttackZoneName(AttackZone zone) {
    switch (zone) {
      case AttackZone.head:
        return 'в голову';
      case AttackZone.body:
        return 'в корпус';
      case AttackZone.belt:
        return 'в пояс';
      case AttackZone.legs:
        return 'по ногам';
    }
  }

  /// Генерировать описание атаки
  String _generateAttackDescription(String attackerName, String defenderName, AttackZone zone, int damage, bool isCritical, bool isBlocked, bool isDodged) {
    String zoneName = _getAttackZoneName(zone);
    String critText = isCritical ? ' критически' : '';
    
    return '$attackerName$critText атакует $defenderName $zoneName и наносит $damage урона!';
  }

  /// Завершить бой
  void _finishBattle(Battle battle) {
    battle.phase = BattlePhase.finished;
    battle.finishedAt = DateTime.now();

    if (battle.player1Health <= 0) {
      battle.winnerId = battle.player2Id;
    } else if (battle.player2Health <= 0) {
      battle.winnerId = battle.player1Id;
    }

    // Перемещаем в завершенные бои
    _activeBattles.remove(battle.id);
    _completedBattles.add(battle);

    print('🏁 Бой завершен: ${battle.player1Name} vs ${battle.player2Name}, '
          'победитель: ${battle.winnerId == battle.player1Id ? battle.player1Name : battle.player2Name}');
  }

  /// Обработать отключение игрока
  void handlePlayerDisconnect(String playerId) {
    final battleToFinish = _activeBattles.values
        .where((battle) => battle.player1Id == playerId || battle.player2Id == playerId)
        .firstOrNull;

    if (battleToFinish != null) {
      // Противник автоматически выигрывает
      battleToFinish.winnerId = battleToFinish.player1Id == playerId 
          ? battleToFinish.player2Id 
          : battleToFinish.player1Id;
      
      _finishBattle(battleToFinish);
      print('📤 Игрок $playerId отключился, бой ${battleToFinish.id} завершен досрочно');
    }
  }

  /// Получить количество активных боев
  int getActiveBattlesCount() {
    return _activeBattles.length;
  }

  /// Получить общее количество боев
  int getTotalBattles() {
    return _totalBattles;
  }

  /// Генерировать ID боя
  String _generateBattleId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(10000).toString().padLeft(4, '0');
    return 'battle_${timestamp}_$randomPart';
  }

  /// Получить статистику боев
  Map<String, dynamic> getStatistics() {
    return {
      'activeBattles': _activeBattles.length,
      'completedBattles': _completedBattles.length,
      'totalBattles': _totalBattles,
      'averageBattleDuration': _calculateAverageBattleDuration(),
    };
  }

  /// Вычислить среднюю продолжительность боя
  double _calculateAverageBattleDuration() {
    if (_completedBattles.isEmpty) return 0.0;
    
    final totalDuration = _completedBattles
        .where((battle) => battle.finishedAt != null)
        .map((battle) => battle.finishedAt!.difference(battle.createdAt).inSeconds)
        .reduce((a, b) => a + b);
        
    return totalDuration / _completedBattles.length;
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
