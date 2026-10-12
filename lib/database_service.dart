import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'episode.dart';

class EpisodeState {
  const EpisodeState({
    required this.rating,
    required this.listened,
    required this.note,
  });

  final int rating;
  final bool listened;
  final String note;
}

class DatabaseService {
  DatabaseService._();

  static final instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    _database = await openDatabase(
      p.join(base, 'sinclair_tracker.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE episode_state (
            id TEXT PRIMARY KEY,
            rating INTEGER NOT NULL DEFAULT 0,
            listened INTEGER NOT NULL DEFAULT 0,
            note TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<Map<String, EpisodeState>> loadStates() async {
    final db = await database;
    final rows = await db.query('episode_state');
    return {
      for (final row in rows)
        row['id'] as String: EpisodeState(
          rating: row['rating'] as int? ?? 0,
          listened: (row['listened'] as int? ?? 0) == 1,
          note: row['note'] as String? ?? '',
        ),
    };
  }

  Future<void> saveEpisode(Episode episode) async {
    final db = await database;
    await db.insert(
        'episode_state',
        {
          'id': episode.id,
          'rating': episode.rating,
          'listened': episode.listened ? 1 : 0,
          'note': episode.note,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> exportState() async {
    final db = await database;
    return db.query('episode_state', orderBy: 'id');
  }

  Future<void> importState(List<dynamic> rows) async {
    final db = await database;
    await db.transaction((transaction) async {
      for (final raw in rows) {
        final row = (raw as Map).cast<String, dynamic>();
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        await transaction.insert(
            'episode_state',
            {
              'id': id,
              'rating': (row['rating'] as num?)?.toInt() ?? 0,
              'listened': (row['listened'] as num?)?.toInt() ?? 0,
              'note': row['note']?.toString() ?? '',
              'updated_at': row['updated_at']?.toString() ??
                  DateTime.now().toUtc().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> removeOrphans(Set<String> validIds) async {
    final db = await database;
    final rows = await db.query('episode_state', columns: ['id']);
    final batch = db.batch();
    for (final row in rows) {
      final id = row['id'] as String;
      if (!validIds.contains(id)) {
        batch.delete('episode_state', where: 'id = ?', whereArgs: [id]);
      }
    }
    await batch.commit(noResult: true);
  }
}
