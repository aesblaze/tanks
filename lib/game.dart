import 'dart:math' as math;

import 'package:flutter/services.dart';

const List<String> kMaze = [
  '###############',
  '#.............#',
  '#.####.#.####.#',
  '#.B.........B.#',
  '#.#.#B...B#.#.#',
  '#....#.#.#....#',
  '##.B...#...B.##',
  '#..#.#####.#..#',
  '#.B.........B.#',
  '#.#.##B####.#.#',
  '#...#.....B...#',
  '###.......#.###',
  '###############',
];

const int kPlayerCol = 1;
const int kPlayerRow = 10;
const int kMazeRows = 13;
const int kMazeCols = 15;
const int kNextLevelStartRow = 11;
const int kNextLevelStartCol = 1;

List<String> generateMaze(math.Random random) {
  final grid = List<List<String>>.generate(
    kMazeRows,
    (_) => List<String>.filled(kMazeCols, '#'),
  );
  grid[1][1] = '.';
  final stack = <int>[1 * kMazeCols + 1];
  while (stack.isNotEmpty) {
    final cell = stack.last;
    final row = cell ~/ kMazeCols;
    final col = cell % kMazeCols;
    final neighbors = <int>[];
    for (final delta in const [
      [-2, 0],
      [2, 0],
      [0, -2],
      [0, 2],
    ]) {
      final nextRow = row + delta[0];
      final nextCol = col + delta[1];
      if (nextRow <= 0 ||
          nextRow >= kMazeRows - 1 ||
          nextCol <= 0 ||
          nextCol >= kMazeCols - 1 ||
          grid[nextRow][nextCol] == '.') {
        continue;
      }
      neighbors.add(nextRow * kMazeCols + nextCol);
    }
    if (neighbors.isEmpty) {
      stack.removeLast();
      continue;
    }
    final next = neighbors[random.nextInt(neighbors.length)];
    final nextRow = next ~/ kMazeCols;
    final nextCol = next % kMazeCols;
    grid[(row + nextRow) ~/ 2][(col + nextCol) ~/ 2] = '.';
    grid[nextRow][nextCol] = '.';
    stack.add(next);
  }

  final walls = <int>[];
  for (var row = 1; row < kMazeRows - 1; row++) {
    for (var col = 1; col < kMazeCols - 1; col++) {
      if (grid[row][col] != '#' || (row.isEven && col.isEven)) {
        continue;
      }
      var touchesFloor = false;
      for (final delta in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        if (grid[row + delta[0]][col + delta[1]] == '.') {
          touchesFloor = true;
          break;
        }
      }
      if (touchesFloor) {
        walls.add(row * kMazeCols + col);
      }
    }
  }
  walls.shuffle(random);
  final openCount = math.min(6, walls.length);
  for (var i = 0; i < openCount; i++) {
    grid[walls[i] ~/ kMazeCols][walls[i] % kMazeCols] = '.';
  }
  final breakable = math.min(10, walls.length - openCount);
  for (var i = 0; i < breakable; i++) {
    final wall = walls[openCount + i];
    grid[wall ~/ kMazeCols][wall % kMazeCols] = 'B';
  }

  return grid.map((line) => line.join()).toList();
}

enum Direction {
  up(0, -1, 0),
  down(0, 1, math.pi),
  left(-1, 0, -math.pi / 2),
  right(1, 0, math.pi / 2);

  const Direction(this.dx, this.dy, this.angle);

  final int dx;
  final int dy;
  final double angle;

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  static Direction? fromKey(KeyEvent event) {
    final key = event.logicalKey;
    final physical = event.physicalKey;
    if (key == LogicalKeyboardKey.keyW ||
        physical == PhysicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.arrowUp) {
      return Direction.up;
    }
    if (key == LogicalKeyboardKey.keyS ||
        physical == PhysicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.arrowDown) {
      return Direction.down;
    }
    if (key == LogicalKeyboardKey.keyA ||
        physical == PhysicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.arrowLeft) {
      return Direction.left;
    }
    if (key == LogicalKeyboardKey.keyD ||
        physical == PhysicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      return Direction.right;
    }
    return null;
  }
}

enum ProjectileOwner { player, enemy }

Direction directionFromName(String? name) => Direction.values.firstWhere(
      (direction) => direction.name == name,
      orElse: () => Direction.up,
    );

enum GameStatus { playing, lost }

class Enemy {
  Enemy({
    required this.row,
    required this.col,
    required this.facing,
    this.armored = false,
  })  : fromRow = row,
        fromCol = col,
        fromFacing = facing,
        shield = armored ? 1 : 0;

  static const int maxLives = 1;

  int row;
  int col;
  Direction facing;
  int fromRow;
  int fromCol;
  Direction fromFacing;
  bool armored;
  int shield;
  int lives = maxLives;
  Duration moveStarted = const Duration(seconds: -10);

