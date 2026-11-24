import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';
import '../storage/local_queue_storage.dart';

class QueueRepository {
  final SupabaseClient? _supabase;
  final LocalQueueStorage _storage;
  StreamController<Client>? _insertController;
  RealtimeChannel? _subscription;

  QueueRepository(this._supabase, this._storage) {
    _initRealtime();
  }

  LocalQueueStorage get storage => _storage;

  void _initRealtime() {
    final client = _supabase;
    if (client == null) return;
    try {
      _insertController = StreamController<Client>.broadcast();
      _subscription = client
          .channel('public:clients_repository')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'clients',
            callback: (payload) {
              try {
                final newClient = Client.fromSupabaseMap(payload.newRecord);
                _insertController?.add(newClient);
              } catch (e) {
                debugPrint('Error parsing realtime payload: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error in repository: $e');
    }
  }

  Stream<Client> get onClientInserted =>
      _insertController?.stream ?? const Stream.empty();

  Future<void> registerOnServer(Client client) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw Exception('Supabase client is not available');
    }

    try {
      // 1. Tenter d'appeler la fonction RPC register_queue_client
      await supabase.rpc('register_queue_client', params: {
        'p_id': client.id,
        'p_name': client.name,
        'p_lat': client.lat,
        'p_lng': client.lng,
        'p_accuracy': client.locationAccuracy,
        'p_created_at': client.createdAt.toIso8601String(),
      });
    } catch (rpcError) {
      debugPrint('RPC error, falling back to direct upsert: $rpcError');
      // 2. Fallback direct upsert
      try {
        await supabase.from('clients').upsert(client.toSupabaseMap());
      } catch (upsertError) {
        // Fallback sans colonnes GPS si non encore migrées sur Supabase
        final fallbackMap = Map<String, dynamic>.from(client.toSupabaseMap())
          ..remove('lat')
          ..remove('lng')
          ..remove('location_accuracy_m');
        await supabase.from('clients').upsert(fallbackMap);
      }
    }
  }

  Future<List<Client>> fetchPage({required int offset, required int limit}) async {
    final supabase = _supabase;
    if (supabase == null) {
      final localRecords = await _storage.getClients();
      final clients = localRecords.map((m) => Client.fromLocalMap(m)).toList();
      if (offset >= clients.length) return [];
      final end = (offset + limit < clients.length) ? offset + limit : clients.length;
      return clients.sublist(offset, end);
    }

    try {
      final response = await supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => Client.fromSupabaseMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Fetch page error, falling back to local storage: $e');
      final localRecords = await _storage.getClients();
      final clients = localRecords.map((m) => Client.fromLocalMap(m)).toList();
      if (offset >= clients.length) return [];
      final end = (offset + limit < clients.length) ? offset + limit : clients.length;
      return clients.sublist(offset, end);
    }
  }

  Future<void> deleteClient(String id) async {
    await _storage.deleteClient(id);
    final supabase = _supabase;
    if (supabase != null) {
      try {
        await supabase.from('clients').delete().match({'id': id});
      } catch (e) {
        debugPrint('Remote delete failed: $e');
      }
    }
  }

  void dispose() {
    _subscription?.unsubscribe();
    _insertController?.close();
  }
}
