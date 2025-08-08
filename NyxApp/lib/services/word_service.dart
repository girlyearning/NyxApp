import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../services/logging_service.dart';

class WordService {
  static List<String> _commonWords = [];
  static List<String> _allValidWords = []; // All words from words_alpha.txt
  static List<String> _mentalHealthWords = [
    'CALM', 'PEACE', 'HOPE', 'CARE', 'LOVE',
    'TRUST', 'HAPPY', 'SMILE', 'LAUGH', 'FOCUS',
    'RELAX', 'BREATHE', 'GROWTH', 'HEAL', 'MOOD',
    'SAFE', 'KIND', 'WARM', 'FEEL', 'HELP',
    'MIND', 'HEART', 'SOUL', 'REST', 'SLEEP',
    'DREAM', 'BRAVE', 'STRONG', 'GOOD', 'WELL'
  ];
  
  static bool _isLoaded = false;
  static const String claudeApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';

  static Future<void> _loadCommonWords() async {
    if (_isLoaded) return;
    
    // First try to load words_alpha.txt
    try {
      final String content = await rootBundle.loadString('assets/words_alpha.txt');
      _allValidWords = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= 3)
          .toList();
      
      // Extract common words (4-6 letters) for games like unscramble - easier for 8th-9th grade level
      _commonWords = _allValidWords
          .where((word) => word.length >= 4 && word.length <= 6)
          .toList();
      
      _isLoaded = true;
      LoggingService.logInfo('✅ Loaded ${_allValidWords.length} words from words_alpha.txt');
      return;
    } catch (e) {
      LoggingService.logError('❌ Failed to load words_alpha.txt: $e');
    }
    
    // Fallback: Try API
    try {
      final response = await http.get(Uri.parse('https://nyxapp.lovable.app/api/words/common'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _commonWords = List<String>.from(data['words']);
          _allValidWords = _commonWords; // Use same for validation
          _isLoaded = true;
          return;
        }
      }
    } catch (e) {
      // API not available, use Claude to generate words
    }
    
    // Fallback: Generate words using Claude API
    try {
      final words = await _generateWordsWithClaude();
      if (words != null) {
        _commonWords = words;
        _allValidWords = words; // Use same for validation
        _isLoaded = true;
        return;
      }
    } catch (e) {
      // Claude API failed
    }
    
