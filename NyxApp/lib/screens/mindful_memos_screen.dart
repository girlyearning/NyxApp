import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dear_diary_screen.dart';
import '../services/qotd_responses_service.dart';
import 'qyknotes_screen.dart';

class MindfulMemosScreen extends StatefulWidget {
  const MindfulMemosScreen({super.key});

  @override
  State<MindfulMemosScreen> createState() => _MindfulMemosScreenState();
}

class _MindfulMemosScreenState extends State<MindfulMemosScreen> {
  final TextEditingController _qotdController = TextEditingController();
  String _currentQuestion = '';
  bool _hasAnsweredToday = false;
  String _todayAnswer = '';
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadTodayQuestion();
  }

  Future<void> _loadTodayQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final savedDate = prefs.getString('qotd_date') ?? '';
    
    if (savedDate == today) {
      // Load today's question and check if answered
      _currentQuestion = prefs.getString('qotd_question') ?? '';
      _hasAnsweredToday = prefs.getBool('qotd_answered_$today') ?? false;
      _todayAnswer = prefs.getString('qotd_answer_$today') ?? '';
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<String?> _callClaudeAPI(String prompt) async {
    try {
      const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
      if (apiKey == null || apiKey.isEmpty) {
        return null;
      }
      
      const claudeApiUrl = 'https://api.anthropic.com/v1/messages';
      
      final requestBody = {
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 200,
        'system': 'You are Nyx, a mental health companion. Generate thoughtful, introspective questions that promote self-reflection and mental wellness. Keep responses concise and meaningful.',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ]
      };
      
      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['content'] != null && data['content'].isNotEmpty) {
          return data['content'][0]['text']?.trim();
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> _loadQuestionsFromAsset() async {
    try {
      final String content = await rootBundle.loadString('assets/qotd.txt');
      final List<String> questions = content.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();
      
      // Shuffle the questions to ensure randomness
      questions.shuffle();
      return questions;
    } catch (e) {
      // Return empty list if file can't be loaded
      return [];
    }
  }

  Future<void> _generateNewQuestion() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final prompts = [
        "Generate a thoughtful mental health reflection question about self-awareness and emotional patterns. Make it personal, supportive, and introspective. One question only.",
        "Create a philosophical daily reflection question about meaning, purpose, or existence. Keep it accessible but thought-provoking. One question only.", 
        "Generate an introspective question about relationships, boundaries, or connection with others. Make it gentle and encouraging. One question only.",
        "Create a mindfulness question about present moment awareness, gratitude, or inner peace. Keep it grounding and practical. One question only.",
        "Generate a self-compassion question about personal growth, healing, or self-acceptance. Make it warm and nurturing. One question only.",
        "Create a question about childhood patterns, family dynamics, or personal history. Keep it safe and exploratory. One question only.",
        "Generate a creative reflection question about dreams, aspirations, or imagination. Make it inspiring but realistic. One question only.",
        "Create an intellectually emotional question about processing difficult feelings or experiences. Make it thoughtful and serious. One question only.",
        "Generate a mindful awareness question about observing thoughts, feelings, or bodily sensations without judgment. One question only.",
        "Create a deep introspective question about core beliefs, values, or identity exploration. Make it profound yet approachable. One question only.",
      ];
      
      // Randomly select a prompt category
      final random = Random();
      final selectedPrompt = prompts[random.nextInt(prompts.length)];
      
      // Try Claude API directly first
      final claudeResponse = await _callClaudeAPI(selectedPrompt);
      
      if (claudeResponse != null && claudeResponse.isNotEmpty && claudeResponse.length > 10) {
        // Clean up the response - remove quotes if present
        _currentQuestion = claudeResponse.replaceAll('"', '').replaceAll("'", '');
      } else {
        // Try to load questions from asset file first
        final assetQuestions = await _loadQuestionsFromAsset();
        
        if (assetQuestions.isNotEmpty) {
          _currentQuestion = assetQuestions[random.nextInt(assetQuestions.length)];
        } else {
          // Final fallback questions if both API and asset fail
          final fallbacks = [
            "What emotion have you been avoiding, and what might it be trying to tell you?",
            "If your life were a story, what chapter would you be writing right now?",
            "What pattern from your past are you ready to break today?",
            "What would self-love look like in action for you today?",
            "What truth about yourself are you beginning to accept?",
            "How do you relate to uncertainty, and what does that reveal about your need for control?",
            "What aspects of your childhood still influence how you respond to stress today?",
            "In what ways do you seek validation, and how might you cultivate self-worth instead?",
            "What fears are you carrying that no longer serve your growth?",
            "How do you define authentic connection, and where do you experience it most?",
          ];
          _currentQuestion = fallbacks[random.nextInt(fallbacks.length)];
        }
      }
      
      // Save the question and today's date
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('qotd_date', today);
      await prefs.setString('qotd_question', _currentQuestion);
      
      // Reset answer status since it's a new question
      _hasAnsweredToday = false;
      _todayAnswer = '';
      _qotdController.clear();
      await prefs.setBool('qotd_answered_$today', false);
      await prefs.remove('qotd_answer_$today');
      
    } catch (e) {
      // Fallback question on error
      _currentQuestion = "What's one thing you're grateful for in this moment?";
      
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('qotd_date', today);
      await prefs.setString('qotd_question', _currentQuestion);
    }
    
    setState(() {
      _isGenerating = false;
    });
  }

  Future<void> _submitAnswer() async {
    if (_qotdController.text.trim().isEmpty) return;
    
    final answer = _qotdController.text.trim();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final prefs = await SharedPreferences.getInstance();
    
    // Save answer to SharedPreferences (for backward compatibility)
    await prefs.setString('qotd_answer_$today', answer);
    await prefs.setBool('qotd_answered_$today', true);
    
    // Save to QOTD responses service for the new feature
    if (_currentQuestion.isNotEmpty) {
      await QotdResponsesService.saveResponse(_currentQuestion, answer);
    }
    
    // Award Nyx Notes
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.addNyxNotes(15);
    
    setState(() {
      _hasAnsweredToday = true;
      _todayAnswer = answer;
    });
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Answer submitted! +15 Nyx Notes'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Mindful Memos',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily Nyx Nudge (at top)
            const MindfulMemosDailyNudgeWidget(),
            const SizedBox(height: 24),
            
            // Question of the Day Section
            _buildQuestionOfTheDay(),
            const SizedBox(height: 16),
            
            // Qyk Notes Section
            _buildQykNotesCard(context),
            const SizedBox(height: 16),
            
            // Personal Journal Section
            _buildDearDiaryCard(context),
            
            const SizedBox(height: 24),

          ],
        ),
      ),
    );
  }

  Widget _buildQuestionOfTheDay() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'QOTD',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_currentQuestion.isNotEmpty && !_isGenerating)
                  TextButton.icon(
                    onPressed: _generateNewQuestion,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('New Question'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Show generate button if no question, otherwise show question
            if (_currentQuestion.isEmpty && !_isGenerating) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generate a thoughtful question for reflection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to create a personalized mental health, introspective, or mindfulness question',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _generateNewQuestion,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Question'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isGenerating) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Nyx is crafting your question...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/nyx_icon.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nyx asks:',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentQuestion,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Answer section - only show if there's a question and not generating
            if (_currentQuestion.isNotEmpty && !_isGenerating) ...[
              const SizedBox(height: 12),
              if (!_hasAnsweredToday) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qotdController,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        enableSuggestions: true,
                        autocorrect: true,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Submit',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '+15 Nyx Notes',
                            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your answer today:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_todayAnswer),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDearDiaryCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DearDiaryScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2BFCF).withValues(alpha: 0.2), // #f2bfcf
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Color(0xFFF2BFCF), // #f2bfcf
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Journal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Write your thoughts, feelings, and daily experiences in a private journal',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQykNotesCard(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QykNotesScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      color: Colors.yellow[700],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Qyk Notes',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${userProvider.qykNotes}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Capture quick notes and ideas (300 characters max)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _qotdController.dispose();
    super.dispose();
  }
}

