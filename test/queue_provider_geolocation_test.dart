import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/queue_provider.dart';

// Génère le mock automatiquement via build_runner
@GenerateMocks([GeolocationService])
import 'queue_provider_geolocation_test.mocks.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('addClient saves client with geolocation coordinates', () async {
    // 1. Créer un mock de GeolocationService
    final mockGeo = MockGeolocationService();

    // 2. Créer une fausse position GPS
    final mockPos = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    // 3. Quand getCurrentPosition() est appelé → retourner mockPos
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

    // 4. Créer le QueueProvider avec le mock injecté + DB en mémoire
    final provider = QueueProvider(
      geoService: mockGeo,
      localDb: LocalQueueService(inMemory: true),
    );

    // 5. Ajouter un client
    await provider.addClient('Test User');

    // 6. Vérifier que les coordonnées GPS sont bien sauvegardées
    final client = provider.clients.last;
    expect(client['lat'], 37.7749);
    expect(client['lng'], -122.4194);
    expect(client['name'], 'Test User');
  });

  test('addClient saves null location when GPS is unavailable', () async {
    final mockGeo = MockGeolocationService();

    // GPS non disponible → retourne null
    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);

    final provider = QueueProvider(
      geoService: mockGeo,
      localDb: LocalQueueService(inMemory: true),
    );

    await provider.addClient('Offline User');

    final client = provider.clients.last;
    expect(client['lat'], isNull);
    expect(client['lng'], isNull);
    expect(client['name'], 'Offline User');
  });
}

