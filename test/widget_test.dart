import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tanks/game.dart';
import 'package:tanks/main.dart';
import 'package:tanks/records.dart';
import 'package:tanks/save.dart';

MazePainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is MazePainter,
    ),
  );
  return customPaint.painter! as MazePainter;
}

Game _gameOf(WidgetTester tester) => _painterOf(tester).game;

SaveStore _tempSaveStore() {
  final dir = Directory.systemTemp.createTempSync('tanks_save');
  addTearDown(() => dir.deleteSync(recursive: true));
  return SaveStore(
    file: File('${dir.path}${Platform.pathSeparator}save.json'),
  );
}

Future<void> _pumpGame(WidgetTester tester, {SaveStore? saveStore}) async {
  await tester.pumpWidget(
    TanksApp(saveStore: saveStore ?? _tempSaveStore()),
  );
  await tester.tap(find.text('Играть'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  _gameOf(tester).mines.clear();
}

void main() {
  testWidgets('Main menu starts instead of the game', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TanksApp());

    expect(find.text('Играть'), findsOneWidget);
    expect(find.text('Рекорды'), findsOneWidget);
    expect(find.text('Правила игры'), findsOneWidget);
    expect(find.text('Выйти из игры'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is MazePainter,
      ),
      findsNothing,
    );
  });

  testWidgets('Records button shows the best results', (
    WidgetTester tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('tanks_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = RecordStore(
      file: File('${dir.path}${Platform.pathSeparator}records.json'),
    );
    store.save(const Records(bestKills: 9, bestLevel: 4));

    await tester.pumpWidget(TanksApp(recordStore: store));
    await tester.tap(find.text('Рекорды'));
    await tester.pump();

    expect(find.text('Рекорд по убийствам'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Максимальный уровень'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('Rules button shows the goal and controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TanksApp());
    await tester.tap(find.text('Правила игры'));
    await tester.pump();

    expect(find.text('Цель'), findsOneWidget);
    expect(find.text('Управление'), findsOneWidget);
    expect(find.textContaining('W A S D'), findsOneWidget);
    expect(find.textContaining('Space'), findsOneWidget);
    expect(find.textContaining('Q — луч'), findsOneWidget);
  });

  testWidgets('Maze, arrow and lives are drawn', (WidgetTester tester) async {
    await _pumpGame(tester);

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Жизни: ${Game.maxLives}'), findsOneWidget);
    expect(find.text('Врагов: 6'), findsOneWidget);
    expect(find.byKey(const Key('shotCharges')), findsOneWidget);
    expect(kMaze, isNotEmpty);
    expect(kMaze.every((row) => row.length == kMaze.first.length), isTrue);
    expect(kMaze[kPlayerRow][kPlayerCol], '.');
  });

  testWidgets('WASD moves the arrow', (WidgetTester tester) async {
    await _pumpGame(tester);

    expect(_gameOf(tester).playerRow, kPlayerRow);
    expect(_gameOf(tester).playerCol, kPlayerCol);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_gameOf(tester).playerRow, kPlayerRow - 1);
    expect(_gameOf(tester).playerCol, kPlayerCol);
    expect(_gameOf(tester).playerFacing, Direction.up);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_gameOf(tester).playerRow, kPlayerRow - 2);
    expect(_gameOf(tester).playerCol, kPlayerCol);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
  });

  testWidgets('Arrow turns but does not walk into walls',
      (WidgetTester tester) async {
    await _pumpGame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_gameOf(tester).playerRow, kPlayerRow);
    expect(_gameOf(tester).playerCol, kPlayerCol);
    expect(_gameOf(tester).playerFacing, Direction.left);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
  });

  testWidgets('Space makes the player shoot', (WidgetTester tester) async {
    await _pumpGame(tester);

    expect(_gameOf(tester).projectiles, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 200));
    final playerShots = _gameOf(tester)
        .projectiles
        .where((projectile) => projectile.owner == ProjectileOwner.player);
    expect(playerShots, isNotEmpty);
    expect(playerShots.first.direction, _gameOf(tester).playerFacing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
  });

  testWidgets('Q fires the beam when a charge is ready', (
    WidgetTester tester,
  ) async {
    await _pumpGame(tester);

    final game = _gameOf(tester);
    expect(game.beam, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(game.beam, isNull);

    game.abilityCharges = 1;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(game.beam, isNotNull);
    expect(game.abilityCharges, 0);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
  });

  testWidgets('Touch controls move and shoot', (WidgetTester tester) async {
    await _pumpGame(tester);

    final move = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.keyboard_arrow_up)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_gameOf(tester).playerRow, lessThan(kPlayerRow));
    await move.up();
    await tester.pump();

    final fire = await tester.startGesture(
      tester.getCenter(find.text('Огонь')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    final playerShots = _gameOf(tester)
        .projectiles
        .where((projectile) => projectile.owner == ProjectileOwner.player);
    expect(playerShots, isNotEmpty);
    await fire.up();
    await tester.pump();

    _gameOf(tester).abilityCharges = 1;
    await tester.tap(find.text('Луч'));
    await tester.pump();
    expect(_gameOf(tester).beam, isNotNull);
  });

  testWidgets('Escape pauses and exit returns to the main menu', (
    WidgetTester tester,
  ) async {
    await _pumpGame(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_gameOf(tester).paused, isTrue);
    expect(find.text('Пауза'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(_gameOf(tester).paused, isFalse);
    expect(find.text('Пауза'), findsNothing);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_gameOf(tester).paused, isTrue);

    await tester.tap(find.text('Выйти в главное меню'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Играть'), findsOneWidget);
  });

  testWidgets('Continue button is disabled without a save', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TanksApp(saveStore: _tempSaveStore()));

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Продолжить игру'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Continue restores the saved game paused', (
    WidgetTester tester,
  ) async {
    final store = _tempSaveStore();
    final saved = Game();
    saved.mines.clear();
    saved.playerRow = 9;
    saved.playerCol = 2;
    saved.lives = 4;
    store.saveGame(saved);

    await tester.pumpWidget(TanksApp(saveStore: store));
    await tester.tap(find.text('Продолжить игру'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Пауза'), findsOneWidget);
    expect(_gameOf(tester).paused, isTrue);
    expect(_gameOf(tester).playerRow, 9);
    expect(_gameOf(tester).lives, 4);

    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(_gameOf(tester).paused, isFalse);
  });

  testWidgets('Play also continues from the saved game', (
    WidgetTester tester,
  ) async {
    final store = _tempSaveStore();
    final saved = Game();
    saved.mines.clear();
    saved.playerRow = 9;
    saved.playerCol = 2;
    saved.lives = 4;
    store.saveGame(saved);

    await tester.pumpWidget(TanksApp(saveStore: store));
    await tester.tap(find.text('Играть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_gameOf(tester).paused, isTrue);
    expect(_gameOf(tester).playerRow, 9);
    expect(_gameOf(tester).lives, 4);
  });

  testWidgets('Exit saves the game and losing erases it', (
    WidgetTester tester,
  ) async {
    final store = _tempSaveStore();
    await _pumpGame(tester, saveStore: store);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tap(find.text('Выйти в главное меню'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.hasSave, isTrue);

    await tester.tap(find.text('Продолжить игру'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_gameOf(tester).paused, isTrue);

    await tester.tap(find.text('Продолжить'));
    await tester.pump();

    final game = _gameOf(tester);
    game.lives = 1;
    game.projectiles.add(
      Projectile(
        row: game.playerRow - 1,
        col: game.playerCol,
        direction: Direction.down,
        owner: ProjectileOwner.enemy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.status, GameStatus.lost);
    await tester.pump();
    expect(store.hasSave, isFalse);
  });

  testWidgets('F fires the triple shot when unlocked', (
    WidgetTester tester,
  ) async {
    await _pumpGame(tester);

    final game = _gameOf(tester);
    game.tripleAmmo = 1;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.pump();

    expect(game.tripleAmmo, 0);
    expect(
      game.projectiles.where(
        (projectile) => projectile.owner == ProjectileOwner.player,
      ),
      hasLength(3),
    );

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
  });

  testWidgets('Enemies stand on open cells and walk', (
    WidgetTester tester,
  ) async {
    await _pumpGame(tester);

    final enemies = _gameOf(tester).enemies;
    expect(enemies, isNotEmpty);
    final starts = enemies.map((enemy) => '${enemy.row}:${enemy.col}').toList();
    for (final enemy in enemies) {
      expect(_gameOf(tester).isOpen(enemy.row, enemy.col), isTrue);
    }

    await tester.pump(const Duration(seconds: 3));
    for (final enemy in _gameOf(tester).enemies) {
      expect(_gameOf(tester).isOpen(enemy.row, enemy.col), isTrue);
    }
    final now = enemies.map((enemy) => '${enemy.row}:${enemy.col}').toList();
    expect(now, isNot(starts));
  });

  testWidgets('Enemies shoot and arrows die at walls', (
    WidgetTester tester,
  ) async {
    await _pumpGame(tester);

    var sawEnemyShot = false;
    for (var i = 0; i < 30 && !sawEnemyShot; i++) {
      await tester.pump(const Duration(milliseconds: 110));
      sawEnemyShot = _gameOf(tester)
          .projectiles
          .any((projectile) => projectile.owner == ProjectileOwner.enemy);
    }
    expect(sawEnemyShot, isTrue);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 110));
      for (final projectile in _gameOf(tester).projectiles) {
        expect(_gameOf(tester).isOpen(projectile.row, projectile.col), isTrue);
      }
    }
  });
}
