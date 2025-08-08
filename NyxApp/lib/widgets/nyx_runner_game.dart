import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class NyxRunnerGame extends StatefulWidget {
  const NyxRunnerGame({super.key});

  @override
  State<NyxRunnerGame> createState() => _NyxRunnerGameState();
}

class _NyxRunnerGameState extends State<NyxRunnerGame>
    with TickerProviderStateMixin {
  bool _isGameRunning = false;
  bool _isJumping = false;
  double _nyxVerticalPosition = 0.0;
  double _gameSpeed = 2.0;
  int _score = 0;
  int _highScore = 0;
  bool _gameOver = false;
  
  late AnimationController _jumpController;
  late AnimationController _runController;
  late Animation<double> _jumpAnimation;
  
  List<Obstacle> _obstacles = [];
  Timer? _gameTimer;
  Timer? _obstacleTimer;
  
  @override
  void initState() {
    super.initState();
    _loadHighScore();
    
    _jumpController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _runController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    
    _jumpAnimation = Tween<double>(
      begin: 0.0,
      end: -80.0,
    ).animate(CurvedAnimation(
      parent: _jumpController,
      curve: Curves.decelerate,
    ));
    
    _jumpAnimation.addListener(() {
      setState(() {
        _nyxVerticalPosition = _jumpAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _runController.dispose();
    _gameTimer?.cancel();
    _obstacleTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isGameRunning = true;
      _gameOver = false;
      _score = 0;
      _gameSpeed = 2.0;
      _obstacles.clear();
    });

    // Game loop
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isGameRunning && !_gameOver) {
        _updateGame();
      }
    });

    // Obstacle spawner
    _obstacleTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isGameRunning && !_gameOver) {
        _spawnObstacle();
      }
    });
  }

  void _stopGame() {
    setState(() {
      _isGameRunning = false;
    });
    _gameTimer?.cancel();
    _obstacleTimer?.cancel();
  }

  void _jump() {
    if (!_isJumping && !_gameOver && _isGameRunning) {
      _isJumping = true;
      _jumpController.forward().then((_) {
        _jumpController.reverse().then((_) {
          _isJumping = false;
        });
      });
    }
  }

  void _spawnObstacle() {
    // Randomly spawn either a bush (short) or tree (tall) obstacle
    final random = Random();
    final isBush = random.nextBool();
    
    _obstacles.add(Obstacle(
      x: 300.0,
      width: isBush ? 15.0 : 25.0,
      height: isBush ? 20.0 : 40.0,
      isBush: isBush,
    ));
  }

  void _updateGame() {
    setState(() {
      // Move obstacles
      _obstacles = _obstacles.map((obstacle) {
        return Obstacle(
          x: obstacle.x - _gameSpeed,
          width: obstacle.width,
          height: obstacle.height,
          isBush: obstacle.isBush,
        );
      }).where((obstacle) => obstacle.x > -50).toList();

      // Check collisions
      for (var obstacle in _obstacles) {
        if (obstacle.x < 80 && 
            obstacle.x > 30) {
          // Different collision detection for bush vs tree
          double requiredJumpHeight = obstacle.isBush ? -15.0 : -35.0;
          if (_nyxVerticalPosition > requiredJumpHeight) {
            _gameOver = true;
            _stopGame();
            break;
          }
        }
      }

      // Update score and speed
      if (!_gameOver) {
        _score++;
        // Slower speed progression
        if (_score % 200 == 0) {
          _gameSpeed += 0.2;
        }
        
        // Update high score
        if (_score > _highScore) {
          _highScore = _score;
          _saveHighScore();
        }
      }
    });
  }

  void _resetGame() {
    setState(() {
      _gameOver = false;
      _score = 0;
      _gameSpeed = 2.0;
      _obstacles.clear();
      _nyxVerticalPosition = 0.0;
    });
    _startGame();
  }
  
  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('nyx_runner_high_score') ?? 0;
    });
  }
  
  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nyx_runner_high_score', _highScore);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Game area
            GestureDetector(
              onTap: _jump,
              child: Container(
                width: double.infinity,
                height: 120,
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                child: Stack(
                  children: [
                    // Ground line
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    
                    // Nyx character (tree symbol)
                    Positioned(
                      bottom: 22 - _nyxVerticalPosition,
                      left: 50,
                      child: AnimatedBuilder(
                        animation: _runController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _isGameRunning ? sin(_runController.value * 2 * pi) * 2 : 0),
                            child: _NyxCharacter(
                              isRunning: _isGameRunning,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Obstacles
                    ..._obstacles.map((obstacle) => Positioned(
                      bottom: 22,
                      left: obstacle.x,
                      child: _ObstacleWidget(
                        obstacle: obstacle,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
            
            // Score and controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Score: $_score',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        if (_highScore > 0)
                          Text(
                            'Best: $_highScore',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 8,
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (_gameOver) ...[
                      TextButton(
                        onPressed: _resetGame,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 24),
                        ),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    TextButton(
                      onPressed: _isGameRunning ? _stopGame : _startGame,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 24),
                      ),
                      child: Text(
                        _isGameRunning ? 'Stop' : 'Start',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Game Over overlay
            if (_gameOver)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Game Over!',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _resetGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            minimumSize: const Size(80, 32),
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NyxCharacter extends StatelessWidget {
  final bool isRunning;
  final Color color;

  const _NyxCharacter({
    required this.isRunning,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 32,
      child: CustomPaint(
        painter: _NyxTreePainter(
          color: color,
          isRunning: isRunning,
        ),
      ),
    );
  }
}

class _NyxTreePainter extends CustomPainter {
  final Color color;
  final bool isRunning;

  _NyxTreePainter({
    required this.color,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Draw tree trunk (body)
    final trunk = Rect.fromLTWH(
      size.width * 0.4,
      size.height * 0.6,
      size.width * 0.2,
      size.height * 0.4,
    );
    canvas.drawRect(trunk, fillPaint);

    // Draw tree crown (head/upper body)
    final crownCenter = Offset(size.width * 0.5, size.height * 0.3);
    canvas.drawCircle(crownCenter, size.width * 0.25, fillPaint);

    // Draw branches (arms)
    final leftBranch = Path()
      ..moveTo(size.width * 0.3, size.height * 0.4)
      ..lineTo(size.width * 0.1, size.height * 0.5);
    canvas.drawPath(leftBranch, paint);

    final rightBranch = Path()
      ..moveTo(size.width * 0.7, size.height * 0.4)
      ..lineTo(size.width * 0.9, size.height * 0.5);
    canvas.drawPath(rightBranch, paint);

    // Draw roots (legs) - animated based on running state
    if (isRunning) {
      // Alternating leg positions for running animation
      final leftRoot = Path()
        ..moveTo(size.width * 0.4, size.height * 1.0)
        ..lineTo(size.width * 0.2, size.height * 1.2);
      canvas.drawPath(leftRoot, paint);

      final rightRoot = Path()
        ..moveTo(size.width * 0.6, size.height * 1.0)
        ..lineTo(size.width * 0.8, size.height * 1.1);
      canvas.drawPath(rightRoot, paint);
    } else {
      // Static leg positions
      final leftRoot = Path()
        ..moveTo(size.width * 0.4, size.height * 1.0)
        ..lineTo(size.width * 0.3, size.height * 1.2);
      canvas.drawPath(leftRoot, paint);

      final rightRoot = Path()
        ..moveTo(size.width * 0.6, size.height * 1.0)
        ..lineTo(size.width * 0.7, size.height * 1.2);
      canvas.drawPath(rightRoot, paint);
    }
  }

  @override
  bool shouldRepaint(_NyxTreePainter oldDelegate) {
    return oldDelegate.isRunning != isRunning || oldDelegate.color != color;
  }
}

class Obstacle {
  final double x;
  final double width;
  final double height;
  final bool isBush;

  Obstacle({
    required this.x,
    required this.width,
    required this.height,
    required this.isBush,
  });
}

class _ObstacleWidget extends StatelessWidget {
  final Obstacle obstacle;
  final Color color;

  const _ObstacleWidget({
    required this.obstacle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: obstacle.width,
      height: obstacle.height,
      child: CustomPaint(
        painter: _ObstaclePainter(
          color: color,
          isBush: obstacle.isBush,
        ),
      ),
    );
  }
}

class _ObstaclePainter extends CustomPainter {
  final Color color;
  final bool isBush;

  _ObstaclePainter({
    required this.color,
    required this.isBush,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (isBush) {
      // Draw bush - rounded shape
      final bushRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.4),
      );
      canvas.drawRRect(bushRect, paint);
      
      // Add some leaves detail
      final leafPaint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      
      // Small circles for leaf texture
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(size.width * (0.3 + i * 0.2), size.height * 0.3),
          size.width * 0.1,
          leafPaint,
        );
      }
    } else {
      // Draw tree - trunk with crown
      // Trunk
      final trunkWidth = size.width * 0.3;
      final trunkRect = Rect.fromLTWH(
        (size.width - trunkWidth) / 2,
        size.height * 0.6,
        trunkWidth,
        size.height * 0.4,
      );
      canvas.drawRect(trunkRect, paint);

      // Crown
      final crownCenter = Offset(size.width * 0.5, size.height * 0.3);
      canvas.drawCircle(crownCenter, size.width * 0.4, paint);
      
      // Additional crown details
      final leafPaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.2),
        size.width * 0.15,
        leafPaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.25),
        size.width * 0.12,
        leafPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ObstaclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isBush != isBush;
  }
}