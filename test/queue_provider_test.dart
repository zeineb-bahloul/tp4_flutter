import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/queue_provider.dart';

void main() {
  group('QueueProvider Tests (Part 5)', () {
    test('Client model fromMap and toMap', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-uuid-1234',
        'name': 'Alice',
        'created_at': now.toIso8601String(),
      };

      final client = Client.fromMap(map);
      expect(client.id, 'test-uuid-1234');
      expect(client.name, 'Alice');

      final serialized = client.toMap();
      expect(serialized['id'], 'test-uuid-1234');
      expect(serialized['name'], 'Alice');
    });

    test('addClient and nextClient local flow', () async {
      final provider = QueueProvider();
      expect(provider.clients.isEmpty, true);

      await provider.addClient('Alice');
      await provider.addClient('Bob');

      expect(provider.clients.length, 2);
      expect(provider.clients[0].name, 'Alice');
      expect(provider.clients[1].name, 'Bob');

      await provider.nextClient();
      expect(provider.clients.length, 1);
      expect(provider.clients[0].name, 'Bob');
    });

    test('removeClient removes correct client by ID', () async {
      final provider = QueueProvider();
      await provider.addClient('Charlie');
      await provider.addClient('David');

      final charlieId = provider.clients[0].id;
      await provider.removeClient(charlieId);

      expect(provider.clients.length, 1);
      expect(provider.clients[0].name, 'David');
    });
  });
}
