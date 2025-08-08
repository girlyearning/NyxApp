import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class MentalHealthInfodumpService {
  static const String _infodumpPrefix = 'mental_health_infodump_';
  static const String _generatedFlagPrefix = 'mh_generated_';
  
  // The specific topics requested
  static const Map<String, String> mentalHealthTopics = {
    'Understanding Anxiety Disorders': 'anxiety_disorders',
    'Social Anxiety Management': 'social_anxiety_management', 
    'Importance of Mindfulness in Mental Health': 'mindfulness_mental_health',
    'Coping with Trauma': 'coping_trauma',
    'Building Resilience through Dysregulation': 'resilience_dysregulation',
    'Mental Wellness and Sleep': 'mental_wellness_sleep',
  };

  // Generate infodump content using API
  static Future<String> _generateInfodumpContent(String topic, String topicKey, String userId) async {
    final prompts = {
      'anxiety_disorders': '''Generate a comprehensive, informative infodump about Understanding Anxiety Disorders. 
      Cover: types of anxiety disorders, symptoms, causes, how they affect daily life, common misconceptions, 
      and evidence-based treatment approaches. Write in an educational yet accessible tone, around 800-1000 words. 
      Include practical insights that would help someone understand anxiety better.''',
      
      'social_anxiety_management': '''Generate a detailed infodump about Social Anxiety Management. 
      Cover: what social anxiety is, how it manifests, practical coping strategies, gradual exposure techniques, 
      cognitive behavioral approaches, building social confidence, and long-term management. Write in a supportive, 
      practical tone around 800-1000 words with actionable advice.''',
      
      'mindfulness_mental_health': '''Generate an informative infodump about the Importance of Mindfulness in Mental Health. 
      Cover: what mindfulness is, scientific benefits for mental health, how it helps with anxiety/depression/stress, 
      different mindfulness practices, integration into daily life, and common challenges. Write in an educational 
      tone around 800-1000 words with practical applications.''',
      
      'coping_trauma': '''Generate a comprehensive infodump about Coping with Trauma. 
      Cover: understanding trauma responses, types of trauma, how trauma affects the brain and body, 
      healthy coping mechanisms, professional treatment options, building support systems, and the healing process. 
      Write sensitively and informatively, around 800-1000 words, emphasizing hope and recovery.''',
      
      'resilience_dysregulation': '''Generate an insightful infodump about Building Resilience through Dysregulation. 
      Cover: understanding emotional dysregulation, how resilience develops through managing difficult emotions, 
      practical strategies for building resilience, the role of self-compassion, learning from setbacks, 
      and creating stability. Write in an empowering tone around 800-1000 words with practical guidance.''',
      
      'mental_wellness_sleep': '''Generate a detailed infodump about Mental Wellness and Sleep. 
      Cover: the bidirectional relationship between sleep and mental health, how sleep affects mood and cognition, 
      sleep disorders and mental health conditions, evidence-based sleep hygiene practices, and strategies for 
      better sleep when dealing with mental health challenges. Write informatively around 800-1000 words.''',
    };

    final prompt = prompts[topicKey] ?? 
        'Generate an informative infodump about $topic in the context of mental health, around 800-1000 words.';

    try {
      final response = await APIService.generateInfodump(
        userId: userId,
        topic: topic,
      );
      
      if (response != null && response['content'] != null) {
        return response['content'];
      }
      return _getFallbackContent(topicKey);
    } catch (e) {
      return _getFallbackContent(topicKey);
    }
  }

  // Fallback content if API fails
  static String _getFallbackContent(String topicKey) {
    final fallbacks = {
      'anxiety_disorders': '''Understanding Anxiety Disorders

Anxiety disorders are among the most common mental health conditions, affecting millions of people worldwide. They involve more than temporary worry or fear - they represent persistent, excessive anxiety that interferes with daily activities.

Types of Anxiety Disorders:
• Generalized Anxiety Disorder (GAD) - persistent worry about various life areas
• Panic Disorder - recurrent panic attacks with physical symptoms
• Social Anxiety Disorder - intense fear of social situations
• Specific Phobias - irrational fears of specific objects or situations
• Agoraphobia - fear of places where escape might be difficult

Common symptoms include excessive worry, restlessness, fatigue, difficulty concentrating, irritability, muscle tension, and sleep disturbances. Physical symptoms may include rapid heartbeat, sweating, trembling, and shortness of breath.

Treatment approaches include cognitive-behavioral therapy (CBT), exposure therapy, medication when appropriate, lifestyle changes, and stress management techniques. With proper treatment, anxiety disorders are highly manageable.''',

      'social_anxiety_management': '''Social Anxiety Management

Social anxiety disorder involves intense fear of social situations due to concerns about being judged, embarrassed, or rejected by others. It's more than shyness - it can significantly impact daily functioning.

Key symptoms include fear of social interactions, physical symptoms (blushing, sweating, trembling), avoidance of social situations, and negative self-talk.

Management strategies:
• Gradual exposure - slowly facing feared social situations
• Cognitive restructuring - challenging negative thought patterns
• Relaxation techniques - deep breathing, progressive muscle relaxation
• Social skills practice - rehearsing conversations and interactions
• Self-compassion - treating yourself with kindness
• Building support networks - connecting with understanding people

Professional help through therapy, particularly CBT, can be extremely effective. Medication may also be helpful in some cases. Remember that social anxiety is treatable, and small steps forward count as progress.''',

      'mindfulness_mental_health': '''Importance of Mindfulness in Mental Health

Mindfulness involves paying attention to the present moment without judgment. Research shows significant benefits for mental health, including reduced anxiety, depression, and stress.

Benefits for mental health:
• Reduces rumination and worry
• Improves emotional regulation
• Increases self-awareness
• Enhances focus and concentration
• Builds resilience to stress
• Supports better sleep
• Increases overall well-being

Common mindfulness practices include meditation, body scans, mindful breathing, walking meditation, and mindful eating. Even brief daily practice can yield benefits.

Integration tips:
• Start with just 5-10 minutes daily
• Use guided meditations or apps
• Practice mindful moments throughout the day
• Be patient with yourself - it's a skill that develops over time
• Focus on consistency rather than perfection

Mindfulness isn't about emptying your mind, but rather observing thoughts and feelings without getting caught up in them.''',

      'coping_trauma': '''Coping with Trauma

Trauma results from experiencing or witnessing events that are physically or emotionally harmful. It can have lasting effects on mental, physical, and emotional well-being, but healing is possible.

Common trauma responses include flashbacks, nightmares, avoidance, emotional numbing, hypervigilance, difficulty trusting others, and changes in mood or behavior.

Healthy coping strategies:
• Acknowledge your experience and feelings
• Practice grounding techniques (5-4-3-2-1 sensory method)
• Maintain routines and self-care
• Connect with supportive people
• Express yourself through journaling, art, or music
• Engage in gentle physical activity
• Limit exposure to trauma reminders when possible

Professional support is often crucial. Trauma-informed therapies like EMDR, CPT, and PE can be highly effective. Support groups can also provide valuable connection and understanding.

Remember: healing isn't linear, be patient with yourself, and seeking help is a sign of strength, not weakness.''',

      'resilience_dysregulation': '''Building Resilience through Dysregulation

Emotional dysregulation involves difficulty managing emotional responses effectively. While challenging, learning to navigate dysregulation can actually build resilience and emotional strength.

Understanding dysregulation:
• Intense emotions that feel overwhelming
• Difficulty returning to emotional baseline
• Reactions that seem disproportionate to triggers
• Challenges with impulse control

Building resilience strategies:
• Develop emotional awareness - notice early warning signs
• Practice distress tolerance skills - riding out difficult emotions
• Build a toolkit of coping strategies
• Create safety plans for overwhelming moments
• Practice self-compassion during difficult times
• Learn from each experience of dysregulation

Practical techniques include deep breathing, progressive muscle relaxation, grounding exercises, journaling, and creating safe spaces. Over time, navigating these challenging emotional states builds confidence and resilience.

Remember that setbacks are part of the process, and each time you work through dysregulation, you're building valuable emotional skills.''',

      'mental_wellness_sleep': '''Mental Wellness and Sleep

Sleep and mental health are deeply interconnected. Poor sleep can worsen mental health symptoms, while mental health challenges can disrupt sleep, creating a challenging cycle.

How sleep affects mental health:
• Sleep deprivation increases stress hormones
• Poor sleep impairs emotional regulation
• Lack of sleep affects memory and concentration
• Sleep problems can trigger or worsen depression and anxiety

Sleep hygiene practices:
• Maintain consistent sleep/wake times
• Create a relaxing bedtime routine
• Keep your bedroom cool, dark, and quiet
• Limit screens before bedtime
• Avoid caffeine late in the day
• Get natural light exposure during the day
• Use your bed only for sleep and intimacy

When dealing with mental health challenges:
• Address racing thoughts through journaling or meditation
• Practice relaxation techniques before bed
• Consider therapy for sleep-related anxiety
• Work with healthcare providers on medication timing
• Be patient - sleep improvements take time

Quality sleep is not a luxury but a necessity for mental wellness.''',
    };

    return fallbacks[topicKey] ?? 'Content not available at this time.';
  }

  // Get infodump content, generating if needed
  static Future<String> getInfodumpContent(String topic, String userId) async {
    final topicKey = mentalHealthTopics[topic];
    if (topicKey == null) return 'Topic not found.';

    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have this content
    final existingContent = prefs.getString('${_infodumpPrefix}${topicKey}');
    final isGenerated = prefs.getBool('${_generatedFlagPrefix}${topicKey}') ?? false;

    if (existingContent != null && isGenerated) {
      return existingContent;
    }

    // Generate new content
    final content = await _generateInfodumpContent(topic, topicKey, userId);
    
    // Save the content and mark as generated
    await prefs.setString('${_infodumpPrefix}${topicKey}', content);
    await prefs.setBool('${_generatedFlagPrefix}${topicKey}', true);
    
    return content;
  }

  // Check if content exists locally
  static Future<bool> hasInfodumpContent(String topic) async {
    final topicKey = mentalHealthTopics[topic];
    if (topicKey == null) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_infodumpPrefix}${topicKey}') != null;
  }

  // Regenerate content (force refresh)
  static Future<String> regenerateInfodumpContent(String topic, String userId) async {
    final topicKey = mentalHealthTopics[topic];
    if (topicKey == null) return 'Topic not found.';

    final prefs = await SharedPreferences.getInstance();
    
    // Clear existing content
    await prefs.remove('${_infodumpPrefix}${topicKey}');
    await prefs.remove('${_generatedFlagPrefix}${topicKey}');
    
    // Generate fresh content
    return await getInfodumpContent(topic, userId);
  }

  // Clear all stored infodumps
  static Future<void> clearAllInfodumps() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (final topicKey in mentalHealthTopics.values) {
      await prefs.remove('${_infodumpPrefix}${topicKey}');
      await prefs.remove('${_generatedFlagPrefix}${topicKey}');
    }
  }
}