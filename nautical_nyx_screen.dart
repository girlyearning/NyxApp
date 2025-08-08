import 'package:flutter/material.dart';
import '../widgets/feature_grid.dart';
import 'nautical_sessions_screen.dart';
import '../screens/sensory_selfcare_screen.dart';

class NauticalNyxScreen extends StatelessWidget {
  const NauticalNyxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nautical Nyx Nook',
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
                color: const Color(0xFFADCF86).withValues(alpha: 0.1), // #adcf86
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFADCF86),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Choose Your Nyx Personality',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF8BB96E), // Darker green
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.sailing, size: 20, color: Color(0xFF8BB96E)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Experience leisure chat with different facets of Nyx\'s personality. Each personality brings a unique perspective and conversation style.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Chat Personalities Grid
            FeatureGrid(
              features: [
                FeatureItem(
                  title: 'Default Nyx',
                  description: 'Chat with the original atypical Nurse Nyx.',
                  icon: Icons.person,
                  onTap: () => _navigateToChat(context, 'Default Nyx', 'default'),
                ),
                FeatureItem(
                  title: 'Ride or Die Nyx',
                  description: 'Chat with the expressively loyal Nyx.',
                  icon: Icons.favorite,
                  onTap: () => _navigateToChat(context, 'Ride or Die Nyx', 'ride_or_die'),
                ),
                FeatureItem(
                  title: 'Dream Analyst Nyx',
                  description: 'Explore dreams and psychological insights with analytical Nyx.',
                  icon: Icons.psychology,
                  onTap: () => _navigateToChat(context, 'Dream Analyst Nyx', 'dream_analyst'),
                ),
                FeatureItem(
                  title: 'Debate Master Nyx',
                  description: 'Engage in spirited debates with rage-baiting Nyx.',
                  icon: Icons.gavel,
                  onTap: () => _navigateToChat(context, 'Debate Master Nyx', 'debate_master'),
                ),
                FeatureItem(
                  title: 'ADHD Nyx',
                  description: 'A Nyx personality curated to those with ADHD.',
                  icon: Icons.flash_on,
                  onTap: () => _navigateToChat(context, 'ADHD Nyx', 'adhd_nyx'),
                ),
                FeatureItem(
                  title: 'Autistic Nyx',
                  description: 'A Nyx personality curated to those with ASD.',
                  icon: Icons.grid_view,
                  onTap: () => _navigateToChat(context, 'Autistic Nyx', 'autistic_nyx'),
                ),
                FeatureItem(
                  title: 'AuDHD Nyx',
                  description: 'A Nyx personality curated to those with ADHD and ASD.',
                  icon: Icons.auto_awesome,
                  onTap: () => _navigateToChat(context, 'AuDHD Nyx', 'autistic_adhd'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String title, String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NauticalSessionsScreen(
          title: title,
          personality: mode,
        ),
      ),
    );
  }
}

