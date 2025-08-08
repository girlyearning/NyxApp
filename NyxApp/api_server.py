#!/usr/bin/env python3
"""
Nyx API Server - FastAPI backend for the Nyx Flutter app

This server converts Discord bot functionality into REST API endpoints
that the Flutter app can consume.
"""

import os
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import bot modules for functionality
import sys
sys.path.append(str(Path(__file__).parent))

# Import cog functionality
try:
    from cogs.memory import NyxMemory
    from cogs.comfort import ComfortChat  
    from cogs.workshop import WorkshopCog
    from cogs.prefixgame import PrefixGame
    from cogs.unscramble import UnscrambleGame  
    from cogs.wordhunt import WordHunt
    from cogs.alliteration import AlliterationGame
except ImportError as e:
    print(f"Warning: Could not import some cogs: {e}")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Nyx API",
    description="Backend API for Nyx Mental Health Support App",
    version="1.0.0"
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Storage configuration
STORAGE_PATH = os.getenv('STORAGE_PATH', './nyxnotes')
Path(STORAGE_PATH).mkdir(exist_ok=True)

# Pydantic models for API requests/responses
class UserRequest(BaseModel):
    user_id: str
    username: Optional[str] = None

class MoodEntry(BaseModel):
    user_id: str
    mood: str
    timestamp: Optional[datetime] = None
    notes: Optional[str] = None

class ChatMessage(BaseModel):
    user_id: str
    message: str
    mode: str = "default"
    session_id: Optional[str] = None

class GameRequest(BaseModel):
    user_id: str
    game_type: str
    difficulty: str = "medium"

class GameResponse(BaseModel):
    game_id: str
    question: str
    options: Optional[List[str]] = None
    hints: Optional[List[str]] = None

class GameAnswer(BaseModel):
    game_id: str
    user_id: str
    answer: str

# API Response Models
class APIResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None

class UserStatsResponse(BaseModel):
    user_id: str
    nyx_notes: int
    total_checkins: int
    current_streak: int
    chat_sessions: int
    achievements: List[Dict[str, Any]]

# In-memory storage for active games and sessions
active_games: Dict[str, Dict] = {}
chat_sessions: Dict[str, List] = {}

# Initialize bot components (mock Discord context)
class MockContext:
    def __init__(self, user_id: str):
        self.author = MockUser(user_id)
        self.bot = None
        
class MockUser:
    def __init__(self, user_id: str):
        self.id = int(user_id) if user_id.isdigit() else hash(user_id)
        self.name = f"User_{user_id}"
        self.display_name = self.name

# API Endpoints

