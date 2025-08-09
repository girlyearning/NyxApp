import 'dart:convert';
import 'package:http/http.dart' as http;

class APIService {
  static const String baseUrl = 'https://nyxapp.onrender.com/api';
  static const Duration timeout = Duration(seconds: 60);

  // General HTTP methods
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      // Validate HTTP status code
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Validate Content-Type header (allow charset parameter)
      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        throw Exception('Invalid Content-Type: $contentType');
      }

      final decoded = json.decode(response.body);
      
      // Validate response structure
      if (decoded is Map<String, dynamic> && decoded['success'] != true) {
        throw Exception('API returned error: ${decoded['message'] ?? 'Unknown error'}');
      }
      
      return decoded;
    } catch (e) {
      throw Exception('GET request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {Duration? customTimeout}) async {
    try {
      final requestTimeout = customTimeout ?? timeout;
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(requestTimeout);

      // Validate HTTP status code
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Validate Content-Type header (allow charset parameter)
      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        throw Exception('Invalid Content-Type: $contentType');
      }

      final decoded = json.decode(response.body);
      
      // Validate response structure
      if (decoded is Map<String, dynamic> && decoded['success'] != true) {
        throw Exception('API returned error: ${decoded['message'] ?? 'Unknown error'}');
      }
      
      return decoded;
    } catch (e) {
      throw Exception('POST request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      // Validate HTTP status code
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Validate Content-Type header (allow charset parameter)
      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        throw Exception('Invalid Content-Type: $contentType');
      }

      final decoded = json.decode(response.body);
      
      // Validate response structure
      if (decoded is Map<String, dynamic> && decoded['success'] != true) {
        throw Exception('API returned error: ${decoded['message'] ?? 'Unknown error'}');
      }
      
      return decoded;
    } catch (e) {
      throw Exception('DELETE request failed: $e');
    }
  }

  // Mood tracking
  static Future<Map<String, dynamic>?> trackMood({
    required String userId,
    required String mood,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mood/track'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'mood': mood,
          'notes': notes,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      // API Error: trackMood failed
      return null;
    }
  }

  // Get mood history
  static Future<List<Map<String, dynamic>>?> getMoodHistory({
    required String userId,
    int days = 30,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mood/$userId/history?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['history'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['history']);
        }
      }
      return null;
    } catch (e) {
      // API Error: getMoodHistory failed
      return null;
    }
  }

  // Get daily nudge
  static Future<String?> getDailyNudge(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nudge/daily/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['nudge'] != null) {
          return data['data']['nudge'];
        }
      }
      return null;
    } catch (e) {
      // API Error: getDailyNudge failed
      return null;
    }
  }

  // Generate infodump
  static Future<Map<String, dynamic>?> generateInfodump({
    required String userId,
    String topic = 'random',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/infodump/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'topic': topic,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      // API Error: generateInfodump failed
      return null;
    }
  }

  // Start game
  static Future<Map<String, dynamic>?> startGame({
    required String userId,
    required String gameType,
    String difficulty = 'medium',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'game_type': gameType,
          'difficulty': difficulty,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      // API Error: startGame failed
      return null;
    }
  }

  // Submit game answer
  static Future<Map<String, dynamic>?> submitGameAnswer({
    required String gameId,
    required String userId,
    required String answer,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/answer'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'game_id': gameId,
          'user_id': userId,
          'answer': answer,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      // API Error: submitGameAnswer failed
      return null;
    }
  }

  // Get user stats
  static Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      // API Error: getUserStats failed
      return null;
    }
  }

  // Register user
  static Future<Map<String, dynamic>?> registerUser({
    required String userId,
    String? username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'username': username,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      // API Error: registerUser failed
      return null;
    }
  }


  // Get symptom-specific Nyx response
  static Future<String?> getSymptomResponse({
    required String userId,
    required String symptom,
    required String userType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/symptom/response'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'symptom': symptom,
          'user_type': userType,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['response'] != null) {
          return data['data']['response'];
        }
      }
      return null;
    } catch (e) {
      // API Error: getSymptomResponse failed
      return null;
    }
  }

  // Health check
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl.replaceAll('/api', '')}/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}