class MindfulMemosDailyNudgeWidget extends StatefulWidget {
  const MindfulMemosDailyNudgeWidget({super.key});

  @override
  State<MindfulMemosDailyNudgeWidget> createState() => _MindfulMemosDailyNudgeWidgetState();
}

class _MindfulMemosDailyNudgeWidgetState extends State<MindfulMemosDailyNudgeWidget> {
  String? _dailyNudge;
  bool _isLoading = true;

  // Fallback nudge messages
  static const List<String> fallbackMessages = [
    "Remember to check in with yourself today. How are you feeling?",
    "Take a moment to breathe deeply and notice what's around you.",
    "Your feelings are valid, whatever they may be right now.",
    "Small steps forward are still progress. You're doing great.",
    "It's okay to have difficult days. Tomorrow is a new opportunity.",
    "Remember to be kind to yourself today.",
    "Your mental health matters. Take care of yourself.",
    "You are stronger than you think, even on the hard days.",
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyNudge();
  }

  Future<void> _loadDailyNudge() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final nudge = await APIService.getDailyNudge(userProvider.currentUserId);
      
      if (!mounted) return;
      
      setState(() {
        _dailyNudge = nudge ?? fallbackMessages[DateTime.now().day % fallbackMessages.length];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _dailyNudge = fallbackMessages[DateTime.now().day % fallbackMessages.length];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _isLoading ? "Loading your daily nudge..." : (_dailyNudge ?? fallbackMessages[DateTime.now().day % fallbackMessages.length]);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Daily Nyx Nudge',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}