import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/ingredient.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sous_chef.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        category TEXT NOT NULL,
        expiryDate TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastUpdated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE chat_sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          lastUpdated TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE chat_messages (
          id TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          content TEXT NOT NULL,
          type TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          status TEXT NOT NULL,
          metadata TEXT,
          FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<int> insertIngredient(Ingredient ingredient) async {
    final db = await database;
    return await db.insert('ingredients', ingredient.toMap());
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final db = await database;
    final result = await db.query('ingredients', orderBy: 'name');
    return result.map((map) => Ingredient.fromMap(map)).toList();
  }

  Future<List<Ingredient>> getIngredientsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'ingredients',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name',
    );
    return result.map((map) => Ingredient.fromMap(map)).toList();
  }

  Future<Ingredient?> getIngredientById(int id) async {
    final db = await database;
    final result = await db.query(
      'ingredients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return Ingredient.fromMap(result.first);
  }

  Future<int> updateIngredient(Ingredient ingredient) async {
    final db = await database;
    return await db.update(
      'ingredients',
      ingredient.toMap(),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );
  }

  Future<int> deleteIngredient(int id) async {
    final db = await database;
    return await db.delete(
      'ingredients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllIngredients() async {
    final db = await database;
    await db.delete('ingredients');
  }

  Future<List<Ingredient>> searchIngredients(String query) async {
    final db = await database;
    final result = await db.query(
      'ingredients',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name',
    );
    return result.map((map) => Ingredient.fromMap(map)).toList();
  }

  // Chat persistence methods
  Future<String> insertChatSession(ChatSession session) async {
    final db = await database;
    await db.insert('chat_sessions', {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.toIso8601String(),
      'lastUpdated': session.lastUpdated.toIso8601String(),
    });
    return session.id;
  }

  Future<void> updateChatSession(ChatSession session) async {
    final db = await database;
    await db.update(
      'chat_sessions',
      {
        'title': session.title,
        'lastUpdated': session.lastUpdated.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<List<ChatSession>> getAllChatSessions() async {
    final db = await database;
    final result = await db.query('chat_sessions', orderBy: 'lastUpdated DESC');
    
    final sessions = <ChatSession>[];
    for (final sessionMap in result) {
      final messages = await getChatMessages(sessionMap['id'] as String);
      sessions.add(ChatSession(
        id: sessionMap['id'] as String,
        title: sessionMap['title'] as String,
        createdAt: DateTime.parse(sessionMap['createdAt'] as String),
        lastUpdated: DateTime.parse(sessionMap['lastUpdated'] as String),
        messages: messages,
      ));
    }
    
    return sessions;
  }

  Future<ChatSession?> getChatSessionById(String sessionId) async {
    final db = await database;
    final result = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    
    final sessionMap = result.first;
    final messages = await getChatMessages(sessionId);
    
    return ChatSession(
      id: sessionMap['id'] as String,
      title: sessionMap['title'] as String,
      createdAt: DateTime.parse(sessionMap['createdAt'] as String),
      lastUpdated: DateTime.parse(sessionMap['lastUpdated'] as String),
      messages: messages,
    );
  }

  Future<void> deleteChatSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<String> insertChatMessage(String sessionId, ChatMessage message) async {
    final db = await database;
    await db.insert('chat_messages', {
      'id': message.id,
      'sessionId': sessionId,
      'content': message.content,
      'type': message.type.name,
      'timestamp': message.timestamp.toIso8601String(),
      'status': message.status.name,
      'metadata': message.metadata != null ? jsonEncode(message.metadata) : null,
    });
    return message.id;
  }

  Future<void> updateChatMessage(ChatMessage message) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {
        'content': message.content,
        'status': message.status.name,
        'metadata': message.metadata != null ? jsonEncode(message.metadata) : null,
      },
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    final db = await database;
    final result = await db.query(
      'chat_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    
    return result.map((map) {
      return ChatMessage(
        id: map['id'] as String,
        content: map['content'] as String,
        type: MessageType.values.firstWhere((e) => e.name == map['type']),
        timestamp: DateTime.parse(map['timestamp'] as String),
        status: MessageStatus.values.firstWhere((e) => e.name == map['status']),
        metadata: map['metadata'] != null 
            ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
            : null,
      );
    }).toList();
  }

  Future<void> deleteChatMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> deleteAllChatMessages(String sessionId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}