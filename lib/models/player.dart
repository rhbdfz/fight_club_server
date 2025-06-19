class Player {
  final String id;
  final String name;
  final int level;
  final int experience;
  
  // Основные характеристики
  final int strength;
  final int dexterity;
  final int intuition;
  final int endurance;
  
  // Здоровье
  final int currentHealth;
  final int maxHealth;
  
  // Умения
  final int lightWeaponSkill;
  final int heavyWeaponSkill;
  final int shieldSkill;
  final int shieldMastery;
  final int dualWieldMastery;
  
  // Экипировка
  final Equipment? weapon;
  final Equipment? shield;
  final Equipment? helmet;
  final Equipment? armor;
  final Equipment? gloves;
  final Equipment? boots;
  
  // Статус
  final bool inBattle;
  final String? battleId;
  final DateTime lastActive;

  Player({
    required this.id,
    required this.name,
    required this.level,
    required this.experience,
    required this.strength,
    required this.dexterity,
    required this.intuition,
    required this.endurance,
    required this.currentHealth,
    required this.maxHealth,
    required this.lightWeaponSkill,
    required this.heavyWeaponSkill,
    required this.shieldSkill,
    required this.shieldMastery,
    required this.dualWieldMastery,
    this.weapon,
    this.shield,
    this.helmet,
    this.armor,
    this.gloves,
    this.boots,
    this.inBattle = false,
    this.battleId,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  // Вычисляемые характеристики (по правилам БК)
  
  /// Модификатор уворота (+5 за каждый пункт ловкости)
  int get dodgeModifier => dexterity * 5;
  
  /// Модификатор антиуворота (+5 за каждый пункт ловкости)
  int get antiDodgeModifier => dexterity * 5;
  
  /// Модификатор критического удара (+5 за каждый пункт интуиции)
  int get criticalHitModifier => intuition * 5;
  
  /// Модификатор защиты от критов (+5 за каждый пункт интуиции)
  int get criticalDefenseModifier => intuition * 5;
  
  /// Защита от урона (+1.5 за каждый пункт выносливости)
  double get damageDefense => endurance * 1.5;
  
  /// Общий урон оружия с учетом силы
  int get totalDamage {
    int baseDamage = weapon?.damage ?? 1;
    return (baseDamage + (strength * 0.5)).round();
  }
  
  /// Общая броня с учетом всей экипировки
  int get totalArmor {
    int armor = 0;
    if (helmet != null) armor += helmet!.armor;
    if (this.armor != null) armor += this.armor!.armor;
    if (gloves != null) armor += gloves!.armor;
    if (boots != null) armor += boots!.armor;
    return armor;
  }

  /// Лимит блока щитом с учетом мастерства
  int get shieldBlockLimit {
    if (shield == null) return 0;
    int baseLimit = 50; // Базовый лимит блока щитом
    return baseLimit + (shieldMastery * 3); // +3% за каждое очко мастерства
  }

  /// Защита от магии с учетом щита и мастерства
  int get magicDefense {
    if (shield == null) return 0;
    int baseDefense = shield!.magicDefense;
    return baseDefense + (shieldMastery * 3); // +3% за каждое очко мастерства
  }

  /// Штраф второй руки с учетом мастерства
  int get dualWieldPenalty {
    int basePenalty = 20; // Базовый штраф 20%
    return (basePenalty - (dualWieldMastery * 2)).clamp(0, 20); // Уменьшение на 2% за очко
  }

  // Копирование с изменениями
  Player copyWith({
    String? id,
    String? name,
    int? level,
    int? experience,
    int? strength,
    int? dexterity,
    int? intuition,
    int? endurance,
    int? currentHealth,
    int? maxHealth,
    int? lightWeaponSkill,
    int? heavyWeaponSkill,
    int? shieldSkill,
    int? shieldMastery,
    int? dualWieldMastery,
    Equipment? weapon,
    Equipment? shield,
    Equipment? helmet,
    Equipment? armor,
    Equipment? gloves,
    Equipment? boots,
    bool? inBattle,
    String? battleId,
    DateTime? lastActive,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      intuition: intuition ?? this.intuition,
      endurance: endurance ?? this.endurance,
      currentHealth: currentHealth ?? this.currentHealth,
      maxHealth: maxHealth ?? this.maxHealth,
      lightWeaponSkill: lightWeaponSkill ?? this.lightWeaponSkill,
      heavyWeaponSkill: heavyWeaponSkill ?? this.heavyWeaponSkill,
      shieldSkill: shieldSkill ?? this.shieldSkill,
      shieldMastery: shieldMastery ?? this.shieldMastery,
      dualWieldMastery: dualWieldMastery ?? this.dualWieldMastery,
      weapon: weapon ?? this.weapon,
      shield: shield ?? this.shield,
      helmet: helmet ?? this.helmet,
      armor: armor ?? this.armor,
      gloves: gloves ?? this.gloves,
      boots: boots ?? this.boots,
      inBattle: inBattle ?? this.inBattle,
      battleId: battleId ?? this.battleId,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  // Сериализация
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'experience': experience,
      'strength': strength,
      'dexterity': dexterity,
      'intuition': intuition,
      'endurance': endurance,
      'currentHealth': currentHealth,
      'maxHealth': maxHealth,
      'lightWeaponSkill': lightWeaponSkill,
      'heavyWeaponSkill': heavyWeaponSkill,
      'shieldSkill': shieldSkill,
      'shieldMastery': shieldMastery,
      'dualWieldMastery': dualWieldMastery,
      'weapon': weapon?.toJson(),
      'shield': shield?.toJson(),
      'helmet': helmet?.toJson(),
      'armor': armor?.toJson(),
      'gloves': gloves?.toJson(),
      'boots': boots?.toJson(),
      'inBattle': inBattle,
      'battleId': battleId,
      'lastActive': lastActive.millisecondsSinceEpoch,
      // Добавляем вычисляемые характеристики для отправки клиенту
      'totalDamage': totalDamage,
      'totalArmor': totalArmor,
      'dodgeModifier': dodgeModifier,
      'criticalHitModifier': criticalHitModifier,
      'criticalDefenseModifier': criticalDefenseModifier,
      'damageDefense': damageDefense,
    };
  }

  static Player fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      level: json['level'] ?? 1,
      experience: json['experience'] ?? 0,
      strength: json['strength'] ?? 1,
      dexterity: json['dexterity'] ?? 1,
      intuition: json['intuition'] ?? 1,
      endurance: json['endurance'] ?? 1,
      currentHealth: json['currentHealth'] ?? 20,
      maxHealth: json['maxHealth'] ?? 20,
      lightWeaponSkill: json['lightWeaponSkill'] ?? 1,
      heavyWeaponSkill: json['heavyWeaponSkill'] ?? 1,
      shieldSkill: json['shieldSkill'] ?? 1,
      shieldMastery: json['shieldMastery'] ?? 0,
      dualWieldMastery: json['dualWieldMastery'] ?? 0,
      weapon: json['weapon'] != null ? Equipment.fromJson(json['weapon']) : null,
      shield: json['shield'] != null ? Equipment.fromJson(json['shield']) : null,
      helmet: json['helmet'] != null ? Equipment.fromJson(json['helmet']) : null,
      armor: json['armor'] != null ? Equipment.fromJson(json['armor']) : null,
      gloves: json['gloves'] != null ? Equipment.fromJson(json['gloves']) : null,
      boots: json['boots'] != null ? Equipment.fromJson(json['boots']) : null,
      inBattle: json['inBattle'] ?? false,
      battleId: json['battleId'],
      lastActive: json['lastActive'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActive'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Player(id: $id, name: $name, level: $level, health: $currentHealth/$maxHealth)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Перечисление для типов экипировки
enum EquipmentType {
  weapon,
  shield,
  helmet,
  armor,
  gloves,
  boots,
}

// Класс экипировки
class Equipment {
  final String id;
  final String name;
  final EquipmentType type;
  final int damage;
  final int armor;
  final int magicDefense;
  final int durability;
  final int maxDurability;
  final Map<String, int> requirements;
  final Map<String, int> bonuses;

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    this.damage = 0,
    this.armor = 0,
    this.magicDefense = 0,
    this.durability = 100,
    this.maxDurability = 100,
    this.requirements = const {},
    this.bonuses = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'damage': damage,
      'armor': armor,
      'magicDefense': magicDefense,
      'durability': durability,
      'maxDurability': maxDurability,
      'requirements': requirements,
      'bonuses': bonuses,
    };
  }

  static Equipment fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
      type: EquipmentType.values[json['type']],
      damage: json['damage'] ?? 0,
      armor: json['armor'] ?? 0,
      magicDefense: json['magicDefense'] ?? 0,
      durability: json['durability'] ?? 100,
      maxDurability: json['maxDurability'] ?? 100,
      requirements: Map<String, int>.from(json['requirements'] ?? {}),
      bonuses: Map<String, int>.from(json['bonuses'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'Equipment(id: $id, name: $name, type: $type)';
  }
}