import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'dart:async';

class QueueProvider extends ChangeNotifier {
  final LocalQueueService _localDb;
  final GeolocationService _geoService;
  SupabaseClient? _supabase;
  RealtimeChannel? _subscription;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;

  QueueProvider({
    GeolocationService? geoService,
    LocalQueueService? localDb,
    SupabaseClient? supabaseClient,
  })  : _geoService = geoService ?? GeolocationService(),
        _localDb = localDb ?? LocalQueueService() {
    try {
      _supabase = supabaseClient ?? Supabase.instance.client;
    } catch (_) {
      _supabase = null;
    }
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    try {
      // 1. Charger depuis la base locale immédiatement
      _clients = List<Map<String, dynamic>>.from(await _localDb.getClients());
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from local db: $e');
    }

    // 2. Si connecté à Supabase, récupérer les clients distants
    if (_supabase != null) {
      try {
        final remoteClients =
            await _supabase!.from('clients').select().order('created_at');
        for (var row in remoteClients as List) {
          final item = Map<String, dynamic>.from(row as Map)..['is_synced'] = 1;
          await _localDb.insertClientLocally(item);
        }
        _clients = List<Map<String, dynamic>>.from(await _localDb.getClients());
        notifyListeners();
      } catch (e) {
        debugPrint('Fetch remote clients skipped (offline or error): $e');
      }
    }

    // 3. Synchroniser les clients locaux non synchronisés vers Supabase
    await _syncLocalToRemote();

    // 4. S'abonner aux changements en temps réel
    _setupRealtimeSubscription();
  }

  Future<void> _syncLocalToRemote() async {
    if (_supabase == null) return;
    try {
      final unsynced = await _localDb.getUnsyncedClients();
      for (var client in unsynced) {
        try {
          final remoteClient = Map<String, dynamic>.from(client)
            ..remove('is_synced');
          try {
            await _supabase!.from('clients').upsert(remoteClient);
          } catch (upsertError) {
            // Si la table Supabase n'a pas lat/lng
            if (upsertError.toString().contains('lat') ||
                upsertError.toString().contains('lng') ||
                upsertError.toString().contains('42703')) {
              final fallbackClient = Map<String, dynamic>.from(remoteClient)
                ..remove('lat')
                ..remove('lng');
              await _supabase!.from('clients').upsert(fallbackClient);
            } else {
              rethrow;
            }
          }
          await _localDb.markClientAsSynced(client['id'] as String);
        } catch (e) {
          debugPrint('Sync failed for ${client['id']}: $e');
        }
      }
      _clients = List<Map<String, dynamic>>.from(await _localDb.getClients());
      notifyListeners();
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  Future<void> addClient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    Position? position;
    try {
      position = await _geoService.getCurrentPosition();
    } catch (e) {
      debugPrint('Error obtaining location: $e');
    }

    final newClient = <String, dynamic>{
      'id': const Uuid().v4(),
      'name': trimmed,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    // Sauvegarder localement immédiatement
    try {
      await _localDb.insertClientLocally(newClient);
    } catch (e) {
      debugPrint('Local insert error: $e');
    }

    // Mettre à jour l'UI immédiatement
    _clients.add(newClient);
    _clients.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    notifyListeners();

    // Lancer la synchronisation vers Supabase
    unawaited(_syncLocalToRemote());
  }

  Future<void> removeClient(String id) async {
    try {
      await _localDb.deleteClientLocally(id);
    } catch (e) {
      debugPrint('Local delete error: $e');
    }
    _clients.removeWhere((c) => c['id'] == id);
    notifyListeners();
    if (_supabase != null) {
      try {
        await _supabase!.from('clients').delete().match({'id': id});
      } catch (e) {
        debugPrint('Remote delete failed: $e');
      }
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) return;
    await removeClient(_clients.first['id'] as String);
  }

  void _setupRealtimeSubscription() {
    if (_supabase == null) return;
    _subscription = _supabase!
        .channel('public:clients')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clients',
          callback: (payload) => _loadQueue(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
