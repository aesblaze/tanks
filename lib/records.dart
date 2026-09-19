import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class Records {
  const Records({this.bestKills = 0, this.bestLevel = 1});

  final int bestKills;
  final int bestLevel;

  Records merge(int kills, int level) => Records(
        bestKills: math.max(bestKills, kills),
        bestLevel: math.max(bestLevel, level),
      );
}

class RecordStore {
  RecordStore({File? file}) : _file = file ?? defaultFile();

  final File _file;

  static File defaultFile() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;
    return File(
      '$base${Platform.pathSeparator}tanks'
      '${Platform.pathSeparator}records.json',
    );
  }

  Records load() {
    try {
      if (!_file.existsSync()) {
        return const Records();
      }
      final data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return Records(
        bestKills: (data['bestKills'] as num?)?.toInt() ?? 0,
        bestLevel: (data['bestLevel'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      return const Records();
    }
  }

  bool save(Records records) {
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(
        jsonEncode({
          'bestKills': records.bestKills,
          'bestLevel': records.bestLevel,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
