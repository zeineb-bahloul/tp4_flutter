import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/models/sync_status.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';
import 'package:waiting_room_app/services/sync_service.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';

class MockQueueRepository extends Mock implements QueueRepository {}

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

  group('SyncService Tests', () {
    late LocalQueueStorage storage;
    late MockQueueRepository mockRepository;
    late SyncService syncService;

    setUp(() async {
      storage = LocalQueueStorage(inMemory: true);
      await storage.clearAll();
      mockRepository = MockQueueRepository();
      syncService = SyncService(storage, mockRepository);
    });

    tearDown(() async {
      await storage.close();
    });

    test('synchronize registers pending clients and marks them synced', () async {
      final client = Client(
        id: '1',
        name: 'Pending Client',
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );

      await storage.saveClient(client.toLocalMap());

      when(() => mockRepository.registerOnServer(any())).thenAnswer((_) async {});

      await syncService.synchronize();

      verify(() => mockRepository.registerOnServer(any())).called(1);

      final pendingList = await storage.getPendingClients();
      expect(pendingList.isEmpty, isTrue);

      final records = await storage.getClients();
      expect(records.first['sync_status'], equals('synced'));
    });

    test('synchronize marks status as failed if registration throws', () async {
      final client = Client(
        id: '2',
        name: 'Failing Client',
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );

      await storage.saveClient(client.toLocalMap());

      when(() => mockRepository.registerOnServer(any()))
          .thenThrow(Exception('Network error'));

      await syncService.synchronize();

      final pendingList = await storage.getPendingClients();
      expect(pendingList.length, 1);
      expect(pendingList.first['sync_status'], equals('failed'));
    });
  });
}

