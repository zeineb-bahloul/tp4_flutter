import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';

@GenerateMocks([QueueProvider])
import 'waiting_room_widget_test.mocks.dart';

void main() {
  testWidgets('Displays location coordinates when available',
      (WidgetTester tester) async {
    final mockProvider = MockQueueProvider();

    when(mockProvider.clients).thenReturn([
      {
        'id': '1',
        'name': 'Sam',
        'lat': 51.5074,
        'lng': -0.1278,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 1,
      }
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>.value(
        value: mockProvider,
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.textContaining('51.5074'), findsOneWidget);
  });

  testWidgets('Displays "Location not captured" when GPS is null',
      (WidgetTester tester) async {
    final mockProvider = MockQueueProvider();

    when(mockProvider.clients).thenReturn([
      {
        'id': '2',
        'name': 'Bob',
        'lat': null,
        'lng': null,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      }
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>.value(
        value: mockProvider,
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('📍 Location not captured'), findsOneWidget);
  });
}
