import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class BotanicalBreakerScreen extends StatefulWidget {
  const BotanicalBreakerScreen({super.key});

  @override
  State<BotanicalBreakerScreen> createState() => _BotanicalBreakerScreenState();
}

class Ball {
  double x;
  double y;
  double vx;
  double vy;
  final double size;

  Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.size = 20,
  });
}

class Paddle {
  double x;
  double y;
  final double width;
  final double height;

  Paddle({
    required this.x,
    required this.y,
    this.width = 80,
    this.height = 16,
  });
}

class Hedge {
  final double x;
  final double y;
  final double width;
  final double height;
  final int row;
  final int col;
  final String id;

  Hedge({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.row,
    required this.col,
    required this.id,
  });
}

class FallingLeaf {
  final double x;
  double y;
  final String id;
  final double driftX;
  final double leafSize;
  final int leafType;

  FallingLeaf({
    required this.x,
    required this.y,
    required this.id,
    required this.driftX,
    required this.leafSize,
    required this.leafType,
  });
}

class _BotanicalBreakerScreenState extends State<BotanicalBreakerScreen>
    with TickerProviderStateMixin {
  String gameState = 'menu'; // 'menu', 'playing', 'victory'
  bool gameStarted = false;
  int score = 0;
  Size gameAreaSize = const Size(0, 0);
  
  Ball? ball;
  Paddle? paddle;
  List<Hedge> hedges = [];
  List<FallingLeaf> fallingLeaves = [];
  
  Timer? gameTimer;
  late AnimationController _ballAnimationController;
  late AnimationController _leafAnimationController;

  @override
  void initState() {
    super.initState();
    _ballAnimationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );
    _leafAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateGameAreaSize());
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _ballAnimationController.dispose();
    _leafAnimationController.dispose();
    super.dispose();
  }

  void _updateGameAreaSize() {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      gameAreaSize = Size(screenSize.width, screenSize.height - 200); // Account for app bar and controls
    });
  }

  void _initializeGame() {
    setState(() {
      score = 0;
      ball = Ball(
        x: gameAreaSize.width / 2,
        y: gameAreaSize.height - 80,
        vx: 0,
        vy: 0,
      );
      paddle = Paddle(
        x: gameAreaSize.width / 2,
        y: gameAreaSize.height - 50,
      );
      fallingLeaves.clear();
      _initializeHedges();
    });
  }

  void _initializeHedges() {
    hedges.clear();
    const rows = 5;
    const cols = 8;
    final hedgeWidth = (gameAreaSize.width - 40) / cols;
    const hedgeHeight = 30.0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        hedges.add(Hedge(
          x: 20 + col * hedgeWidth,
          y: 80 + row * (hedgeHeight + 5),
          width: hedgeWidth - 5,
          height: hedgeHeight,
          row: row,
          col: col,
          id: 'hedge-$row-$col',
        ));
      }
    }
  }

  void _startGame() {
    setState(() {
      gameState = 'playing';
    });
    _initializeGame();
  }

  void _launchBall() {
    if (ball != null && ball!.vx == 0 && ball!.vy == 0) {
      setState(() {
        gameStarted = true;
        ball!.vx = 150 + Random().nextDouble() * 100 - 50;
        ball!.vy = -300;
      });
      _startGameLoop();
    }
  }

  void _startGameLoop() {
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (ball == null || !gameStarted) return;

    setState(() {
      // Update ball position
      const deltaTime = 0.016; // 16ms
      ball!.x += ball!.vx * deltaTime;
      ball!.y += ball!.vy * deltaTime;

      // Check wall collisions
      _checkBallWallCollision();

      // Check paddle collision
      _checkBallPaddleCollision();

      // Check hedge collisions
      _checkBallHedgeCollisions();

      // Update falling leaves
      _updateFallingLeaves();

      // Check victory condition
      if (hedges.isEmpty) {
        _endGame(victory: true);
      }
    });
  }

  void _checkBallWallCollision() {
    if (ball == null) return;

    // Left and right walls
    if (ball!.x - ball!.size / 2 <= 0) {
      ball!.x = ball!.size / 2;
      ball!.vx = ball!.vx.abs();
    } else if (ball!.x + ball!.size / 2 >= gameAreaSize.width) {
      ball!.x = gameAreaSize.width - ball!.size / 2;
      ball!.vx = -ball!.vx.abs();
    }

    // Top wall
    if (ball!.y - ball!.size / 2 <= 0) {
      ball!.y = ball!.size / 2;
      ball!.vy = ball!.vy.abs();
    }

    // Bottom wall - bounce back instead of game over
    if (ball!.y + ball!.size / 2 >= gameAreaSize.height) {
      ball!.y = gameAreaSize.height - ball!.size / 2;
      ball!.vy = -ball!.vy.abs();
    }
  }

  void _checkBallPaddleCollision() {
    if (ball == null || paddle == null) return;

    final ballLeft = ball!.x - ball!.size / 2;
    final ballRight = ball!.x + ball!.size / 2;
    final ballTop = ball!.y - ball!.size / 2;
    final ballBottom = ball!.y + ball!.size / 2;

    final paddleLeft = paddle!.x - paddle!.width / 2;
    final paddleRight = paddle!.x + paddle!.width / 2;
    final paddleTop = paddle!.y - paddle!.height / 2;
    final paddleBottom = paddle!.y + paddle!.height / 2;

    if (ballBottom >= paddleTop &&
        ballTop <= paddleBottom &&
        ballRight >= paddleLeft &&
        ballLeft <= paddleRight) {
      // Calculate hit position for angle variation
      final hitPos = (ball!.x - paddle!.x) / (paddle!.width / 2);
      final angle = hitPos * 0.5; // Max angle of 0.5 radians

      final speed = sqrt(ball!.vx * ball!.vx + ball!.vy * ball!.vy);

      ball!.y = paddleTop - ball!.size / 2;
      ball!.vx = speed * sin(angle);
      ball!.vy = -(speed * cos(angle)).abs();
    }
  }

  void _checkBallHedgeCollisions() {
    if (ball == null) return;

    final ballLeft = ball!.x - ball!.size / 2;
    final ballRight = ball!.x + ball!.size / 2;
    final ballTop = ball!.y - ball!.size / 2;
    final ballBottom = ball!.y + ball!.size / 2;

    for (int i = hedges.length - 1; i >= 0; i--) {
      final hedge = hedges[i];
      final hedgeLeft = hedge.x;
      final hedgeRight = hedge.x + hedge.width;
      final hedgeTop = hedge.y;
      final hedgeBottom = hedge.y + hedge.height;

      if (ballBottom >= hedgeTop &&
          ballTop <= hedgeBottom &&
          ballRight >= hedgeLeft &&
          ballLeft <= hedgeRight) {
        // Determine collision side for bounce direction
        final overlapLeft = ballRight - hedgeLeft;
        final overlapRight = hedgeRight - ballLeft;
        final overlapTop = ballBottom - hedgeTop;
        final overlapBottom = hedgeBottom - ballTop;

        final minOverlap = [overlapLeft, overlapRight, overlapTop, overlapBottom]
            .reduce((a, b) => a < b ? a : b);

        if (minOverlap == overlapTop || minOverlap == overlapBottom) {
          ball!.vy = -ball!.vy;
        } else {
          ball!.vx = -ball!.vx;
        }

        // Remove hedge and add falling leaves
        hedges.removeAt(i);
        score += 10;
        _addFallingLeaves(hedge);
        break; // Only handle one collision per frame
      }
    }
  }

  void _addFallingLeaves(Hedge hedge) {
    final leafCount = 3 + Random().nextInt(3);
    for (int i = 0; i < leafCount; i++) {
      fallingLeaves.add(FallingLeaf(
        x: hedge.x + Random().nextDouble() * hedge.width,
        y: hedge.y + hedge.height / 2,
        id: 'leaf-${hedge.id}-$i-${DateTime.now().millisecondsSinceEpoch}',
        driftX: (Random().nextDouble() - 0.5) * 40,
        leafSize: 8 + Random().nextDouble() * 8,
        leafType: Random().nextInt(3),
      ));
    }

    // Remove leaves after animation
    Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        fallingLeaves.removeWhere((leaf) => 
          leaf.id.startsWith('leaf-${hedge.id}'));
      });
    });
  }

  void _updateFallingLeaves() {
    for (var leaf in fallingLeaves) {
      leaf.y += 100 * 0.016; // Fall speed
    }
  }

  void _handlePaddleMove(Offset position) {
    if (paddle == null) return;

    setState(() {
      paddle!.x = position.dx.clamp(paddle!.width / 2, gameAreaSize.width - paddle!.width / 2);
    });
  }

  void _endGame({bool victory = false}) {
    gameTimer?.cancel();
    gameStarted = false;

    if (victory) {
      setState(() {
        gameState = 'victory';
      });
      _awardPoints();
    }
  }

  Future<void> _awardPoints() async {
    final points = score;
    if (points > 0) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.addNyxNotes(points);
      await userProvider.incrementGamesPlayed();
    }
  }

  void _restartGame() {
    setState(() {
      gameState = 'menu';
      gameStarted = false;
    });
    gameTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Botanical Breaker',
          style: TextStyle(fontWeight: FontWeight.w600),
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
        actions: gameState == 'playing'
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Text(
                      'Score: $score',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: gameState == 'menu' ? _buildMenuScreen() : _buildGameScreen(),
    );
  }

  Widget _buildMenuScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pink.shade300,
                          Colors.pink.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.local_florist,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Botanical Breaker',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A calming nature-themed brick breaker game. Launch roses to break hedges and watch beautiful leaves fall.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Play',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...const [
                          '• Tap to launch the rose ball',
                          '• Move your finger to control the paddle',
                          '• Break hedges to earn points',
                          '• Enjoy the falling leaf animations',
                        ].map((instruction) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            instruction,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    if (gameState == 'victory') {
      return _buildVictoryScreen();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          if (!gameStarted)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Tap to launch the rose ball!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) => _handlePaddleMove(details.localPosition),
              onTapDown: (details) => _launchBall(),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    // Game ball
                    if (ball != null) _buildGameBall(),
                    
                    // Paddle
                    if (paddle != null) _buildPaddle(),
                    
                    // Hedges
                    ...hedges.map(_buildHedge),
                    
                    // Falling leaves
                    ...fallingLeaves.map(_buildFallingLeaf),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBall() {
    return Positioned(
      left: ball!.x - ball!.size / 2,
      top: ball!.y - ball!.size / 2,
      child: Container(
        width: ball!.size,
        height: ball!.size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.pink.shade300,
              Colors.pink.shade500,
              Colors.pink.shade700,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.pink.shade400,
              width: 1,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.pink.shade400.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaddle() {
    return Positioned(
      left: paddle!.x - paddle!.width / 2,
      top: paddle!.y - paddle!.height / 2,
      child: Container(
        width: paddle!.width,
        height: paddle!.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHedge(Hedge hedge) {
    final baseHue = 120.0; // Green base
    final saturation = (45 - hedge.row * 5).toDouble();
    final lightness = (35 + hedge.row * 3).toDouble();
    final hedgeColor = HSLColor.fromAHSL(1.0, baseHue, saturation / 100, lightness / 100).toColor();

    return Positioned(
      left: hedge.x,
      top: hedge.y,
      child: Container(
        width: hedge.width,
        height: hedge.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              hedgeColor.withValues(alpha: 0.9),
              hedgeColor,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: hedgeColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
            ),
            // Foliage details
            Positioned(
              top: 2,
              left: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingLeaf(FallingLeaf leaf) {
    final leafColors = [
      Colors.green.shade400,
      Colors.brown.shade400,
      Colors.green.shade600,
    ];

    return Positioned(
      left: leaf.x + leaf.driftX,
      top: leaf.y,
      child: Container(
        width: leaf.leafSize,
        height: leaf.leafSize,
        decoration: BoxDecoration(
          color: leafColors[leaf.leafType],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: leafColors[leaf.leafType].withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Container(
          margin: EdgeInsets.all(leaf.leafSize * 0.2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(leaf.leafSize * 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildVictoryScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎉',
                    style: TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Garden Cleared!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Final Score: $score',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _restartGame,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Back to Menu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}