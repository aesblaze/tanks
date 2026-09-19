import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tanks/records.dart';

void main() {
  test('Records merge keeps the maximum values', () {
    const records = Records(bestKills: 5, bestLevel: 3);

    expect(records.merge(3, 2).bestKills, 5);
    expect(records.merge(3, 2).bestLevel, 3);
    expect(records.merge(9, 1).bestKills, 9);
    expect(records.merge(1, 7).bestLevel, 7);
  });

  test('Record store saves and loads records from a file', () {
    final dir = Directory.systemTemp.createTempSync('tanks_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = RecordStore(
      file: File('${dir.path}${Platform.pathSeparator}records.json'),
    );

    expect(store.load().bestKills, 0);
    expect(store.load().bestLevel, 1);

    expect(store.save(const Records(bestKills: 12, bestLevel: 4)), isTrue);

    final loaded = store.load();
    expect(loaded.bestKills, 12);
    expect(loaded.bestLevel, 4);
  });

  test('Record store survives corrupted files', () {
    final dir = Directory.systemTemp.createTempSync('tanks_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}records.json');
    file.writeAsStringSync('not json');

    final store = RecordStore(file: file);

    expect(store.load().bestKills, 0);
    expect(store.load().bestLevel, 1);
  });
}