  bool get shielded => shield > 0;
}

class Medkit {
  Medkit({required this.row, required this.col});

  final int row;
  final int col;
}

class Beam {
  Beam({
    required this.row,
    required this.col,
    required this.cells,
    required this.direction,
    required this.started,
  });

  final int row;
  final int col;
  final List<int> cells;
  final Direction direction;
  final Duration started;
  int ticks = 0;
}

class Projectile {
  Projectile({
    required this.row,
    required this.col,
    required this.direction,
    required this.owner,
  });

  int row;
  int col;
  final Direction direction;
  final ProjectileOwner owner;
}

class Explosion {
  Explosion({required this.row, required this.col, required this.started});

  final int row;
  final int col;
  final Duration started;
}

class Mine {
  Mine({required this.row, required this.col});

  final int row;
  final int col;
}

class Bush {
  Bush({required this.row, required this.col});

  final int row;
  final int col;
}

class Game {
  Game._restore({math.Random? random})
      : level = 1,
        random = random ?? math.Random();

  factory Game.fromJson(Map<String, dynamic> json, {math.Random? random}) {
    final game = Game._restore(random: random);
    game.level = (json['level'] as num?)?.toInt() ?? 1;
    game.maze = (json['maze'] as List).map((row) => row as String).toList();
    for (final cell in (json['destroyed'] as List? ?? const [])) {
      final index = (cell as num).toInt();
      final row = index ~/ kMazeCols;
      final col = index % kMazeCols;
      if (row >= 0 && row < kMazeRows && col >= 0 && col < kMazeCols) {
        game._destroyed[row][col] = true;
      }
    }
    game.playerRow = (json['playerRow'] as num?)?.toInt() ?? kPlayerRow;
    game.playerCol = (json['playerCol'] as num?)?.toInt() ?? kPlayerCol;
    game.playerFacing = directionFromName(json['playerFacing'] as String?);
    game.playerFromRow = game.playerRow;
    game.playerFromCol = game.playerCol;
    game.playerFromFacing = game.playerFacing;
    game.lives = (json['lives'] as num?)?.toInt() ?? maxLives;
    game.kills = (json['kills'] as num?)?.toInt() ?? 0;
    game.abilityCharges = (json['abilityCharges'] as num?)?.toInt() ?? 0;
    game.shotCharges =
        (json['shotCharges'] as num?)?.toInt() ?? maxShotCharges;
    game.tripleAmmo = (json['tripleAmmo'] as num?)?.toInt() ?? 0;

    for (final item in (json['enemies'] as List? ?? const [])) {
      final data = item as Map<String, dynamic>;
      final enemy = Enemy(
        row: (data['row'] as num?)?.toInt() ?? 1,
        col: (data['col'] as num?)?.toInt() ?? 1,
        facing: directionFromName(data['facing'] as String?),
        armored: data['armored'] == true,
      );
      enemy.shield = (data['shield'] as num?)?.toInt() ?? enemy.shield;
      enemy.lives = (data['lives'] as num?)?.toInt() ?? enemy.lives;
      game.enemies.add(enemy);
    }

    for (final item in (json['medkits'] as List? ?? const [])) {
      final data = item as Map<String, dynamic>;
      game.medkits.add(
        Medkit(
          row: (data['row'] as num).toInt(),
          col: (data['col'] as num).toInt(),
        ),
      );
    }
    for (final item in (json['mines'] as List? ?? const [])) {
      final data = item as Map<String, dynamic>;
      game.mines.add(
        Mine(
          row: (data['row'] as num).toInt(),
          col: (data['col'] as num).toInt(),
        ),
      );
    }
    for (final item in (json['bushes'] as List? ?? const [])) {
      final data = item as Map<String, dynamic>;
      game.bushes.add(
        Bush(
          row: (data['row'] as num).toInt(),
          col: (data['col'] as num).toInt(),
        ),
      );
    }

    game._levelStartedAt = const Duration(seconds: -10);
    return game;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'level': level,
        'maze': maze,
        'destroyed': <int>[
          for (var row = 0; row < maze.length; row++)
            for (var col = 0; col < maze.first.length; col++)
              if (_destroyed[row][col]) row * maze.first.length + col,
        ],
        'playerRow': playerRow,
        'playerCol': playerCol,
        'playerFacing': playerFacing.name,
        'lives': lives,
        'kills': kills,
        'abilityCharges': abilityCharges,
        'shotCharges': shotCharges,
        'tripleAmmo': tripleAmmo,
        'enemies': <Map<String, dynamic>>[
          for (final enemy in enemies)
            <String, dynamic>{
              'row': enemy.row,
              'col': enemy.col,
              'facing': enemy.facing.name,
              'armored': enemy.armored,
              'shield': enemy.shield,
              'lives': enemy.lives,
            },
        ],
        'medkits': <Map<String, dynamic>>[
          for (final medkit in medkits)
            <String, dynamic>{'row': medkit.row, 'col': medkit.col},
        ],
        'mines': <Map<String, dynamic>>[
          for (final mine in mines)
            <String, dynamic>{'row': mine.row, 'col': mine.col},
        ],
        'bushes': <Map<String, dynamic>>[
          for (final bush in bushes)
            <String, dynamic>{'row': bush.row, 'col': bush.col},
        ],
      };

