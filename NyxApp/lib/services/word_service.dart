import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../services/logging_service.dart';
import '../services/api_service.dart';

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
  
  // Word history tracking to avoid repeats
  static Map<String, List<String>> _usedWords = {
    'unscramble': [],
    'wordhunt': [],
    'prefixgame': [],
    'general': [],
  };
  static const int _maxHistorySize = 100; // Track last 100 words used per game

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
    
    // Fallback: Try backend API
    try {
      final response = await APIService.get('/words/common');
      if (response['success'] == true) {
        _commonWords = List<String>.from(response['data']['words']);
        _allValidWords = _commonWords; // Use same for validation
        _isLoaded = true;
        return;
      }
    } catch (e) {
      // API not available
    }
    
    // Fallback: Generate words using backend API
    try {
      final response = await APIService.post('/words/generate', {
        'count': 1000,
        'minLength': 4,
        'maxLength': 6,
      });
      if (response['success'] == true) {
        final words = List<String>.from(response['data']['words']);
        _commonWords = words;
        _allValidWords = words; // Use same for validation
        _isLoaded = true;
        return;
      }
    } catch (e) {
      // Backend API failed
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


  static Future<List<String>> getWordsForGame(String gameType, {int count = 20}) async {
    // Special handling for unscramble game
    if (gameType == 'unscramble') {
      return await getUnscrambleWords(count: count);
    }
    
    await _loadCommonWords();
    
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    
    // Combine all words
    final allWords = [..._mentalHealthWords, ..._commonWords];
    
    // Filter out recently used words
    final availableWords = _filterUsedWords(gameType, allWords);
    
    // Shuffle and select words
    availableWords.shuffle(random);
    final selectedWords = availableWords.take(count).toList();
    
    // Add selected words to history
    for (final word in selectedWords) {
      _addToHistory(gameType, word);
    }
    
    LoggingService.logInfo('✅ Generated ${selectedWords.length} words for $gameType (${availableWords.length} available)');
    return selectedWords;
  }

  // Helper method to manage word history
  static void _addToHistory(String gameType, String word) {
    if (!_usedWords.containsKey(gameType)) {
      _usedWords[gameType] = [];
    }
    
    _usedWords[gameType]!.add(word);
    
    // Keep only the last _maxHistorySize words
    if (_usedWords[gameType]!.length > _maxHistorySize) {
      _usedWords[gameType]!.removeAt(0);
    }
  }
  
  // Helper method to filter out recently used words
  static List<String> _filterUsedWords(String gameType, List<String> words) {
    if (!_usedWords.containsKey(gameType)) {
      return words;
    }
    
    final usedWordsSet = Set<String>.from(_usedWords[gameType]!);
    final availableWords = words.where((word) => !usedWordsSet.contains(word)).toList();
    
    // If we filtered out too many words, reset history and use original list
    if (availableWords.length < words.length * 0.3) {
      _usedWords[gameType]!.clear();
      LoggingService.logInfo('⚠️ Reset word history for $gameType - too many words filtered');
      return words;
    }
    
    return availableWords;
  }

  static Future<List<String>> getUnscrambleWords({int count = 20}) async {
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final words = <String>[];
    
    // Try to load from common_words.txt first
    try {
      final String content = await rootBundle.loadString('assets/common_words.txt');
      final allWordsFromFile = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= 4 && word.length <= 6)
          .toList();
      
      if (allWordsFromFile.length >= count) {
        // Filter out recently used words
        final availableWords = _filterUsedWords('unscramble', allWordsFromFile);
        
        // Shuffle and select words
        availableWords.shuffle(random);
        final selectedWords = availableWords.take(count).toList();
        
        // Add selected words to history
        for (final word in selectedWords) {
          _addToHistory('unscramble', word);
        }
        
        words.addAll(selectedWords);
        LoggingService.logInfo('✅ Generated ${words.length} unscramble words from common_words.txt (4-6 letters, ${availableWords.length} available)');
        return words;
      }
    } catch (e) {
      LoggingService.logError('❌ Failed to load common_words.txt for unscramble: $e');
    }
    
    // Fallback: Use existing method with updated letter count and history tracking
    await _loadCommonWords();
    
    // Combine all available words and filter to 4-6 letters
    final allWords = [..._mentalHealthWords, ..._commonWords];
    final filteredWords = allWords
        .where((word) => word.length >= 4 && word.length <= 6)
        .toList();
    
    // Filter out recently used words
    final availableWords = _filterUsedWords('unscramble', filteredWords);
    
    // Shuffle and select words
    availableWords.shuffle(random);
    final selectedWords = availableWords.take(count).toList();
    
    // Add selected words to history
    for (final word in selectedWords) {
      _addToHistory('unscramble', word);
    }
    
    words.addAll(selectedWords);
    LoggingService.logInfo('✅ Generated ${words.length} unscramble words (fallback mode, ${availableWords.length} available) - 4-6 letters');
    return words;
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
    
    // If we don't have enough prefix words from words_alpha.txt, use backend API fallback
    if (prefixWords.length < 5) {
      try {
        final response = await APIService.post('/words/generate-prefix', {
          'prefix': prefix,
          'count': 10,
        });
        if (response['success'] == true) {
          final words = List<String>.from(response['data']['words']);
          prefixWords.addAll(words);
        }
      } catch (e) {
        // Backend API failed, use what we have
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
    
    // Fallback: Use backend API for validation
    return await _validateWordWithBackend(upperWord);
  }

  static Future<bool> _validateWordWithBackend(String word) async {
    try {
      final response = await APIService.post('/words/validate', {
        'word': word,
      });
      if (response['success'] == true) {
        return response['data']['isValid'] ?? false;
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


  static Future<List<String>> getWordHuntWords({required int count, required int minLength, required int maxLength}) async {
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    
    try {
      // Load directly from common_words.txt file
      final String content = await rootBundle.loadString('assets/common_words.txt');
      final allWordsFromFile = content.split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.isNotEmpty && word.length >= minLength && word.length <= maxLength)
          .toList();
      
      // Filter out recently used words
      final availableWords = _filterUsedWords('wordhunt', allWordsFromFile);
      
      // Shuffle and select words
      availableWords.shuffle(random);
      final selectedWords = availableWords.take(count).toList();
      
      // Add selected words to history
      for (final word in selectedWords) {
        _addToHistory('wordhunt', word);
      }
      
      LoggingService.logInfo('✅ Generated ${selectedWords.length} Word Hunt words from common_words.txt (${availableWords.length} available)');
      return selectedWords;
    } catch (e) {
      LoggingService.logError('❌ Failed to load common_words.txt for Word Hunt: $e');
      
      // Fallback to existing method with history tracking
      await _loadCommonWords();
      
      final allWords = [..._mentalHealthWords, ..._commonWords];
      final filteredWords = allWords
          .where((word) => word.length >= minLength && word.length <= maxLength)
          .toList();
      
      // Filter out recently used words
      final availableWords = _filterUsedWords('wordhunt', filteredWords);
      
      // Shuffle and select words
      availableWords.shuffle(random);
      final selectedWords = availableWords.take(count).toList();
      
      // Add selected words to history
      for (final word in selectedWords) {
        _addToHistory('wordhunt', word);
      }
      
      LoggingService.logInfo('✅ Generated ${selectedWords.length} Word Hunt words (fallback mode, ${availableWords.length} available)');
      return selectedWords;
    }
  }
}