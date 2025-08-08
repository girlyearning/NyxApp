import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/word_service.dart';
import '../services/api_service.dart';
import 'dart:math';

// Common Game Widget Base
abstract class BaseGameWidget extends StatefulWidget {
  const BaseGameWidget({super.key});
}

abstract class BaseGameState<T extends BaseGameWidget> extends State<T> {
  final TextEditingController answerController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode focusNode = FocusNode();
  
  int score = 0;
  String message = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    setupKeyboardScrolling();
  }

  void setupKeyboardScrolling() {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (scrollController.hasClients && mounted) {
            // For Unscramble: Scroll to show "Check Answer" button above keyboard
            // Calculate scroll position to show the main action button properly
            final targetOffset = scrollController.position.maxScrollExtent * 0.6; // Scroll to 60% to show Check Answer button
            
            scrollController.animateTo(
              targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    answerController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Widget buildScoreContainer(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Score: $score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          buildExtraScoreInfo(context),
        ],
      ),
    );
  }

  Widget buildExtraScoreInfo(BuildContext context) => const SizedBox.shrink();

  Widget buildGameTextField(BuildContext context, String labelText) {
    return TextField(
      controller: answerController,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          onPressed: onSubmitAnswer,
        ),
        enabled: isGameActive(),
      ),
      textCapitalization: TextCapitalization.characters,
      onSubmitted: (_) => onSubmitAnswer(),
    );
  }

  Widget buildPrimaryButton(BuildContext context, String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? Colors.grey : Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildMessageContainer(BuildContext context, bool isCorrect) {
    if (message.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withValues(alpha: 0.1) 
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect 
              ? Colors.green 
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isCorrect 
              ? Colors.green[700] 
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget buildScrollableGameContainer(BuildContext context, List<Widget> children) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return SingleChildScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: bottomPadding > 0 ? bottomPadding + 80.0 : 16.0, // Optimized padding for keyboard
      ),
      child: Column(
        children: [
          ...children,
          SizedBox(height: bottomPadding > 0 ? 120 : 50), // Optimized space at bottom
        ],
      ),
    );
  }

  // Abstract methods that games must implement
  void onSubmitAnswer();
  bool isGameActive();
}

// Unscramble Game Implementation
class UnscrambleGameWidget extends BaseGameWidget {
  const UnscrambleGameWidget({super.key});

  @override
  State<UnscrambleGameWidget> createState() => _UnscrambleGameWidgetState();
}

class _UnscrambleGameWidgetState extends BaseGameState<UnscrambleGameWidget> {
  List<String> _gameWords = [];
  