  Game({
    math.Random? random,
    List<Enemy>? enemies,
    List<String>? maze,
    this.level = 1,
  }) : random = random ?? math.Random() {
    this.maze = maze ?? (level == 1 ? kMaze : generateMaze(this.random));
    if (maze == null && level > 1) {
      playerRow = kNextLevelStartRow;
      playerCol = kNextLevelStartCol;
      playerFromRow = kNextLevelStartRow;
      playerFromCol = kNextLevelStartCol;
    }
    this.enemies.addAll(
          enemies ?? (level == 1 ? _defaultEnemies() : _placeEnemies()),
        );
    _lastMedkitSpawn = _clock;
    _spawnMedkits();
    _lastMineSpawn = _clock;
    for (var i = 0; i < initialMines; i++) {
      _spawnMines();
    }
    _spawnBushes();
  }

  static const int maxLives = 6;
  static const int maxMedkits = 3;
  static const int maxMines = 5;
  static const int initialMines = 3;
  static const int bushCount = 14;
  static const int maxEnemies = 12;
  static const int maxShotCharges = 5;
  static const int tripleAmmoMax = 5;
  static const int killsForTriple = 5;
  static const Duration shotRechargeInterval = Duration(seconds: 1);
  static const Duration medkitSpawnInterval = Duration(seconds: 30);
  static const Duration mineSpawnInterval = Duration(seconds: 20);
  static const Duration playerMoveInterval = Duration(milliseconds: 130);
  static const Duration playerShotInterval = Duration(milliseconds: 320);
  static const Duration enemyMoveInterval = Duration(milliseconds: 450);
  static const Duration enemyShotInterval = Duration(milliseconds: 2000);
  static const Duration projectileMoveInterval = Duration(milliseconds: 140);
  static const Duration invulnerability = Duration(milliseconds: 1000);
  static const Duration beamDuration = Duration(seconds: 5);
  static const Duration beamTickInterval = Duration(seconds: 1);
  static const Duration explosionDuration = Duration(milliseconds: 300);
  static const Duration levelBannerDuration = Duration(milliseconds: 1600);
  static const int killsPerCharge = 3;

  final math.Random random;
  final List<Enemy> enemies = <Enemy>[];
  final List<Projectile> projectiles = <Projectile>[];
  final List<Medkit> medkits = <Medkit>[];
  final List<Mine> mines = <Mine>[];
  final List<Bush> bushes = <Bush>[];
  final List<Explosion> explosions = <Explosion>[];
  final List<Direction> _pressed = <Direction>[];
  final List<List<bool>> _destroyed = List<List<bool>>.generate(
    kMazeRows,
    (_) => List<bool>.filled(kMazeCols, false),
  );

  late List<String> maze;
  int level;
  int playerRow = kPlayerRow;
  int playerCol = kPlayerCol;
  Direction playerFacing = Direction.up;
  int playerFromRow = kPlayerRow;
  int playerFromCol = kPlayerCol;
  Direction playerFromFacing = Direction.up;
  int lives = maxLives;
  int kills = 0;
  int abilityCharges = 0;
  int shotCharges = maxShotCharges;
  int tripleAmmo = 0;
  GameStatus status = GameStatus.playing;
  Beam? beam;
  bool awaitingNextLevel = false;
  bool paused = false;
  int revision = 0;

  Duration _clock = Duration.zero;
  Duration _levelStartedAt = Duration.zero;
  Duration _lastPlayerMove = const Duration(seconds: -10);
  Duration _playerMoveAnimStart = const Duration(seconds: -10);
  Duration _lastMedkitSpawn = Duration.zero;
  Duration _lastMineSpawn = Duration.zero;
  Duration _lastPlayerShot = Duration.zero;
  Duration _lastShotRecharge = Duration.zero;
  Duration _lastEnemyMove = Duration.zero;
  Duration _lastEnemyShot = Duration.zero;
  Duration _lastProjectileMove = Duration.zero;
  Duration _lastHit = const Duration(seconds: -10);
  bool _shooting = false;
  bool _levelComplete = false;

  bool get playerInvulnerable => _clock - _lastHit < invulnerability;

  double get playerMoveProgress =>
      _progress(_playerMoveAnimStart, playerMoveInterval);

  double enemyMoveProgress(Enemy enemy) =>
      _progress(enemy.moveStarted, enemyMoveInterval);

