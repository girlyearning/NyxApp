import 'package:flutter/material.dart';
import '../widgets/section_card.dart';
import '../widgets/feature_grid.dart';
import '../screens/games_screen.dart';
import '../screens/infodump_screen.dart';
import '../screens/nyx_queries_screen.dart';
import '../screens/nautical_nyx_screen.dart';
import '../screens/kitty_katch_screen.dart';
import '../screens/botanical_breaker_screen.dart';

class SensorySelfcareScreen extends StatelessWidget {
  const SensorySelfcareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sensory Selfcare',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1,
                ),
              ),
              child: Text(
                'Your playground for games, leisure chat, and knowledge sharing. Choose your adventure!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 24),

            // NyxQueries
            SectionCard(
              title: 'NyxQueries',
              subtitle: 'Got a question? Want a spunky answer? Ask Nyx.',
              icon: Icons.help_outline,
              color: const Color(0xFF7aa5bf), // #7aa5bf
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToNyxQueries(context),
                    icon: const Icon(Icons.psychology),
                    label: const Text('Ask Nyx Anything'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5a8aa0), // Darker blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nautical Nyx Nook
            _buildNauticalNyxCard(context),
            const SizedBox(height: 24),

            // Kitty Katch Game
            _buildKittyKatchCard(context),
            const SizedBox(height: 24),

            // Botanical Breaker Game
            _buildBotanicalBreakerCard(context),
            const SizedBox(height: 24),

            // Prescription Puzzles
            SectionCard(
              title: 'Prescription Puzzles',
              subtitle: 'Word games and brain teasers for mental stimulation',
              icon: Icons.extension,
              color: const Color(0xFFE91E63), // More vibrant pink for better contrast
              child: FeatureGrid(
                features: [
                  FeatureItem(
                    title: 'Word Hunt',
                    description: 'Find hidden words in letter grids',
                    icon: Icons.search,
                    onTap: () => _navigateToGame(context, 'wordhunt'),
                  ),
                  FeatureItem(
                    title: 'Unscramble',
                    description: 'Unscramble letters to form words',
                    icon: Icons.shuffle,
                    onTap: () => _navigateToGame(context, 'unscramble'),
                  ),
                  FeatureItem(
                    title: 'Prefix Game',
                    description: 'Find words starting with given prefixes',
                    icon: Icons.text_fields,
                    onTap: () => _navigateToGame(context, 'prefixgame'),
                  ),
                  FeatureItem(
                    title: 'Scattergories',
                    description: 'Name items in categories with specific letters',
                    icon: Icons.category,
                    onTap: () => _navigateToGame(context, 'scattergories'),
                  ),
                  FeatureItem(
                    title: 'Letter Sequence',
                    description: 'Find words containing specific letter sequences',
                    icon: Icons.sort_by_alpha,
                    onTap: () => _navigateToGame(context, 'lettersequence'),
                  ),
                  FeatureItem(
                    title: 'Coming Soon',
                    description: 'More games in development',
                    icon: Icons.more_horiz,
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Infodump Incorporated
            SectionCard(
              title: 'Infodump Incorporated',
              subtitle: 'Share and discover fascinating information',
              icon: Icons.library_books,
              color: const Color(0xFF8B0000), // Burgundy color
              child: FeatureGrid(
                features: [
                  FeatureItem(
                    title: 'Generate Infodumps',
                    description: 'Ask Nyx to infodump about any topic',
                    icon: Icons.auto_awesome,
                    onTap: () => _navigateToInfodump(context, 'generate'),
                  ),
                  FeatureItem(
                    title: 'Mental Health Topics',
                    description: 'Pre-curated infodumps about mental health',
                    icon: Icons.psychology_alt,
                    onTap: () => _navigateToInfodump(context, 'mental_health'),
                  ),
                  FeatureItem(
                    title: 'Share Your Infodump',
                    description: 'Earn Nyx Notes by sharing your knowledge',
                    icon: Icons.share,
                    onTap: () => _navigateToInfodump(context, 'share'),
                  ),
                  FeatureItem(
                    title: 'Browse Community',
                    description: 'Explore infodumps from other users',
                    icon: Icons.explore,
                    onTap: () => _navigateToInfodump(context, 'browse'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNauticalNyxCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFADCF86), // #adcf86
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NauticalNyxScreen()),
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
                  color: const Color(0xFFADCF86).withValues(alpha: 0.2), // #adcf86
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sailing,
                  color: Color(0xFF8BB96E), // Darker green
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nautical Nyx Nook',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leisure chat with Nyx\'s different personalities',
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

  Widget _buildKittyKatchCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFFF9CAE), // Pink color similar to Nautical Nyx but different
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KittyKatchScreen()),
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
                  color: const Color(0xFFFF9CAE).withValues(alpha: 0.2), // Pink with transparency
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pets,
                  color: Color(0xFFE91E63), // Darker pink
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kitty Katch',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the adorable pixel cats before they disappear!',
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

  Widget _buildBotanicalBreakerCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF98D982), // Green color for botanical theme
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BotanicalBreakerScreen()),
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
                  color: const Color(0xFF98D982).withValues(alpha: 0.2), // Green with transparency
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_florist,
                  color: Color(0xFF4CAF50), // Darker green
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Botanical Breaker',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Launch rose balls to break hedges and watch leaves fall!',
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

  void _navigateToGame(BuildContext context, String gameType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamesScreen(gameType: gameType),
      ),
    );
  }

  void _navigateToInfodump(BuildContext context, String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfodumpScreen(mode: mode),
      ),
    );
  }

  void _navigateToNyxQueries(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NyxQueriesScreen(),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: const Text('More exciting games are being developed. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class FeatureItem {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  FeatureItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
}