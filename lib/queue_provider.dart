import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => _clients;

  SupabaseClient? _supabase;
  RealtimeChannel? _subscription;

  QueueProvider({SupabaseClient? supabaseClient}) {
    if (supabaseClient != null) {
      _supabase = supabaseClient;
    } else {
      try {
        _supabase = Supabase.instance.client;
      } catch (_) {
        // Supabase not initialized yet (e.g. in test or missing credentials)
        _supabase = null;
      }
    }

    if (_supabase != null) {
      _fetchInitialClients();
      _setupRealtimeSubscription();
    }
  }

  // Constructor for testing (Part 5)
  QueueProvider.forTesting(SupabaseClient supabase) : _supabase = supabase;

  Future<void> _fetchInitialClients() async {
    if (_supabase == null) return;
    try {
      final response = await _supabase!
          .from('clients')
          .select()
          .order('created_at'); // ASC by default
      _clients.clear();
      _clients.addAll(
        (response as List).map(
          (item) => Client.fromMap(item as Map<String, dynamic>),
        ),
      );
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching clients: $error');
    }
  }

  void _setupRealtimeSubscription() {
    if (_supabase == null) return;
    try {
      _subscription = _supabase!
          .channel('public:clients')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'clients',
            callback: (payload) {
              debugPrint('Realtime change received: ${payload.eventType}');
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newClient = Client.fromMap(payload.newRecord);
                if (!_clients.any((c) => c.id == newClient.id)) {
                  _clients.add(newClient);
                  _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  notifyListeners();
                }
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final deletedId = payload.oldRecord['id'];
                if (deletedId != null) {
                  _clients.removeWhere((client) => client.id == deletedId);
                  notifyListeners();
                } else {
                  // If id is not in oldRecord, re-fetch list
                  _fetchInitialClients();
                }
              } else {
                _fetchInitialClients();
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint('Realtime channel status: $status (error: $error)');
          });
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  static int _idCounter = 0;

  Future<void> addClient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      debugPrint('Cannot add empty client name');
      return;
    }

    if (_supabase == null) {
      _idCounter++;
      _clients.add(Client(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}_$_idCounter',
        name: trimmed,
        createdAt: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    try {
      final response = await _supabase!
          .from('clients')
          .insert({'name': trimmed})
          .select()
          .single();
      debugPrint('Client added: $trimmed');

      final newClient = Client.fromMap(response);
      if (!_clients.any((c) => c.id == newClient.id)) {
        _clients.add(newClient);
        _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Failed to add client: $error');
    }
  }

  Future<void> removeClient(String id) async {
    if (_supabase == null) {
      _clients.removeWhere((c) => c.id == id);
      notifyListeners();
      return;
    }

    try {
      await _supabase!.from('clients').delete().match({'id': id});
      debugPrint('Client removed: $id');
      if (_clients.any((c) => c.id == id)) {
        _clients.removeWhere((client) => client.id == id);
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Failed to remove client: $error');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      debugPrint('Queue is empty!');
      return;
    }
    final firstClient = _clients.first;
    await removeClient(firstClient.id);
    debugPrint('Next client: ${firstClient.name}');
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