@app.get("/")
async def root():
    return {"message": "Nyx API Server is running", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

# User Management Endpoints
@app.post("/api/users/register", response_model=APIResponse)
async def register_user(user: UserRequest):
    """Register a new user or update existing user info"""
    try:
        # Initialize user data in memory system
        ctx = MockContext(user.user_id)
        
        # This would create user record if it doesn't exist
        user_data = {
            "user_id": user.user_id,
            "username": user.username or f"User_{user.user_id}",
            "registered_at": datetime.now().isoformat(),
            "nyx_notes": 0,
            "total_checkins": 0,
            "achievements": []
        }
        
        return APIResponse(
            success=True,
            message="User registered successfully",
            data=user_data
        )
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/users/{user_id}/stats", response_model=UserStatsResponse)
async def get_user_stats(user_id: str):
    """Get user statistics and achievements"""
    try:
        # Mock data - in real implementation, this would fetch from memory system
        stats = UserStatsResponse(
            user_id=user_id,
            nyx_notes=150,
            total_checkins=12,
            current_streak=3,
            chat_sessions=8,
            achievements=[
                {"id": "first_steps", "name": "First Steps", "unlocked": True},
                {"id": "note_collector", "name": "Note Collector", "unlocked": True}
            ]
        )
        return stats
    except Exception as e:
        logger.error(f"Failed to get user stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Mood Tracking Endpoints
@app.post("/api/mood/track", response_model=APIResponse)
async def track_mood(mood_entry: MoodEntry):
    """Track a user's mood entry"""
    try:
        # Store mood entry
        mood_data = {
            "user_id": mood_entry.user_id,
            "mood": mood_entry.mood,
            "timestamp": (mood_entry.timestamp or datetime.now()).isoformat(),
            "notes": mood_entry.notes
        }
        
        # Award Nyx Notes for mood tracking
        nyx_notes_earned = 5
        
        return APIResponse(
            success=True,
            message=f"Mood tracked successfully! Earned {nyx_notes_earned} Nyx Notes.",
            data={
                "mood_entry": mood_data,
                "nyx_notes_earned": nyx_notes_earned
            }
        )
    except Exception as e:
        logger.error(f"Mood tracking failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/mood/{user_id}/history")
async def get_mood_history(user_id: str, days: int = 30):
    """Get user's mood history for the specified number of days"""
    try:
        # Mock mood history data
        history = []
        for i in range(days):
            date = datetime.now() - timedelta(days=i)
            if i % 3 == 0:  # Add some variation
                history.append({
                    "date": date.isoformat(),
                    "mood": ["Happy", "Neutral", "Anxious", "Depressed"][i % 4],
                    "notes": f"Day {i} mood entry"
                })
        
        return APIResponse(
            success=True,
            message="Mood history retrieved successfully",
            data={"history": history}
        )
    except Exception as e:
        logger.error(f"Failed to get mood history: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Chat Endpoints
@app.post("/api/chat/message", response_model=APIResponse)
async def send_chat_message(chat: ChatMessage):
    """Send a message to Nyx and get a response"""
    try:
        # Initialize chat session if needed
        if chat.session_id not in chat_sessions:
            chat_sessions[chat.session_id or chat.user_id] = []
        
        # Generate response based on mode
        response = await generate_chat_response(chat.message, chat.mode, chat.user_id)
        
        # Store messages in session
        session_key = chat.session_id or chat.user_id
        chat_sessions[session_key].extend([
            {"sender": "user", "message": chat.message, "timestamp": datetime.now().isoformat()},
            {"sender": "nyx", "message": response, "timestamp": datetime.now().isoformat()}
        ])
        
        return APIResponse(
            success=True,
            message="Message sent successfully",
            data={"response": response, "session_id": session_key}
        )
    except Exception as e:
        logger.error(f"Chat message failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def generate_chat_response(message: str, mode: str, user_id: str) -> str:
    """Generate chat response based on mode and message"""
    
    # Mode-specific responses (similar to ChatService in Flutter)
    responses = {
        'default': {
            'general': "Well, isn't this interesting.\n\nWhat strange corner of existence has brought you to me today?",
            'help': "Oh, you need help? How refreshingly honest.\n\nMost people pretend they have it all figured out.",
            'thanks': "Don't mention it. I'm contractually obligated to care about your wellbeing.\n\nIt's in the fine print of being your asylum nurse."
        },
        'ride_or_die': {
            'general': "Bestie, you look like you need either therapy or a really bad decision.\n\nI'm here for both.",
            'help': "Say less. Whatever chaos you're about to unleash, I'm here for it.\n\nWhat's the plan?",
            'thanks': "Please, like I'd let my person struggle alone.\n\nThat's not how this friendship works."
        },
        'comfort': {
            'general': "I'm here with you, honey. Whatever you're going through, you don't have to face it alone. What's on your heart today?",
            'help': "Of course I'll help however I can. You matter so much, and your feelings are important. What would feel most supportive right now?",
            'thanks': "You're so welcome, sweetheart. Taking care of you is what I'm here for. You deserve all the comfort and support in the world."
        },
        'suicide': {
            'general': "I hear you, and I want you to know that your pain is real and valid. You don't have to go through this alone. What's weighing on you right now?",
            'help': "Right now, the most important thing is that you're here and you're talking. That takes incredible strength. Can you tell me what's been the hardest part today?"
        }
    }
    
    mode_responses = responses.get(mode, responses['default'])
    
    # Simple keyword matching for response selection
    message_lower = message.lower()
    if 'help' in message_lower or 'how' in message_lower:
        return mode_responses.get('help', mode_responses['general'])
    elif 'thank' in message_lower:
        return mode_responses.get('thanks', mode_responses['general'])
    else:
        return mode_responses['general']

@app.get("/api/chat/{user_id}/sessions")
async def get_chat_sessions(user_id: str):
    """Get user's chat session history"""
    try:
        sessions = chat_sessions.get(user_id, [])
        return APIResponse(
            success=True,
            message="Chat sessions retrieved successfully",
            data={"sessions": sessions}
        )
    except Exception as e:
        logger.error(f"Failed to get chat sessions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Game Endpoints
@app.post("/api/games/start", response_model=GameResponse)
async def start_game(game_request: GameRequest):
    """Start a new game session"""
    try:
        game_id = f"{game_request.user_id}_{game_request.game_type}_{datetime.now().timestamp()}"
        
        # Generate game content based on type
        game_data = await generate_game_content(game_request.game_type, game_request.difficulty)
        game_data["game_id"] = game_id
        game_data["user_id"] = game_request.user_id
        game_data["started_at"] = datetime.now().isoformat()
        
        # Store active game
        active_games[game_id] = game_data
        
        return GameResponse(
            game_id=game_id,
            question=game_data["question"],
            options=game_data.get("options"),
            hints=game_data.get("hints")
        )
    except Exception as e:
        logger.error(f"Failed to start game: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def generate_game_content(game_type: str, difficulty: str) -> Dict[str, Any]:
    """Generate game content based on type and difficulty"""
    
    if game_type == "wordhunt":
        return {
            "question": "Find all words in this 4x4 grid:",
            "grid": [
                ["C", "A", "T", "S"],
                ["O", "L", "E", "N"],
                ["D", "O", "V", "E"],
                ["R", "A", "M", "P"]
            ],
            "target_words": ["CAT", "DOG", "LOVE", "RAMP", "DOVE"],
            "time_limit": 300
        }
    elif game_type == "unscramble":
        return {
            "question": "Unscramble this word: MEILPS",
            "answer": "SIMPLE",
            "hints": ["It's the opposite of complex", "6 letters"]
        }
    elif game_type == "prefix":
        return {
            "question": "What word starts with 'un-' and means not happy?",
            "options": ["unhappy", "unclear", "unable", "unfair"],
            "answer": "unhappy"
        }
    elif game_type == "alliteration":
        return {
            "question": "Create an alliterative phrase with the letter 'B':",
            "example": "Big blue balloon",
            "hints": ["Use at least 3 words", "All words should start with 'B'"]
        }
    else:
        return {
            "question": "Generic game question",
            "answer": "Generic answer"
        }

@app.post("/api/games/answer", response_model=APIResponse)
async def submit_game_answer(answer: GameAnswer):
    """Submit an answer for a game"""
    try:
        if answer.game_id not in active_games:
            raise HTTPException(status_code=404, detail="Game not found")
        
        game = active_games[answer.game_id]
        
        # Check answer (simplified logic)
        is_correct = False
        points_earned = 0
        
        if game.get("answer"):
            is_correct = answer.answer.lower() == game["answer"].lower()
        elif game.get("target_words"):
            is_correct = answer.answer.upper() in game["target_words"]
        
        if is_correct:
            points_earned = 10
        
        # Clean up completed game
        del active_games[answer.game_id]
        
        return APIResponse(
            success=True,
            message="Answer submitted successfully",
            data={
                "correct": is_correct,
                "points_earned": points_earned,
                "correct_answer": game.get("answer")
            }
        )
    except Exception as e:
        logger.error(f"Failed to submit answer: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Daily Nyx Nudge Endpoint
@app.get("/api/nudge/daily/{user_id}")
async def get_daily_nudge(user_id: str):
    """Get daily Nyx nudge message"""
    try:
        # Rotate through different nudge messages with Nyx's authentic personality
        nudges = [
            "Another day of being human. How's that going for you so far?",
            "Time for your contractually obligated check-in. Seriously though, how are you holding up?",
            "Your feelings today are valid, even the messy complicated ones. What's going on?",
            "I've seen people have worse days than this. Still, how are you managing right now?",
            "Well, you made it through another night. That's something. How are we feeling today?",
            "Reality check time - and I mean that in the gentlest way possible. How are you doing?",
            "Not gonna lie, being a person is weird sometimes. How's your version of weird going?",
            "Your mental health nurse checking in. What does taking care of yourself look like today?",
            "Some days are survival days, some are thriving days. Which kind is today for you?",
            "It's okay if today feels heavy. I'm here either way. What's on your mind?",
            "Progress isn't linear, and that's annoyingly normal. How are you navigating today?",
            "You don't have to be okay all the time. Really. How are you actually doing right now?",
            "Another plot twist in the ongoing series that is your life. How are you handling this episode?",
            "Your asylum nurse here with a gentle reminder that you matter. How's your day treating you?",
            "Some days we thrive, some days we survive. Both count. Which one is today?",
            "Real talk: being human is complicated. How are you working through the complications today?",
            "I've seen every type of day there is. None of them define you. How's yours going?",
            "Checking in because that's what I do. But also because I genuinely want to know - how are you?",
            "Life keeps happening whether we're ready or not. How are you keeping up with it all?",
            "Your feelings are information, not instructions. What are they telling you today?"
        ]
        
        # Simple rotation based on day of year
        day_of_year = datetime.now().timetuple().tm_yday
        nudge = nudges[day_of_year % len(nudges)]
        
        return APIResponse(
            success=True,
            message="Daily nudge retrieved successfully",
            data={"nudge": nudge, "date": datetime.now().date().isoformat()}
        )
    except Exception as e:
        logger.error(f"Failed to get daily nudge: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Infodump Endpoint
@app.post("/api/infodump/generate")
async def generate_infodump(request: dict):
    """Generate an infodump on a requested topic"""
    try:
        topic = request.get("topic", "random")
        user_id = request.get("user_id")
        
        # Mock infodump generation
        infodumps = {
            "octopus": "Did you know octopuses have three hearts and blue blood? Two hearts pump blood to the gills, while the third pumps blood to the rest of the body. Their blue blood comes from a copper-based protein called hemocyanin, which is more efficient than our iron-based hemoglobin in cold, low-oxygen environments!",
            "space": "The largest known star, UY Scuti, is so massive that if it replaced our Sun, its surface would extend beyond the orbit of Jupiter. Light would take over 6 hours to travel from its center to its surface, compared to 8 minutes for our Sun!",
            "ocean": "The deepest part of our oceans, the Challenger Deep in the Mariana Trench, is deeper than Mount Everest is tall. The pressure there is over 1,000 times greater than at sea level - equivalent to having 50 jumbo jets pressing down on every square meter!"
        }
        
        infodump_text = infodumps.get(topic.lower(), 
            "Here's a fascinating fact: Honey never spoils! Archaeologists have found edible honey in ancient Egyptian tombs that's over 3,000 years old. Its low moisture content and acidic pH create an environment where bacteria cannot survive.")
        
        return APIResponse(
            success=True,
            message="Infodump generated successfully",
            data={
                "topic": topic,
                "content": infodump_text,
                "generated_at": datetime.now().isoformat()
            }
        )
    except Exception as e:
        logger.error(f"Failed to generate infodump: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Memory Management Endpoints
@app.get("/api/memories/{user_id}")
async def get_user_memories(user_id: str):
    """Get all conversation memories/contexts for a user"""
    try:
        # In a real implementation, this would fetch from the bot's memory system
        # For now, return mock memory data showing conversation context
        memories = [
            {
                "id": f"memory_{i}",
                "content": f"User mentioned they enjoy {['reading', 'gaming', 'music', 'art', 'cooking'][i % 5]} and feel {['anxious', 'happy', 'stressed', 'calm', 'excited'][i % 5]} about it",
                "timestamp": (datetime.now() - timedelta(days=i)).isoformat(),
                "session_id": f"session_{i}",
                "context_type": ["preference", "emotion", "goal", "trigger", "coping_strategy"][i % 5],
                "importance": ["high", "medium", "low"][i % 3]
            }
            for i in range(15)  # 15 mock memories
        ]
        
        return APIResponse(
            success=True,
            message="User memories retrieved successfully",
            data={"memories": memories, "total_count": len(memories)}
        )
    except Exception as e:
        logger.error(f"Failed to get user memories: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/memories/{memory_id}")
async def delete_memory(memory_id: str, user_id: str = None):
    """Delete a specific memory"""
    try:
        # In a real implementation, this would remove the memory from storage
        # For now, return success response
        return APIResponse(
            success=True,
            message=f"Memory {memory_id} deleted successfully",
            data={"deleted_memory_id": memory_id}
        )
    except Exception as e:
        logger.error(f"Failed to delete memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/memories/{user_id}/summary")
async def get_memory_summary(user_id: str):
    """Get a summary of user's memory data"""
    try:
        summary = {
            "total_memories": 15,
            "memory_categories": {
                "preferences": 4,
                "emotions": 3,
                "goals": 3,
                "triggers": 2,
                "coping_strategies": 3
            },
            "oldest_memory": (datetime.now() - timedelta(days=14)).isoformat(),
            "newest_memory": datetime.now().isoformat(),
            "most_common_topics": ["anxiety", "reading", "music", "work stress", "family"]
        }
        
        return APIResponse(
            success=True,
            message="Memory summary retrieved successfully",
            data=summary
        )
    except Exception as e:
        logger.error(f"Failed to get memory summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"Starting Nyx API Server on {host}:{port}")
    
    uvicorn.run(
        "api_server:app",
        host=host,
        port=port,
        reload=True,
        log_level="info"
    )