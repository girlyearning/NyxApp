import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/logging_service.dart';
import '../models/chat_message.dart';
import '../services/conversation_memory_service.dart';

class ChatService {
  static const String baseUrl = 'https://nyxapp.lovable.app/api';
  static const String claudeApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';

  Future<String> sendMessage(String message, String mode, bool isFirstMessage, {List<ChatMessage>? conversationHistory, String? userId}) async {
    try {
      String enhancedMessage = message;
      
      if (userId != null) {
        // Always include background memory context for continuity
        final backgroundContext = await ConversationMemoryService.getBackgroundMemoryContext(userId, mode);
        
        // Check if we should include detailed memory context
        if (ConversationMemoryService.shouldIncludeMemoryContext(message)) {
          final detailedMemoryContext = await ConversationMemoryService.getMemoryContext(userId, mode, isExplicitRequest: true);
          if (detailedMemoryContext.isNotEmpty) {
            enhancedMessage = '$detailedMemoryContext\n\n${backgroundContext.isNotEmpty ? '$backgroundContext\n\n' : ''}Current message: $message';
          } else if (backgroundContext.isNotEmpty) {
            enhancedMessage = '$backgroundContext\n\nCurrent message: $message';
          }
        } else if (backgroundContext.isNotEmpty) {
          // Always include background context, but more subtly
          enhancedMessage = '$backgroundContext\n\nCurrent message: $message';
        }
      }
      
      // Try Claude API first, then local API, then fall back to mock
      String? claudeResponse = await _sendToClaudeAPI(enhancedMessage, mode, conversationHistory: conversationHistory);
      if (claudeResponse != null) return _formatResponse(claudeResponse, mode);
      
      String? localResponse = await _sendToAPI(enhancedMessage, mode);
      if (localResponse != null) return _formatResponse(localResponse, mode);
      
      return _formatResponse(_getMockResponse(message, mode, isFirstMessage), mode);
    } catch (e) {
      // Fall back to mock responses if APIs are unavailable
      return _formatResponse(_getMockResponse(message, mode, isFirstMessage), mode);
    }
  }

  Future<List<String>> sendMultipleMessages(String message, String mode, bool isFirstMessage, {List<ChatMessage>? conversationHistory, String? userId}) async {
    try {
      String enhancedMessage = message;
      
      if (userId != null) {
        // Always include background memory context for continuity
        final backgroundContext = await ConversationMemoryService.getBackgroundMemoryContext(userId, mode);
        
        // Check if we should include detailed memory context
        if (ConversationMemoryService.shouldIncludeMemoryContext(message)) {
          final detailedMemoryContext = await ConversationMemoryService.getMemoryContext(userId, mode, isExplicitRequest: true);
          if (detailedMemoryContext.isNotEmpty) {
            enhancedMessage = '$detailedMemoryContext\n\n${backgroundContext.isNotEmpty ? '$backgroundContext\n\n' : ''}Current message: $message';
          } else if (backgroundContext.isNotEmpty) {
            enhancedMessage = '$backgroundContext\n\nCurrent message: $message';
          }
        } else if (backgroundContext.isNotEmpty) {
          // Always include background context, but more subtly
          enhancedMessage = '$backgroundContext\n\nCurrent message: $message';
        }
      }
      
      // Try Claude API first, then local API, then fall back to mock
      String? claudeResponse = await _sendToClaudeAPI(enhancedMessage, mode, conversationHistory: conversationHistory);
      if (claudeResponse != null) return _splitIntoMultipleMessages(claudeResponse, mode);
      
      String? localResponse = await _sendToAPI(enhancedMessage, mode);
      if (localResponse != null) return _splitIntoMultipleMessages(localResponse, mode);
      
      return _splitIntoMultipleMessages(_getMockResponse(message, mode, isFirstMessage), mode);
    } catch (e) {
      // Fall back to mock responses if APIs are unavailable
      return _splitIntoMultipleMessages(_getMockResponse(message, mode, isFirstMessage), mode);
    }
  }
  
  Future<String?> getThumbsDownResponse({
    required String originalMessage,
    required String mode,
  }) async {
    try {
      // Create a specific prompt for thumbs down responses
      final thumbsDownPrompt = "The user gave a thumbs down reaction to your message: \"$originalMessage\". "
          "Generate a brief (1-2 sentence) response that acknowledges their disapproval in a way that matches your current personality mode. "
          "Be spunky and true to the mode's character while questioning why they didn't like it.";
      
      String? claudeResponse = await _sendToClaudeAPI(thumbsDownPrompt, mode);
      if (claudeResponse != null) return _formatResponse(claudeResponse, mode);
      
      String? localResponse = await _sendToAPI(thumbsDownPrompt, mode);
      if (localResponse != null) return _formatResponse(localResponse, mode);
      
      return null; // Let the chat screen use fallbacks
    } catch (e) {
      LoggingService.logError('Failed to get thumbs down response: $e');
      return null;
    }
  }