    // Final fallback: Use hardcoded common words (4-6 letters) - easier for 8th-9th grade level
    _commonWords = [
      'APPLE', 'OCEAN', 'HOUSE', 'WATER', 'LIGHT', 'MUSIC', 
      'WORLD', 'BEACH', 'SMILE', 'HEART', 'DANCE', 'LAUGH', 
      'STORY', 'PIZZA', 'GAMES', 'PHOTO', 'GIFTS', 'HAPPY', 
      'PARTY', 'SLEEP', 'DREAM', 'FUNNY', 'SMART', 'LEARN',
      'TEACH', 'THINK', 'WRITE', 'FRIEND', 'FAMILY', 'HELP',
      'KIND', 'LOVE', 'HOPE', 'PEACE', 'TRUST', 'BRAVE',
      'QUIET', 'QUICK', 'CLEAN', 'FRESH', 'SWEET', 'WARMTH'
    ];
    _allValidWords = _commonWords; // Use same for validation
    _isLoaded = true;
  }

  static Future<List<String>?> _generateWordsWithClaude() async {
    try {
      // Validate API key first
      if (claudeApiKey.isEmpty) {
        LoggingService.logError('❌ Claude API key is empty for word generation');
        return null;
      }

      LoggingService.logInfo('🎯 Generating words with Claude API');

      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 4000,
          'system': 'You are a word list generator. Provide exactly 1000 common English words that are 4-6 letters long, suitable for 8th-9th grade reading level. Use simple, everyday words that are familiar to teenagers. Return only the words in uppercase, one per line, no numbers or extra text.',
          'messages': [
            {
              'role': 'user',
              'content': 'Generate 1000 simple, common English words for word games, 4-6 letters each, at 8th-9th grade reading level.',
            }
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust JSON structure validation
        if (data is Map<String, dynamic> && 
            data['content'] is List && 
            (data['content'] as List).isNotEmpty &&
            data['content'][0] is Map<String, dynamic> &&
            data['content'][0]['text'] is String) {
          final wordsText = data['content'][0]['text'] as String;
          final words = wordsText.split('\n')
              .map((w) => w.trim().toUpperCase())
              .where((w) => w.isNotEmpty && w.length >= 4 && w.length <= 6)
              .toList();
          
          if (words.length >= 20) {  // Minimum viable word count
            return words;
          }
        } else {
          LoggingService.logError('Invalid JSON structure in word generation: ${data.toString()}');
        }
      } else {
        LoggingService.logError('Word generation API error: ${response.body}');
      }
      return null;
    } catch (e) {
      LoggingService.logError('Word generation exception: $e');
      return null;
    }
  }

  static Future<List<String>> getWordsForGame(String gameType, {int count = 20}) async {
    // Special handling for unscramble game
    if (gameType == 'unscramble') {
      return await getUnscrambleWords(count: count);
    }
    
    await _loadCommonWords();
    
    final random = Random();
    final words = <String>[];
    
    // Mix: 40% mental health words, 60% general words
    final mentalHealthCount = (count * 0.4).round();
    final generalCount = count - mentalHealthCount;
    
    // Add mental health words
    final shuffledMentalHealth = List<String>.from(_mentalHealthWords)..shuffle(random);
    words.addAll(shuffledMentalHealth.take(mentalHealthCount));
    
    // Add general words
    final shuffledGeneral = List<String>.from(_commonWords)..shuffle(random);
    words.addAll(shuffledGeneral.take(generalCount));
    
    // Shuffle the final mix
    words.shuffle(random);
    
    return words;
  }

  static Future<List<String>> getUnscrambleWords({int count = 20}) async {
    final random = Random();
    final words = <String>[];
    
    // Try to load from common_words.txt first
    try {
      final String content = await rootBundle.loadString('assets/common_words.txt');
      final commonWordsFromFile = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= 4 && word.length <= 6) // Updated to 4-6 letters
          .toList();
      
      if (commonWordsFromFile.length >= count) {
        commonWordsFromFile.shuffle(random);
        words.addAll(commonWordsFromFile.take(count));
        LoggingService.logInfo('✅ Generated ${words.length} unscramble words from common_words.txt (4-6 letters)');
        return words;
      }
    } catch (e) {
      LoggingService.logError('❌ Failed to load common_words.txt for unscramble: $e');
    }
    
    // Fallback: Use existing method with updated letter count
    await _loadCommonWords();
    
    // 50% mental health/psychological words, 50% general/interesting words
    final mentalHealthCount = (count * 0.5).round();
    final generalCount = count - mentalHealthCount;
    
    // Try to get additional words from Claude API for better variety
    List<String> claudeMentalWords = [];
    List<String> claudeGeneralWords = [];
    
    if (claudeApiKey.isNotEmpty) {
      claudeMentalWords = await _generateUnscrambleWords('mental health and psychological wellness', mentalHealthCount) ?? [];
      claudeGeneralWords = await _generateUnscrambleWords('general interesting topics', generalCount) ?? [];
    }
    
    // Combine Claude words with existing lists
    final allMentalHealthWords = [..._mentalHealthWords, ...claudeMentalWords];
    final allGeneralWords = [..._commonWords, ...claudeGeneralWords];
    
    // Filter to 4-6 letters for optimal gameplay
    final mentalHealthFiltered = allMentalHealthWords
        .where((word) => word.length >= 4 && word.length <= 6)
        .toList();
    final generalFiltered = allGeneralWords
        .where((word) => word.length >= 4 && word.length <= 6)
        .toList();
    
    // Add mental health words
    final shuffledMentalHealth = List<String>.from(mentalHealthFiltered)..shuffle(random);
    words.addAll(shuffledMentalHealth.take(mentalHealthCount));
    
    // Add general words
    final shuffledGeneral = List<String>.from(generalFiltered)..shuffle(random);
    words.addAll(shuffledGeneral.take(generalCount));
    
    // Shuffle the final mix
    words.shuffle(random);
    
    LoggingService.logInfo('✅ Generated ${words.length} unscramble words (${mentalHealthCount} mental health, ${generalCount} general) - 4-6 letters');
    return words.take(count).toList();
  }

  static Future<List<String>?> _generateUnscrambleWords(String category, int count) async {
    try {
      if (claudeApiKey.isEmpty) return null;

      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 500,
          'system': 'You are a word generator for unscramble games. Generate exactly $count simple, common English words that are 4-6 letters long, at 8th-9th grade reading level, related to the given category. Use everyday words that teenagers would know. Return only the words in uppercase, one per line, no numbers or extra text.',
          'messages': [
            {
              'role': 'user',
              'content': 'Generate $count simple words (4-6 letters each) at 8th-9th grade level related to: $category',
            }
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && 
            data['content'] is List && 
            (data['content'] as List).isNotEmpty &&
            data['content'][0] is Map<String, dynamic> &&
            data['content'][0]['text'] is String) {
          final wordsText = data['content'][0]['text'] as String;
          final words = wordsText.split('\n')
              .map((w) => w.trim().toUpperCase())
              .where((w) => w.isNotEmpty && w.length >= 4 && w.length <= 6)
              .toList();
          
          LoggingService.logInfo('✅ Generated ${words.length} $category words via Claude');
          return words;
        }
      }
      return null;
    } catch (e) {
      LoggingService.logError('❌ Failed to generate $category words: $e');
      return null;
    }
  }

  static Future<String> getRandomWord() async {
    final words = await getWordsForGame('general', count: 1);
    return words.first;
  }

  static Future<List<String>> getPrefixWords(String prefix) async {
    await _loadCommonWords();
    
    // Use words_alpha.txt for validation (all valid words)
    final prefixWords = _allValidWords
        .where((word) => word.startsWith(prefix.toUpperCase()))
        .toList();
    
    // If we don't have enough prefix words from words_alpha.txt, use Claude API fallback
    if (prefixWords.length < 5) {
      try {
        final claudeWords = await _generatePrefixWordsWithClaude(prefix);
        if (claudeWords != null) {
          prefixWords.addAll(claudeWords);
        }
      } catch (e) {
        // Claude API failed, use what we have
      }
    }
    
    return prefixWords.take(20).toList(); // Return more valid words
  }

  // Method to validate if a word is valid (for prefix game)
  static Future<bool> isValidWord(String word) async {
    await _loadCommonWords();
    
    final upperWord = word.toUpperCase();
    
    // First check words_alpha.txt
    if (_allValidWords.contains(upperWord)) {
      return true;
    }
    
    // Fallback: Use Claude API for validation
    return await _validateWordWithClaude(upperWord);
  }

  static Future<bool> _validateWordWithClaude(String word) async {
    try {
      if (claudeApiKey.isEmpty) return false;

      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 50,
          'system': 'You are a word validator. Answer only "YES" if the word is a valid English word, or "NO" if it is not. No explanations.',
          'messages': [
            {
              'role': 'user',
              'content': 'Is "$word" a valid English word?',
            }
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && 
            data['content'] is List && 
            (data['content'] as List).isNotEmpty &&
            data['content'][0] is Map<String, dynamic> &&
            data['content'][0]['text'] is String) {
          final responseText = (data['content'][0]['text'] as String).trim().toUpperCase();
          return responseText.contains('YES');
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Generate prefixes from common_words.txt file (so they're not too hard)
  static Future<List<String>> getCommonPrefixes() async {
    try {
      // Load from common_words.txt file specifically
      final String content = await rootBundle.loadString('assets/common_words.txt');
      final commonWordsFromFile = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= 3)
          .toList();
      
      final prefixes = <String>{};
      
      // Extract 3-letter prefixes from common words file
      for (final word in commonWordsFromFile) {
        if (word.length >= 3) {
          prefixes.add(word.substring(0, 3));
        }
      }
      
      final prefixList = prefixes.toList()..shuffle();
      LoggingService.logInfo('✅ Generated ${prefixList.length} prefixes from common_words.txt');
      return prefixList;
    } catch (e) {
      LoggingService.logError('❌ Failed to load common_words.txt: $e');
      
      // Fallback to existing method
      await _loadCommonWords();
      
      final prefixes = <String>{};
      
      // Extract 3-letter prefixes from common words and mental health words
      final sourceWords = [..._mentalHealthWords, ..._commonWords];
      
      for (final word in sourceWords) {
        if (word.length >= 3) {
          prefixes.add(word.substring(0, 3));
        }
      }
      
      return prefixes.toList()..shuffle();
    }
  }

  static Future<List<String>?> _generatePrefixWordsWithClaude(String prefix) async {
    try {
      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 500,
          'system': 'You are a word generator. Provide exactly 10 common English words that start with the given prefix. Return only the words in uppercase, one per line, no numbers or extra text.',
          'messages': [
            {
              'role': 'user',
              'content': 'Generate 10 common English words that start with "$prefix"',
            }
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust JSON structure validation
        if (data is Map<String, dynamic> && 
            data['content'] is List && 
            (data['content'] as List).isNotEmpty &&
            data['content'][0] is Map<String, dynamic> &&
            data['content'][0]['text'] is String) {
          final wordsText = data['content'][0]['text'] as String;
          final words = wordsText.split('\n')
              .map((w) => w.trim().toUpperCase())
              .where((w) => w.isNotEmpty && w.startsWith(prefix.toUpperCase()))
              .toList();
          
          return words;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> getWordHuntWords({required int count, required int minLength, required int maxLength}) async {
    try {
      // Load directly from common_words.txt file
      final String content = await rootBundle.loadString('assets/common_words.txt');
      final commonWordsFromFile = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= minLength && word.length <= maxLength)
          .toList();
      
      final random = Random();
      commonWordsFromFile.shuffle(random);
      
      LoggingService.logInfo('✅ Generated ${count} Word Hunt words from common_words.txt');
      return commonWordsFromFile.take(count).toList();
    } catch (e) {
      LoggingService.logError('❌ Failed to load common_words.txt for Word Hunt: $e');
      
      // Fallback to existing method
      await _loadCommonWords();
      
      final allWords = [..._mentalHealthWords, ..._commonWords];
      final suitableWords = allWords
          .where((word) => word.length >= minLength && word.length <= maxLength)
          .toList();
      
      final random = Random();
      suitableWords.shuffle(random);
      
      return suitableWords.take(count).toList();
    }
  }
}