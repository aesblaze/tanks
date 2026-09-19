import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'game.dart';

class SaveStore {
  SaveStore({File? file}) : _file = file ?? defaultFile();

  final File _file;

  static File defaultFile() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;
    return File(
      '$base${Platform.pathSeparator}tanks'
      '${Platform.pathSeparator}save.json',
    );
  }

  bool get hasSave => _file.existsSync();

  bool saveGame(Game game) {
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode(game.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  Game? loadGame({math.Random? random}) {
    try {
      if (!_file.existsSync()) {
        return null;
      }
      final data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return Game.fromJson(data, random: random);
    } catch (_) {
      return null;
    }
  }

  bool clear() {
    try {
      if (_file.existsSync()) {
        _file.deleteSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
