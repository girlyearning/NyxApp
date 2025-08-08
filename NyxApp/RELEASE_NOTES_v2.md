# Nyx App v2.0 Release Notes
## Build Date: August 4, 2025

### 🎉 New Features

#### QykNotes System
- **Quick thought sharing** - Twitter-like posts limited to 350 characters
- **Instant rewards** - Earn 15 Nyx Notes for each QykNote posted
- **Persistent storage** - All QykNotes saved locally with timestamps
- **Clean interface** - View all your QykNotes with delete functionality

#### Enhanced Mental Health Infodumps
- **AI-Generated Content** - Claude API creates comprehensive 800-1000 word infodumps
- **6 Core Topics**:
  - Understanding Anxiety Disorders
  - Social Anxiety Management
  - Importance of Mindfulness in Mental Health
  - Coping with Trauma
  - Building Resilience through Dysregulation
  - Mental Wellness and Sleep
- **Offline Access** - Content generated once and saved permanently
- **Refresh Capability** - Regenerate content with new AI insights

#### Smart Notifications
- **Daily Nyx Nudges** - Personalized mental health reminders
- **Mood Check Reminders** - Morning and evening mood tracking prompts
- **User Timezone Support** - Notifications sent at your local time
- **Full Control** - Enable/disable and customize timing in settings

#### Enhanced Daily Questions
- **Claude API Generated** - Fresh, thoughtful questions daily
- **Mental Health Focus** - Introspective and philosophical themes
- **7 Question Categories** - Self-awareness, relationships, mindfulness, trauma, resilience, creativity
- **Automatic Generation** - No more static question files

### 🎨 Visual Updates

#### New App Icon
- **Custom Nyx Design** - Beautiful futuristic/mystical character
- **Consistent Branding** - Green/teal theme with tree of life symbol
- **All Platforms** - Updated across Android, iOS, web, desktop

#### Fixed Profile Icon Flashing
- **Smooth Loading** - No more flashing between old and new profile icons
- **State Management** - Proper caching and lifecycle handling
- **Consistent Colors** - Loading states match app theme

#### UI Polish
- **Green Theme Consistency** - All text boxes use matching green colors
- **Better Organization** - Moved journaling features to Mindful Memos
- **Improved Navigation** - Cleaner layout and better feature grouping

### 🔧 Technical Improvements

#### Chat System Enhancements
- **3-Day Persistence** - Chats automatically saved for 3 days
- **Save Forever Option** - Mark important conversations as permanent
- **Session Management** - Smart session reuse and background saving
- **Lifecycle Handling** - Saves on app minimize, disposal, and lifecycle changes

#### Performance & Reliability
- **Error Handling** - Comprehensive try-catch blocks throughout
- **Fallback Content** - Offline content when API unavailable
- **Memory Management** - Proper widget disposal and cleanup
- **Build Fixes** - Resolved desugaring issues for notifications

### 📱 New Screens & Navigation

#### Reorganized Structure
- **Mindful Memos**: Question of the Day → Dear Diary → QykNotes
- **Coping Corner**: Crisis Support → Targeted Support → Self-Discovery Tools
- **Sensory Selfcare**: Enhanced with AI-generated mental health topics
- **Settings**: New notification management with full customization

#### New Screens Added
- `QykNotesScreen` - Full QykNotes management interface
- `InfodumpContentScreen` - Professional infodump display
- `NotificationSettingsScreen` - Complete notification control
- `SettingsScreen` - Main settings hub

### 🛠️ Developer Notes

#### Code Quality
- **Consistent Architecture** - Services, models, screens properly separated
- **Async Best Practices** - Proper Future/async/await patterns
- **Error Recovery** - Graceful handling of API failures
- **Type Safety** - Fixed all Flutter analyzer warnings

#### Dependencies Added
- `flutter_local_notifications: ^17.2.3` - Cross-platform notifications
- `permission_handler: ^11.3.1` - Runtime permission management  
- `timezone: ^0.9.4` - Proper timezone handling
- `flutter_launcher_icons: ^0.13.1` - Icon generation

### 🚀 Installation
Install the APK file: `nyx-app-v2-with-all-updates-20250804.apk` (28.6MB)

### 🔐 Permissions
- **Notifications** - For daily nudges and mood reminders
- **Internet** - For Claude API and chat functionality
- **Storage** - For local data persistence

---

*This release represents a major enhancement to the Nyx mental health support app with AI-powered content generation, comprehensive notification system, and improved user experience throughout.*