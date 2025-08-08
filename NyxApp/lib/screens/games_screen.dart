import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/game_widgets.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GamesScreen extends StatefulWidget {
  final String gameType;

  const GamesScreen({
    super.key,
    required this.gameType,
  });

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  late String _gameTitle;
  late String _gameDescription;
  late Widget _gameWidget;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    switch (widget.gameType) {
      case 'wordhunt':
        _gameTitle = 'Word Hunt';
        _gameDescription = 'Find hidden words in the letter grid';
        _gameWidget = const WordHuntGameWidget();
        break;
      case 'unscramble':
        _gameTitle = 'Unscramble';
        _gameDescription = 'Unscramble the letters to form words';
        _gameWidget = const UnscrambleGameWidget();
        break;
      case 'prefixgame':
        _gameTitle = 'Prefix Game';
        _gameDescription = 'Find words starting with the given prefix';
        _gameWidget = const PrefixGameWidget();
        break;
      case 'scattergories':
        _gameTitle = 'Scattergories';
        _gameDescription = 'Name items in categories with specific letters';
        _gameWidget = const ScattergoriesGame();
        break;
      case 'lettersequence':
        _gameTitle = 'Letter Sequence';
        _gameDescription = 'Find words containing specific letter sequences';
        _gameWidget = const LetterSequenceGameWidget();
        break;
      default:
        _gameTitle = 'Game';
        _gameDescription = 'Game description';
        _gameWidget = const ComingSoonWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          _gameTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Game info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gameDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    return Text(
                      'Current Nyx Notes: ${userProvider.nyxNotes} 🪙',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Game content
          Expanded(
            child: _gameWidget,
          ),
        ],
      ),
    );
  }
}

// Placeholder game widgets - will be implemented with actual game logic
class WordHuntGame extends StatelessWidget {
  const WordHuntGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const GamePlaceholder(
      title: 'Word Hunt',
      description: 'Letter grid and word finding interface coming soon!',
      icon: Icons.search,
    );
  }
}

class UnscrambleGame extends StatelessWidget {
  const UnscrambleGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const GamePlaceholder(
      title: 'Unscramble',
      description: 'Word unscrambling interface coming soon!',
      icon: Icons.shuffle,
    );
  }
}

class PrefixGame extends StatelessWidget {
  const PrefixGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const GamePlaceholder(
      title: 'Prefix Game',
      description: 'Prefix word challenge interface coming soon!',
      icon: Icons.text_fields,
    );
  }
}


class ScattergoriesGame extends StatefulWidget {
  const ScattergoriesGame({super.key});

  @override
  State<ScattergoriesGame> createState() => _ScattergoriesGameState();
}

