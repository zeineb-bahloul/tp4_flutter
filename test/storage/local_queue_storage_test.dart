import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/models/sync_status.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalQueueStorage Tests', () {
    late LocalQueueStorage storage;

    setUp(() async {
      storage = LocalQueueStorage(inMemory: true);
      await storage.clearAll();
    });

    tearDown(() async {
      await storage.close();
    });

    test('saveClient and getClients work correctly', () async {
      final client = Client(
        id: '123',
        name: 'Bob',
        lat: 36.8,
        lng: 10.1,
        locationAccuracy: 10.0,
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );

      await storage.saveClient(client.toLocalMap());

      final records = await storage.getClients();
      expect(records.length, 1);
      expect(records.first['name'], 'Bob');
      expect(records.first['sync_status'], 'pending');
    });

    test('getPendingClients returns pending and failed but not synced', () async {
      final pendingClient = Client(
        id: '1',
        name: 'Pending User',
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );
      final failedClient = Client(
        id: '2',
        name: 'Failed User',
        createdAt: DateTime(2026, 1, 2),
        syncStatus: SyncStatus.failed,
      );
      final syncedClient = Client(
        id: '3',
        name: 'Synced User',
        createdAt: DateTime(2026, 1, 3),
        syncStatus: SyncStatus.synced,
      );

      await storage.saveClient(pendingClient.toLocalMap());
      await storage.saveClient(failedClient.toLocalMap());
      await storage.saveClient(syncedClient.toLocalMap());

      final pendingList = await storage.getPendingClients();
      expect(pendingList.length, 2);
      expect(pendingList.any((c) => c['name'] == 'Pending User'), isTrue);
      expect(pendingList.any((c) => c['name'] == 'Failed User'), isTrue);
      expect(pendingList.any((c) => c['name'] == 'Synced User'), isFalse);
    });

    test('updateSyncStatus updates the status', () async {
      final client = Client(
        id: '99',
        name: 'Alice',
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pending,
      );

      await storage.saveClient(client.toLocalMap());
      await storage.updateSyncStatus('99', SyncStatus.synced);

      final records = await storage.getClients();
      expect(records.first['sync_status'], 'synced');
    });
  });
}

