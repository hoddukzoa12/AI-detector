import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';

class _MemoryWatchStore implements WatchStore {
  String? raw;

  @override
  Future<String?> loadWatchStoreJson() async => raw;

  @override
  Future<void> saveWatchStoreJson(String raw) async {
    this.raw = raw;
  }
}

void main() {
  test('addTarget cleans aliases and persists the watch store', () async {
    final store = _MemoryWatchStore();
    final service = WatchService(store: store);

    await service.addTarget(
      name: '  Jane   Doe ',
      aliases: [' JD ', '', 'Jane', 'JD'],
    );

    expect(service.targets, hasLength(1));
    expect(service.targets.single.name, 'Jane Doe');
    expect(service.targets.single.aliases, ['JD', 'Jane']);
    expect(service.activeTerms(), ['jane doe', 'jd', 'jane']);
    expect(store.raw, isNotNull);
  });

  test('global enabled gates active terms', () async {
    final service = WatchService(store: _MemoryWatchStore());

    await service.addTarget(name: 'Jane Doe');
    await service.setGlobalEnabled(false);

    expect(service.activeTerms(), isEmpty);
  });

  test('buildRuntimeState exposes enabled target terms', () async {
    final service = WatchService(store: _MemoryWatchStore());

    final target = await service.addTarget(
      name: 'Jane Doe',
      aliases: ['JD'],
    );
    final state = service.buildRuntimeState();

    expect(state['version'], watchStorageVersion);
    expect(state['globalEnabled'], isTrue);
    expect(state['autoMask'], isTrue);
    expect(state['terms'], [
      {'targetId': target.id, 'term': 'Jane Doe'},
      {'targetId': target.id, 'term': 'JD'},
    ]);
  });

  test('WatchDetection.tryParse records recent detections with dedupe', () {
    final service = WatchService(store: _MemoryWatchStore());
    final detection = WatchDetection.tryParse([
      {
        'targetId': 't1',
        'term': 'Jane',
        'url': 'https://example.com',
        'pageTitle': 'Example',
        'matchedText': 'Hello Jane',
        'tag': 'p',
      }
    ]);

    expect(detection, isNotNull);
    service.recordDetection(detection!);
    service.recordDetection(detection);

    expect(service.recentDetections, hasLength(1));
    expect(service.recentDetections.single.term, 'Jane');
    expect(service.recentDetections.single.matchedText, 'Hello Jane');
  });
}