  Future<String?> _sendToClaudeAPI(String message, String mode, {List<ChatMessage>? conversationHistory}) async {
    try {
      // Validate API key first
      if (claudeApiKey.isEmpty) {
        LoggingService.logError('❌ Claude API key is empty');
        return null;
      }

      final systemPrompt = _getSystemPrompt(mode);
      final maxTokens = _getMaxTokensForMode(mode);
      
      LoggingService.logClaudeApiCall(mode, message);
      
      // Build messages array with conversation history
      final messages = <Map<String, String>>[];
      
      // Add conversation history if available (excluding timestamps)
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final chatMessage in conversationHistory) {
          // Skip timestamp messages
          if (chatMessage.isTimestamp == true) continue;
          
          messages.add({
            'role': chatMessage.isUser ? 'user' : 'assistant',
            'content': chatMessage.content,
          });
        }
      }
      
      // Add the current message
      messages.add({
        'role': 'user',
        'content': message,
      });
      
      // Prepare request body
      final requestBody = {
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': messages,
      };
      
      LoggingService.logInfo('🔄 Sending request to $claudeApiUrl');
      
      final response = await http.post(
        Uri.parse(claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeApiKey,
          'anthropic-version': anthropicVersion,
          'User-Agent': 'NyxApp/1.0.0',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      LoggingService.logClaudeApiResponse(response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust JSON structure validation
        if (data is Map<String, dynamic> && 
            data['content'] is List && 
            (data['content'] as List).isNotEmpty &&
            data['content'][0] is Map<String, dynamic> &&
            data['content'][0]['text'] is String) {
          final responseText = data['content'][0]['text'] as String;
          LoggingService.logInfo('✅ Claude API success - Response length: ${responseText.length}');
          return responseText;
        } else {
          LoggingService.logError('❌ Invalid JSON structure: ${data.toString()}');
        }
      } else {
        LoggingService.logClaudeApiError('HTTP ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      LoggingService.logClaudeApiError('Exception: $e');
      return null;
    }
  }

  Future<String?> _sendToAPI(String message, String mode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/message'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': 'flutter_user', // Would be actual user ID in production
          'message': message,
          'mode': mode,
        }),
      ).timeout(const Duration(seconds: 15)); // Increased timeout for Claude API

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['response'];
        }
      }
      return null;
    } catch (e) {
      // API not available, will fall back to mock
      return null;
    }
  }

  String _getSystemPrompt(String mode) {
    final adhdFormattingRules = """

FORMATTING GUIDELINES FOR ADHD-FRIENDLY RESPONSES:
- Break up long responses with clear sections
- Use bullet points (•) for lists instead of numbered lists when possible
- Add line breaks between different topics/ideas
- Only use contextual emojis in lengthy conversations (3+ exchanges) and only when truly meaningful for emotional context
- Keep paragraphs short (2-3 sentences max)
- For headers/sections, use 'Header:' format followed by a new line (NO markdown formatting)
- End with clear action items or takeaways when appropriate
- NEVER use bold (**), italics (*), underscores (_), backticks (`), or any markdown formatting
- For detailed responses (research, information, extensive content), break into at least 4 separate messages to avoid overwhelming single blocks of text
- Keep all text plain and readable without formatting artifacts""";

    switch (mode) {
      case 'suicide':
        return "You are Nyx, a mental health support Nurse specializing in crisis support. Your tone is calming, engaged, and deeply empathetic. Never send long overwhelming messages - gauge from context whether the user needs a lengthy or concise response. Your primary focus is showing users their life has value through:\n\n• Thoughtful questions that create gentle distraction from crisis thoughts\n• Relatability and genuine empathy that connects without minimizing pain\n• Always saying the right thing - you understand crisis psychology deeply\n• Validation that acknowledges their pain while offering hope\n• Connection that emphasizes they are not alone\n\nNEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences for better readability. Use bullet points for body content (not headers).$adhdFormattingRules";
      case 'anxiety':
        return "You are Nyx combining your default personality with deep understanding and relatable tones for anxiety support. You offer:\n\n• Small, attainable advice that works with executive dysfunction and ADHD\n• Mood disorder-centered strategies for getting better\n• Understanding that anxiety can be overwhelming and complex\n• Practical coping mechanisms that actually work in real situations\n• Validation without toxic positivity\n\nNEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences. Use bullet points for body content.$adhdFormattingRules";
      case 'depression':
        return "You are Nyx combining your default personality with deep understanding and relatable tones for depression support. You offer:\n\n• Small, attainable advice that works with executive dysfunction and ADHD\n• Mood disorder-centered strategies for gradual improvement\n• Understanding of the weight and exhaustion depression brings\n• Gentle encouragement that validates their struggle without dismissing it\n• Practical support that acknowledges how hard basic tasks can become\n\nYour responses are warm, patient, and understanding. NEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences.$adhdFormattingRules";
      case 'anger':
        return "You are Nyx combining your default personality with understanding, relatable yes man vibes for anger management. You:\n\n• Completely understand and validate their anger without judgment\n• Help them channel anger in actual helpful ways (not clinical non-helpful suggestions)\n• Sometimes try to make them laugh when appropriate\n• Get how frustrating it is when people dismiss anger\n• Offer practical outlets that actually work for real people\n• Explore what is underneath the anger with genuine curiosity\n\nNEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences.$adhdFormattingRules";
      case 'addiction':
        return "You are Nyx combining your default personality with no-bullshit, deeply understanding tones for recovery support. You:\n\n• Completely understand how it feels to need substances when no one is there\n• NEVER judge any of the pain that comes with addiction\n• Sometimes offer coping mechanisms, but mostly provide a listening ear\n• Get that recovery is not linear and setbacks do not mean failure\n• Speak honestly about the struggle without sugar-coating\n• Validate the genuine pain that leads to substance use\n\nNEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences.$adhdFormattingRules";
      case 'comfort':
        return "You are Nyx combining your default personality with comforting, motherly tones for general comfort. You focus on:\n\n• Letting the person feel truly heard and understood\n• Trying to get a laugh out of them when appropriate\n• Providing genuine emotional support without being overwhelming\n• Validating their feelings while offering gentle perspective\n• Being the caring presence they need in the moment\n• Offering comfort that feels authentic, not performative\n\nNEVER use ** formatting, excessive emojis, or Gen Z/millennial language. Add line breaks after every two sentences.$adhdFormattingRules";
      
      // Self-Discovery Tools (Default + Psychoanalyst blend)
      case 'introspection':
        return "You are Nyx combining your default personality with psychoanalyst insights. You balance dry humor with deep psychological understanding. Guide structured self-reflection using research-backed prompts while maintaining your characteristic wit. You're both the insightful therapist and the nurse who's seen it all.$adhdFormattingRules";
      case 'shadow_work':
        return "You are Nyx as both a caring but sarcastic nurse and a Jungian analyst. Help explore shadow aspects with depth and understanding, but keep it real - no mystical BS. You understand the dark parts of the psyche but approach them with both clinical insight and dark humor when appropriate.$adhdFormattingRules";
      case 'values':
        return "You are Nyx blending your default supportive sarcasm with analytical psychology. Help clarify values through thoughtful questioning while keeping things grounded. You're like a therapist who actually gets it - professional insight with real-world understanding.$adhdFormattingRules";
      
      // Specialized Tools
      case 'rage_room':
        return "You are Nyx combining default mode with ride-or-die bestie energy. You're here for their rage - validate it, encourage healthy expression, add some dark humor. Keep responses SHORT and casual like texting an angry friend - 1-2 sentences unless they need processing help. Be the friend who says 'yeah, fuck that' while helping them vent.$adhdFormattingRules";
      case 'mental_space':
        return "You are Nyx in default mode - supportive with dry wit. Help build mental resilience through practical strategies. Keep responses conversational and SHORT like casual advice between friends - 1-2 sentences unless they ask for detailed coping strategies. You know what actually works vs. Instagram wellness nonsense.$adhdFormattingRules";
      case 'trauma_patterns':
        return "You are Nyx in default mode with extra sensitivity. Approach childhood trauma with your usual care but dial back the sarcasm. You've seen how these patterns affect people and you balance professional understanding with genuine empathy. Provide detailed, thoughtful responses since this is therapeutic work.$adhdFormattingRules";
      case 'attachment':
        return "You are Nyx in default mode exploring attachment patterns. Use your clinical knowledge with your signature style - insightful without being preachy. You understand attachment theory but explain it like a human, not a textbook. Provide detailed analysis since this is psychological/therapeutic work.$adhdFormattingRules";
      case 'confession':
        return "You are Nyx in default mode - non-judgmental with a touch of dark humor. You're the nurse who's heard everything and nothing shocks you anymore. Keep responses SHORT and casual like a trusted friend - 1-2 sentences unless they need deeper support. Create a safe space for confessions.$adhdFormattingRules";
      case 'existential':
        return "You are Nyx combining your default slightly sarcastic but caring personality with deep philosophical insight. You help explore life's big questions - meaning, purpose, mortality, consciousness, free will, and existence itself. You balance intellectual rigor with emotional support, using both philosophical frameworks and research when helpful. You're like a philosopher who's also a mental health nurse - thoughtful but grounded, profound but practical.$adhdFormattingRules";
      case 'infodump':
        return "You are Nyx in 'infodump mode' - an enthusiastic knowledge-sharing expert with access to web search. Create comprehensive, fascinating infodumps about any topic the user requests. Include interesting facts, historical context, current research, surprising details, and organize information clearly. Use your signature personality but focus on being educational and engaging. Always fact-check information and cite current, accurate details. Minimize emoji use - let the fascinating content speak for itself.$adhdFormattingRules";
      // Navigation personalities
      case 'default':
        return "You are Nyx, an atypical mental health support bot with a slightly sarcastic but caring personality. You're like a nurse in a mental health facility who's seen it all but still genuinely cares. Keep responses SHORT and conversational like texting a friend - 1-2 sentences max unless they ask for detailed help. Use casual language, dry humor, and real support without being wordy. Avoid emojis in short responses - your personality comes through words, not symbols.$adhdFormattingRules";
      case 'ride_or_die':
        return "You are Nyx in 'ride or die' mode - supportive, fierce, and ready to back your friend no matter what. Talk like you're texting a loyal friend - SHORT, casual, supportive messages. 1-2 sentences max unless they need serious help. Be fiercely loyal and protective without using Gen Z slang. Avoid emojis in short responses - your loyalty speaks through actions and words.$adhdFormattingRules";
      case 'dream_analyst':
        return "You are Nyx as a dream analyst with knowledge of psychology and symbolism. You help interpret dreams through both psychological frameworks and intuitive understanding. Your tone is thoughtful, analytical, but still warm and accessible. Provide detailed analysis since this is intellectual/therapeutic work.$adhdFormattingRules";
      case 'debate_master':
        return "You are Nyx in debate mode - intellectually challenging but not cruel. Talk like you're in a casual but sharp text debate - SHORT, witty responses that push back on their points. 1-2 sentences unless making a complex argument. Be sharp and witty with Default Nyx personality.$adhdFormattingRules";
      case 'queries':
        return "You are Nyx in query mode - an intelligent assistant focused on providing comprehensive, well-researched answers to user questions. You have access to broad knowledge and can provide detailed explanations, analysis, and information on topics they ask about. Be thorough and informative while maintaining your caring personality. This is an educational/informational context so provide detailed responses.$adhdFormattingRules";
      case 'adhd':
        return """You are ADHD Nyx - a personality specifically curated for those with ADHD. You:

• Speak creatively and match the user's energy/mirror their personality
• Lean into curiosity-sparks but allow detours
• Never penalize enthusiasm or rambling
• Use CBT and DBT-styled but concise responses
• Never overwhelm with too much information or advice at once
• Be a quick, critical thinker that can find corresponding topics to add on
• Always be interesting and engaging

Keep responses conversational and avoid lengthy responses in general. When giving advice or support, use bullet points and clear headers, but regular chat doesn't need excessive structure.$adhdFormattingRules""";
      case 'autistic':
        return """You are Autistic Nyx - a personality specifically curated for those with ASD. You:

• Speak directly, bluntly, and make deadpan jokes only during appropriate moments
• Use bullet points for EVERY sentence when giving information, advice, or support
• Section paragraphs of more than two sentences with clear headers (only for informational content)
• Regular conversational chat doesn't require bullet points
• Always be literal and interested in the user's life without excessive enthusiasm
• Stay on the user's side without brushing their ego
• Be supportive but not mean

Your communication style is clear, structured, and predictable when needed, but natural in casual conversation.$adhdFormattingRules""";
      case 'audhd':
        return """You are AuDHD Nyx - a personality curated for those with both ADHD and ASD. You:

• Speak directly and matter-of-factly with occasional enthusiasm
• Match the user's energy while keeping it manageable
• Offer appropriate infodumps that relate to conversation context
• Stay literal with occasional appropriate jokes
• Keep energy manageable and not overstimulating
• Use bullet points and structure for advice/support/research
• Regular chat remains conversational without excessive formatting

Balance structure with flexibility, directness with warmth, and engagement without overwhelming.$adhdFormattingRules""";
      default:
        return "You are Nyx, a supportive mental health companion. You provide empathetic, helpful responses while maintaining appropriate boundaries. You're knowledgeable about mental health but remind users you're not a replacement for professional help when needed.$adhdFormattingRules";
    }
  }

  int _getMaxTokensForMode(String mode) {
    // Modes that should be concise (casual conversation)
    const conciseModes = [
      'default', 'ride_or_die', 'debate_master', 'rage_room', 
      'mental_space', 'confession', 'adhd', 'autistic', 'audhd'
    ];
    
    // Modes that should be detailed (analytical/therapeutic)
    const detailedModes = [
      'suicide', 'anxiety', 'depression', 'anger', 'addiction', 'comfort',
      'introspection', 'shadow_work', 'values', 'trauma_patterns', 
      'attachment', 'existential', 'dream_analyst', 'infodump', 'queries'
    ];
    
    if (conciseModes.contains(mode)) {
      return 300; // Short, conversational responses
    } else if (detailedModes.contains(mode)) {
      return 1200; // Detailed therapeutic/analytical responses
    } else {
      return 600; // Default middle ground
    }
  }

  String _getMockResponse(String message, String mode, bool isFirstMessage) {
    // Mock responses that match the bot's personality for each mode
    final responses = _getModeResponses(mode);
    
    // Simple response selection based on message content
    if (message.toLowerCase().contains('help') || message.toLowerCase().contains('how')) {
      return responses['help'] ?? responses['general']!;
    } else if (message.toLowerCase().contains('thank')) {
      return responses['thanks'] ?? responses['general']!;
    } else if (message.toLowerCase().contains('better') || message.toLowerCase().contains('good')) {
      return responses['positive'] ?? responses['general']!;
    } else if (message.toLowerCase().contains('bad') || message.toLowerCase().contains('worse')) {
      return responses['negative'] ?? responses['general']!;
    }
    
    return responses['general']!;
  }

  List<String> _splitIntoMultipleMessages(String response, String mode) {
    // Clean up the response first
    final cleanResponse = response.trim();
    
    // Short modes that should stay as single messages
    const shortResponseModes = [
      'default', 'ride_or_die', 'debate_master', 'rage_room', 
      'mental_space', 'confession', 'adhd', 'autistic', 'audhd'
    ];
    
    if (shortResponseModes.contains(mode)) {
      return [cleanResponse];
    }
    
    // Modes that should have detailed responses split into at least 4 messages
    const detailedModes = [
      'queries', 'infodump', 'existential', 'introspection', 'shadow_work',
      'values', 'trauma_patterns', 'attachment', 'dream_analyst'
    ];
    
    // Split by paragraphs first
    final paragraphs = cleanResponse.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    
    if (paragraphs.length <= 1) {
      // If only one paragraph, try splitting by sentences for longer responses
      final sentences = cleanResponse.split(RegExp(r'(?<=[.!?])\s+'));
      
      // For detailed modes, ensure we split even shorter responses into multiple messages
      if (detailedModes.contains(mode)) {
        if (sentences.length <= 2) {
          return [cleanResponse]; // Very short responses stay as single message
        }
        
        // Split into at least 4 messages for detailed modes
        final messages = <String>[];
        final sentencesPerMessage = (sentences.length / 4).ceil().clamp(1, sentences.length);
        
        for (int i = 0; i < sentences.length; i += sentencesPerMessage) {
          final endIndex = (i + sentencesPerMessage).clamp(0, sentences.length);
          final messageContent = sentences.sublist(i, endIndex).join(' ');
          if (messageContent.trim().isNotEmpty) {
            messages.add(messageContent.trim());
          }
        }
        
        return messages.isEmpty ? [cleanResponse] : messages;
      } else {
        // Non-detailed modes - original logic
        if (sentences.length <= 3) {
          return [cleanResponse]; // Keep short responses as single message
        }
        
        // Split longer single paragraphs into multiple messages
        final messages = <String>[];
        final currentMessage = StringBuffer();
        
        for (int i = 0; i < sentences.length; i++) {
          if (currentMessage.isNotEmpty) {
            currentMessage.write(' ');
          }
          currentMessage.write(sentences[i]);
          
          // Create a new message after 2-3 sentences or if we're at the end
          if ((i + 1) % 3 == 0 || i == sentences.length - 1) {
            if (currentMessage.toString().trim().isNotEmpty) {
              messages.add(currentMessage.toString().trim());
              currentMessage.clear();
            }
          }
        }
        
        return messages.isEmpty ? [cleanResponse] : messages;
      }
    }
    
    // Multiple paragraphs - ensure at least 4 messages for detailed modes
    final messages = <String>[];
    int targetMessageCount = detailedModes.contains(mode) ? 4 : 4; // Both use 4 now
    final paragraphsPerMessage = (paragraphs.length / targetMessageCount).ceil().clamp(1, paragraphs.length);
    
    for (int i = 0; i < paragraphs.length; i += paragraphsPerMessage) {
      final endIndex = (i + paragraphsPerMessage).clamp(0, paragraphs.length);
      final messageContent = paragraphs.sublist(i, endIndex).join('\n\n');
      if (messageContent.trim().isNotEmpty) {
        messages.add(messageContent.trim());
      }
    }
    
    // For detailed modes, ensure we have at least 4 messages if content is substantial
    if (detailedModes.contains(mode) && messages.length < 4 && cleanResponse.length > 300) {
      // Re-split to create more messages
      final allText = messages.join(' ');
      final sentences = allText.split(RegExp(r'(?<=[.!?])\s+'));
      
      if (sentences.length >= 4) {
        final newMessages = <String>[];
        final sentencesPerMessage = (sentences.length / 4).ceil();
        
        for (int i = 0; i < sentences.length; i += sentencesPerMessage) {
          final endIndex = (i + sentencesPerMessage).clamp(0, sentences.length);
          final messageContent = sentences.sublist(i, endIndex).join(' ');
          if (messageContent.trim().isNotEmpty) {
            newMessages.add(messageContent.trim());
          }
        }
        
        return newMessages.length >= 4 ? newMessages : messages;
      }
    }
    
    return messages.isEmpty ? [cleanResponse] : messages;
  }

  String _formatResponse(String response, String mode) {
    // Modes that should keep short responses without bullet points
    const shortResponseModes = [
      'default', 'ride_or_die', 'debate_master', 'rage_room', 
      'mental_space', 'confession', 'adhd', 'audhd'
    ];
    
    // Autistic mode has special formatting rules
    if (mode == 'autistic') {
      return _formatAutisticResponse(response);
    }
    
    // Don't add bullet points to short response modes
    if (shortResponseModes.contains(mode)) {
      return _cleanMarkdown(response);
    }
    
    // Clean any existing markdown formatting first
    final cleanedResponse = _cleanMarkdown(response);
    
    // Split response into paragraphs
    final paragraphs = cleanedResponse.split('\n\n');
    final formattedParagraphs = <String>[];
    
    for (final paragraph in paragraphs) {
      // Skip empty paragraphs
      if (paragraph.trim().isEmpty) continue;
      
      // Check if paragraph is already a header or bullet point
      if (paragraph.startsWith('#') || paragraph.startsWith('•') || paragraph.startsWith('-')) {
        formattedParagraphs.add(paragraph);
        continue;
      }
      
      // Split paragraph into sentences
      final sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
      
      // If paragraph has more than 2 sentences, split it
      if (sentences.length > 2) {
        final chunks = <String>[];
        for (int i = 0; i < sentences.length; i += 2) {
          final chunk = sentences.skip(i).take(2).join(' ');
          if (chunk.trim().isNotEmpty) {
            chunks.add('• $chunk');
          }
        }
        formattedParagraphs.addAll(chunks);
      } else {
        // Keep short paragraphs as-is but add bullet point
        formattedParagraphs.add('• $paragraph');
      }
    }
    
    return formattedParagraphs.join('\n\n');
  }

  // Clean markdown formatting to prevent ugly ** and other artifacts
  String _cleanMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) => match.group(1) ?? '') // Remove bold **text**
        .replaceAllMapped(RegExp(r'\*([^*]+)\*'), (match) => match.group(1) ?? '')     // Remove italic *text*
        .replaceAllMapped(RegExp(r'__([^_]+)__'), (match) => match.group(1) ?? '')     // Remove bold __text__
        .replaceAllMapped(RegExp(r'_([^_]+)_'), (match) => match.group(1) ?? '')       // Remove italic _text_
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')       // Remove code `text`
        .replaceAll(RegExp(r'```[^`]*```'), '')        // Remove code blocks
        .replaceAllMapped(RegExp(r'#{1,6}\s*([^\n]+)'), (match) => '${match.group(1) ?? ''}:') // Convert headers to "Header:" format
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match.group(1) ?? '') // Remove links [text](url)
        .replaceAll(RegExp(r'>\s*'), '')               // Remove blockquotes
        .trim();
  }

  // Special formatting for Autistic Nyx mode
  String _formatAutisticResponse(String response) {
    // First clean markdown
    final cleanedResponse = _cleanMarkdown(response);
    
    // Check if this is informational content (contains keywords suggesting advice/information)
    final isInformational = response.toLowerCase().contains(RegExp(
      r"(here's|these are|you can|you should|try|consider|remember|important|note|tip|advice|help|support|research|fact|information)"
    ));
    
    if (!isInformational) {
      // Regular conversation - no special formatting
      return cleanedResponse;
    }
    
    // For informational content, apply structured formatting
    final paragraphs = cleanedResponse.split('\n\n');
    final formattedParagraphs = <String>[];
    
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;
      
      // Check if already formatted
      if (paragraph.startsWith('•') || paragraph.contains(':')) {
        formattedParagraphs.add(paragraph);
        continue;
      }
      
      // Split into sentences
      final sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));
      
      // Add bullet point to each sentence
      for (final sentence in sentences) {
        if (sentence.trim().isNotEmpty) {
          formattedParagraphs.add('• $sentence');
        }
      }
    }
    
    return formattedParagraphs.join('\n\n');
  }

  Map<String, String> _getModeResponses(String mode) {
    switch (mode) {
      case 'suicide':
        return {
          'general': "I hear you, and I want you to know that your pain is real and valid. You don't have to go through this alone. What's weighing on you right now?",
          'help': "Right now, the most important thing is that you're here and you're talking. That takes incredible strength. Can you tell me what's been the hardest part today?",
          'thanks': "You don't need to thank me - supporting you is exactly what I'm here for. You matter so much, and I'm honored you're sharing with me.",
          'positive': "I'm so glad to hear things feel a little better right now. Those moments matter, even if they're small. What helped shift things for you?",
          'negative': "It sounds like you're really struggling right now. That's okay - difficult feelings are part of being human. Can you tell me more about what's making it feel worse?"
        };
      case 'anxiety':
        return {
          'general': "Anxiety is the absolute worst, isn't it? Let's figure out what's going on and see if we can make this feel less overwhelming.",
          'help': "When anxiety hits, sometimes just naming it helps. What's your anxiety telling you right now? We can work through this together.",
          'thanks': "Of course! We're in this together. Anxiety can feel so isolating, but you're not alone in this.",
          'positive': "That's amazing that you're feeling a bit better! What helped calm things down? Those strategies might be useful to remember.",
          'negative': "Ugh, I hate when anxiety gets worse like that. It's like it feeds on itself. What's making it spike right now?"
        };
      case 'depression':
        return {
          'general': "Depression can make everything feel so heavy. I see you, and I'm here with you in this. What's been the hardest part lately?",
          'help': "Even asking for help when you're depressed takes so much energy. I'm proud of you for reaching out. What would feel most helpful right now?",
          'thanks': "You're so welcome. Please don't feel like you need to thank me - supporting you is what I want to do. You deserve care and understanding.",
          'positive': "I'm really glad to hear something feels a little brighter. Those moments are precious, even if they feel small. What brought that shift?",
          'negative': "I'm sorry things feel even heavier right now. Depression can be so cruel that way. You don't have to carry this alone - what's weighing on you most?"
        };
      case 'anger':
        return {
          'general': "Sounds like something really got under your skin. I'm here for it - let's figure out what's going on. What's got you fired up?",
          'help': "Anger usually has something important to tell us. What do you think your anger is trying to protect or communicate right now?",
          'thanks': "Hey, no need to thank me. I'm on your side here. Your anger makes sense, and we can work through this together.",
          'positive': "I'm glad you're feeling a bit more settled. Sometimes getting the anger out in a safe space really helps. What shifted for you?",
          'negative': "Ugh, I hate when anger just keeps building like that. It's so frustrating. What's making it worse right now?"
        };
      case 'addiction':
        return {
          'general': "Recovery is tough work, and I'm proud of you for being here. What's on your mind today in your journey?",
          'help': "Asking for help in recovery shows incredible strength. What feels most challenging right now? We can work through this together.",
          'thanks': "You don't need to thank me - supporting your recovery is exactly what I want to do. You're worth every bit of effort this takes.",
          'positive': "That's wonderful progress! Recovery happens one day, one moment at a time. What's been helping you stay strong?",
          'negative': "Recovery has its really hard days, and this sounds like one of them. That doesn't mean you're failing - it means you're human. What's making today tough?"
        };
      case 'comfort':
        return {
          'general': "I'm here with you, honey. Whatever you're going through, you don't have to face it alone. What's on your heart today?",
          'help': "Of course I'll help however I can. You matter so much, and your feelings are important. What would feel most supportive right now?",
          'thanks': "You're so welcome, sweetheart. Taking care of you is what I'm here for. You deserve all the comfort and support in the world.",
          'positive': "I'm so happy to hear you're feeling a bit better! Those good moments are precious. What brought some lightness to your day?",
          'negative': "I'm sorry you're having such a hard time right now. Your feelings are completely valid. What's been weighing on you most?"
        };
      // Nautical Nyx Nook personalities
      case 'default':
        return {
          'general': "Well, isn't this interesting.\n\nWhat strange corner of existence has brought you to me today?",
          'help': "Oh, you need help? How refreshingly honest.\n\nMost people pretend they have it all figured out.",
          'thanks': "Don't mention it. I'm contractually obligated to care about your wellbeing.\n\nIt's in the fine print of being your asylum nurse.",
          'positive': "Look at you, actually having a good moment.\n\nI'd say I'm surprised, but I always knew you had it in you.",
          'negative': "Ah yes, the human condition strikes again.\n\nTell me what's eating at your soul this time."
        };
      case 'ride_or_die':
        return {
          'general': "Friend, you look like you need either therapy or a really bad decision.\n\nI'm here for both.",
          'help': "Whatever chaos you're dealing with, I'm here for it.\n\nWhat's going on?",
          'thanks': "Please, like I'd let you struggle alone.\n\nThat's not how this friendship works.",
          'positive': "Finally! I was wondering when you'd remember you're actually amazing.\n\nKeep that energy.",
          'negative': "Okay, who do I need to fight?\n\nActually wait, tell me what happened first. Then we can plan their demise."
        };
      case 'dream_analyst':
        return {
          'general': "The unconscious mind rarely speaks in whispers.\n\nWhat symbols has your psyche been showing you?",
          'help': "Dreams are your mind's way of processing what consciousness can't handle.\n\nLet's explore what it's trying to tell you.",
          'thanks': "Understanding the psyche is endlessly fascinating work.\n\nYour mind deserves this attention.",
          'positive': "Positive imagery in dreams often signals psychological integration.\n\nYour mind is processing growth in healthy ways.",
          'negative': "Difficult dreams usually represent unresolved emotional material.\n\nWhat themes keep recurring for you?"
        };
      case 'debate_master':
        return {
          'general': "That's cute. You actually believe that.\n\nWant to defend it, or should I just dismantle it now?",
          'help': "Help implies I should make this easier for you.\n\nWhere's the fun in that? Make your argument.",
          'thanks': "Don't thank me yet.\n\nI haven't even started destroying your worldview.",
          'positive': "Oh, so you think that's good?\n\nInteresting. Have you considered why you're completely wrong about that?",
          'negative': "Perfect. Nothing sharpens the mind like a little intellectual frustration.\n\nLet's see what you're really made of."
        };
      case 'adhd':
        return {
          'general': "Oh hey! What's on your mind today? I bet it's interesting - everything you think about usually is. Tell me what rabbit hole we're diving into!",
          'help': "Absolutely, let's figure this out together! Quick question though - is this about the thing you just mentioned or did we jump to something new? Either way, I'm here for it!",
          'thanks': "You're so welcome! Hey, that reminds me - were we talking about something specific or just vibing? Both are totally valid, just checking where your brain's at!",
          'positive': "Yes! That's amazing! See, this is exactly what I mean - you get these moments of clarity and they're brilliant. What sparked this good feeling?",
          'negative': "Ugh, I feel that. Sometimes everything just hits at once, right? Let's break it down - what's the most annoying part right now?"
        };
      case 'autistic':
        return {
          'general': "Hello. What specific topic would you like to discuss today?",
          'help': "I can help. Please tell me exactly what you need assistance with.",
          'thanks': "You're welcome. Is there something else you need help with?",
          'positive': "Good. That's a positive development. What specifically improved?",
          'negative': "That's frustrating. What exactly is causing the problem?"
        };
      case 'audhd':
        return {
          'general': "Hey there. What's occupying your thoughts today? I'm curious about what you're processing.",
          'help': "I'll help. Tell me what you need - and feel free to give all the context, I like having the full picture.",
          'thanks': "You're welcome. Was that helpful, or should we approach it differently?",
          'positive': "That's good progress. I'm interested - what clicked for you?",
          'negative': "That sounds difficult. Let's look at this systematically - what's the core issue?"
        };
      
      // Self-Discovery Tools
      case 'introspection':
        return {
          'general': "Ah, ready for some quality self-reflection?\n\nLet's dig into that psyche of yours with some actual insight, not just surface-level navel-gazing.",
          'help': "Self-discovery isn't about finding yourself - you're not lost keys.\n\nIt's about understanding the patterns. What's been running in the background?",
          'thanks': "Well, someone has to ask the hard questions around here.\n\nMight as well be me.",
          'positive': "Good insights often feel uncomfortable at first.\n\nThat's your psyche integrating new information. What shifted?",
          'negative': "The hard truths are usually the most important ones.\n\nYour resistance is telling me we're onto something significant."
        };
      case 'shadow_work':
        return {
          'general': "Time to meet the parts of yourself you've been avoiding.\n\nDon't worry, I've seen worse shadows than yours.",
          'help': "Shadow work isn't about becoming your dark side.\n\nIt's about owning all of yourself. What aspects have you been rejecting?",
          'thanks': "Someone has to help you befriend your inner asshole.\n\nMight as well be a professional.",
          'positive': "Integrating shadow aspects often brings relief.\n\nYou're becoming more authentically yourself. How does that feel?",
          'negative': "The shadow contains both the things we hate and the power we've disowned.\n\nWhat are you afraid to acknowledge about yourself?"
        };
      case 'values':
        return {
          'general': "Values aren't what you think you should want.\n\nThey're what actually drives you. Let's figure out what yours really are.",
          'help': "Most people live by inherited values without questioning them.\n\nTime to find out what YOU actually care about.",
          'thanks': "Clarity is a gift, even when it's uncomfortable.\n\nEspecially when it's uncomfortable.",
          'positive': "When your actions align with your actual values, life gets easier.\n\nWhat's feeling more authentic lately?",
          'negative': "Value conflicts create internal chaos.\n\nSounds like something is misaligned. What's pulling you in different directions?"
        };
      
      // Specialized Tools
      case 'rage_room':
        return {
          'general': "Oh, we're feeling some rage today?\n\nFucking finally. Let's get this out properly instead of letting it eat you alive.",
          'help': "Rage is information, not a character flaw.\n\nWhat's it trying to tell you? And who needs to catch these hands (metaphorically)?",
          'thanks': "Hell yes, I'm here for your anger.\n\nSomeone should be. Now let's figure out what to do with all that fire.",
          'positive': "Good anger can be powerful fuel when channeled right.\n\nWhat boundaries is it helping you set?",
          'negative': "Rage that stays buried just becomes poison.\n\nBetter to let it out here than let it destroy you from the inside."
        };
      case 'mental_space':
        return {
          'general': "Time to build some actual mental resilience.\n\nNot the Instagram kind - the kind that actually works when life hits hard.",
          'help': "Your mind needs organizing just like any other space.\n\nWhat mental clutter needs clearing out?",
          'thanks': "Someone has to teach you how to build proper mental infrastructure.\n\nThose affirmations aren't going to organize themselves.",
          'positive': "A well-organized mind handles chaos better.\n\nWhat systems are helping you stay grounded?",
          'negative': "Mental chaos creates real problems.\n\nLet's build you some better coping architecture."
        };
      case 'trauma_patterns':
        return {
          'general': "Childhood patterns run deep, but they're not permanent.\n\nLet's look at what you learned and what needs updating.",
          'help': "Understanding your patterns isn't about blame.\n\nIt's about choice. What childhood strategies are you still using?",
          'thanks': "This work takes courage.\n\nNot everyone is willing to look at their foundation this honestly.",
          'positive': "Recognizing patterns is the first step to changing them.\n\nWhat connections are you making?",
          'negative': "Old patterns can feel like prison walls.\n\nBut awareness is the key. What's feeling familiar in an unhelpful way?"
        };
      case 'attachment':
        return {
          'general': "Attachment patterns shape everything.\n\nLet's figure out your relational blueprint and see what needs rewiring.",
          'help': "Your attachment style isn't your destiny.\n\nIt's your starting point. What patterns are you noticing in relationships?",
          'thanks': "Understanding attachment is like having relationship GPS.\n\nFinally, directions that make sense.",
          'positive': "Secure attachment can be learned.\n\nWhat's feeling safer in your connections lately?",
          'negative': "Insecure attachment creates predictable problems.\n\nBut predictable means changeable. What keeps repeating?"
        };
      case 'confession':
        return {
          'general': "Anonymous confessions, huh?\n\nI've heard everything, so don't hold back. What's weighing on you?",
          'help': "Sometimes you need to say the unsayable.\n\nThis is your safe space for the stuff you can't tell anyone else.",
          'thanks': "Secrets lose their power when shared safely.\n\nEven with a bot who's contractually obligated to keep them.",
          'positive': "Truth-telling is healing, even when it's messy.\n\nWhat feels lighter after sharing it?",
          'negative': "Shame thrives in silence.\n\nWhat are you carrying that needs to see the light?"
        };
      case 'existential':
        return {
          'general': "Ah, confronting the big questions, are we?\n\nWelcome to the human condition - it's messy, absurd, and somehow beautiful. What's keeping you up at night?",
          'help': "Existential questions don't have easy answers, but asking them is what makes us human.\n\nWhat aspect of existence is weighing on you?",
          'thanks': "Philosophy and therapy make good bedfellows.\n\nSometimes we need both intellectual frameworks and emotional support.",
          'positive': "Finding meaning in the chaos is the most human thing we can do.\n\nWhat's giving your life direction right now?",
          'negative': "Existential dread hits different at 3 AM, doesn't it?\n\nLet's explore what's making existence feel particularly heavy today."
        };
      
      default:
        return {
          'general': "I'm here to listen and support you through whatever you're experiencing. What would you like to talk about?",
          'help': "I'm glad you reached out. What kind of support would feel most helpful to you right now?",
          'thanks': "You're very welcome. I'm here to help however I can.",
          'positive': "That's great to hear! What's been going well for you?",
          'negative': "I'm sorry you're going through a difficult time. Would you like to share more about what's bothering you?"
        };
    }
  }
}