  bool get isAnimating =>
      playerMoveProgress < 1 ||
      beam != null ||
      explosions.isNotEmpty ||
      enemies.any((enemy) => enemyMoveProgress(enemy) < 1);

  double explosionProgress(Explosion explosion) =>
      _progress(explosion.started, explosionDuration);

  bool get levelBannerVisible =>
      _clock - _levelStartedAt < levelBannerDuration;

  double get levelBannerOpacity {
    final remaining = levelBannerDuration - (_clock - _levelStartedAt);
    if (remaining.inMilliseconds <= 0) {
      return 0;
    }
    return (remaining.inMilliseconds / 500).clamp(0.0, 1.0);
  }

  double get beamProgress => beam == null
      ? 1
      : ((_clock - beam!.started).inMicroseconds / beamDuration.inMicroseconds)
          .clamp(0.0, 1.0);

  double _progress(Duration start, Duration interval) =>
      ((_clock - start).inMicroseconds / interval.inMicroseconds)
          .clamp(0.0, 1.0);

  static List<Enemy> _defaultEnemies() => <Enemy>[
        Enemy(row: 1, col: 1, facing: Direction.down),
        Enemy(row: 1, col: 7, facing: Direction.down, armored: true),
        Enemy(row: 1, col: 13, facing: Direction.down),
        Enemy(row: 6, col: 6, facing: Direction.right, armored: true),
        Enemy(row: 8, col: 7, facing: Direction.right),
        Enemy(row: 11, col: 5, facing: Direction.left, armored: true),
      ];

  bool _inBounds(int row, int col) =>
      row >= 0 && row < maze.length && col >= 0 && col < maze.first.length;

  bool isWall(int row, int col) =>
      maze[row][col] == '#' || maze[row][col] == 'B';

  bool isPerimeter(int row, int col) =>
      row == 0 ||
      col == 0 ||
      row == maze.length - 1 ||
      col == maze.first.length - 1;

  bool isBreakable(int row, int col) =>
      maze[row][col] == 'B' && !isPerimeter(row, col);

  bool isDestroyed(int row, int col) => _destroyed[row][col];

  bool isOpen(int row, int col) {
    if (!_inBounds(row, col)) {
      return false;
    }
    if (!isWall(row, col)) {
      return true;
    }
    return _destroyed[row][col];
  }

  bool isPlayerAt(int row, int col) => playerRow == row && playerCol == col;

  bool isEnemyAt(int row, int col) =>
      enemies.any((enemy) => enemy.row == row && enemy.col == col);

  Enemy? _enemyAt(int row, int col) {
    for (final enemy in enemies) {
      if (enemy.row == row && enemy.col == col) {
        return enemy;
      }
    }
    return null;
  }

  Medkit? _medkitAt(int row, int col) {
    for (final medkit in medkits) {
      if (medkit.row == row && medkit.col == col) {
        return medkit;
      }
    }
    return null;
  }

  void _spawnMedkits() {
    if (medkits.length >= maxMedkits) {
      return;
    }
    final cols = maze.first.length;
    final cells = <int>[];
    for (var row = 0; row < maze.length; row++) {
      for (var col = 0; col < cols; col++) {
        if (!isOpen(row, col) ||
            isPlayerAt(row, col) ||
            isEnemyAt(row, col) ||
            _medkitAt(row, col) != null) {
          continue;
        }
        cells.add(row * cols + col);
      }
    }
    if (cells.isEmpty) {
      return;
    }
    final cell = cells[random.nextInt(cells.length)];
    medkits.add(Medkit(row: cell ~/ cols, col: cell % cols));
    revision++;
  }

  void _pickUpMedkits() {
    var changed = false;
    if (lives < maxLives) {
      final medkit = _medkitAt(playerRow, playerCol);
      if (medkit != null) {
        lives += 1;
        medkits.remove(medkit);
        changed = true;
      }
    }
    for (final enemy in enemies) {
      if (enemy.lives >= Enemy.maxLives) {
        continue;
      }
      final medkit = _medkitAt(enemy.row, enemy.col);
      if (medkit != null) {
        enemy.lives += 1;
        medkits.remove(medkit);
        changed = true;
      }
    }
    if (changed) {
      revision++;
    }
  }

