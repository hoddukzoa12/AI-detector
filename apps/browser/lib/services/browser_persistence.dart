import 'package:sqflite/sqflite.dart';

abstract interface class BrowserPersistence {
  Future<void> deleteAllWindows();

  Future<List<String>> loadWindowJsons();

  Future<String?> loadBrowserJson();

  Future<void> saveBrowserJson(String raw);
}

abstract interface class WindowPersistence {
  String? get initialWindowId;

  Future<void> deleteWindow(String id);

  Future<String?> loadWindowJson(String id);

  Future<String?> loadFirstWindowJson();

  Future<void> saveWindowJson(String id, String raw);
}

class SqfliteBrowserPersistence
    implements BrowserPersistence, WindowPersistence {
  const SqfliteBrowserPersistence({
    required Database database,
    this.initialWindowId,
  }) : _database = database;

  final Database _database;

  @override
  final String? initialWindowId;

  @override
  Future<void> deleteAllWindows() async {
    await _database.rawDelete('DELETE FROM windows');
  }

  @override
  Future<void> deleteWindow(String id) async {
    await _database.rawDelete('DELETE FROM windows WHERE id = ?', [id]);
  }

  @override
  Future<String?> loadBrowserJson() async {
    final rows =
        await _database.rawQuery('SELECT json FROM browser WHERE id = ?', [1]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['json'] as String?;
  }

  @override
  Future<List<String>> loadWindowJsons() async {
    final rows = await _database.rawQuery('SELECT id, json FROM windows');
    return rows
        .where((row) => (row['id'] as String?)?.startsWith('window_') ?? false)
        .map((row) => row['json'])
        .whereType<String>()
        .toList();
  }

  @override
  Future<String?> loadWindowJson(String id) async {
    final rows =
        await _database.rawQuery('SELECT json FROM windows WHERE id = ?', [id]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['json'] as String?;
  }

  @override
  Future<String?> loadFirstWindowJson() async {
    final rows = await _database.rawQuery('SELECT json FROM windows LIMIT 1');
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['json'] as String?;
  }

  @override
  Future<void> saveBrowserJson(String raw) async {
    final rows =
        await _database.rawQuery('SELECT id FROM browser WHERE id = ?', [1]);
    if (rows.isEmpty) {
      await _database
          .rawInsert('INSERT INTO browser(id, json) VALUES(?, ?)', [1, raw]);
      return;
    }
    await _database.rawUpdate(
      'UPDATE browser SET json = ? WHERE id = ?',
      [raw, 1],
    );
  }

  @override
  Future<void> saveWindowJson(String id, String raw) async {
    final rows =
        await _database.rawQuery('SELECT id FROM windows WHERE id = ?', [id]);
    if (rows.isEmpty) {
      await _database.rawInsert(
        'INSERT INTO windows(id, json) VALUES(?, ?)',
        [id, raw],
      );
      return;
    }
    await _database.rawUpdate(
      'UPDATE windows SET json = ? WHERE id = ?',
      [raw, id],
    );
  }
}