  String _currentWord = '';
  String _scrambledWord = '';
  int _streak = 0;
  bool _isCorrect = false;
  bool _hintShown = false;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _loadWordsAndStart();
  }

  @override
  void onSubmitAnswer() => _checkAnswer();
  
  @override
  bool isGameActive() => !_isRevealed;
  
  @override
  Widget buildExtraScoreInfo(BuildContext context) {
    return Text(
      'Streak: $_streak',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Future<void> _loadWordsAndStart() async {
    setState(() {
      isLoading = false;
    });
    _generateNewWord();
  }

  void _generateNewWord() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Call backend API to generate unscramble word
      final response = await APIService.post('/games/unscramble/generate', {
        'user_id': 'flutter_user',
      });

      if (response['success'] == true) {
        final data = response['data'];
        _currentWord = data['current_word'];
        _scrambledWord = data['scrambled_word'];
      } else {
        // Fallback to local generation
        await _generateWordLocally();
      }
    } catch (e) {
      // Fallback to local generation if API fails
      await _generateWordLocally();
    }

    answerController.clear();
    _isCorrect = false;
    message = '';
    _hintShown = false;
    _isRevealed = false;
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _generateWordLocally() async {
    // Fallback local generation
    if (_gameWords.isEmpty) {
      _gameWords = await WordService.getWordsForGame('unscramble', count: 50);
    }
    
    if (_gameWords.isEmpty) return;
    
    final random = Random();
    _currentWord = _gameWords[random.nextInt(_gameWords.length)];
    _scrambledWord = _scrambleWord(_currentWord);
  }

  String _scrambleWord(String word) {
    final letters = word.split('');
    do {
      letters.shuffle();
    } while (letters.join('') == word && word.length > 3); // Ensure it's actually scrambled
    return letters.join('');
  }

  void _showHint() {
    if (_currentWord.isEmpty) return;
    
    _hintShown = true;
    
    // Show first and last letter as hint
    final firstLetter = _currentWord[0];
    final lastLetter = _currentWord[_currentWord.length - 1];
    message = 'Hint: The word starts with "$firstLetter" and ends with "$lastLetter"';
    
    setState(() {});
  }

  void _checkAnswer() async {
    if (_isRevealed) return; // Don't allow checking if word was revealed
    
    final answer = answerController.text.trim().toUpperCase();
    
    try {
      // Use backend API for validation
      final response = await APIService.post('/games/unscramble/validate', {
        'user_id': 'flutter_user',
        'answer': answer,
        'current_word': _currentWord,
      });

      if (response['success'] == true) {
        final data = response['data'];
        
        if (data['isValid'] == true) {
          _isCorrect = true;
          _streak++;
          final points = (data['points'] ?? 10) as int;
          score = score + points;
          message = data['message'] ?? 'Correct! +$points Nyx Notes';
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.addNyxNotes(points);
          
          setState(() {});
          
          Future.delayed(const Duration(seconds: 2), () {
            _generateNewWord();
          });
        } else {
          _streak = 0;
          message = data['message'] ?? 'Try again! The word starts with "${_currentWord[0]}"';
          setState(() {});
        }
      } else {
        // Fallback to local validation
        _checkAnswerLocally(answer);
      }
    } catch (e) {
      // Fallback to local validation if API fails
      _checkAnswerLocally(answer);
    }
    
    answerController.clear();
  }

  void _checkAnswerLocally(String answer) async {
    // Original local validation logic
    if (answer == _currentWord) {
      _isCorrect = true;
      _streak++;
      final points = 10;  // Fixed 10 points per word
      score += points;
      message = 'Correct! +$points Nyx Notes';
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.addNyxNotes(points);
      
      setState(() {});
      
      Future.delayed(const Duration(seconds: 2), () {
        _generateNewWord();
      });
    } else {
      _streak = 0;
      message = 'Try again! The word starts with "${_currentWord[0]}"';
      setState(() {});
    }
  }
  
  void _revealWord() {
    if (_isRevealed || _isCorrect) return;
    
    _isRevealed = true;
    _streak = 0; // Reset streak when revealing
    message = 'The word was: $_currentWord';
    answerController.text = _currentWord;
    
    setState(() {});
    
    // Automatically move to next word after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _generateNewWord();
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildScrollableGameContainer(context, [
      buildScoreContainer(context),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 2,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Unscramble this word:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _scrambledWord,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          buildGameTextField(context, 'Your answer'),
          
          const SizedBox(height: 16),
          
          buildPrimaryButton(
            context, 
            _isRevealed ? 'Word Revealed' : 'Check Answer', 
            _isRevealed ? null : _checkAnswer
          ),
          
          const SizedBox(height: 16),
          
          buildMessageContainer(context, _isCorrect),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: _hintShown ? null : _showHint,
                child: Text(
                  'Get Hint',
                  style: TextStyle(
                    color: _hintShown ? Colors.grey : Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: (_isCorrect || _isRevealed) ? null : _revealWord,
                child: Text(
                  'Reveal Word',
                  style: TextStyle(
                    color: (_isCorrect || _isRevealed) ? Colors.grey : Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _generateNewWord,
                child: Text(
                  'Next Word',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ]);
  }

  // Note: dispose method is now handled by BaseGameState
}

// Prefix Game Implementation
class PrefixGameWidget extends BaseGameWidget {
  const PrefixGameWidget({super.key});

  @override
  State<PrefixGameWidget> createState() => _PrefixGameWidgetState();
}

class _PrefixGameWidgetState extends BaseGameState<PrefixGameWidget> {
  List<String> _availablePrefixes = [];
  
  String _currentPrefix = '';
  List<String> _foundWords = [];
  List<String> _validWords = [];
  int _timeLeft = 60;
  bool _gameActive = false;

  @override
  void initState() {
    super.initState();
    _setupPrefixGameScrolling();
    _loadPrefixAndStart();
  }
  
  void _setupPrefixGameScrolling() {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (scrollController.hasClients && mounted) {
            // For PrefixGame: Scroll to show "Submit Word" and "End Round" buttons above keyboard
            final maxScroll = scrollController.position.maxScrollExtent;
            final targetScroll = maxScroll * 0.75; // Scroll to 75% to show action buttons
            
            scrollController.animateTo(
              targetScroll.clamp(0.0, maxScroll),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  Future<void> _loadPrefixAndStart() async {
    await _startNewRound();
  }

  Future<void> _startNewRound() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Call backend API to generate prefix challenge
      final response = await APIService.post('/games/prefixgame/generate', {
        'user_id': 'flutter_user',
      });

      if (response['success'] == true) {
        final data = response['data'];
        _currentPrefix = data['current_prefix'];
        _validWords = List<String>.from(data['valid_words'] ?? []);
      } else {
        // Fallback to local generation
        await _generatePrefixLocally();
      }
    } catch (e) {
      // Fallback to local generation if API fails
      await _generatePrefixLocally();
    }

    _foundWords.clear();
    answerController.clear();
    message = '';
    _timeLeft = 60;
    _gameActive = true;
    isLoading = false;
    
    setState(() {});
    _startTimer();
  }

  Future<void> _generatePrefixLocally() async {
    // Fallback local generation
    if (_availablePrefixes.isEmpty) {
      _availablePrefixes = await WordService.getCommonPrefixes();
    }
    
    final random = Random();
    _currentPrefix = _availablePrefixes[random.nextInt(_availablePrefixes.length)];
    
    // Get valid words for this prefix using WordService (from words_alpha.txt)
    _validWords = await WordService.getPrefixWords(_currentPrefix);
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_gameActive && _timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
        _startTimer();
      } else if (_timeLeft <= 0) {
        _endGame();
      }
    });
  }

  void _endGame() {
    _gameActive = false;
    message = 'Time\'s up! You found ${_foundWords.length}/${_validWords.length} words.';
    setState(() {});
  }

  void _endRoundEarly() async {
    _gameActive = false;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Keep points only if at least one word was found
    if (_foundWords.isNotEmpty) {
      message = 'Round ended! You keep your $score Nyx Notes. Found ${_foundWords.length}/${_validWords.length} words.';
    } else {
      // No points earned, so no points to keep
      message = 'Round ended! No points earned this round. Found ${_foundWords.length}/${_validWords.length} words.';
    }
    
    setState(() {});
  }

  void _checkAnswer() async {
    final answer = answerController.text.trim().toUpperCase();
    
    if (answer.isEmpty) return;
    
    try {
      // Use backend API for validation
      final response = await APIService.post('/games/prefixgame/validate', {
        'user_id': 'flutter_user',
        'answer': answer,
        'current_prefix': _currentPrefix,
        'found_words': _foundWords,
      });

      if (response['success'] == true) {
        final data = response['data'];
        
        if (data['isValid'] == true) {
          _foundWords.add(answer);
          final points = (data['points'] ?? 10) as int;
          score = score + points;
          message = data['message'] ?? 'Correct! "$answer" +$points Nyx Notes';
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.addNyxNotes(points);
        } else {
          message = data['message'] ?? 'Not a valid word';
        }
      } else {
        // Fallback to local validation
        await _checkAnswerLocally(answer);
      }
    } catch (e) {
      // Fallback to local validation if API fails
      await _checkAnswerLocally(answer);
    }
    
    answerController.clear();
    setState(() {});
  }

  Future<void> _checkAnswerLocally(String answer) async {
    // Original local validation logic
    if (_foundWords.contains(answer)) {
      message = 'You already found that word!';
    } else if (!answer.startsWith(_currentPrefix)) {
      message = 'Word must start with "$_currentPrefix"';
    } else {
      // Use proper validation: words_alpha.txt first, then Claude API
      final isValid = await WordService.isValidWord(answer);
      
      if (isValid) {
        _foundWords.add(answer);
        final points = 10;  // Fixed 10 points per word
        score += points;
        message = 'Correct! "$answer" +$points Nyx Notes';
        
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.addNyxNotes(points);
      } else {
        message = 'Not a valid English word';
      }
    }
  }

  @override
  void dispose() {
    // No _wordInputController in PrefixGame
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading prefix words...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 
            ? MediaQuery.of(context).viewInsets.bottom + 80.0 
            : 16.0,
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Time: $_timeLeft',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _timeLeft <= 10 ? Colors.red : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Found: ${_foundWords.length}/${_validWords.length} words',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Find words starting with:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentPrefix,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (_gameActive) ...[
            TextField(
              controller: answerController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Enter a word starting with $_currentPrefix',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _checkAnswer,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _checkAnswer(),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Word',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _endRoundEarly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'End Round',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startNewRound(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start New Round',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          const SizedBox(height: 16),
          
          if (_foundWords.isNotEmpty) ...[
            Text(
              'Found Words:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foundWords.map((word) => Chip(
                label: Text(word),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: BorderSide(color: Colors.green),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void onSubmitAnswer() => _checkAnswer();
  
  @override
  bool isGameActive() => _gameActive;
}

// Word Hunt Game Implementation
class WordHuntGameWidget extends BaseGameWidget {
  const WordHuntGameWidget({super.key});

  @override
  State<WordHuntGameWidget> createState() => _WordHuntGameWidgetState();
}

class _WordHuntGameWidgetState extends BaseGameState<WordHuntGameWidget> {
  // Game configuration
  bool _isEasyMode = true;
  int _gridSize = 6;
  List<List<String>> _grid = [];
  List<String> _hiddenWords = [];
  List<String> _foundWords = [];
  Set<List<int>> _selectedCells = {};
  Set<List<int>> _correctCells = {};
  bool _showWordList = false;
  
  // Swipe functionality
  bool _isDragging = false;
  List<List<int>> _currentSwipePath = [];
  
  // Word placement tracking
  Map<String, List<List<int>>> _wordPositions = {};
  Map<String, String> _placedWords = {}; // Maps original word to word as placed in grid
  
  // Hint system
  int _hintsUsed = 0;
  int _maxHints = 2;
  List<String> _hintedWords = [];
  
  // Word input controller for manual entry
  final TextEditingController _wordInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await _generateNewPuzzle();
  }

  Future<void> _generateNewPuzzle() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Call backend API to generate Word Hunt puzzle
      final difficulty = _isEasyMode ? 'easy' : 'hard';
      final response = await APIService.post('/games/wordhunt/generate', {
        'difficulty': difficulty,
        'user_id': 'flutter_user',
      });

      if (response['success'] == true) {
        final data = response['data'];
        
        // Update game state with backend data
        _gridSize = data['grid_size'];
        _grid = List<List<String>>.from(
          data['grid'].map((row) => List<String>.from(row))
        );
        _hiddenWords = List<String>.from(data['target_words']);
        
        // Parse word positions and placed words
        _wordPositions.clear();
        _placedWords.clear();
        
        if (data['word_positions'] != null) {
          data['word_positions'].forEach((word, positions) {
            _wordPositions[word] = List<List<int>>.from(
              positions.map((pos) => List<int>.from(pos))
            );
          });
        }
        
        if (data['placed_words'] != null) {
          data['placed_words'].forEach((word, placedWord) {
            _placedWords[word] = placedWord;
          });
        }
        
        // Reset game state
        _foundWords.clear();
        _selectedCells.clear();
        _correctCells.clear();
        score = 0;
        _showWordList = false;
        _hintsUsed = 0;
        _hintedWords.clear();
        message = data['message'] ?? (_isEasyMode ? 'Easy Mode: Find 4 words (4-6 letters)' : 'Hard Mode: Find 4 words (5-9 letters)');
      } else {
        // Fallback to local generation if API fails
        await _generatePuzzleLocally();
      }
    } catch (e) {
      // Fallback to local generation if API fails
      await _generatePuzzleLocally();
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _generatePuzzleLocally() async {
    // Fallback local generation (original logic)
    _gridSize = _isEasyMode ? 6 : 10;
    _grid = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => ''));
    _hiddenWords.clear();
    _foundWords.clear();
    _selectedCells.clear();
    _correctCells.clear();
    _wordPositions.clear();
    _placedWords.clear();
    score = 0;
    _showWordList = false;
    _hintsUsed = 0;
    _hintedWords.clear();
    message = _isEasyMode ? 'Easy Mode: Find 4 words (4-6 letters)' : 'Hard Mode: Find 4 words (5-9 letters)';
    
    // Get words based on difficulty
    final minLength = _isEasyMode ? 4 : 5;
    final maxLength = _isEasyMode ? 6 : 9;
    final words = await WordService.getWordHuntWords(
      count: 4,
      minLength: minLength,
      maxLength: maxLength,
    );
    
    _hiddenWords = words;
    
    // Place words in grid with various orientations
    final random = Random();
    for (final word in _hiddenWords) {
      bool placed = false;
      int attempts = 0;
      
      while (!placed && attempts < 100) {
        attempts++;
        // Random direction: 0=horizontal, 1=vertical, 2=diagonal-down, 3=diagonal-up
        final direction = random.nextInt(4);
        // Random if backwards
        final backwards = random.nextBool();
        
        placed = _tryPlaceWord(word, direction, backwards);
      }
    }
    
    // Fill empty cells with random letters
    for (int i = 0; i < _gridSize; i++) {
      for (int j = 0; j < _gridSize; j++) {
        if (_grid[i][j].isEmpty) {
          _grid[i][j] = String.fromCharCode(65 + random.nextInt(26));
        }
      }
    }
  }

  bool _tryPlaceWord(String word, int direction, bool backwards) {
    final random = Random();
    final wordToPlace = backwards ? word.split('').reversed.join('') : word;
    
    // Calculate valid starting positions based on direction and word length
    int maxRow = _gridSize;
    int maxCol = _gridSize;
    
    switch (direction) {
      case 0: // Horizontal
        maxCol = _gridSize - word.length + 1;
        break;
      case 1: // Vertical
        maxRow = _gridSize - word.length + 1;
        break;
      case 2: // Diagonal down-right
        maxRow = _gridSize - word.length + 1;
        maxCol = _gridSize - word.length + 1;
        break;
      case 3: // Diagonal down-left
        maxRow = _gridSize - word.length + 1;
        maxCol = word.length - 1;
        break;
    }
    
    if (maxRow <= 0 || maxCol < 0) return false;
    
    final startRow = random.nextInt(maxRow);
    final startCol = direction == 3 
        ? word.length - 1 + random.nextInt(_gridSize - word.length + 1)
        : random.nextInt(maxCol);
    
    // Check if word can be placed without conflicts
    List<List<int>> positions = [];
    for (int i = 0; i < word.length; i++) {
      int row = startRow;
      int col = startCol;
      
      switch (direction) {
        case 0: // Horizontal
          col = startCol + i;
          break;
        case 1: // Vertical
          row = startRow + i;
          break;
        case 2: // Diagonal down-right
          row = startRow + i;
          col = startCol + i;
          break;
        case 3: // Diagonal down-left
          row = startRow + i;
          col = startCol - i;
          break;
      }
      
      // Check bounds
      if (row >= _gridSize || col >= _gridSize || col < 0) return false;
      
      // Check for conflicts (allow overlapping if same letter)
      if (_grid[row][col].isNotEmpty && _grid[row][col] != wordToPlace[i]) {
        return false;
      }
      
      positions.add([row, col]);
    }
    
    // Place the word
    for (int i = 0; i < word.length; i++) {
      _grid[positions[i][0]][positions[i][1]] = wordToPlace[i];
    }
    
    // Store word positions for checking later
    _wordPositions[word] = positions;
    _placedWords[word] = wordToPlace; // Store how the word actually appears in grid
    
    return true;
  }

  void _checkWordFromText(String input) async {
    final word = input.trim().toUpperCase();
    
    if (_foundWords.contains(word)) {
      message = 'Already found "$word"!';
      setState(() {});
      return;
    }
    
    try {
      // Use backend API for validation
      final response = await APIService.post('/games/wordhunt/validate', {
        'user_id': 'flutter_user',
        'word': word,
        'target_words': _hiddenWords,
        'placed_words': _placedWords,
      });

      if (response['success'] == true) {
        final data = response['data'];
        
        if (data['isValid'] == true) {
          final matchedWord = data['matched_word'];
          _foundWords.add(matchedWord);
          final points = 10;  // Fixed 10 points per word
          score = score + points.toInt();
          message = data['message'] ?? 'Found "$matchedWord"! +$points Nyx Notes';
          
          // Highlight the word in the grid
          if (_wordPositions.containsKey(matchedWord)) {
            _correctCells.addAll(_wordPositions[matchedWord]!);
          }
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.addNyxNotes(points);
          
          if (_foundWords.length == _hiddenWords.length) {
            message = 'Puzzle complete! Bonus +50 Nyx Notes!';
            await userProvider.addNyxNotes(50);
          }
        } else {
          message = data['message'] ?? '"$word" is not a hidden word';
        }
      } else {
        // Fallback to local validation
        await _checkWordLocalFallback(word);
      }
    } catch (e) {
      // Fallback to local validation if API fails
      await _checkWordLocalFallback(word);
    }
    
    setState(() {});
  }

  Future<void> _checkWordLocalFallback(String word) async {
    // Original local validation logic
    String? matchedOriginalWord;
    if (_hiddenWords.contains(word)) {
      matchedOriginalWord = word;
    } else {
      // Check if input matches any placed word (could be reversed)
      for (final originalWord in _hiddenWords) {
        if (_placedWords[originalWord] == word) {
          matchedOriginalWord = originalWord;
          break;
        }
      }
    }
    
    if (matchedOriginalWord != null) {
      _foundWords.add(matchedOriginalWord);
      final points = 10;  // Fixed 10 points per word
      score += points;
      message = 'Found "$matchedOriginalWord"! +$points Nyx Notes';
      
      // Highlight the word in the grid
      if (_wordPositions.containsKey(matchedOriginalWord)) {
        _correctCells.addAll(_wordPositions[matchedOriginalWord]!);
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.addNyxNotes(points);
      
      if (_foundWords.length == _hiddenWords.length) {
        message = 'Puzzle complete! Bonus +50 Nyx Notes!';
        await userProvider.addNyxNotes(50);
      }
    } else {
      message = '"$word" is not a hidden word';
    }
  }

  void _onCellTap(int row, int col) {
    final cell = [row, col];
    
    if (_selectedCells.any((c) => c[0] == row && c[1] == col)) {
      _selectedCells.removeWhere((c) => c[0] == row && c[1] == col);
    } else {
      _selectedCells.add(cell);
    }
    
    // Check if selected cells form a valid word
    _checkSelectedCells();
    
    setState(() {});
  }

  void _onPanStart(DragStartDetails details, int row, int col) {
    setState(() {
      _isDragging = true;
      _currentSwipePath.clear();
      _selectedCells.clear();
      _currentSwipePath.add([row, col]);
      _selectedCells.add([row, col]);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox renderBox) {
    if (!_isDragging) return;
    
    // Convert global position to local position
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final cellSize = _isEasyMode ? 40.0 : 30.0;
    final margin = 2.0;
    final totalCellSize = cellSize + (margin * 2);
    
    // Calculate which cell the user is currently over
    final col = (localPosition.dx / totalCellSize).floor();
    final row = (localPosition.dy / totalCellSize).floor();
    
    // Check bounds
    if (row >= 0 && row < _gridSize && col >= 0 && col < _gridSize) {
      final cell = [row, col];
      
      // Only add if this cell follows a valid swipe pattern
      if (_currentSwipePath.isNotEmpty) {
        final lastCell = _currentSwipePath.last;
        
        // Check if we haven't already added this cell
        if (!_currentSwipePath.any((c) => c[0] == row && c[1] == col)) {
          // Calculate the movement from last cell
          final rowDiff = row - lastCell[0];
          final colDiff = col - lastCell[1];
          final absRowDiff = rowDiff.abs();
          final absColDiff = colDiff.abs();
          
          // Allow adjacent cells (horizontal, vertical, diagonal)
          bool isValidMove = false;
          
          // Horizontal movement (row same, col changes by 1)
          if (absRowDiff == 0 && absColDiff == 1) {
            isValidMove = true;
          }
          // Vertical movement (col same, row changes by 1)
          else if (absRowDiff == 1 && absColDiff == 0) {
            isValidMove = true;
          }
          // Diagonal movement (both change by 1)
          else if (absRowDiff == 1 && absColDiff == 1) {
            isValidMove = true;
          }
          
          // If we have established a direction, maintain it
          if (isValidMove && _currentSwipePath.length >= 2) {
            // Get the established direction from first two cells
            final firstCell = _currentSwipePath[0];
            final secondCell = _currentSwipePath[1];
            final dirRowDiff = secondCell[0] - firstCell[0];
            final dirColDiff = secondCell[1] - firstCell[1];
            
            // Check if new movement maintains the line
            // For straight lines, the direction should be the same
            // For diagonals, allow the same diagonal direction
            bool maintainsDirection = false;
            
            // Check if it's the next cell in the established direction
            final expectedRow = lastCell[0] + dirRowDiff;
            final expectedCol = lastCell[1] + dirColDiff;
            
            if (row == expectedRow && col == expectedCol) {
              maintainsDirection = true;
            }
            
            if (maintainsDirection) {
              setState(() {
                _currentSwipePath.add(cell);
                _selectedCells.add(cell);
              });
            }
          } else if (isValidMove && _currentSwipePath.length == 1) {
            // For the second cell, allow any adjacent move
            setState(() {
              _currentSwipePath.add(cell);
              _selectedCells.add(cell);
            });
          }
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _isDragging = false;
      
      // Check if the swipe path forms a valid word
      _checkSwipePath();
      
      // Clear the swipe path but keep selected cells for visual feedback
      _currentSwipePath.clear();
    });
  }

  void _checkSwipePath() {
    if (_currentSwipePath.length < 2) {
      _selectedCells.clear();
      return;
    }
    
    // Extract the word from the swipe path
    final swipedWord = _currentSwipePath.map((cell) => _grid[cell[0]][cell[1]]).join('');
    
    // Check if this matches any hidden word
    for (final word in _hiddenWords) {
      if (_foundWords.contains(word)) continue;
      
      final placedWord = _placedWords[word] ?? word;
      
      // Check if swiped word matches the placed word or its reverse
      if (swipedWord == placedWord || swipedWord == placedWord.split('').reversed.join('')) {
        // Check if the swipe path matches the word's actual position
        if (_wordPositions.containsKey(word)) {
          final wordPositions = _wordPositions[word]!;
          
          // Check if swipe path matches word positions (in order or reverse order)
          bool pathMatches = false;
          
          if (_currentSwipePath.length == wordPositions.length) {
            // Check if the swipe follows a consistent direction
            pathMatches = _checkSwipeDirection(_currentSwipePath, wordPositions);
          }
          
          if (pathMatches) {
            _foundWords.add(word);
            final points = 10;
            score = score + points.toInt();
            message = 'Found "$word"! +$points Nyx Notes';
            
            // Add to correct cells and clear selection
            _correctCells.addAll(wordPositions);
            _selectedCells.clear();
            
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            userProvider.addNyxNotes(points);
            
            if (_foundWords.length == _hiddenWords.length) {
              message = 'Puzzle complete! Bonus +50 Nyx Notes!';
              userProvider.addNyxNotes(50);
            }
            
            return;
          }
        }
      }
    }
    
    // No match found, clear selection
    _selectedCells.clear();
  }
  
  bool _checkSwipeDirection(List<List<int>> swipePath, List<List<int>> wordPositions) {
    // Check forward direction
    bool forwardMatch = true;
    for (int i = 0; i < swipePath.length; i++) {
      if (swipePath[i][0] != wordPositions[i][0] || 
          swipePath[i][1] != wordPositions[i][1]) {
        forwardMatch = false;
        break;
      }
    }
    
    if (forwardMatch) return true;
    
    // Check reverse direction
    bool reverseMatch = true;
    for (int i = 0; i < swipePath.length; i++) {
      final reverseIndex = wordPositions.length - 1 - i;
      if (swipePath[i][0] != wordPositions[reverseIndex][0] || 
          swipePath[i][1] != wordPositions[reverseIndex][1]) {
        reverseMatch = false;
        break;
      }
    }
    
    return reverseMatch;
  }

  void _checkSelectedCells() {
    if (_selectedCells.length < 2) return;
    
    // Try to form words from selected cells
    for (final word in _hiddenWords) {
      if (_foundWords.contains(word)) continue;
      
      if (_wordPositions.containsKey(word)) {
        final positions = _wordPositions[word]!;
        
        // Check if all word positions are selected
        bool allSelected = positions.every((pos) => 
          _selectedCells.any((cell) => cell[0] == pos[0] && cell[1] == pos[1])
        );
        
        if (allSelected) {
          _foundWords.add(word);
          final points = 10;  // Fixed 10 points per word
          score = score + points.toInt();
          message = 'Found "$word"! +$points Nyx Notes';
          
          // Add to correct cells and clear selection
          _correctCells.addAll(positions);
          _selectedCells.clear();
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.addNyxNotes(points);
          
          if (_foundWords.length == _hiddenWords.length) {
            message = 'Puzzle complete! Bonus +50 Nyx Notes!';
            userProvider.addNyxNotes(50);
          }
          
          setState(() {});
          break;
        }
      }
    }
  }
  
  void _showHint() {
    if (_hintsUsed >= _maxHints || _foundWords.length >= _hiddenWords.length) return;
    
    // Find words that haven't been found or hinted
    final unhintedWords = _hiddenWords.where((word) => 
      !_foundWords.contains(word) && !_hintedWords.contains(word)
    ).toList();
    
    if (unhintedWords.isEmpty) {
      // If all unfound words have been hinted, pick from unfound words
      final unfoundWords = _hiddenWords.where((word) => 
        !_foundWords.contains(word)
      ).toList();
      
      if (unfoundWords.isNotEmpty) {
        final wordToHint = unfoundWords.first;
        final placedWord = _placedWords[wordToHint] ?? wordToHint;
        message = 'Hint: Look for "${placedWord[0]}..." (${placedWord.length} letters)';
      }
    } else {
      // Show hint for a word that hasn't been hinted yet
      final wordToHint = unhintedWords.first;
      final placedWord = _placedWords[wordToHint] ?? wordToHint;
      _hintedWords.add(wordToHint);
      message = 'Hint: Look for "${placedWord[0]}..." (${placedWord.length} letters)';
    }
    
    _hintsUsed++;
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating puzzle...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Mode selector and New Game button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Easy'),
                    selected: _isEasyMode,
                    onSelected: (selected) {
                      if (selected && !_isEasyMode) {
                        setState(() {
                          _isEasyMode = true;
                        });
                        _generateNewPuzzle();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Hard'),
                    selected: !_isEasyMode,
                    onSelected: (selected) {
                      if (selected && _isEasyMode) {
                        setState(() {
                          _isEasyMode = false;
                        });
                        _generateNewPuzzle();
                      }
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _generateNewPuzzle(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('New Game'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Score and progress with Nyx Notes message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Found: ${_foundWords.length}/${_hiddenWords.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (message.isNotEmpty && message.contains('Nyx Notes'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Word grid with swipe support
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onPanStart: (details) {
                    // Find which cell was tapped based on local position
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    final cellSize = _isEasyMode ? 40.0 : 30.0;
                    final margin = 2.0;
                    final totalCellSize = cellSize + (margin * 2);
                    
                    final col = (localPosition.dx / totalCellSize).floor();
                    final row = (localPosition.dy / totalCellSize).floor();
                    
                    if (row >= 0 && row < _gridSize && col >= 0 && col < _gridSize) {
                      _onPanStart(details, row, col);
                    }
                  },
                  onPanUpdate: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    _onPanUpdate(details, renderBox);
                  },
                  onPanEnd: _onPanEnd,
                  child: Column(
                    children: List.generate(_gridSize, (row) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_gridSize, (col) {
                          final isSelected = _selectedCells.any((c) => c[0] == row && c[1] == col);
                          final isCorrect = _correctCells.any((c) => c[0] == row && c[1] == col);
                          final isInSwipePath = _currentSwipePath.any((c) => c[0] == row && c[1] == col);
                          
                          return GestureDetector(
                            onTap: () => _onCellTap(row, col),
                            child: Container(
                              width: _isEasyMode ? 40.0 : 30.0,
                              height: _isEasyMode ? 40.0 : 30.0,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : (isSelected || isInSwipePath)
                                        ? Colors.blue.withValues(alpha: 0.3)
                                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrect
                                      ? Colors.green
                                      : (isSelected || isInSwipePath)
                                          ? Colors.blue
                                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  width: (isCorrect || isSelected || isInSwipePath) ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _grid[row][col],
                                  style: TextStyle(
                                    fontSize: _isEasyMode ? 16 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: (isCorrect || isSelected || isInSwipePath) ? Colors.black : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Word input field (moved up for better visibility)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordInputController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter a word',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _wordInputController.clear(),
                    ),
                  ),
                  onSubmitted: (value) {
                    _checkWordFromText(value);
                    _wordInputController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _checkWordFromText(_wordInputController.text);
                  _wordInputController.clear();
                },
                child: const Text('Check'),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Non-Nyx Notes messages display
          if (message.isNotEmpty && !message.contains('Nyx Notes'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Found words display (without revealing unfound words)
          if (_foundWords.isNotEmpty) ...[
            Text(
              'Found Words:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foundWords.map((word) => Chip(
                label: Text(word),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: const BorderSide(color: Colors.green),
              )).toList(),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: (_hintsUsed < _maxHints && _foundWords.length < _hiddenWords.length) 
                    ? _showHint 
                    : null,
                child: Text(
                  _hintsUsed >= _maxHints 
                      ? 'No hints left' 
                      : 'Hint ($_hintsUsed/$_maxHints used)',
                  style: TextStyle(
                    color: (_hintsUsed < _maxHints && _foundWords.length < _hiddenWords.length)
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showWordList = !_showWordList;
                  });
                },
                child: Text(_showWordList ? 'Hide Word List' : 'Show Word List (Spoiler!)'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          
          // Only show word list if user explicitly wants to see it
          if (_showWordList) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                children: [
                  const Text(
                    'Hidden Words (Spoiler!):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hiddenWords.map((word) {
                      final isFound = _foundWords.contains(word);
                      final placedWord = _placedWords[word] ?? word;
                      final isReversed = placedWord != word;
                      return Chip(
                        label: Text(isReversed ? '$word (as $placedWord)' : word),
                        backgroundColor: isFound
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: isFound ? Colors.green : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _wordInputController.dispose();
    super.dispose();
  }

  @override
  void onSubmitAnswer() {
    // WordHunt uses both grid selection and text input
    // This method is not used for this game
  }
  
  @override
  bool isGameActive() {
    return !isLoading; // Game is active when not loading
  }
}


// Letter Sequence Game Implementation
class LetterSequenceGameWidget extends BaseGameWidget {
  const LetterSequenceGameWidget({super.key});

  @override
  State<LetterSequenceGameWidget> createState() => _LetterSequenceGameWidgetState();
}

class _LetterSequenceGameWidgetState extends BaseGameState<LetterSequenceGameWidget> {
  List<String> _availableSequences = [];
  
  String _currentSequence = '';
  List<String> _foundWords = [];
  int _timeLeft = 60;
  bool _gameActive = false;

  @override
  void initState() {
    super.initState();
    _loadSequenceAndStart();
    
    // Auto-scroll when keyboard appears
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  Future<void> _loadSequenceAndStart() async {
    await _startNewRound();
  }

  Future<void> _startNewRound() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Call backend API to generate letter sequence challenge
      final response = await APIService.post('/games/lettersequence/generate', {
        'user_id': 'flutter_user',
      });

      if (response['success'] == true) {
        final data = response['data'];
        _currentSequence = data['current_sequence'];
      } else {
        // Fallback to local generation
        _generateSequenceLocally();
      }
    } catch (e) {
      // Fallback to local generation if API fails
      _generateSequenceLocally();
    }

    _foundWords.clear();
    answerController.clear();
    message = '';
    _timeLeft = 60;
    _gameActive = true;
    isLoading = false;
    
    setState(() {});
    _startTimer();
  }

  void _generateSequenceLocally() {
    // Fallback local generation
    _availableSequences = [
      'MIC', 'CAR', 'PRO', 'TER', 'CON', 'MAN', 'LIG', 'STR', 'PEN', 'TAR',
      'BAN', 'CAN', 'DEN', 'FAN', 'GEN', 'HEN', 'LEN', 'MEN', 'PAN', 'RAN',
      'SAN', 'TAN', 'VAN', 'WAN', 'BAT', 'CAT', 'FAT', 'HAT', 'MAT', 'PAT',
      'RAT', 'SAT', 'VAT', 'ART', 'BIT', 'FIT', 'HIT', 'KIT', 'LIT', 'PIT',
      'SIT', 'WIT', 'ACE', 'AGE', 'ATE', 'EAR', 'EAT', 'END', 'ICE', 'INE',
      'ING', 'ION', 'ORE', 'OUR', 'OUT', 'OWN', 'UMP', 'UNE', 'URE', 'USE'
    ];
    
    final random = Random();
    _currentSequence = _availableSequences[random.nextInt(_availableSequences.length)];
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_gameActive && _timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
        _startTimer();
      } else if (_timeLeft <= 0) {
        _endGame();
      }
    });
  }

  void _endGame() {
    _gameActive = false;
    message = 'Time\'s up! You found ${_foundWords.length} words.';
    setState(() {});
  }

  void _endRoundEarly() async {
    _gameActive = false;
    
    if (_foundWords.isNotEmpty) {
      message = 'Round ended! You keep your $score Nyx Notes. Found ${_foundWords.length} words.';
    } else {
      message = 'Round ended! No points earned this round.';
    }
    
    setState(() {});
  }

  void _checkAnswer() async {
    final answer = answerController.text.trim().toUpperCase();
    
    if (answer.isEmpty) return;
    
    try {
      // Use backend API for validation
      final response = await APIService.post('/games/lettersequence/validate', {
        'user_id': 'flutter_user',
        'answer': answer,
        'current_sequence': _currentSequence,
        'found_words': _foundWords,
      });

      if (response['success'] == true) {
        final data = response['data'];
        
        if (data['isValid'] == true) {
          _foundWords.add(answer);
          final points = (data['points'] ?? 10) as int;
          score = score + points;
          message = data['message'] ?? 'Correct! "$answer" +$points Nyx Notes';
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.addNyxNotes(points);
        } else {
          message = data['message'] ?? 'Not a valid word';
        }
      } else {
        // Fallback to local validation
        await _checkAnswerLocally(answer);
      }
    } catch (e) {
      // Fallback to local validation if API fails
      await _checkAnswerLocally(answer);
    }
    
    answerController.clear();
    setState(() {});
  }

  Future<void> _checkAnswerLocally(String answer) async {
    // Original local validation logic
    if (_foundWords.contains(answer)) {
      message = 'You already found that word!';
    } else if (!answer.contains(_currentSequence)) {
      message = 'Word must contain "$_currentSequence" in that order!';
    } else {
      // Verify it contains the sequence in order
      final sequenceIndex = answer.indexOf(_currentSequence);
      if (sequenceIndex != -1) {
        // Use WordService to validate the word
        final isValid = await WordService.isValidWord(answer);
        
        if (isValid) {
          _foundWords.add(answer);
          final points = 10;  // Fixed 10 points per word
          score = score + points.toInt();
          message = 'Correct! "$answer" +$points Nyx Notes';
          
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.addNyxNotes(points);
        } else {
          message = 'Not a valid English word';
        }
      } else {
        message = 'Word must contain "$_currentSequence" in that exact order!';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing letter sequence...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Time: $_timeLeft',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _timeLeft <= 10 ? Colors.red : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Found: ${_foundWords.length} words',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Find words containing:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentSequence,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Letters must appear in this exact order',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (_gameActive) ...[
            TextField(
              controller: answerController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Enter a word containing $_currentSequence',
                hintText: 'e.g., for "MIC": MICROPHONE, COMIC, MIMIC...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _checkAnswer,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _checkAnswer(),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Word',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _endRoundEarly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'End Round',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startNewRound(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start New Round',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.contains('Correct') 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: message.contains('Correct')
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: message.contains('Correct')
                      ? Colors.green[700]
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          const SizedBox(height: 16),
          
          if (_foundWords.isNotEmpty) ...[
            Text(
              'Found Words:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _foundWords.map((word) => Chip(
                label: Text(word),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: BorderSide(color: Colors.green),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void onSubmitAnswer() => _checkAnswer();
  
  @override
  bool isGameActive() => _gameActive;
}