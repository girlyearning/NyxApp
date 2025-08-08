import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class KittyKatchScreen extends StatefulWidget {
  const KittyKatchScreen({super.key});

  @override
  State<KittyKatchScreen> createState() => _KittyKatchScreenState();
}

class CatSprite {
  final String id;
  final String image;
  final double x;
  final double y;
  final DateTime timestamp;
  Timer? removalTimer;

  CatSprite({
    required this.id,
    required this.image,
    required this.x,
    required this.y,
    required this.timestamp,
  });
}

class _KittyKatchScreenState extends State<KittyKatchScreen>
    with TickerProviderStateMixin {
  String gameState = 'idle'; // 'idle', 'playing', 'finished'
  List<CatSprite> cats = [];
  int score = 0;
  int timeLeft = 30;
  Size gameContainerSize = const Size(0, 0);
  
  Timer? gameTimer;
  Timer? spawnTimer;
  
  // Improved shuffling system
  List<String> _shuffledCatImages = [];
  int _currentCatIndex = 0;
  
  // Cat images list - using only existing local assets
  final List<String> catImages = [
    'assets/images/cats/cat1.png',
    'assets/images/cats/cat2.png',
    'assets/images/cats/cat3.png',
    'assets/images/cats/cat4.png',
    'assets/images/cats/cat5.png',
    'assets/images/cats/cat6.png',
    'assets/images/cats/cat7.png',
    'assets/images/cats/cat8.png',
    'assets/images/cats/cat10.png',
    'assets/images/cats/cat13.png',
    'assets/images/cats/cat14.png',
    'assets/images/cats/cat16.png',
  ];

  @override
  void initState() {
    super.initState();
    _initializeShuffledCats();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContainerSize());
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    
    // Cancel all cat removal timers
    for (final cat in cats) {
      cat.removalTimer?.cancel();
    }
    
    super.dispose();
  }
  
  void _initializeShuffledCats() {
    _shuffledCatImages = List<String>.from(catImages);
    _shuffledCatImages.shuffle(Random());
    _currentCatIndex = 0;
  }
  
  String _getNextCatImage() {
    if (_currentCatIndex >= _shuffledCatImages.length) {
      // Reshuffle when we've used all cats
      _shuffledCatImages.shuffle(Random());
      _currentCatIndex = 0;
    }
    
    final catImage = _shuffledCatImages[_currentCatIndex];
    _currentCatIndex++;
    return catImage;
  }

  void _updateContainerSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        setState(() {
          gameContainerSize = Size(
            MediaQuery.of(context).size.width - 32, // Account for padding
            400, // Fixed height for game area
          );
        });
      }
    });
  }

  Offset _generateRandomPosition() {
    const padding = 80.0; // Space for cat size and meow bubble
    final random = Random();
    return Offset(
      random.nextDouble() * (gameContainerSize.width - padding) + padding / 2,
      random.nextDouble() * (gameContainerSize.height - padding) + padding / 2,
    );
  }

  void _spawnCat() {
    if (gameState != 'playing') return;
    
    final random = Random();
    final position = _generateRandomPosition();
    
    final newCat = CatSprite(
      id: DateTime.now().millisecondsSinceEpoch.toString() + random.nextInt(1000).toString(),
      image: _getNextCatImage(),
      x: position.dx,
      y: position.dy,
      timestamp: DateTime.now(),
    );

    setState(() {
      cats.add(newCat);
    });

    // Auto-remove cat after 3.5 seconds if not caught
    newCat.removalTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && gameState == 'playing') {
        setState(() {
          cats.removeWhere((cat) => cat.id == newCat.id);
        });
      }
    });
  }

  void _catchCat(String catId) {
    if (!mounted || gameState != 'playing') return;
    
    setState(() {
      final catIndex = cats.indexWhere((cat) => cat.id == catId);
      if (catIndex != -1) {
        // Cancel the removal timer before removing the cat
        cats[catIndex].removalTimer?.cancel();
        cats.removeAt(catIndex);
        score++;
      }
    });
  }

  void _startGame() {
    setState(() {
      gameState = 'playing';
      score = 0;
      timeLeft = 30;
      cats.clear();
    });
    
    // Reset the shuffled cat system for a new game
    _initializeShuffledCats();

    // Game timer
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() {
          timeLeft--;
        });
      } else {
        _endGame();
      }
    });

    // Cat spawning timer - controlled spawning with anti-spam protection
    spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (gameState == 'playing' && timeLeft > 0 && cats.length < 6) {
        _spawnCat();
        
        // Occasionally spawn an extra cat for variety, but with stricter limits
        final random = Random();
        if (random.nextDouble() < 0.15 && cats.length < 4) { // Reduced to 15% chance, max 4 cats
          Future.delayed(const Duration(milliseconds: 800), () {
            if (gameState == 'playing' && cats.length < 6) {
              _spawnCat();
            }
          });
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Game started! Catch the kitties!'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _endGame() async {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    
    // Cancel all cat removal timers before clearing
    for (final cat in cats) {
      cat.removalTimer?.cancel();
    }
    
    setState(() {
      gameState = 'finished';
      cats.clear();
    });

    // Award 20 Nyx Notes for completing the game
    if (mounted) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.addNyxNotes(20);
        
        // Show completion message with Nyx Notes reward
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game Complete! You caught $score kitties and earned 20 Nyx Notes! 🐱'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } catch (e) {
        // Fallback if points can't be added
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game over! You caught $score kitties!'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🐱 Kitty Katch',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Game instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Tap the non-meowing kitties as fast as you can in 30 seconds!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Game stats
              _buildGameStats(),
              const SizedBox(height: 16),

              // Game area
              Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Background pattern
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5],
                            center: const Alignment(0.25, 0.25),
                          ),
                        ),
                      ),

                      // Game state overlay
                      if (gameState == 'idle') _buildIdleState(),
                      if (gameState == 'finished') _buildFinishedState(),

                      // Cats
                      ...cats.map((cat) => CatWidget(
                        cat: cat,
                        onCatch: _catchCat,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Multiple cats can appear at once! Be quick and catch them all!',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Score', score.toString(), Icons.star),
          _buildStatItem('Time', timeLeft.toString(), Icons.timer),
          _buildStatItem('Status', gameState.toUpperCase(), Icons.info),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: const Text('Start Game'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Game Over!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You caught $score kitties!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }
}

