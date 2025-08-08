import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/infodump_storage_service.dart';
import '../services/mental_health_infodump_service.dart';
import '../screens/infodump_content_screen.dart';

class InfodumpScreen extends StatefulWidget {
  final String mode;

  const InfodumpScreen({
    super.key,
    required this.mode,
  });

  @override
  State<InfodumpScreen> createState() => _InfodumpScreenState();
}

class _InfodumpScreenState extends State<InfodumpScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  String _generatedContent = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          _getScreenTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  String _getScreenTitle() {
    switch (widget.mode) {
      case 'generate':
        return 'Generate Infodump';
      case 'mental_health':
        return 'Mental Health Topics';
      case 'share':
        return 'Share Your Infodump';
      case 'browse':
        return 'Browse Community';
      default:
        return 'Infodump';
    }
  }

  Widget _buildBody() {
    switch (widget.mode) {
      case 'generate':
        return _buildGenerateMode();
      case 'mental_health':
        return _buildMentalHealthMode();
      case 'share':
        return _buildShareMode();
      case 'browse':
        return _buildBrowseMode();
      default:
        return _buildPlaceholder();
    }
  }

  Widget _buildGenerateMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B0000).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: const Color(0xFF8B0000)),
                    const SizedBox(width: 8),
                    Text(
                      'Generate Infodump',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF8B0000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask Nyx to create an interesting infodump about any topic you\'re curious about!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Topic input
          Text(
            'What topic would you like Nyx to infodump about?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              hintText: 'e.g., Octopus intelligence, Black holes, Medieval medicine...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 2,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _generateInfodump,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onSecondary),
                      ),
                    )
                  : const Text(
                      'Generate Infodump',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentalHealthMode() {
    final topics = MentalHealthInfodumpService.mentalHealthTopics.keys.toList();

    return Column(
      children: [
        // Header explanation
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Generated Infodumps',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comprehensive, educational content generated by Claude AI and saved for offline reading.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Topics list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.psychology_alt,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: Text(
                    topic,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: FutureBuilder<bool>(
                    future: MentalHealthInfodumpService.hasInfodumpContent(topic),
                    builder: (context, snapshot) {
                      final hasContent = snapshot.data ?? false;
                      return Text(
                        hasContent 
                          ? 'Tap to read Nyx\'s infodump' 
                          : 'Tap to generate infodump with AI',
                        style: TextStyle(
                          color: hasContent ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : Colors.blue,
                        ),
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<bool>(
                        future: MentalHealthInfodumpService.hasInfodumpContent(topic),
                        builder: (context, snapshot) {
                          final hasContent = snapshot.data ?? false;
                          return Icon(
                            hasContent ? Icons.article : Icons.auto_awesome,
                            size: 16,
                            color: hasContent ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : Colors.blue,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () => _showInfodump(topic),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShareMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.share, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Share Your Knowledge',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your passion! Write about something you love and earn Nyx Notes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Topic field
          Text(
            'Topic',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              hintText: 'What are you passionate about?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Content field
          Text(
            'Your Infodump',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'Share everything you know about this topic...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitInfodump,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Share & Earn Nyx Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseMode() {
    return FutureBuilder<List<InfodumpEntry>>(
      future: InfodumpStorageService.getAllInfodumps(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final infodumps = snapshot.data ?? [];
        
        if (infodumps.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Saved Infodumps Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by generating or sharing infodumps to see them here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: infodumps.length,
          itemBuilder: (context, index) {
            final infodump = infodumps[infodumps.length - 1 - index]; // Newest first
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (infodump.isUserCreated ? Colors.green : const Color(0xFF8B0000)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    infodump.isUserCreated ? Icons.person : Icons.auto_awesome,
                    color: infodump.isUserCreated ? Colors.green : const Color(0xFF8B0000),
                  ),
                ),
                title: Text(
                  infodump.topic,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      infodump.isUserCreated ? 'Your infodump' : 'Generated by Nyx',
                      style: TextStyle(
                        color: infodump.isUserCreated ? Colors.green : const Color(0xFF8B0000),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_formatDate(infodump.createdAt)} • ${_getWordCount(infodump.content)} words',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view') {
                      _showSavedInfodump(infodump);
                    } else if (value == 'delete') {
                      _confirmDeleteInfodump(infodump);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility),
                          SizedBox(width: 8),
                          Text('View'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => _showSavedInfodump(infodump),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Text('Infodump feature coming soon!'),
    );
  }

  void _generateInfodump() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedContent = '';
    });

    try {
      final topic = _topicController.text.trim();
      final prompt = "Create a comprehensive, fascinating infodump about ${topic}. Include interesting facts, historical context, current research, and surprising details that would captivate someone learning about this topic. Make it engaging and informative but accessible. Structure it with clear sections and use web search to ensure accuracy and current information.";
      
      final response = await _chatService.sendMessage(prompt, 'infodump', true);
      
      // Save the generated infodump
      final infodump = InfodumpEntry(
        id: InfodumpStorageService.generateId(),
        topic: topic,
        content: response,
        createdAt: DateTime.now(),
        isUserCreated: false,
      );
      await InfodumpStorageService.saveInfodump(infodump);
      
      setState(() {
        _generatedContent = response;
        _isLoading = false;
      });

      if (mounted) {
        _showGeneratedInfodump(topic, _generatedContent);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate infodump. Please try again.')),
        );
      }
    }
  }

  void _submitInfodump() async {
    if (_topicController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both topic and content')),
      );
      return;
    }

    // Save user infodump permanently
    final infodump = InfodumpEntry(
      id: InfodumpStorageService.generateId(),
      topic: _topicController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: DateTime.now(),
      isUserCreated: true,
    );
    await InfodumpStorageService.saveInfodump(infodump);

    // Award points
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.addNyxNotes(25); // Reward for sharing

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Infodump saved & shared! +25 Nyx Notes earned 🪙')),
      );
      
      _topicController.clear();
      _contentController.clear();
    }
  }

  void _showInfodump(String topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfodumpContentScreen(topic: topic),
      ),
    );
  }

  void _showGeneratedInfodump(String topic, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage('assets/images/nyx_icon.png'),
                        fit: BoxFit.cover,
                        scale: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nyx\'s Infodump:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8B0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          topic,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '🧠 Generated with research and love by Nyx',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveGeneratedInfodump(topic, content),
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Save Infodump'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedInfodump(InfodumpEntry infodump) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: infodump.isUserCreated ? Colors.green : const Color(0xFF8B0000),
                    ),
                    child: Icon(
                      infodump.isUserCreated ? Icons.person : Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          infodump.isUserCreated ? 'Your Infodump:' : 'Nyx\'s Infodump:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: infodump.isUserCreated ? Colors.green : const Color(0xFF8B0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          infodump.topic,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatDate(infodump.createdAt)} • ${_getWordCount(infodump.content)} words',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    infodump.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteInfodump(InfodumpEntry infodump) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Infodump'),
        content: Text('Are you sure you want to delete "${infodump.topic}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await InfodumpStorageService.deleteInfodump(infodump.id);
              setState(() {}); // Refresh the list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Infodump deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _saveGeneratedInfodump(String topic, String content) async {
    try {
      final infodump = InfodumpEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        topic: topic,
        content: content,
        isUserCreated: false,
        createdAt: DateTime.now(),
      );

      await InfodumpStorageService.saveInfodump(infodump);
      
      Navigator.pop(context); // Close the dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary, size: 16),
              SizedBox(width: 8),
              Text('Infodump "$topic" saved!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Refresh the widget to show updated infodumps
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.onPrimary, size: 16),
              const SizedBox(width: 8),
              const Text('Failed to save infodump'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  int _getWordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _topicController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}