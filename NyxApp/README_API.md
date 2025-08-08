# Nyx API Server Setup Guide

## Overview

The Nyx API Server converts your Discord bot functionality into REST endpoints that the Flutter app can consume. This allows the mobile app to access all the mental health features, games, and personality modes from your existing bot.

## Quick Start

### 1. Start the API Server

```bash
cd /Users/vct/MyCode/Nyx
./start_api.sh
```

This script will:
- Create a Python virtual environment
- Install required dependencies  
- Start the FastAPI server on `http://localhost:8000`
- Show API documentation at `http://localhost:8000/docs`

### 2. Test the Flutter App

```bash
cd nyx_app
flutter run
```

The app will:
- Try to connect to the API server first
- Fall back to mock responses if server is unavailable
- Show enhanced features when connected to the real API

## API Endpoints

### Core Features
- `POST /api/mood/track` - Track mood entries and award Nyx Notes
- `GET /api/mood/{user_id}/history` - Get mood history with charts
- `GET /api/nudge/daily/{user_id}` - Get rotating daily check-in messages
- `POST /api/chat/message` - Chat with Nyx personality modes
- `POST /api/infodump/generate` - Generate knowledge dumps on topics

### Games
- `POST /api/games/start` - Start word games (wordhunt, unscramble, prefix, alliteration)
- `POST /api/games/answer` - Submit game answers and get points

### User Management  
- `POST /api/users/register` - Register new users
- `GET /api/users/{user_id}/stats` - Get user statistics and achievements
- `GET /api/health` - Check if server is running

## Configuration

### Environment Variables (.env file)

```bash
# Required for bot functionality
DISCORD_TOKEN=your_discord_bot_token_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Server configuration
STORAGE_PATH=./nyxnotes
HOST=127.0.0.1
PORT=8000
```

### Flutter App Configuration

The app automatically detects if the API server is running:
- **Server available**: Uses real API endpoints for enhanced features
- **Server offline**: Falls back to mock responses for basic functionality

## Development

### API Documentation
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`

### Testing API Endpoints

```bash
# Test server health
curl http://localhost:8000/health

# Test daily nudge
curl http://localhost:8000/api/nudge/daily/test_user

# Test mood tracking
curl -X POST http://localhost:8000/api/mood/track \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "mood": "Happy", "notes": "Great day!"}'
```

### Integration with Existing Bot

The API server is designed to gradually integrate with your existing Discord bot cogs:

1. **Current**: Mock responses that match bot personality
2. **Phase 2**: Import and adapt existing cog logic
3. **Phase 3**: Share data storage between Discord bot and API
4. **Phase 4**: Real-time Claude API integration

## Deployment Options

### Local Development
```bash
./start_api.sh  # Runs on localhost:8000
```

### Production Deployment
- Deploy to cloud platforms (Heroku, Railway, DigitalOcean)
- Use environment variables for configuration
- Set up proper database for persistent storage
- Configure CORS for your app's domain

## Architecture

```
Flutter App ←→ FastAPI Server ←→ Discord Bot Cogs
     ↓              ↓                    ↓
Mock Responses  REST Endpoints    Existing Logic
```

The Flutter app gets the best of both worlds:
- **Offline capability** with mock responses
- **Enhanced features** when connected to the API server
- **Future expansion** as more bot features are integrated

## Troubleshooting

### Server Won't Start
- Check Python 3.7+ is installed
- Verify virtual environment creation
- Check port 8000 isn't already in use

### Flutter App Can't Connect
- Ensure API server is running on `localhost:8000`
- Check firewall settings
- Verify CORS configuration

### Missing Bot Features
- Some advanced features require the full Discord bot integration
- Current version provides core functionality with mock data
- Real integration comes in future phases

## Next Steps

1. **Test the API server** with the provided startup script
2. **Run the Flutter app** and verify it connects to the API
3. **Explore the API documentation** at `http://localhost:8000/docs`
4. **Gradually integrate** real Discord bot logic as needed

The system is designed to work immediately with mock data while providing a clear path to full integration with your existing Discord bot codebase.