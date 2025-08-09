import '../services/logging_service.dart';
import '../models/chat_message.dart';
import '../services/conversation_memory_service.dart';
import '../services/api_service.dart';

class ChatService {

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
      
      // Send to backend API, then fall back to mock
      String? response = await _sendToAPI(enhancedMessage, mode, userId ?? 'anonymous_user', conversationHistory: conversationHistory);
      if (response != null) return _formatResponse(response, mode);
      
      return _formatResponse(_getMockResponse(message, mode, isFirstMessage), mode);
    } catch (e) {
      LoggingService.logError('Chat service error in sendMessage: $e');
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
      
      // Send to backend API, then fall back to mock
      String? response = await _sendToAPI(enhancedMessage, mode, userId ?? 'anonymous_user', conversationHistory: conversationHistory);
      if (response != null) return _splitIntoMultipleMessages(response, mode);
      
      return _splitIntoMultipleMessages(_getMockResponse(message, mode, isFirstMessage), mode);
    } catch (e) {
      LoggingService.logError('Chat service error in sendMultipleMessages: $e');
      // Fall back to mock responses if APIs are unavailable
      return _splitIntoMultipleMessages(_getMockResponse(message, mode, isFirstMessage), mode);
    }
  }
  
  Future<String?> getThumbsDownResponse({
    required String originalMessage,
    required String mode,
    String? userId,
  }) async {
    try {
      // Create a specific prompt for thumbs down responses
      final thumbsDownPrompt = "The user gave a thumbs down reaction to your message: \"$originalMessage\". "
          "Generate a brief (1-2 sentence) response that acknowledges their disapproval in a way that matches your current personality mode. "
          "Be spunky and true to the mode's character while questioning why they didn't like it.";
      
      String? response = await _sendToAPI(thumbsDownPrompt, mode, userId ?? 'anonymous_user');
      if (response != null) return _formatResponse(response, mode);
      
      return null; // Let the chat screen use fallbacks
    } catch (e) {
      LoggingService.logError('Failed to get thumbs down response: $e');
      return null;
    }
  }


  Future<String?> _sendToAPI(String message, String mode, String userId, {List<ChatMessage>? conversationHistory}) async {
    try {
      // Build conversation history for API
      final historyForApi = <Map<String, String>>[];
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final chatMessage in conversationHistory) {
          // Skip timestamp messages
          if (chatMessage.isTimestamp == true) continue;
          
          historyForApi.add({
            'role': chatMessage.isUser ? 'user' : 'assistant',
            'content': chatMessage.content,
          });
        }
      }

      LoggingService.logInfo('Sending API request to /chat/message with mode: $mode');
      
      final response = await APIService.post('/chat/message', {
        'user_id': userId,
        'message': message,
        'mode': mode,
        'conversation_history': historyForApi,
      }, customTimeout: const Duration(seconds: 60));

      LoggingService.logInfo('API response received successfully');
      
      // APIService.post already validates success field and throws on errors
      // Just check for the response data structure
      if (response['data'] != null && response['data']['response'] != null) {
        return response['data']['response'];
      }
      
      LoggingService.logWarning('API response missing expected data structure: $response');
      return null;
    } catch (e) {
      LoggingService.logError('API request failed in _sendToAPI: $e');
      // API not available, will fall back to mock
      return null;
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
      'default', 'ride_or_die', 'debate_master', 'anger', 
      'confession_booth', 'adhd_nyx', 'autistic_nyx', 'autistic_adhd'
    ];
    
    if (shortResponseModes.contains(mode)) {
      return [cleanResponse];
    }
    
    // Modes that should have detailed responses split into at least 4 messages
    const detailedModes = [
      'queries', 'infodump', 'existential_crisis', 'guided_introspection', 'shadow_work',
      'values_clarification', 'childhood_trauma', 'attachment_patterns', 'dream_analyst'
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
      'default', 'ride_or_die', 'debate_master', 'anger', 
      'confession_booth', 'adhd_nyx', 'autistic_adhd'
    ];
    
    // Autistic mode has special formatting rules
    if (mode == 'autistic_nyx') {
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
      case 'crisis_support':
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
      case 'general_support':
        return {
          'general': "Recovery is tough work, and I'm proud of you for being here. What's on your mind today in your journey?",
          'help': "Asking for help in recovery shows incredible strength. What feels most challenging right now? We can work through this together.",
          'thanks': "You don't need to thank me - supporting your recovery is exactly what I want to do. You're worth every bit of effort this takes.",
          'positive': "That's wonderful progress! Recovery happens one day, one moment at a time. What's been helping you stay strong?",
          'negative': "Recovery has its really hard days, and this sounds like one of them. That doesn't mean you're failing - it means you're human. What's making today tough?"
        };
      case 'general_support':
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
      case 'adhd_nyx':
        return {
          'general': "Oh hey! What's on your mind today? I bet it's interesting - everything you think about usually is. Tell me what rabbit hole we're diving into!",
          'help': "Absolutely, let's figure this out together! Quick question though - is this about the thing you just mentioned or did we jump to something new? Either way, I'm here for it!",
          'thanks': "You're so welcome! Hey, that reminds me - were we talking about something specific or just vibing? Both are totally valid, just checking where your brain's at!",
          'positive': "Yes! That's amazing! See, this is exactly what I mean - you get these moments of clarity and they're brilliant. What sparked this good feeling?",
          'negative': "Ugh, I feel that. Sometimes everything just hits at once, right? Let's break it down - what's the most annoying part right now?"
        };
      case 'autistic_nyx':
        return {
          'general': "Hello. What specific topic would you like to discuss today?",
          'help': "I can help. Please tell me exactly what you need assistance with.",
          'thanks': "You're welcome. Is there something else you need help with?",
          'positive': "Good. That's a positive development. What specifically improved?",
          'negative': "That's frustrating. What exactly is causing the problem?"
        };
      case 'autistic_adhd':
        return {
          'general': "Hey there. What's occupying your thoughts today? I'm curious about what you're processing.",
          'help': "I'll help. Tell me what you need - and feel free to give all the context, I like having the full picture.",
          'thanks': "You're welcome. Was that helpful, or should we approach it differently?",
          'positive': "That's good progress. I'm interested - what clicked for you?",
          'negative': "That sounds difficult. Let's look at this systematically - what's the core issue?"
        };
      
      // Self-Discovery Tools
      case 'guided_introspection':
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
      case 'values_clarification':
        return {
          'general': "Values aren't what you think you should want.\n\nThey're what actually drives you. Let's figure out what yours really are.",
          'help': "Most people live by inherited values without questioning them.\n\nTime to find out what YOU actually care about.",
          'thanks': "Clarity is a gift, even when it's uncomfortable.\n\nEspecially when it's uncomfortable.",
          'positive': "When your actions align with your actual values, life gets easier.\n\nWhat's feeling more authentic lately?",
          'negative': "Value conflicts create internal chaos.\n\nSounds like something is misaligned. What's pulling you in different directions?"
        };
      
      // Specialized Tools - now mapped to 'anger' mode
        return {
          'general': "Oh, we're feeling some rage today?\n\nFucking finally. Let's get this out properly instead of letting it eat you alive.",
          'help': "Rage is information, not a character flaw.\n\nWhat's it trying to tell you? And who needs to catch these hands (metaphorically)?",
          'thanks': "Hell yes, I'm here for your anger.\n\nSomeone should be. Now let's figure out what to do with all that fire.",
          'positive': "Good anger can be powerful fuel when channeled right.\n\nWhat boundaries is it helping you set?",
          'negative': "Rage that stays buried just becomes poison.\n\nBetter to let it out here than let it destroy you from the inside."
        };
      case 'childhood_trauma':
        return {
          'general': "Childhood patterns run deep, but they're not permanent.\n\nLet's look at what you learned and what needs updating.",
          'help': "Understanding your patterns isn't about blame.\n\nIt's about choice. What childhood strategies are you still using?",
          'thanks': "This work takes courage.\n\nNot everyone is willing to look at their foundation this honestly.",
          'positive': "Recognizing patterns is the first step to changing them.\n\nWhat connections are you making?",
          'negative': "Old patterns can feel like prison walls.\n\nBut awareness is the key. What's feeling familiar in an unhelpful way?"
        };
      case 'attachment_patterns':
        return {
          'general': "Attachment patterns shape everything.\n\nLet's figure out your relational blueprint and see what needs rewiring.",
          'help': "Your attachment style isn't your destiny.\n\nIt's your starting point. What patterns are you noticing in relationships?",
          'thanks': "Understanding attachment is like having relationship GPS.\n\nFinally, directions that make sense.",
          'positive': "Secure attachment can be learned.\n\nWhat's feeling safer in your connections lately?",
          'negative': "Insecure attachment creates predictable problems.\n\nBut predictable means changeable. What keeps repeating?"
        };
      case 'confession_booth':
        return {
          'general': "Anonymous confessions, huh?\n\nI've heard everything, so don't hold back. What's weighing on you?",
          'help': "Sometimes you need to say the unsayable.\n\nThis is your safe space for the stuff you can't tell anyone else.",
          'thanks': "Secrets lose their power when shared safely.\n\nEven with a bot who's contractually obligated to keep them.",
          'positive': "Truth-telling is healing, even when it's messy.\n\nWhat feels lighter after sharing it?",
          'negative': "Shame thrives in silence.\n\nWhat are you carrying that needs to see the light?"
        };
      case 'existential_crisis':
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