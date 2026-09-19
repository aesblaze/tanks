import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tanks/game.dart';

void main() {
  test('Player shot kills the last enemy and starts the next level', () {
    final game = Game(
      random: Random(1),
      enemies: [Enemy(row: 8, col: 1, facing: Direction.down)],
    );

    game.setShooting(true);
    for (var i = 0; i < 40; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    expect(game.awaitingNextLevel, isTrue);
    game.startNextLevel();

    expect(game.level, 2);
    expect(game.enemies, isNotEmpty);
    expect(game.status, GameStatus.playing);
  });

  test('Default level has six enemies, three of them armored', () {
    final game = Game();
    expect(game.enemies, hasLength(6));
    expect(game.enemies.where((enemy) => enemy.shielded).length, 3);
    expect(game.enemies.where((enemy) => !enemy.shielded).length, 3);
  });

  test('Next level is a different, fully reachable maze', () {
    final game = Game(random: Random(7), level: 2, enemies: []);

    expect(game.maze, hasLength(kMazeRows));
    for (final line in game.maze) {
      expect(line.length, kMazeCols);
    }
    for (var col = 0; col < kMazeCols; col++) {
      expect(game.maze[0][col], '#');
      expect(game.maze[kMazeRows - 1][col], '#');
    }
    for (var row = 0; row < kMazeRows; row++) {
      expect(game.maze[row][0], '#');
      expect(game.maze[row][kMazeCols - 1], '#');
    }

    final distances = game.distancesToPlayer();
    for (var row = 0; row < kMazeRows; row++) {
      for (var col = 0; col < kMazeCols; col++) {
        if (game.maze[row][col] == '.') {
          expect(distances[row][col], greaterThanOrEqualTo(0));
        }
      }
    }
  });

  test('Clearing a level spawns a new maze with more enemies', () {
    final game = Game(
      random: Random(1),
      enemies: [Enemy(row: 8, col: 1, facing: Direction.down)],
    );
    game.lives = 5;

    game.setShooting(true);
    for (var i = 0; i < 40; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    expect(game.awaitingNextLevel, isTrue);
    game.startNextLevel();

    expect(game.level, 2);
    expect(game.maze, isNot(same(kMaze)));
    expect(game.enemies, hasLength(8));
    expect(game.lives, 6);
    expect(game.levelBannerVisible, isTrue);
  });

  test('Armored enemy loses its shield first and dies on the next hit', () {
    final game = Game(
      enemies: [Enemy(row: 9, col: 1, facing: Direction.down, armored: true)],
    );
    game.mines.clear();

    game.projectiles.add(
      Projectile(
        row: 10,
        col: 1,
        direction: Direction.up,
        owner: ProjectileOwner.player,
      ),
    );
    game.advance(Game.projectileMoveInterval);

    expect(game.enemies, hasLength(1));
    expect(game.enemies.single.shielded, isFalse);

    game.projectiles.add(
      Projectile(
        row: 10,
        col: 1,
        direction: Direction.up,
        owner: ProjectileOwner.player,
      ),
    );
    game.advance(Game.projectileMoveInterval);

    expect(game.awaitingNextLevel, isTrue);
    game.startNextLevel();

    expect(game.enemies, isNotEmpty);
    expect(game.level, 2);
  });

  test('Enemy shots fly out of the cannon barrel', () {
    final game = Game(random: Random(3));
    game.mines.clear();

    for (var i = 0; i < 125; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    final enemyShots = game.projectiles
        .where((shot) => shot.owner == ProjectileOwner.enemy)
        .toList();
    expect(enemyShots, isNotEmpty);
    for (final shot in enemyShots) {
      final owners = game.enemies.where(
        (enemy) =>
            enemy.row + enemy.facing.dy == shot.row &&
            enemy.col + enemy.facing.dx == shot.col &&
            enemy.facing == shot.direction,
      );
      expect(owners, hasLength(1));
    }
  });

  test('Ability charge is granted after three kills', () {
    final game = Game(enemies: [
      Enemy(row: 9, col: 1, facing: Direction.down),
      Enemy(row: 8, col: 1, facing: Direction.down),
      Enemy(row: 7, col: 1, facing: Direction.down),
    ]);
    expect(game.abilityCharges, 0);

    for (final row in [9, 8, 7]) {
      game.projectiles.add(
        Projectile(
          row: row,
          col: 0,
          direction: Direction.right,
          owner: ProjectileOwner.player,
        ),
      );
      game.advance(Game.projectileMoveInterval);
    }

    expect(game.kills, 3);
    expect(game.abilityCharges, 1);
  });

  test('Beam burns through the corridor and kills enemies', () {
    final game = Game(enemies: [
      Enemy(row: 8, col: 1, facing: Direction.down),
      Enemy(row: 7, col: 1, facing: Direction.down),
    ]);
    game.abilityCharges = 1;

    game.useAbility();

    expect(game.abilityCharges, 0);
    expect(game.beam, isNotNull);
    expect(game.beam!.cells, hasLength(3));
    expect(game.enemies, hasLength(2));

    game.advance(const Duration(seconds: 1));

    expect(game.awaitingNextLevel, isTrue);
    game.startNextLevel();

    expect(game.enemies, isNotEmpty);
    expect(game.level, 2);
  });

  test('Beam deals one damage per second', () {
    final game = Game(enemies: [
      Enemy(row: 8, col: 1, facing: Direction.down, armored: true),
    ]);
    game.mines.clear();
    game.abilityCharges = 1;
    game.useAbility();

    game.advance(const Duration(milliseconds: 500));
    expect(game.enemies.single.shielded, isTrue);

    game.advance(const Duration(milliseconds: 500));
    expect(game.enemies.single.shielded, isFalse);
    expect(game.enemies, hasLength(1));

    game.advance(const Duration(seconds: 1));

    expect(game.awaitingNextLevel, isTrue);
    game.startNextLevel();

    expect(game.level, 2);
    expect(game.enemies, isNotEmpty);
  });

  test('Beam destroys a breakable wall and stops there', () {
    final game = Game(enemies: []);
    game.mines.clear();
    game.abilityCharges = 1;
    game.playerRow = 8;
    game.playerCol = 1;
    game.playerFacing = Direction.right;

    game.useAbility();

    expect(game.beam, isNotNull);
    expect(game.isOpen(8, 2), isTrue);
    expect(game.beam!.cells, isEmpty);
  });

  test('Ability does nothing without a charge', () {
    final game = Game(enemies: []);
    game.useAbility();
    expect(game.beam, isNull);
    expect(game.abilityCharges, 0);
  });

  test('Beam fades after its duration', () {
    final game = Game(enemies: []);
    game.abilityCharges = 1;
    game.useAbility();
    expect(game.beam, isNotNull);

    game.advance(const Duration(seconds: 4));
    expect(game.beam, isNotNull);

    game.advance(const Duration(seconds: 1));
    expect(game.beam, isNull);
  });

  test('Enemies chase the player', () {
    final game = Game(
      random: Random(4),
      enemies: [Enemy(row: 1, col: 1, facing: Direction.down)],
    );
    game.mines.clear();
    final before = game.distancesToPlayer()[1][1];
    expect(before, greaterThan(0));

    for (var i = 0; i < 60; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    final enemy = game.enemies.single;
    final after = game.distancesToPlayer()[enemy.row][enemy.col];
    expect(after, lessThan(before));
  });

  test('Colliding projectiles explode and vanish', () {
    final game = Game(enemies: []);
    game.projectiles.add(
      Projectile(
        row: 8,
        col: 4,
        direction: Direction.left,
        owner: ProjectileOwner.player,
      ),
    );
    game.projectiles.add(
      Projectile(
        row: 8,
        col: 2,
        direction: Direction.right,
        owner: ProjectileOwner.enemy,
      ),
    );

    game.advance(Game.projectileMoveInterval);

    expect(game.projectiles, isEmpty);
    expect(game.explosions, hasLength(1));
    expect(game.explosions.single.row, 8);
    expect(game.explosions.single.col, 3);

    game.advance(Game.explosionDuration);
    expect(game.explosions, isEmpty);
  });

  test('Crossing projectiles also collide', () {
    final game = Game(enemies: []);
    game.projectiles.add(
      Projectile(
        row: 8,
        col: 4,
        direction: Direction.left,
        owner: ProjectileOwner.player,
      ),
    );
    game.projectiles.add(
      Projectile(
        row: 8,
        col: 3,
        direction: Direction.right,
        owner: ProjectileOwner.enemy,
      ),
    );

    game.advance(Game.projectileMoveInterval);

    expect(game.projectiles, isEmpty);
    expect(game.explosions, hasLength(1));
  });

  test('Mine damages the player who steps on it', () {
    final game = Game(enemies: []);
    game.medkits.clear();
    game.mines.clear();
    game.mines.add(Mine(row: 10, col: 2));

    game.playerRow = 10;
    game.playerCol = 2;
    game.advance(const Duration(milliseconds: 16));

    expect(game.lives, Game.maxLives - 1);
    expect(game.mines, isEmpty);
    expect(game.explosions, hasLength(1));
  });

  test('Mine damages enemies', () {
    final game = Game(
      enemies: [Enemy(row: 8, col: 1, facing: Direction.down, armored: true)],
    );
    game.mines.clear();
    game.mines.add(Mine(row: 8, col: 1));

    game.advance(const Duration(milliseconds: 16));

    expect(game.enemies.single.shielded, isFalse);
    expect(game.mines, isEmpty);
  });

  test('Mines are placed so they can be bypassed', () {
    final game = Game(random: Random(11), level: 2, enemies: []);

    expect(game.mines, isNotEmpty);
    for (final mine in game.mines) {
      expect(game.isBypassableCell(mine.row, mine.col), isTrue);
    }
  });

  test('Bushes stand on open cells and do not block movement', () {
    final game = Game(random: Random(2));

    expect(game.bushes, isNotEmpty);
    for (final bush in game.bushes) {
      expect(game.isOpen(bush.row, bush.col), isTrue);
      expect(game.hasBush(bush.row, bush.col), isTrue);
    }

    final hasNeighbor = game.bushes.any(
      (bush) => game.bushes.any(
        (other) =>
            (other.row - bush.row).abs() + (other.col - bush.col).abs() == 1,
      ),
    );
    expect(hasNeighbor, isTrue);

    final bush = game.bushes.first;
    game.playerFromRow = bush.row;
    game.playerFromCol = bush.col;
    game.playerRow = bush.row;
    game.playerCol = bush.col;
    game.advance(const Duration(milliseconds: 16));
    expect(game.hasBush(game.playerRow, game.playerCol), isTrue);
    expect(game.lives, Game.maxLives);
  });

  test('Pause freezes the game until resumed', () {
    final game = Game(enemies: [
      Enemy(row: 8, col: 1, facing: Direction.down),
    ]);
    game.mines.clear();

    game.togglePause();
    expect(game.paused, isTrue);

    game.advance(const Duration(seconds: 3));
    expect(game.enemies.single.row, 8);
    expect(game.playerRow, kPlayerRow);

    game.togglePause();
    expect(game.paused, isFalse);

    game.pressDirection(Direction.up);
    game.advance(const Duration(milliseconds: 16));
    expect(game.playerRow, kPlayerRow - 1);
  });

  test('Game state survives save and restore', () {
    final game = Game(random: Random(3));
    game.mines.clear();
    game.playerRow = 9;
    game.playerCol = 2;
    game.playerFacing = Direction.left;
    game.lives = 4;
    game.kills = 7;
    game.abilityCharges = 2;
    game.shotCharges = 2;
    game.tripleAmmo = 3;

    final restored = Game.fromJson(game.toJson());

    expect(restored.level, game.level);
    expect(restored.maze, game.maze);
    expect(restored.playerRow, 9);
    expect(restored.playerCol, 2);
    expect(restored.playerFacing, Direction.left);
    expect(restored.lives, 4);
    expect(restored.kills, 7);
    expect(restored.abilityCharges, 2);
    expect(restored.shotCharges, 2);
    expect(restored.tripleAmmo, 3);
    expect(restored.enemies.length, game.enemies.length);
    expect(restored.bushes.length, game.bushes.length);
  });

  test('Shots spend charges that recharge over time', () {
    final game = Game(enemies: []);
    game.mines.clear();
    expect(game.shotCharges, Game.maxShotCharges);

    game.setShooting(true);
    game.advance(const Duration(milliseconds: 16));
    expect(game.shotCharges, Game.maxShotCharges - 1);

    game.setShooting(false);
    game.advance(Game.shotRechargeInterval);
    expect(game.shotCharges, Game.maxShotCharges);
  });

  test('No shots when charges are empty', () {
    final game = Game(enemies: []);
    game.mines.clear();
    game.shotCharges = 0;

    game.setShooting(true);
    game.advance(const Duration(milliseconds: 16));

    expect(
      game.projectiles
          .where((projectile) => projectile.owner == ProjectileOwner.player),
      isEmpty,
    );
  });

  test('Triple shot fires three shells forward', () {
    final game = Game(enemies: []);
    game.mines.clear();
    game.tripleAmmo = 1;
    game.playerRow = 10;
    game.playerCol = 1;
    game.playerFacing = Direction.up;

    game.useTripleShot();

    expect(game.tripleAmmo, 0);
    final shots = game.projectiles
        .where((projectile) => projectile.owner == ProjectileOwner.player)
        .toList();
    expect(shots, hasLength(3));
    expect(shots.every((shot) => shot.direction == Direction.up), isTrue);
    expect(shots.map((shot) => shot.row).toSet(), {8, 9, 10});
  });

  test('Triple ability unlocks after five kills and carries over', () {
    final game = Game(
      enemies: [Enemy(row: 8, col: 1, facing: Direction.down)],
    );
    game.mines.clear();
    game.kills = 4;
    expect(game.tripleAmmo, 0);

    game.projectiles.add(
      Projectile(
        row: 8,
        col: 0,
        direction: Direction.right,
        owner: ProjectileOwner.player,
      ),
    );
    game.advance(Game.projectileMoveInterval);

    expect(game.kills, 5);
    expect(game.tripleAmmo, Game.tripleAmmoMax);

    game.startNextLevel();
    expect(game.tripleAmmo, Game.tripleAmmoMax);
  });

  test('Triple shot does nothing without ammo', () {
    final game = Game(enemies: []);
    game.mines.clear();
    game.tripleAmmo = 0;

    game.useTripleShot();

    expect(game.projectiles, isEmpty);
  });

  test('Enemy arrow takes one life', () {
    final game = Game(enemies: []);
    game.projectiles.add(
      Projectile(
        row: kPlayerRow - 1,
        col: kPlayerCol,
        direction: Direction.down,
        owner: ProjectileOwner.enemy,
      ),
    );

    game.advance(Game.projectileMoveInterval);

    expect(game.lives, Game.maxLives - 1);
    expect(game.projectiles, isEmpty);
  });

  test('Invulnerability blocks a second hit', () {
    final game = Game(enemies: []);

    for (var i = 0; i < 2; i++) {
      game.projectiles.add(
        Projectile(
          row: kPlayerRow - 1,
          col: kPlayerCol,
          direction: Direction.down,
          owner: ProjectileOwner.enemy,
        ),
      );
      game.advance(Game.projectileMoveInterval);
    }

    expect(game.lives, Game.maxLives - 1);
    expect(game.status, GameStatus.playing);
  });

  test('Six hits lose the game', () {
    final game = Game(enemies: []);

    for (var i = 0; i < Game.maxLives; i++) {
      game.projectiles.add(
        Projectile(
          row: kPlayerRow - 1,
          col: kPlayerCol,
          direction: Direction.down,
          owner: ProjectileOwner.enemy,
        ),
      );
      game.advance(Game.projectileMoveInterval);
      expect(game.lives, Game.maxLives - 1 - i);
      game.advance(Game.invulnerability);
    }

    expect(game.lives, 0);
    expect(game.status, GameStatus.lost);
  });

  test('Player arrow destroys a breakable wall and dies', () {
    final game = Game(enemies: []);
    game.mines.clear();
    game.playerRow = 8;
    game.playerCol = 1;
    game.playerFacing = Direction.right;
    expect(game.isOpen(8, 2), isFalse);

    game.setShooting(true);
    game.advance(const Duration(milliseconds: 16));
    expect(game.projectiles, hasLength(1));
    game.setShooting(false);

    for (var i = 0; i < 50; i++) {
      game.advance(const Duration(milliseconds: 16));
    }
    expect(game.projectiles, isEmpty);
    expect(game.isOpen(8, 2), isTrue);
  });

  test('Solid inner walls are indestructible', () {
    final game = Game(enemies: []);
    expect(game.isBreakable(6, 1), isFalse);

    game.setShooting(true);
    game.advance(const Duration(milliseconds: 16));
    game.setShooting(false);
    for (var i = 0; i < 50; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    expect(game.projectiles, isEmpty);
    expect(game.isOpen(6, 1), isFalse);
  });

  test('Only some inner walls are breakable, none on the perimeter', () {
    final game = Game();
    var breakable = 0;
    var solid = 0;
    for (var row = 0; row < game.maze.length; row++) {
      for (var col = 0; col < game.maze.first.length; col++) {
        if (!game.isWall(row, col)) {
          continue;
        }
        if (game.isPerimeter(row, col)) {
          expect(game.isBreakable(row, col), isFalse);
          solid++;
        } else if (game.isBreakable(row, col)) {
          breakable++;
        } else {
          solid++;
        }
      }
    }
    expect(breakable, greaterThan(0));
    expect(solid, greaterThan(0));
    expect(breakable, lessThan(solid));
  });

  test('Player movement animates from cell to cell', () {
    final game = Game(enemies: []);
    game.pressDirection(Direction.right);
    game.advance(const Duration(milliseconds: 16));

    expect(game.playerCol, kPlayerCol + 1);
    expect(game.playerFromCol, kPlayerCol);
    expect(game.playerMoveProgress, lessThan(1));
    expect(game.isAnimating, isTrue);

    game.releaseDirection(Direction.right);
    game.advance(const Duration(milliseconds: 130));
    expect(game.playerMoveProgress, 1);
    expect(game.isAnimating, isFalse);
  });

  test('Crashing into a wall turns instantly', () {
    final game = Game(enemies: []);
    game.pressDirection(Direction.left);
    game.advance(const Duration(milliseconds: 16));

    expect(game.playerRow, kPlayerRow);
    expect(game.playerCol, kPlayerCol);
    expect(game.playerFacing, Direction.left);
    expect(game.playerMoveProgress, 1);
  });

  test('Enemy movement animates from cell to cell', () {
    final game = Game(
      random: Random(2),
      enemies: [Enemy(row: 8, col: 1, facing: Direction.down)],
    );

    for (var i = 0; i < 30; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    final enemy = game.enemies.single;
    expect(enemy.row, 9);
    expect(enemy.fromRow, 8);
    expect(game.enemyMoveProgress(enemy), lessThan(1));
    expect(game.isAnimating, isTrue);
  });

  test('Perimeter walls are indestructible', () {    final game = Game(enemies: []);
    game.pressDirection(Direction.left);
    game.advance(const Duration(milliseconds: 16));
    game.releaseDirection(Direction.left);
    expect(game.playerFacing, Direction.left);

    game.setShooting(true);
    game.advance(const Duration(milliseconds: 16));
    game.setShooting(false);
    for (var i = 0; i < 20; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    expect(game.isOpen(10, 0), isFalse);
    expect(game.projectiles, isEmpty);
  });

  test('Enemies walk only on open cells and shoot', () {
    final game = Game(random: Random(7));
    game.mines.clear();
    var sawProjectile = false;

    for (var i = 0; i < 200; i++) {
      game.advance(const Duration(milliseconds: 16));
      for (final enemy in game.enemies) {
        expect(game.isOpen(enemy.row, enemy.col), isTrue);
      }
      if (game.projectiles.isNotEmpty) {
        sawProjectile = true;
      }
    }

    expect(sawProjectile, isTrue);
  });

  test('Medkit heals a wounded player and disappears', () {
    final game = Game(enemies: []);
    game.medkits.clear();
    game.mines.clear();
    game.medkits.add(Medkit(row: 10, col: 2));

    game.projectiles.add(
      Projectile(
        row: 9,
        col: 1,
        direction: Direction.down,
        owner: ProjectileOwner.enemy,
      ),
    );
    game.advance(Game.projectileMoveInterval);
    expect(game.lives, Game.maxLives - 1);

    game.playerRow = 10;
    game.playerCol = 2;
    game.advance(const Duration(milliseconds: 16));

    expect(game.lives, Game.maxLives);
    expect(game.medkits, isEmpty);
  });

  test('Medkit is not consumed at full health', () {
    final game = Game(enemies: []);
    game.medkits.clear();
    game.mines.clear();
    game.medkits.add(Medkit(row: 10, col: 2));
    game.playerRow = 10;
    game.playerCol = 2;

    game.advance(const Duration(milliseconds: 16));

    expect(game.lives, Game.maxLives);
    expect(game.medkits, hasLength(1));
  });

  test('Medkits appear over time and never exceed the limit', () {
    final game = Game(random: Random(5), enemies: []);
    expect(game.medkits, hasLength(1));

    for (var i = 0; i < 6250; i++) {
      game.advance(const Duration(milliseconds: 16));
    }

    expect(game.medkits, hasLength(Game.maxMedkits));
  });

  test('Dead player cannot keep playing', () {
    final game = Game(enemies: []);

    for (var i = 0; i < Game.maxLives; i++) {
      game.projectiles.add(
        Projectile(
          row: kPlayerRow - 1,
          col: kPlayerCol,
          direction: Direction.down,
          owner: ProjectileOwner.enemy,
        ),
      );
      game.advance(Game.projectileMoveInterval);
      game.advance(Game.invulnerability);
    }
    expect(game.status, GameStatus.lost);

    final before = game.playerRow;
    game.pressDirection(Direction.up);
    for (var i = 0; i < 100; i++) {
      game.advance(const Duration(milliseconds: 16));
    }
    expect(game.playerRow, before);
    expect(game.projectiles, isEmpty);
  });
}
