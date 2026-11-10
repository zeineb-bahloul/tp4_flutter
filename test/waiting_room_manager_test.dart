import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/queue_provider.dart';

@GenerateMocks([GeolocationService])
import 'waiting_room_manager_test.mocks.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final localDb = LocalQueueService(inMemory: true);
    await localDb.clearAll();
  });

  MockGeolocationService _mockGeo() {
    final mock = MockGeolocationService();
    when(mock.getCurrentPosition()).thenAnswer((_) async => null);
    return mock;
  }

  test('should add a client to the waiting list', () async {
    final manager = QueueProvider(
      geoService: _mockGeo(),
      localDb: LocalQueueService(inMemory: true),
    );

    await manager.addClient('John Doe');

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'John Doe');
  });

  test('should remove a client from the waiting list', () async {
    final manager = QueueProvider(
      geoService: _mockGeo(),
      localDb: LocalQueueService(inMemory: true),
    );

    await manager.addClient('John Doe');
    await manager.addClient('Jane Doe');

    final johnId = manager.clients.first['id'] as String;
    await manager.removeClient(johnId);

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'Jane Doe');
  });

  test('should remove the first client when nextClient() is called', () async {
    final manager = QueueProvider(
      geoService: _mockGeo(),
      localDb: LocalQueueService(inMemory: true),
    );

    await manager.addClient('Client A');
    await manager.addClient('Client B');

    await manager.nextClient();

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'Client B');
  });
}
