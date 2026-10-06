import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';

/// Database lokal SQLite: tabel `users` (template embedding) & `access_log`.
class UserRepository {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'mastersafety.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            access_id TEXT NOT NULL UNIQUE,
            access_status TEXT NOT NULL,
            embedding BLOB NOT NULL,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE access_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            granted INTEGER NOT NULL,
            similarity REAL NOT NULL,
            timestamp INTEGER NOT NULL
          )''');
      },
    );
  }

  Uint8List _encode(List<double> v) =>
      Float32List.fromList(v).buffer.asUint8List();

  List<double> _decode(Uint8List bytes) =>
      Uint8List.fromList(bytes).buffer.asFloat32List().toList();

  Future<int> insert(UserProfile u) async {
    final db = await _database;
    return db.insert('users', {
      'name': u.name,
      'access_id': u.accessId,
      'access_status': u.accessStatus,
      'embedding': _encode(u.embedding),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<UserProfile>> all() async {
    final db = await _database;
    final rows = await db.query('users');
    return rows
        .map((r) => UserProfile(
              id: r['id'] as int,
              name: r['name'] as String,
              accessId: r['access_id'] as String,
              accessStatus: r['access_status'] as String,
              embedding: _decode(r['embedding'] as Uint8List),
            ))
        .toList();
  }

  Future<int> count() async => (await all()).length;

  Future<String> nextAccessId() async {
    final n = await count();
    return 'MS-${(n + 1).toString().padLeft(4, '0')}';
  }

  Future<void> logAttempt(int? userId, bool granted, double similarity) async {
    final db = await _database;
    await db.insert('access_log', {
      'user_id': userId,
      'granted': granted ? 1 : 0,
      'similarity': similarity,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