  bool isBypassableCell(int row, int col) {
    if (!isOpen(row, col)) {
      return false;
    }
    var neighbors = 0;
    for (final direction in Direction.values) {
      if (isOpen(row + direction.dy, col + direction.dx)) {
        neighbors++;
      }
    }
    if (neighbors < 2) {
      return false;
    }

    final cols = maze.first.length;
    final visited = <int>{playerRow * cols + playerCol};
    final queue = <int>[playerRow * cols + playerCol];
    var head = 0;
    while (head < queue.length) {
      final cell = queue[head++];
      final currentRow = cell ~/ cols;
      final currentCol = cell % cols;
      for (final direction in Direction.values) {
        final nextRow = currentRow + direction.dy;
        final nextCol = currentCol + direction.dx;
        if (!_inBounds(nextRow, nextCol) || isWall(nextRow, nextCol)) {
          continue;
        }
        if (nextRow == row && nextCol == col) {
          continue;
        }
        if (!visited.add(nextRow * cols + nextCol)) {
          continue;
        }
        queue.add(nextRow * cols + nextCol);
      }
    }

    for (var r = 0; r < maze.length; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r == row && c == col) || !isOpen(r, c)) {
          continue;
        }
        if (!visited.contains(r * cols + c)) {
          return false;
        }
      }
    }
    return true;
  }

  void _spawnMines() {
    if (mines.length >= maxMines) {
      return;
    }
    final cols = maze.first.length;
    final cells = <int>[];
    for (var row = 0; row < maze.length; row++) {
      for (var col = 0; col < cols; col++) {
        if (!isBypassableCell(row, col) ||
            isPlayerAt(row, col) ||
            isEnemyAt(row, col) ||
            _medkitAt(row, col) != null ||
            _mineAt(row, col) != null) {
          continue;
        }
        cells.add(row * cols + col);
      }
    }
    if (cells.isEmpty) {
      return;
    }
    final cell = cells[random.nextInt(cells.length)];
    mines.add(Mine(row: cell ~/ cols, col: cell % cols));
    revision++;
  }

  Mine? _mineAt(int row, int col) {
    for (final mine in mines) {
      if (mine.row == row && mine.col == col) {
        return mine;
      }
    }
    return null;
  }

  Bush? _bushAt(int row, int col) {
    for (final bush in bushes) {
      if (bush.row == row && bush.col == col) {
        return bush;
      }
    }
    return null;
  }

  bool hasBush(int row, int col) => _bushAt(row, col) != null;

  void _spawnBushes() {
    final cols = maze.first.length;
    bool isFree(int row, int col) =>
        isOpen(row, col) &&
        !isPlayerAt(row, col) &&
        _bushAt(row, col) == null &&
        _medkitAt(row, col) == null &&
        _mineAt(row, col) == null;

    while (bushes.length < bushCount) {
      final candidates = <int>[];
      for (var row = 0; row < maze.length; row++) {
        for (var col = 0; col < cols; col++) {
          if (isFree(row, col)) {
            candidates.add(row * cols + col);
          }
        }
      }
      if (candidates.isEmpty) {
        break;
      }

      final start = candidates[random.nextInt(candidates.length)];
      final clusterSize = 3 + random.nextInt(2);
      final cluster = <int>{start};
      final frontier = <int>[start];
      while (cluster.length < clusterSize && frontier.isNotEmpty) {
        final cell = frontier.removeAt(random.nextInt(frontier.length));
        final row = cell ~/ cols;
        final col = cell % cols;
        for (final direction in Direction.values) {
          final nextRow = row + direction.dy;
          final nextCol = col + direction.dx;
          if (!isFree(nextRow, nextCol)) {
            continue;
          }
          final encoded = nextRow * cols + nextCol;
          if (!cluster.contains(encoded) && !frontier.contains(encoded)) {
            frontier.add(encoded);
          }
        }
        if (frontier.isEmpty) {
          break;
        }
        cluster.add(frontier.removeAt(random.nextInt(frontier.length)));
      }

      for (final cell in cluster) {
        bushes.add(Bush(row: cell ~/ cols, col: cell % cols));
      }
    }
    revision++;
  }

  void _checkMines() {
    if (mines.isEmpty) {
      return;
    }
    final triggered = <Mine>[];
    for (final mine in mines) {
      if (isPlayerAt(mine.row, mine.col)) {
        triggered.add(mine);
        _damagePlayer();
        continue;
      }
      final enemy = _enemyAt(mine.row, mine.col);
      if (enemy != null) {
        triggered.add(mine);
        _damageEnemy(enemy);
      }
    }
    for (final mine in triggered) {
      mines.remove(mine);
      explosions.add(
        Explosion(row: mine.row, col: mine.col, started: _clock),
      );
    }
  }

  void togglePause() {
    if (status != GameStatus.playing || awaitingNextLevel) {
      return;
    }
    paused = !paused;
    if (paused) {
      clearInput();
    }
    revision++;
  }

  void pressDirection(Direction direction) {
    if (_pressed.contains(direction)) {
      return;
    }
    _pressed.add(direction);
    _lastPlayerMove = _clock - playerMoveInterval;
    revision++;
  }

  void releaseDirection(Direction direction) {
    if (_pressed.remove(direction)) {
      revision++;
    }
  }

  void setShooting(bool shooting) {
    if (_shooting == shooting) {
      return;
    }
    _shooting = shooting;
    if (shooting) {
      _lastPlayerShot = _clock - playerShotInterval;
    }
    revision++;
  }

  void clearInput() {
    _pressed.clear();
    _shooting = false;
    revision++;
  }

  void _killEnemy(Enemy enemy) {
    if (!enemies.remove(enemy)) {
      return;
    }
    kills += 1;
    if (kills % killsPerCharge == 0) {
      abilityCharges += 1;
    }
    if (kills == killsForTriple) {
      tripleAmmo = tripleAmmoMax;
    }
    if (enemies.isEmpty) {
      _levelComplete = true;
    }
    revision++;
  }

  List<Enemy> _placeEnemies() {
    final cols = maze.first.length;
    final distances = distancesToPlayer();
    final count = math.min(6 + (level - 1) * 2, maxEnemies);
    final armoredCount = count ~/ 2;

    var candidates = <int>[];
    for (var row = 0; row < maze.length; row++) {
      for (var col = 0; col < cols; col++) {
        if (!isOpen(row, col) || isPlayerAt(row, col)) {
          continue;
        }
        if (distances[row][col] >= 4) {
          candidates.add(row * cols + col);
        }
      }
    }
    if (candidates.length < count) {
      candidates = <int>[];
      for (var row = 0; row < maze.length; row++) {
        for (var col = 0; col < cols; col++) {
          if (isOpen(row, col) && !isPlayerAt(row, col)) {
            candidates.add(row * cols + col);
          }
        }
      }
    }
    candidates.shuffle(random);

    final placed = <Enemy>[];
    for (var i = 0; i < count && i < candidates.length; i++) {
      final cell = candidates[i];
      placed.add(
        Enemy(
          row: cell ~/ cols,
          col: cell % cols,
          facing: Direction.values[random.nextInt(Direction.values.length)],
          armored: i < armoredCount,
        ),
      );
    }
    return placed;
  }

  void _advanceLevel() {
    level += 1;
    maze = generateMaze(random);
    enemies.clear();
    projectiles.clear();
    medkits.clear();
    mines.clear();
    bushes.clear();
    explosions.clear();
    beam = null;
    playerRow = kNextLevelStartRow;
    playerCol = kNextLevelStartCol;
    playerFromRow = playerRow;
    playerFromCol = playerCol;
    playerFacing = Direction.up;
    playerFromFacing = Direction.up;
    _pressed.clear();
    _shooting = false;
    if (lives < maxLives) {
      lives += 1;
    }
    enemies.addAll(_placeEnemies());
    _lastMedkitSpawn = _clock;
    _spawnMedkits();
    _lastMineSpawn = _clock;
    for (var i = 0; i < initialMines; i++) {
      _spawnMines();
    }
    _spawnBushes();
    _levelStartedAt = _clock;
    revision++;
  }

  void useAbility() {
    if (status != GameStatus.playing ||
        awaitingNextLevel ||
        abilityCharges <= 0) {
      return;
    }
    abilityCharges -= 1;

    final cols = maze.first.length;
    final cells = <int>[];
    var row = playerRow + playerFacing.dy;
    var col = playerCol + playerFacing.dx;
    while (_inBounds(row, col)) {
      if (isWall(row, col)) {
        if (isBreakable(row, col)) {
          _destroyed[row][col] = true;
        }
        break;
      }
      cells.add(row * cols + col);
      row += playerFacing.dy;
      col += playerFacing.dx;
    }

    beam = Beam(
      row: playerRow,
      col: playerCol,
      cells: cells,
      direction: playerFacing,
      started: _clock,
    );
    revision++;
  }

  void _updateBeam() {
    final activeBeam = beam;
    if (activeBeam == null) {
      return;
    }
    final elapsed = _clock - activeBeam.started;
    final ticks = elapsed.inMilliseconds ~/ beamTickInterval.inMilliseconds;
    while (activeBeam.ticks < ticks) {
      activeBeam.ticks += 1;
      _damageEnemiesInBeam(activeBeam);
    }
    if (elapsed >= beamDuration) {
      beam = null;
      revision++;
    }
  }

  void _damageEnemiesInBeam(Beam activeBeam) {
    final cols = maze.first.length;
    final hit = <Enemy>[];
    for (final cell in activeBeam.cells) {
      final enemy = _enemyAt(cell ~/ cols, cell % cols);
      if (enemy != null && !hit.contains(enemy)) {
        hit.add(enemy);
      }
    }
    for (final enemy in hit) {
      _damageEnemy(enemy);
    }
  }

  void _damageEnemy(Enemy enemy) {
    if (enemy.shield > 0) {
      enemy.shield -= 1;
    } else {
      _killEnemy(enemy);
    }
  }

  void advance(Duration delta) {
    if (paused) {
      return;
    }
    _clock += delta;
    _updateBeam();
    if (explosions.isNotEmpty) {
      explosions.removeWhere(
        (explosion) => _clock - explosion.started >= explosionDuration,
      );
    }
    if (status != GameStatus.playing || awaitingNextLevel) {
      return;
    }

    if (_clock - _lastProjectileMove >= projectileMoveInterval) {
      _lastProjectileMove = _clock;
      _moveProjectiles();
    }
    if (_clock - _lastEnemyMove >= enemyMoveInterval) {
      _lastEnemyMove = _clock;
      _moveEnemies();
    }
    if (_clock - _lastEnemyShot >= enemyShotInterval) {
      _lastEnemyShot = _clock;
      _shootEnemies();
    }
    if (_clock - _lastMedkitSpawn >= medkitSpawnInterval) {
      _lastMedkitSpawn = _clock;
      _spawnMedkits();
    }
    if (_clock - _lastShotRecharge >= shotRechargeInterval) {
      _lastShotRecharge = _clock;
      if (shotCharges < maxShotCharges) {
        shotCharges += 1;
        revision++;
      }
    }
    if (_clock - _lastMineSpawn >= mineSpawnInterval) {
      _lastMineSpawn = _clock;
      _spawnMines();
    }
    if (_shooting && _clock - _lastPlayerShot >= playerShotInterval) {
      _lastPlayerShot = _clock;
      _shootPlayer();
    }
    if (_pressed.isNotEmpty && _clock - _lastPlayerMove >= playerMoveInterval) {
      _lastPlayerMove = _clock;
      _movePlayer(_pressed.last);
    }
    _pickUpMedkits();
    _checkMines();
    if (_levelComplete) {
      _levelComplete = false;
      awaitingNextLevel = true;
      _pressed.clear();
      _shooting = false;
      revision++;
    }
  }

  void startNextLevel() {
    if (!awaitingNextLevel) {
      return;
    }
    awaitingNextLevel = false;
    _advanceLevel();
  }

  void _movePlayer(Direction direction) {
    final nextRow = playerRow + direction.dy;
    final nextCol = playerCol + direction.dx;
    final canMove = isOpen(nextRow, nextCol) && !isEnemyAt(nextRow, nextCol);
    if (canMove) {
      playerFromRow = playerRow;
      playerFromCol = playerCol;
      playerFromFacing = playerFacing;
      playerRow = nextRow;
      playerCol = nextCol;
      playerFacing = direction;
      _lastPlayerMove = _clock;
      _playerMoveAnimStart = _clock;
      revision++;
    } else if (playerFacing != direction) {
      playerFromFacing = playerFacing;
      playerFacing = direction;
      revision++;
    }
  }

  List<List<int>> distancesToPlayer() {
    final rows = maze.length;
    final cols = maze.first.length;
    final distances = List<List<int>>.generate(
      rows,
      (_) => List<int>.filled(cols, -1),
    );
    final queue = <int>[playerRow * cols + playerCol];
    distances[playerRow][playerCol] = 0;
    var head = 0;
    while (head < queue.length) {
      final cell = queue[head++];
      final row = cell ~/ cols;
      final col = cell % cols;
      final next = distances[row][col] + 1;
      for (final direction in Direction.values) {
        final nextRow = row + direction.dy;
        final nextCol = col + direction.dx;
        if (!_inBounds(nextRow, nextCol) ||
            isWall(nextRow, nextCol) ||
            distances[nextRow][nextCol] != -1) {
          continue;
        }
        distances[nextRow][nextCol] = next;
        queue.add(nextRow * cols + nextCol);
      }
    }
    return distances;
  }

  void _moveEnemies() {
    final distances = distancesToPlayer();
    var changed = false;
    for (final enemy in enemies) {
      Direction? chosen;
      var chosenDistance = -1;

      for (final direction in Direction.values) {
        final row = enemy.row + direction.dy;
        final col = enemy.col + direction.dx;
        if (!_inBounds(row, col) || isWall(row, col)) {
          continue;
        }
        if (isPlayerAt(row, col) || isEnemyAt(row, col)) {
          continue;
        }
        final distance = distances[row][col];
        if (distance < 0) {
          continue;
        }
        final better = chosen == null ||
            distance < chosenDistance ||
            (distance == chosenDistance && direction == enemy.facing);
        if (better) {
          chosen = direction;
          chosenDistance = distance;
        }
      }

      if (chosen == null) {
        final options = Direction.values.where((direction) {
          final row = enemy.row + direction.dy;
          final col = enemy.col + direction.dx;
          return direction != enemy.facing.opposite &&
              isOpen(row, col) &&
              !isPlayerAt(row, col) &&
              !isEnemyAt(row, col);
        }).toList();

        if (options.isEmpty) {
          final reverse = enemy.facing.opposite;
          final row = enemy.row + reverse.dy;
          final col = enemy.col + reverse.dx;
          if (isOpen(row, col) &&
              !isPlayerAt(row, col) &&
              !isEnemyAt(row, col)) {
            options.add(reverse);
          }
        }
        if (options.isEmpty) {
          continue;
        }
        chosen = options[random.nextInt(options.length)];
      }

      enemy
        ..fromRow = enemy.row
        ..fromCol = enemy.col
        ..fromFacing = enemy.facing
        ..row += chosen.dy
        ..col += chosen.dx
        ..facing = chosen
        ..moveStarted = _clock;
      changed = true;
    }
    if (changed) {
      revision++;
    }
  }

  void _shootEnemies() {
    var changed = false;
    for (final enemy in enemies) {
      final row = enemy.row + enemy.facing.dy;
      final col = enemy.col + enemy.facing.dx;
      if (!isOpen(row, col) || isEnemyAt(row, col)) {
        continue;
      }
      if (isPlayerAt(row, col)) {
        _damagePlayer();
        changed = true;
        continue;
      }
      projectiles.add(
        Projectile(
          row: row,
          col: col,
          direction: enemy.facing,
          owner: ProjectileOwner.enemy,
        ),
      );
      changed = true;
    }
    if (changed) {
      revision++;
    }
  }

  void useTripleShot() {
    if (status != GameStatus.playing ||
        awaitingNextLevel ||
        paused ||
        tripleAmmo <= 0) {
      return;
    }
    tripleAmmo -= 1;

    var row = playerRow;
    var col = playerCol;
    projectiles.add(
      Projectile(
        row: row,
        col: col,
        direction: playerFacing,
        owner: ProjectileOwner.player,
      ),
    );
    for (var i = 0; i < 2; i++) {
      row += playerFacing.dy;
      col += playerFacing.dx;
      if (!_inBounds(row, col) || isWall(row, col)) {
        break;
      }
      final enemy = _enemyAt(row, col);
      if (enemy != null) {
        _damageEnemy(enemy);
      }
      projectiles.add(
        Projectile(
          row: row,
          col: col,
          direction: playerFacing,
          owner: ProjectileOwner.player,
        ),
      );
    }
    revision++;
  }

  void _shootPlayer() {
    if (shotCharges <= 0) {
      return;
    }
    shotCharges -= 1;
    projectiles.add(
      Projectile(
        row: playerRow,
        col: playerCol,
        direction: playerFacing,
        owner: ProjectileOwner.player,
      ),
    );
    revision++;
  }

  void _moveProjectiles() {
    if (projectiles.isEmpty) {
      return;
    }
    final cols = maze.first.length;
    final oldCells = <Projectile, int>{
      for (final projectile in projectiles)
        projectile: projectile.row * cols + projectile.col,
    };

    projectiles.removeWhere((projectile) {
      final row = projectile.row + projectile.direction.dy;
      final col = projectile.col + projectile.direction.dx;
      if (!_inBounds(row, col)) {
        return true;
      }
      if (isWall(row, col)) {
        if (isBreakable(row, col)) {
          _destroyed[row][col] = true;
        }
        return true;
      }
      projectile
        ..row = row
        ..col = col;
      if (projectile.owner == ProjectileOwner.player) {
        final enemy = _enemyAt(row, col);
        if (enemy != null) {
          _damageEnemy(enemy);
          return true;
        }
      } else if (isPlayerAt(row, col)) {
        _damagePlayer();
        return true;
      }
      return false;
    });

    _resolveProjectileCollisions(oldCells);
    revision++;
  }

  void _resolveProjectileCollisions(Map<Projectile, int> oldCells) {
    if (projectiles.isEmpty) {
      return;
    }
    final cols = maze.first.length;
    final playerShots = projectiles
        .where((projectile) => projectile.owner == ProjectileOwner.player)
        .toList();
    final enemyShots = projectiles
        .where((projectile) => projectile.owner == ProjectileOwner.enemy)
        .toList();
    if (playerShots.isEmpty || enemyShots.isEmpty) {
      return;
    }

    final destroyed = <Projectile>{};
    for (final playerShot in playerShots) {
      for (final enemyShot in enemyShots) {
        final playerCell = playerShot.row * cols + playerShot.col;
        final enemyCell = enemyShot.row * cols + enemyShot.col;
        final sameCell = playerCell == enemyCell;
        final swapped =
            oldCells[playerShot] == enemyCell && oldCells[enemyShot] == playerCell;
        if (!sameCell && !swapped) {
          continue;
        }
        destroyed
          ..add(playerShot)
          ..add(enemyShot);
        explosions.add(
          Explosion(
            row: playerShot.row,
            col: playerShot.col,
            started: _clock,
          ),
        );
      }
    }
    if (destroyed.isNotEmpty) {
      projectiles.removeWhere(destroyed.contains);
    }
  }

  void _damagePlayer() {
    if (playerInvulnerable) {
      return;
    }
    _lastHit = _clock;
    lives -= 1;
    if (lives <= 0) {
      lives = 0;
      status = GameStatus.lost;
      clearInput();
    }
    revision++;
  }
}
