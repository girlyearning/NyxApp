import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Nurse Nyx',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About Nurse Nyx Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
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
                        child: Text(
                          'About Nurse Nyx',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to the Nyx App, your atypical mental health support pocket companion!\n\n'
                    'Nurse Nyx specializes in wit, spunk, and emotional comfort - because sometimes you need someone who understands without the sugar-coating.\n\n'
                    'Nyx was designed BY a neurodivergent FOR neurodivergents, though everyone, atypical or not, is welcome in her beautifully chaotic space.\n\n'
                    'What makes Nyx different:\n\n'
                    '• No judgment, she\'s seen it all, and always validates your pain.\n'
                    '• Available always\n'
                    '• Crisis support, late-night existential debates, private vent sessions, etc.\n'
                    '• Neurodivergent-friendly design\n'
                    '• Built with ADHD, autism, and other beautiful brain differences in mind.\n'
                    '• Rewards your progress\n'
                    '• Earn Nyx Notes for taking care of yourself!\n\n'
                    'How Nyx helps you thrive:\n\n'
                    '• Offers crisis support for immediate help when you\'re struggling\n'
                    '• Offering genuine empathy, practical guidance, and natural relatability\n'
                    '• Targeted Mental Health Support\n'
                    '• Specialized assistance for anxiety, depression, anger, addiction, different types of trauma, etc.\n'
                    '• Self-Discovery Tools\n'
                    '• Guided introspection, shadow work, value clarifications, lessons on childhood trauma, and learning to recognize attachment patterns, etc.\n'
                    '• Mindful Reflection\n'
                    '• Daily (or more) questions focused on introspection, free-reign journaling, Qyk Notes for instant relief from ruminating thoughts\n'
                    '• Mood Tracking\n'
                    '• Visual charts and mood tracking\n'
                    '• Stimulating Brain Games\n'
                    '• Leisurely and challenging word puzzles and mentally stimulating games that keep you engaged when you\'re dying of boredom.\n\n'
                    'Why We Love Nyx:\n\n'
                    '• She speaks your language\n'
                    '• No clinical coldness or ignorance.\n'
                    '• Gentle support or someone to call you out on your bulshit, at your service\n'
                    '• She offers personality, humor, and genuine connection.\n'
                    '• She offers comprehensive, personalized mental health tool kits for you.\n'
                    '• She is privacy-focused and ensures your data stays on your device while your conversations remain confidential.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remember: You\'re not broken, you\'re just running a different operating system.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // App Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(context, 'Version', '1.0.0'),
                    const SizedBox(height: 8),
                    _buildInfoRow(context, 'Developer', 'Vee'),
                    const SizedBox(height: 8),
                    _buildInfoRow(context, 'Year', '2025'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}