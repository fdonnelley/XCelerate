import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/race.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('races.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create shared runners table
    await db.execute('''
      CREATE TABLE shared_runners (
        runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        school TEXT,
        grade INTEGER,
        bib_number INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create races table
    await db.execute('''
      CREATE TABLE races (
        race_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_name TEXT NOT NULL,
        race_date DATE,
        location TEXT,
        distance DECIMAL(5,2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create race runners table with updated structure
    await db.execute('''
      CREATE TABLE race_runners (
        race_runner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        bib_number INTEGER NOT NULL,
        name TEXT NOT NULL,
        school TEXT,
        grade INTEGER,
        FOREIGN KEY (race_id) REFERENCES races(race_id),
        UNIQUE(race_id, bib_number)
      )
    ''');

    // Create race results table
    await db.execute('''
      CREATE TABLE race_results (
        result_id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER NOT NULL,
        race_runner_id INTEGER NOT NULL,
        place INTEGER,
        finish_time TEXT,
        FOREIGN KEY (race_id) REFERENCES races(race_id),
        FOREIGN KEY (race_runner_id) REFERENCES race_runners(race_runner_id)
      )
    ''');
  }

  // Shared Runners Methods
  Future<int> insertSharedRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.insert('shared_runners', runner);
  }

  Future<List<Map<String, dynamic>>> getAllSharedRunners() async {
    final db = await instance.database;
    return await db.query('shared_runners');
  }

  Future<Map<String, dynamic>?> getSharedRunnerByBib(int bib) async {
    final db = await instance.database;
    final results = await db.query(
      'shared_runners',
      where: 'bib_number = ?',
      whereArgs: [bib],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Races Methods
  Future<int> insertRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.insert('races', race);
  }
  
  Future<int> updateRace(Map<String, dynamic> race) async {
    final db = await instance.database;
    return await db.update(
      'races',
      race,
      where: 'race_id = ?',
      whereArgs: [race['race_id']],
    );
  }

  Future<List<Race>> getAllRaces() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'races',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      DateTime raceDate;
      try {
        raceDate = DateTime.parse(maps[i]['race_date'].trim());
      } catch (e) {
        print('Error parsing date: ${maps[i]['race_date']}');
        raceDate = DateTime.now(); // or handle it in a way that makes sense for your app
      }

      return Race(
        raceId: maps[i]['race_id'],
        raceName: maps[i]['race_name'],
        raceDate: raceDate,
        location: maps[i]['location'],
        distance: double.tryParse(maps[i]['distance'].toString()) ?? 0.0,
      );
    });
  }

  Future<Map<String, dynamic>?> getRaceById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'races',
      where: 'race_id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Race Runners Methods
  Future<int> insertRaceRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    return await db.insert(
      'race_runners',
      runner,
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if bib number exists in race
    );
  }

  Future<List<Map<String, dynamic>>> getRaceRunners(int raceId) async {
    final db = await instance.database;
    return await db.query(
      'race_runners',
      where: 'race_id = ?',
      whereArgs: [raceId],
      orderBy: 'bib_number',
    );
  }

  Future<Map<String, dynamic>?> getRaceRunnerByBib(int raceId, int bibNumber, {bool getShared=false}) async {
    final db = await instance.database;
    final results = await db.query(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );

    final runner = results.isNotEmpty ? results.first : null;
    if (runner == null && getShared){
      return getSharedRunnerByBib(bibNumber);
    }
    return runner;
  }

  Future<void> updateRaceRunner(Map<String, dynamic> runner) async {
    final db = await instance.database;
    await db.update(
      'race_runners',
      runner,
      where: 'race_runner_id = ?',
      whereArgs: [runner['race_runner_id']],
    );
  }

  Future<void> deleteRaceRunner(int raceId, int bibNumber) async {
    final db = await instance.database;
    await db.delete(
      'race_runners',
      where: 'race_id = ? AND bib_number = ?',
      whereArgs: [raceId, bibNumber],
    );
  }

  // Race Results Methods
  Future<int> insertRaceResult(Map<String, dynamic> result) async {
    final db = await instance.database;
    return await db.insert('race_results', result);
  }

  Future<void> insertRaceResults(List<Map<String, dynamic>> results) async {
    final db = await instance.database;
    final batch = db.batch();
    results.forEach((result) {
      batch.insert('race_results', result);
    });
    await batch.commit();
    return;
  }

  Future<List<Map<String, dynamic>>> getRaceResults(int raceId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT rr.*, r.place, r.finish_time
      FROM race_runners rr
      INNER JOIN race_results r 
        ON rr.race_runner_id = r.race_runner_id
      WHERE rr.race_id = ?
      ORDER BY r.place NULLS LAST, rr.bib_number
    ''', [raceId]);
  }


  // Cleanup Methods
  Future<void> deleteRace(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related records first
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
      await txn.delete('races', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }

  Future<void> deleteAllRaces() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('race_results');
      await txn.delete('race_runners');
      await txn.delete('races');
    });
  }

  Future<void> deleteAllRaceRunners(int raceId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete related race results first (due to foreign key constraint)
      await txn.delete('race_results', where: 'race_id = ?', whereArgs: [raceId]);
      // Then delete all runners for this race
      await txn.delete('race_runners', where: 'race_id = ?', whereArgs: [raceId]);
    });
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), 'races.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}