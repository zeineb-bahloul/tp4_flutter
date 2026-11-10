import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalQueueService {
  Database? _database;
  static const String tableName = 'local_clients';
  final bool _inMemory;
  final List<Map<String, dynamic>> _webStorage = [];

  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (_inMemory) {
      return await openDatabase(
        ':memory:',
        version: 1,
        onCreate: _onCreate,
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'waiting_room.db');
      return openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    if (kIsWeb) {
      _webStorage.removeWhere((c) => c['id'] == client['id']);
      _webStorage.add(Map<String, dynamic>.from(client));
      return;
    }
    final db = await database;
    await db.insert(
      tableName,
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (kIsWeb) {
      final list = List<Map<String, dynamic>>.from(_webStorage);
      list.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      return list;
    }
    final db = await database;
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    if (kIsWeb) {
      return _webStorage.where((c) => c['is_synced'] == 0).toList();
    }
    final db = await database;
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markClientAsSynced(String id) async {
    if (kIsWeb) {
      final index = _webStorage.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        _webStorage[index]['is_synced'] = 1;
      }
      return;
    }
    final db = await database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteClientLocally(String id) async {
    if (kIsWeb) {
      _webStorage.removeWhere((c) => c['id'] == id);
      return;
    }
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      _webStorage.clear();
      return;
    }
    final db = await database;
    await db.delete(tableName);
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
