# Security Setup for NyxApp

## API Key Configuration

The NyxApp has been updated to use a more secure method for handling API keys:

### ✅ What Changed

1. **Removed .env file** - No longer storing sensitive keys in files that could be exposed
2. **Using GitHub Secrets** - API key is now stored securely in GitHub repository secrets
3. **Compile-time injection** - API key is injected at build time using `--dart-define`
4. **No client-side storage** - API key is never stored in the APK or accessible to end users

### 🔐 GitHub Setup

1. Go to your GitHub repository settings
2. Navigate to Settings → Secrets and variables → Actions
3. Add a new secret named `ANTHROPIC_API_KEY` with your Claude API key

### 🏗️ Building Locally

When building the app locally, you need to provide the API key:

```bash
# Set environment variable
export ANTHROPIC_API_KEY="your-api-key-here"

# Build with the key
flutter build apk --release --dart-define=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Or use the build script
./build_apk.sh
```

### 🚀 GitHub Actions

The GitHub workflow automatically injects the API key from secrets:
- Located at `.github/workflows/build.yml`
- Automatically builds APK with API key on push to main/nyxapp-flutter branches
- Creates releases with properly configured APKs

### 🌐 API Endpoints

All API calls now use the public domain:
- Base URL: `https://nyxapp.lovable.app/api`
- No localhost connections exposed in the app

### 📝 Code Changes

API key access in code:
```dart
// Old (insecure)
dotenv.env['ANTHROPIC_API_KEY']

// New (secure)
String.fromEnvironment('ANTHROPIC_API_KEY')
```

### ⚠️ Important Notes

- Never commit API keys to the repository
- Always use GitHub secrets for sensitive data
- The API key will be empty when building without `--dart-define`
- Mock responses are available when API key is not configured