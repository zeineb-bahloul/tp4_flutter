import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';

class QueueProvider extends ChangeNotifier {
  final QueueRepository _repository;
  final GeolocationService _geolocationService;
  final SyncService? _syncService;
  StreamSubscription<Client>? _realtimeSubscription;

  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;

  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  QueueProvider(
    this._repository,
    this._geolocationService, {
    this._syncService,
  }) {
    _listenRealtime();
    fetchInitialQueue();
  }

  List<Client> get clients => List.unmodifiable(_clients);
  QueueState get state => _state;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  void _listenRealtime() {
    _realtimeSubscription = _repository.onClientInserted.listen(
      handleRealtimeInsert,
      onError: (error) => debugPrint('Realtime error: $error'),
    );
  }

  Future<void> fetchInitialQueue() async {
    _state = QueueState.loading;
    _page = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final data = await _repository.fetchPage(offset: 0, limit: _pageSize);
      _clients.clear();
      _clients.addAll(data);
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      if (data.length < _pageSize) _hasMore = false;
    } catch (e) {
      _errorMessage = 'Failed to load queue';
      _state = QueueState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _page++;
      final newClients = await _repository.fetchPage(
        offset: _page * _pageSize,
        limit: _pageSize,
      );

      final existingIds = _clients.map((c) => c.id).toSet();
      final uniqueNewClients =
          newClients.where((c) => !existingIds.contains(c.id));

      _clients.addAll(uniqueNewClients);
      if (newClients.length < _pageSize) _hasMore = false;
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void handleRealtimeInsert(Client client) {
    final exists = _clients.any((c) => c.id == client.id);
    if (!exists) {
      _clients.insert(0, client);
      if (_state == QueueState.empty) _state = QueueState.loaded;
      notifyListeners();
    }
  }

  Future<void> addClient(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final position = await _geolocationService.getCurrentPosition();

    final newClient = Client(
      id: const Uuid().v4(),
      name: trimmed,
      lat: position?.latitude,
      lng: position?.longitude,
      locationAccuracy: position?.accuracy,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // Sauvegarder localement en premier
    await _repository.storage.saveClient(newClient.toLocalMap());

    // Ajouter à la liste UI immédiatement
    final exists = _clients.any((c) => c.id == newClient.id);
    if (!exists) {
      _clients.add(newClient);
      if (_state == QueueState.empty || _state == QueueState.initial) {
        _state = QueueState.loaded;
      }
      notifyListeners();
    }

    // Tenter la synchronisation
    final syncService = _syncService;
    if (syncService != null) {
      unawaited(syncService.synchronize());
    } else {
      try {
        await _repository.registerOnServer(newClient);
        await _repository.storage
            .updateSyncStatus(newClient.id, SyncStatus.synced);
      } catch (_) {
        await _repository.storage
            .updateSyncStatus(newClient.id, SyncStatus.failed);
      }
    }
  }

  Future<void> removeClient(String id) async {
    await _repository.deleteClient(id);
    _clients.removeWhere((c) => c.id == id);
    if (_clients.isEmpty) {
      _state = QueueState.empty;
    }
    notifyListeners();
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) return;
    await removeClient(_clients.first.id);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
