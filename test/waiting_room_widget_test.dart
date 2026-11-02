import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';

Widget createTestWidget() {
  return ChangeNotifierProvider(
    create: (context) => QueueProvider(),
    child: const WaitingRoomApp(),
  );
}

void main() {
  testWidgets('should add a new client to the list on button tap', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify initial empty state
    expect(find.text('No one in queue yet...'), findsOneWidget);

    // Enter name and tap Add
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    // Verify Alice is added
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('No one in queue yet...'), findsNothing);
  });

  testWidgets('should remove a client from the list when the delete button is tapped', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);

    // Tap delete icon
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);
    expect(find.text('No one in queue yet...'), findsOneWidget);
  });

  testWidgets('should remove the first client from the list when Next Client is tapped', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Add Client A
    await tester.enterText(find.byType(TextField), 'Client A');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    // Add Client B
    await tester.enterText(find.byType(TextField), 'Client B');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    // Tap Next Client
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next Client'));
    await tester.pumpAndSettle();

    expect(find.text('Client A'), findsNothing);
    expect(find.text('Client B'), findsOneWidget);
  });
}
