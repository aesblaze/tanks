import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tanks/game.dart';
import 'package:tanks/save.dart';

void main() {
  test('Save store saves, loads and clears the game', () {
    final dir = Directory.systemTemp.createTempSync('tanks_save');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = SaveStore(
      file: File('${dir.path}${Platform.pathSeparator}save.json'),
    );

    expect(store.hasSave, isFalse);
    expect(store.loadGame(), isNull);

    final game = Game();
    game.mines.clear();
    game.playerRow = 9;
    game.lives = 3;
    expect(store.saveGame(game), isTrue);
    expect(store.hasSave, isTrue);

    final loaded = store.loadGame();
    expect(loaded, isNotNull);
    expect(loaded!.playerRow, 9);
    expect(loaded.lives, 3);
    expect(loaded.enemies.length, game.enemies.length);

    expect(store.clear(), isTrue);
    expect(store.hasSave, isFalse);
    expect(store.loadGame(), isNull);
  });

  test('Corrupted saves load as null', () {
    final dir = Directory.systemTemp.createTempSync('tanks_save');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}save.json');
    file.writeAsStringSync('not json');

    final store = SaveStore(file: file);

    expect(store.loadGame(), isNull);
  });
}