class CatWidget extends StatefulWidget {
  final CatSprite cat;
  final Function(String) onCatch;

  const CatWidget({
    super.key,
    required this.cat,
    required this.onCatch,
  });

  @override
  State<CatWidget> createState() => _CatWidgetState();
}

class _CatWidgetState extends State<CatWidget>
    with TickerProviderStateMixin {
  bool showMeow = false;
  bool isClicked = false;
  
  late AnimationController _scaleController;
  late AnimationController _meowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _meowAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _meowController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _meowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _meowController, curve: Curves.bounceOut),
    );

    // Start appearance animation immediately
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _meowController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (isClicked) return;
    
    setState(() {
      isClicked = true;
      showMeow = true;
    });
    
    _meowController.forward();
    
    // Small delay to show meow animation, then catch
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onCatch(widget.cat.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.cat.x,
      top: widget.cat.y,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isClicked ? 1.2 : _scaleAnimation.value,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cat image with larger tap area
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            widget.cat.image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            opacity: isClicked 
                              ? const AlwaysStoppedAnimation(0.8)
                              : const AlwaysStoppedAnimation(1.0),
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Icon(
                                  Icons.pets,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Meow bubble
                  if (showMeow)
                    Positioned(
                      top: -32,
                      left: -8,
                      child: AnimatedBuilder(
                        animation: _meowAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _meowAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'meow!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}