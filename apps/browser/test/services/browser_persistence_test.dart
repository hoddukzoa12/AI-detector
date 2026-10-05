import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/services/browser_persistence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression net for the SQLite-backed browser/window store. Runs against a
/// real in-memory database (sqflite_common_ffi) rather than a mock, so the raw
/// SQL in [SqfliteBrowserPersistence] is exercised as written.
void main() {
  sqfliteFfiInit();

  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE browser(id INTEGER PRIMARY KEY, '
              'json TEXT)');
          await db.execute('CREATE TABLE windows(id TEXT PRIMARY KEY, '
              'json TEXT)');
        },
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  SqfliteBrowserPersistence store({String? initialWindowId}) =>
      SqfliteBrowserPersistence(
        database: database,
        initialWindowId: initialWindowId,
      );

  group('browser json', () {
    test('returns null before anything is saved', () async {
      expect(await store().loadBrowserJson(), isNull);
    });

    test('saves once then updates in place (single row, id = 1)', () async {
      final persistence = store();

      await persistence.saveBrowserJson('{"v":1}');
      expect(await persistence.loadBrowserJson(), '{"v":1}');

      await persistence.saveBrowserJson('{"v":2}');
      expect(await persistence.loadBrowserJson(), '{"v":2}');

      // The upsert must never accumulate rows.
      final rows = await database.rawQuery('SELECT id FROM browser');
      expect(rows, hasLength(1));
    });

    test('round-trips an empty string', () async {
      final persistence = store();
      await persistence.saveBrowserJson('');
      expect(await persistence.loadBrowserJson(), '');
    });
  });

  group('window json', () {
    test('loadWindowJson returns null for an unknown id', () async {
      expect(await store().loadWindowJson('window_missing'), isNull);
    });

    test('saves once then updates in place for the same id', () async {
      final persistence = store();

      await persistence.saveWindowJson('window_a', '{"tabs":0}');
      await persistence.saveWindowJson('window_a', '{"tabs":3}');

      expect(await persistence.loadWindowJson('window_a'), '{"tabs":3}');
      expect(
        await database.rawQuery('SELECT id FROM windows'),
        hasLength(1),
      );
    });

    test('loadFirstWindowJson returns null on an empty table', () async {
      expect(await store().loadFirstWindowJson(), isNull);
    });

    test('loadFirstWindowJson ignores the window_ id prefix rule', () async {
      // Unlike loadWindowJsons, "first" does no filtering — it is a plain
      // LIMIT 1. Fixing this asymmetry would legitimately change this test.
      final persistence = store();
      await persistence.saveWindowJson('legacy', '{"legacy":true}');

      expect(await persistence.loadFirstWindowJson(), '{"legacy":true}');
    });

    test('deleteWindow removes only the addressed row', () async {
      final persistence = store();
      await persistence.saveWindowJson('window_a', 'a');
      await persistence.saveWindowJson('window_b', 'b');

      await persistence.deleteWindow('window_a');

      expect(await persistence.loadWindowJson('window_a'), isNull);
      expect(await persistence.loadWindowJson('window_b'), 'b');
    });

    test('deleteWindow on a missing id is a no-op', () async {
      final persistence = store();
      await persistence.saveWindowJson('window_a', 'a');

      await persistence.deleteWindow('window_zzz');

      expect(await persistence.loadWindowJson('window_a'), 'a');
    });

    test('deleteAllWindows clears windows but keeps browser json', () async {
      final persistence = store();
      await persistence.saveBrowserJson('{"kept":true}');
      await persistence.saveWindowJson('window_a', 'a');
      await persistence.saveWindowJson('window_b', 'b');

      await persistence.deleteAllWindows();

      expect(await persistence.loadWindowJsons(), isEmpty);
      expect(await persistence.loadBrowserJson(), '{"kept":true}');
    });
  });

  group('loadWindowJsons filtering', () {
    test('keeps only rows whose id starts with window_', () async {
      final persistence = store();
      await persistence.saveWindowJson('window_1', 'one');
      await persistence.saveWindowJson('legacy_1', 'skipped');
      await persistence.saveWindowJson('window_2', 'two');

      expect(await persistence.loadWindowJsons(), ['one', 'two']);
    });

    test('drops rows with a null json payload', () async {
      await database.rawInsert(
        'INSERT INTO windows(id, json) VALUES(?, ?)',
        ['window_null', null],
      );

      expect(await store().loadWindowJsons(), isEmpty);
    });

    test('returns an empty list when nothing is stored', () async {
      expect(await store().loadWindowJsons(), isEmpty);
    });
  });

  test('initialWindowId is carried through verbatim', () async {
    expect(
        store(initialWindowId: 'window_seed').initialWindowId, 'window_seed');
    expect(store().initialWindowId, isNull);
  });
}
