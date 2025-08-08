#!/bin/bash

# NyxApp APK Build Script
# This script builds the APK with all recent changes

echo "🚀 Building NyxApp APK with all recent changes..."
echo "📂 Working directory: $(pwd)"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Make sure you're in the NyxApp directory."
    exit 1
fi

# Check Flutter installation
echo "🔍 Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Run Flutter doctor
echo "🏥 Running Flutter doctor..."
flutter doctor

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build APK with API key from environment
echo "🔨 Building release APK..."
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "⚠️  Warning: ANTHROPIC_API_KEY not set. The app may not be able to use Claude API."
    echo "   To set it, run: export ANTHROPIC_API_KEY='your-api-key'"
    flutter build apk --release
else
    echo "✅ Building with API key configured"
    flutter build apk --release --dart-define=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
fi

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ APK build successful!"
    
    # Create a timestamped copy
    TIMESTAMP=$(date +"%Y%m%d-%H%M")
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    NEW_APK_NAME="nyx-app-updated-changes-${TIMESTAMP}.apk"
    
    if [ -f "$APK_PATH" ]; then
        cp "$APK_PATH" "$NEW_APK_NAME"
        echo "📱 APK created: $NEW_APK_NAME"
        echo "📁 Original location: $APK_PATH"
        
        # Show file size
        FILE_SIZE=$(du -h "$NEW_APK_NAME" | cut -f1)
        echo "📊 APK size: $FILE_SIZE"
        
        echo ""
        echo "🎉 Build complete! Your updated NyxApp APK is ready."
        echo "📥 Install with: adb install $NEW_APK_NAME"
    else
        echo "❌ APK file not found at expected location."
    fi
else
    echo "❌ Build failed. Check the error messages above."
    exit 1
fi

echo ""
echo "📋 Changes included in this build:"
echo "✅ Journal popup dialogs: Theme-specific background colors with white text"
echo "✅ ADHD/Autism/AuDHD entry messages: Changed to 'Nice of you to pop in. What's up?'"
echo "✅ Send button colors: Fixed to use secondary color for each theme"
echo "✅ Home screen: Larger 'Welcome to Nyx' title text"
echo "✅ Previous fixes: Wordhunt, Unscramble, Scattergories improvements"