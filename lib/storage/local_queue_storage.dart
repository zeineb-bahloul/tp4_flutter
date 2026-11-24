import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_status.dart';

class LocalQueueStorage {
  Database? _database;
  final bool inMemory;
  final List<Map<String, dynamic>> _webStorage = [];

  LocalQueueStorage({this.inMemory = false});

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (inMemory) {
      _database = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: _onCreate,
      );
      return _database!;
    }
    final path = join(await getDatabasesPath(), 'waiting_queue.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        location_accuracy_m REAL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveClient(Map<String, dynamic> client) async {
    if (kIsWeb) {
      _webStorage.removeWhere((c) => c['id'] == client['id']);
      _webStorage.add(Map<String, dynamic>.from(client));
      return;
    }
    final db = await database;
    await db.insert(
      'clients',
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (kIsWeb) {
      final list = List<Map<String, dynamic>>.from(_webStorage);
      list.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      return list;
    }
    final db = await database;
    return db.query('clients', orderBy: 'created_at DESC, id DESC');
  }

  /// Corrected: Fetches both 'pending' and 'failed' records for retry logic
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    if (kIsWeb) {
      return _webStorage.where((c) => c['sync_status'] == 'pending' || c['sync_status'] == 'failed').toList();
    }
    final db = await database;
    return db.query(
      'clients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    if (kIsWeb) {
      final index = _webStorage.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        _webStorage[index]['sync_status'] = status.name;
      }
      return;
    }
    final db = await database;
    await db.update(
      'clients',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteClient(String id) async {
    if (kIsWeb) {
      _webStorage.removeWhere((c) => c['id'] == id);
      return;
    }
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      _webStorage.clear();
      return;
    }
    final db = await database;
    await db.delete('clients');
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
