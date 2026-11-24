import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/connectivity_provider.dart';
import 'providers/queue_provider.dart';
import 'repositories/queue_repository.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'storage/local_queue_storage.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser sqflite pour Windows / macOS / Linux desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Load .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  const defaultSupabaseUrl = 'https://yyvxowsptnfcomzuavgj.supabase.co';
  const defaultSupabaseKey = 'sb_publishable_hkUPwiGwJEUAM0oQjLRaoQ_E3nu2OF8';

  final envUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  final envKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  String supabaseUrl = envUrl.isNotEmpty ? envUrl : defaultSupabaseUrl;
  String supabaseAnonKey = envKey.isNotEmpty ? envKey : defaultSupabaseKey;

  SupabaseClient? supabaseClient;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabaseClient = Supabase.instance.client;
    debugPrint('Supabase initialized successfully!');
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  final storage = LocalQueueStorage();
  final repository = QueueRepository(supabaseClient, storage);
  final syncService = SyncService(storage, repository);
  final geolocationService = GeolocationService();
  final connectivityService = ConnectivityService(supabaseClient);

  final connectivityProvider = ConnectivityProvider(connectivityService);
  // Initialiser de manière asynchrone sans bloquer le premier affichage de l'application
  connectivityProvider.initialize().catchError((e) {
    debugPrint('Error initializing connectivity provider: $e');
  });

  final queueProvider = QueueProvider(
    repository,
    geolocationService,
    syncService: syncService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivityProvider),
        ChangeNotifierProvider.value(value: queueProvider),
      ],
      child: WaitingRoomApp(supabaseReady: supabaseClient != null),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key, this.supabaseReady = true});

  final bool supabaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resilient Waiting Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: AuthGate(supabaseReady: supabaseReady),
    );
  }
}
