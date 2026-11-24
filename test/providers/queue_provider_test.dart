import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/models/queue_state.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';
import 'package:waiting_room_app/services/sync_service.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';

class MockQueueRepository extends Mock implements QueueRepository {}
class MockGeolocationService extends Mock implements GeolocationService {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(
      Client(
        id: 'fake',
        name: 'fake',
        createdAt: DateTime.now(),
      ),
    );
  });

  group('QueueProvider Workshop 6 Tests', () {
    late MockQueueRepository mockRepo;
    late MockGeolocationService mockGeo;
    late MockSyncService mockSync;
    late LocalQueueStorage storage;

    setUp(() async {
      storage = LocalQueueStorage(inMemory: true);
      await storage.clearAll();
      mockRepo = MockQueueRepository();
      mockGeo = MockGeolocationService();
      mockSync = MockSyncService();

      when(() => mockRepo.storage).thenReturn(storage);
      when(() => mockRepo.onClientInserted).thenAnswer((_) => const Stream.empty());
      when(() => mockRepo.fetchPage(offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => []);
      when(() => mockGeo.getCurrentPosition()).thenAnswer((_) async => null);
      when(() => mockSync.synchronize()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await storage.close();
    });

    test('fetchInitialQueue loads clients and sets loaded state', () async {
      final initialClients = [
        Client(id: '1', name: 'Alice', createdAt: DateTime(2026, 1, 1)),
        Client(id: '2', name: 'Bob', createdAt: DateTime(2026, 1, 2)),
      ];

      when(() => mockRepo.fetchPage(offset: 0, limit: 20))
          .thenAnswer((_) async => initialClients);

      final provider = QueueProvider(
        mockRepo,
        mockGeo,
        syncService: mockSync,
      );

      await provider.fetchInitialQueue();

      expect(provider.state, equals(QueueState.loaded));
      expect(provider.clients.length, equals(2));
      expect(provider.clients.first.name, equals('Alice'));
    });

    test('handleRealtimeInsert adds new client without duplicates', () {
      final provider = QueueProvider(
        mockRepo,
        mockGeo,
        syncService: mockSync,
      );

      final client = Client(id: '10', name: 'Charlie', createdAt: DateTime.now());
      provider.handleRealtimeInsert(client);

      expect(provider.clients.length, equals(1));
      expect(provider.clients.first.id, equals('10'));

      // Re-inserting the same client does not duplicate
      provider.handleRealtimeInsert(client);
      expect(provider.clients.length, equals(1));
    });

    test('addClient saves locally and notifies listeners', () async {
      when(() => mockRepo.registerOnServer(any())).thenAnswer((_) async {});

      final provider = QueueProvider(
        mockRepo,
        mockGeo,
        syncService: mockSync,
      );

      await provider.addClient('New User');

      expect(provider.clients.length, equals(1));
      expect(provider.clients.first.name, equals('New User'));
      verify(() => mockSync.synchronize()).called(1);
    });
  });
}
