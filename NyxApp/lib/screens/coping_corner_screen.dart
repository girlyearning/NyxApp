import 'package:flutter/material.dart';
import '../widgets/coping_feature_card.dart';
import '../widgets/section_card.dart';
import '../widgets/feature_grid.dart';
import '../screens/coping_options_screen.dart';
import '../screens/sensory_selfcare_screen.dart';

class CopingCornerScreen extends StatefulWidget {
  const CopingCornerScreen({super.key});

  @override
  State<CopingCornerScreen> createState() => _CopingCornerScreenState();
}

class _CopingCornerScreenState extends State<CopingCornerScreen> {
  @override
  void initState() {
    super.initState();
    // Dismiss keyboard when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Coping Corner',
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
                'Your safe space for mental health support, guidance, and healing. Choose what you need today.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 24),

            // Crisis Support Section
            Text(
              'Crisis Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            const CopingFeatureCard(
              title: 'Crisis Support',
              description: 'Immediate support for when you\'re in emotional crisis',
              icon: Icons.emergency,
              mode: 'suicide',
              color: Colors.red,
            ),
            const SizedBox(height: 24),

            // Targeted Support Section
            SectionCard(
              title: 'Targeted Support',
              subtitle: 'Focused support for specific needs and situations',
              icon: Icons.psychology,
              color: const Color(0xFF7aa5bf), // Using similar color scheme
              child: FeatureGrid(
                features: [
                  FeatureItem(
                    title: 'General Support',
                    description: 'For anxiety, depression, and general comfort',
                    icon: Icons.favorite,
                    onTap: () => _navigateToGeneralSupport(context),
                  ),
                  FeatureItem(
                    title: 'Rage Room',
                    description: 'For releasing the more passionate parts of your emotions',
                    icon: Icons.whatshot,
                    onTap: () => _navigateToRageRoom(context),
                  ),
                  FeatureItem(
                    title: 'Recovery Support',
                    description: 'For battling addiction and maintaining sobriety',
                    icon: Icons.healing,
                    onTap: () => _navigateToRecoverySupport(context),
                  ),
                  FeatureItem(
                    title: 'Development & Disorders',
                    description: 'For understanding and coping with specific symptoms',
                    icon: Icons.psychology_alt,
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Specialized Self-Discovery Tools (keeping existing section)
            SectionCard(
              title: 'Specialized Self-Discovery Tools',
              subtitle: 'Advanced tools for deep personal exploration',
              icon: Icons.explore,
              color: const Color(0xFFE91E63), // More vibrant pink for better contrast
              child: Column(
                children: [
                  _buildSelfDiscoveryCard(
                    context,
                    'Guided Introspection',
                    'Structured self-reflection sessions with research-backed prompts',
                    Icons.lightbulb,
                    'introspection',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Shadow Work Prompts',
                    'Explore and integrate your shadow self safely',
                    Icons.nights_stay,
                    'shadow_work',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Existential Crisis Navigator',
                    'Explore life\'s big questions with philosophical guidance',
                    Icons.psychology_alt,
                    'existential',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Childhood Trauma Patterns',
                    'Understand and process childhood experiences safely',
                    Icons.child_care,
                    'trauma_patterns',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Attachment Pattern Scenarios',
                    'Interactive scenarios to understand your attachment style',
                    Icons.connect_without_contact,
                    'attachment',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Value Clarification',
                    'Discover and align with your core values',
                    Icons.compass_calibration,
                    'values',
                  ),
                  const SizedBox(height: 12),
                  _buildSelfDiscoveryCard(
                    context,
                    'Anonymous Confession Booth',
                    'Share your thoughts in complete anonymity',
                    Icons.lock,
                    'confession',
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

  void _navigateToGeneralSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CopingOptionsScreen(
          category: 'general_support',
          categoryTitle: 'General Support',
          categoryIcon: Icons.favorite,
          categoryColor: const Color(0xFF7aa5bf),
          options: [
            CopingOption(
              title: 'Nurturing from Nyx',
              description: 'When you just need someone to talk to and understand',
              icon: Icons.favorite,
              supportType: 'general_comfort',
            ),
            CopingOption(
              title: 'Anxiety Support',
              description: 'Calming techniques and understanding for anxious moments',
              icon: Icons.psychology,
              supportType: 'anxiety_support',
            ),
            CopingOption(
              title: 'Depression Support',
              description: 'Gentle guidance through difficult emotional periods',
              icon: Icons.cloud,
              supportType: 'depression_support',
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRageRoom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CopingOptionsScreen(
          category: 'rage_room',
          categoryTitle: 'Rage Room',
          categoryIcon: Icons.whatshot,
          categoryColor: const Color(0xFFFF6B6B),
          options: [
            CopingOption(
              title: 'Personal Rage Room',
              description: 'Process and understand your anger in a healthy way',
              icon: Icons.whatshot,
              supportType: 'anger_management',
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRecoverySupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CopingOptionsScreen(
          category: 'recovery_support',
          categoryTitle: 'Recovery Support',
          categoryIcon: Icons.healing,
          categoryColor: const Color(0xFF4ECDC4),
          options: [
            CopingOption(
              title: 'Addicts Anonymous',
              description: 'Support for addiction recovery and maintaining sobriety',
              icon: Icons.healing,
              supportType: 'recovery_support',
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon!'),
        content: const Text('Development & Disorders support tools are currently being developed. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfDiscoveryCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String mode,
  ) {
    return CopingFeatureCard(
      title: title,
      description: description,
      icon: icon,
      mode: mode,
    );
  }
}