class _ScattergoriesGameState extends State<ScattergoriesGame> with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = [];
  late AnimationController _timerController;
  
  List<String> _currentCategories = [];
  String _currentLetter = '';
  int _score = 0;
  int _round = 1;
  bool _gameActive = false;
  bool _isSubmitting = false;
  String _message = '';
  
  List<Map<String, String>> _submissions = [];
  List<String> _submissionResults = [];
  
  static const int _timerDuration = 45; // 45 seconds
  
  // Mix of general and mental health categories
  static const List<String> _allCategories = [
    // General categories
    'Things in a kitchen',
    'Animals',
    'Movies',
    'Colors',
    'Countries',
    'Foods',
    'Sports',
    'School subjects',
    'Clothing items',
    'Things in a car',
    'Board games',
    'TV shows',
    'Things that are round',
    'Things you can break',
    'Things that make noise',
    'Things in a bathroom',
    'Hobbies',
    'Things in nature',
    'Jobs/Occupations',
    'Things you find at a beach',
    
    // Mental health/wellness categories
    'Positive emotions',
    'Coping strategies',
    'Self-care activities',
    'Things that reduce stress',
    'Mindfulness practices',
    'Ways to show kindness',
    'Positive affirmations',
    'Things that bring joy',
    'Healthy habits',
    'Ways to connect with others',
    'Things that inspire you',
    'Relaxation techniques',
    'Ways to express creativity',
    'Things that make you smile',
    'Acts of self-compassion',
    'Mental health resources',
    'Ways to practice gratitude',
    'Things that boost confidence',
    'Emotional support tools',
    'Ways to celebrate achievements',
  ];

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      duration: const Duration(seconds: _timerDuration),
      vsync: this,
    );
    _generateNewRound();
  }

  @override
  void dispose() {
    _timerController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generateNewRound() {
    final random = Random();
    
    // Generate random letter (avoiding difficult letters)
    const letters = 'ABCDEFGHIJKLMNOPRSTUVWY'; // Removed Q, X, Z for better gameplay
    _currentLetter = letters[random.nextInt(letters.length)];
    
    // Select 5 random categories
    final shuffledCategories = List<String>.from(_allCategories)..shuffle();
    _currentCategories = shuffledCategories.take(5).toList();
    
    // Create controllers for each category
    _controllers.clear();
    for (int i = 0; i < 5; i++) {
      _controllers.add(TextEditingController());
    }
    
    _message = '';
    _submissionResults.clear();
    setState(() {});
  }

  void _startGame() {
    _gameActive = true;
    _timerController.reset();
    _timerController.forward();
    
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _endGame();
      }
    });
    
    setState(() {});
  }

  void _endGame() {
    _gameActive = false;
    _timerController.stop();
    _submitAnswers();
  }

  Future<void> _submitAnswers() async {
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
      _message = 'Validating your answers with Claude...';
    });
    
    final answers = _controllers.map((c) => c.text.trim()).toList();
    final completedAnswers = answers.where((a) => a.isNotEmpty).toList();
    
    // Check if all 5 answers are completed before timer ends
    bool allCompleted = completedAnswers.length == 5 && _timerController.value < 1.0;
    
    int validAnswers = 0;
    List<String> results = [];
    
    for (int i = 0; i < answers.length; i++) {
      if (answers[i].isEmpty) {
        results.add('Empty');
        continue;
      }
      
      final isValid = await _validateAnswerWithClaude(answers[i], _currentCategories[i], _currentLetter);
      if (isValid) {
        validAnswers++;
        results.add('✓ Valid');
      } else {
        results.add('✗ Invalid');
      }
    }
    
    // Calculate points
    int points;
    if (allCompleted) {
      points = 15; // Bonus for completing all before timer
      _message = 'Amazing! All 5 completed before time! +$points Nyx Notes';
    } else {
      points = validAnswers * 10; // 10 points per valid answer
      _message = '$validAnswers valid answers. +$points Nyx Notes';
    }
    
    if (points > 0) {
      _score += points;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.addNyxNotes(points);
      
      // Track game played for achievements (first time scoring points in this session)
      await userProvider.incrementGamesPlayed();
    }
    
    // Store submission
    final submission = <String, String>{};
    for (int i = 0; i < _currentCategories.length; i++) {
      submission[_currentCategories[i]] = answers[i];
    }
    _submissions.add(submission);
    _submissionResults = results;
    
    setState(() {
      _isSubmitting = false;
    });
  }

  Future<bool> _validateAnswerWithClaude(String answer, String category, String letter) async {
    try {
      const claudeApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
      if (claudeApiKey.isEmpty) return _basicValidation(answer, letter);

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 50,
          'system': 'You are a Scattergories validator. Check if the answer fits the category and starts with the correct letter. Answer only "YES" or "NO".',
          'messages': [
            {
              'role': 'user',
              'content': 'Does "$answer" fit the category "$category" and start with the letter "$letter"?',
            }
          ]
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'][0]['text'].toString().trim().toUpperCase();
        return content.contains('YES');
      }
    } catch (e) {
      // Fallback to basic validation
    }
    
    return _basicValidation(answer, letter);
  }

  bool _basicValidation(String answer, String letter) {
    return answer.isNotEmpty && 
           answer.trim()[0].toUpperCase() == letter.toUpperCase();
  }

  void _startNewRound() {
    _round++;
    _timerController.reset();
    _gameActive = false;
    _generateNewRound();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Score and Round Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Round $_round', style: Theme.of(context).textTheme.titleMedium),
                Text('Score: $_score', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Current Letter and Timer
          if (_gameActive || _currentLetter.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.secondary),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Letter: ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentLetter,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_gameActive) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _timerController.value,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timerController.value > 0.8 ? Colors.red : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_timerDuration * (1 - _timerController.value)).ceil()}s remaining',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _timerController.value > 0.8 ? Colors.red : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Categories and Input Fields
          if (_currentCategories.isNotEmpty) ...[
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  children: List.generate(_currentCategories.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentCategories[index],
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controllers[index],
                                enabled: _gameActive,
                                decoration: InputDecoration(
                                  hintText: 'Enter answer starting with $_currentLetter...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.secondary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                textCapitalization: TextCapitalization.words,
                                scrollPadding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                                ),
                              ),
                            ),
                            if (_submissionResults.isNotEmpty && index < _submissionResults.length) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _submissionResults[index].contains('✓') 
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _submissionResults[index],
                                  style: TextStyle(
                                    color: _submissionResults[index].contains('✓') 
                                        ? Colors.green[700] 
                                        : Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                  }),
                ),
              ),
            ),
          ],

          // Message
          if (_message.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _message.contains('Amazing') 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Loading indicator
          if (_isSubmitting) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],

          // Game Controls
          Row(
            children: [
              if (!_gameActive && !_isSubmitting) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_round == 1 ? 'Start Game' : 'Start Round $_round'),
                  ),
                ),
              ],
              if (_gameActive) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _endGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF87A96B), // Sage green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Submit Early'),
                  ),
                ),
              ],
              if (!_gameActive && !_isSubmitting && _round > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startNewRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('New Round'),
                  ),
                ),
              ],
            ],
          ),

          // Previous Submissions
          if (_submissions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Previous Submissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              child: ListView.builder(
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  final submission = _submissions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Round ${index + 1}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ...submission.entries.map((entry) => Text(
                            '${entry.key}: ${entry.value}',
                            style: Theme.of(context).textTheme.bodySmall,
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ComingSoonWidget extends StatelessWidget {
  const ComingSoonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const GamePlaceholder(
      title: 'Coming Soon',
      description: 'This game is still in development!',
      icon: Icons.construction,
    );
  }
}

class GamePlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const GamePlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Back to Games'),
            ),
          ],
        ),
      ),
    );
  }
}