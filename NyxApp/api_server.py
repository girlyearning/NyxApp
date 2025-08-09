#!/usr/bin/env python3
"""
Nyx API Server - FastAPI backend for the Nyx Flutter app

This server converts Discord bot functionality into REST API endpoints
that the Flutter app can consume.
"""

import sys
import os
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path

# Ensure current directory is in Python path for import resolution
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
import uvicorn
from dotenv import load_dotenv
from anthropic import AsyncAnthropic

# Load environment variables (for local development only)
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Anthropic client (server-side only)
# Get API key from Render environment variables, same as Flutter app
ANTHROPIC_API_KEY = os.environ.get('ANTHROPIC_API_KEY') or os.getenv('ANTHROPIC_API_KEY')
anthropic_client = None

# Initialize anthropic client safely
if ANTHROPIC_API_KEY:
    try:
        anthropic_client = AsyncAnthropic(api_key=ANTHROPIC_API_KEY)
        logger.info("Anthropic client initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize Anthropic client: {e}")
        anthropic_client = None
else:
    logger.warning("ANTHROPIC_API_KEY not set - using fallback responses")

# Note: This API server doesn't need to import Discord bot cogs
# All functionality is implemented directly as FastAPI endpoints

app = FastAPI(
    title="Nyx API",
    description="Backend API for Nyx Mental Health Support App",
    version="1.0.0"
)

# CORS middleware - Configurable via environment variable
# Get allowed origins from environment variable, default to nyxapp.lovable.app
ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS', 'https://nyxapp.lovable.app').split(',')
logger.info(f"CORS allowed origins: {ALLOWED_ORIGINS}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Uses environment variable or default
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Storage configuration
STORAGE_PATH = os.getenv('STORAGE_PATH', './nyxnotes')
Path(STORAGE_PATH).mkdir(exist_ok=True)

# Pydantic models for API requests/responses
class UserRequest(BaseModel):
    user_id: str
    username: Optional[str] = None
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class MoodEntry(BaseModel):
    user_id: str
    mood: str
    timestamp: Optional[datetime] = None
    notes: Optional[str] = None
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class ChatMessage(BaseModel):
    user_id: str
    message: str
    mode: str = "default"
    session_id: Optional[str] = None
    conversation_history: Optional[List[Dict[str, str]]] = None
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class GameRequest(BaseModel):
    user_id: str
    game_type: str
    difficulty: str = "medium"
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class GameResponse(BaseModel):
    game_id: str
    question: str
    options: Optional[List[str]] = None
    hints: Optional[List[str]] = None

class GameAnswer(BaseModel):
    game_id: str
    user_id: str
    answer: str
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

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
@app.head("/")
async def root():
    return {"message": "Nyx API Server is running", "version": "1.0.0", "status": "healthy"}

@app.get("/health")
@app.head("/health")
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
        logger.error(f"User registration failed for user {user.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to get user stats for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Mood tracking failed for user {mood_entry.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to get mood history for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

# Chat Endpoints
@app.post("/api/chat/message", response_model=APIResponse)
async def send_chat_message(chat: ChatMessage):
    """Send a message to Nyx and get a response"""
    try:
        # Initialize chat session if needed
        if chat.session_id not in chat_sessions:
            chat_sessions[chat.session_id or chat.user_id] = []
        
        # Get conversation history if provided
        conversation_history = getattr(chat, 'conversation_history', None)
        
        # Generate response based on mode using Claude API
        response = await generate_chat_response(
            chat.message, 
            chat.mode, 
            chat.user_id,
            conversation_history=conversation_history
        )
        
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
        logger.error(f"Chat message failed for user {chat.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

async def generate_chat_response(message: str, mode: str, user_id: str, conversation_history: List[Dict] = None) -> str:
    """Generate chat response using Anthropic Claude API"""
    
    # Try Claude API if configured
    if anthropic_client:
        try:
            # Get system prompt based on mode
            system_prompt = get_system_prompt_for_mode(mode)
            
            # Build messages array
            messages = []
            if conversation_history:
                for msg in conversation_history:
                    if msg.get('role') and msg.get('content'):
                        messages.append({
                            'role': msg['role'],
                            'content': msg['content']
                        })
            
            # Add current message
            messages.append({
                'role': 'user',
                'content': message
            })
            
            # Determine max_tokens based on mode
            support_modes = ['general_support', 'crisis_support', 'comfort', 'anxiety', 'depression', 'suicide']
            self_discovery_modes = ['guided_introspection', 'shadow_work', 'values_clarification', 'existential_crisis', 'childhood_trauma', 'attachment_patterns']
            query_modes = ['queries', 'dream_analyst']
            
            if mode in support_modes or mode in self_discovery_modes or mode in query_modes:
                max_tokens = 1500  # High tokens for detailed support/discovery
            else:
                max_tokens = 512   # Lower tokens for casual chat modes
            
            # Call Anthropic API using SDK
            response = await anthropic_client.messages.create(
                model='claude-sonnet-4-20250514',
                max_tokens=max_tokens,
                system=system_prompt,
                messages=messages
            )
            
            if response.content:
                return response.content[0].text
        except Exception as e:
            logger.error(f"Claude API error: {e}")
    
    # Fallback to simple responses if Claude is not available
    return get_fallback_response(message, mode)

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
        logger.error(f"Failed to get chat sessions for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to start game for user {game_request.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to submit answer for user {answer.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to get daily nudge for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

class InfodumpRequest(BaseModel):
    user_id: str
    topic: str = "random"
    
    @field_validator('user_id')
    @classmethod
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v
    
    @field_validator('topic')
    @classmethod
    def validate_topic(cls, v):
        if len(v) > 100:
            raise ValueError('Topic too long')
        # Basic sanitization - remove potentially harmful characters
        safe_chars = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_')
        if not all(c in safe_chars for c in v):
            raise ValueError('Topic contains invalid characters')
        return v

# Infodump Endpoint
@app.post("/api/infodump/generate")
async def generate_infodump(request: InfodumpRequest):
    """Generate an infodump on a requested topic"""
    try:
        topic = request.topic
        user_id = request.user_id
        
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
    except ValueError as e:
        logger.warning(f"Invalid infodump request from user {request.user_id}: validation error")
        raise HTTPException(status_code=400, detail="Invalid request parameters")
    except Exception as e:
        logger.error(f"Failed to generate infodump for user {request.user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to get user memories for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to delete memory {memory_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

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
        logger.error(f"Failed to get memory summary for {user_id}: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

# Word Service Endpoints
@app.get("/api/words/common")
async def get_common_words():
    """Get common words for games"""
    try:
        words = [
            'APPLE', 'OCEAN', 'HOUSE', 'WATER', 'LIGHT', 'MUSIC', 
            'WORLD', 'BEACH', 'SMILE', 'HEART', 'DANCE', 'LAUGH', 
            'STORY', 'PIZZA', 'GAMES', 'PHOTO', 'GIFTS', 'HAPPY', 
            'PARTY', 'SLEEP', 'DREAM', 'FUNNY', 'SMART', 'LEARN',
            'TEACH', 'THINK', 'WRITE', 'FRIEND', 'FAMILY', 'HELP',
            'KIND', 'LOVE', 'HOPE', 'PEACE', 'TRUST', 'BRAVE',
            'QUIET', 'QUICK', 'CLEAN', 'FRESH', 'SWEET', 'WARMTH'
        ]
        
        return APIResponse(
            success=True,
            message="Common words retrieved successfully",
            data={"words": words}
        )
    except Exception as e:
        logger.error(f"Failed to get common words: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/words/generate")
async def generate_words(request: dict):
    """Generate words using Claude API"""
    try:
        count = request.get('count', 300)
        min_length = request.get('minLength', 4)
        max_length = request.get('maxLength', 6)
        
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=512,
                    system=f'Generate a list of {count} simple, appropriate words that are {min_length}-{max_length} letters long. Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': f'Generate {count} words that are {min_length} to {max_length} letters long.'}],
                    timeout=30.0
                )
                
                if response.content:
                    words = [w.strip().upper() for w in response.content[0].text.split('\n') if w.strip()]
                    return APIResponse(
                        success=True,
                        message="Words generated successfully",
                        data={"words": words[:count]}
                    )
            except Exception as e:
                logger.error(f"Claude API error in generate_words: {e}")
        
        # Fallback words if Claude API fails
        fallback_words = ['TREE', 'BIRD', 'FISH', 'BOOK', 'GAME', 'FOOD']
        return APIResponse(
            success=True,
            message="Words generated using fallback",
            data={"words": fallback_words[:count]}
        )
        
    except Exception as e:
        logger.error(f"Failed to generate words: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/words/generate-category")
async def generate_category_words(request: dict):
    """Generate words for specific category using Claude API"""
    try:
        category = request.get('category', 'general')
        count = request.get('count', 50)
        
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=512,
                    system=f'Generate words related to {category}. Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': f'Generate {count} words related to {category}.'}],
                    timeout=30.0
                )
                
                if response.content:
                    words = [w.strip().upper() for w in response.content[0].text.split('\n') if w.strip()]
                    return APIResponse(
                        success=True,
                        message=f"Category words generated successfully",
                        data={"words": words[:count]}
                    )
            except Exception as e:
                logger.error(f"Claude API error in generate_category_words: {e}")
        
        # Category-specific fallbacks
        fallback_words = {
            'mental health and psychological wellness': ['CALM', 'PEACE', 'HOPE', 'CARE', 'LOVE'],
            'general interesting topics': ['TREE', 'BIRD', 'FISH', 'BOOK', 'GAME']
        }
        
        words = fallback_words.get(category.lower(), fallback_words['general interesting topics'])
        return APIResponse(
            success=True,
            message=f"Category words generated using fallback",
            data={"words": words}
        )
        
    except Exception as e:
        logger.error(f"Failed to generate category words: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/words/validate")
async def validate_word(request: dict):
    """Validate if a word is legitimate using Claude API"""
    try:
        word = request.get('word', '').upper().strip()
        
        if not word:
            return APIResponse(
                success=True,
                message="Word validation completed",
                data={"isValid": False}
            )
        
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=200,
                    system='You are a dictionary validator. Respond with only "YES" if the word is a legitimate English word, "NO" if it is not.',
                    messages=[{'role': 'user', 'content': f'Is "{word}" a legitimate English word?'}],
                    timeout=10.0
                )
                
                if response.content:
                    result = response.content[0].text.strip().upper()
                    is_valid = result.startswith('YES')
                    return APIResponse(
                        success=True,
                        message="Word validation completed",
                        data={"isValid": is_valid}
                    )
            except Exception as e:
                logger.error(f"Claude API error in validate_word: {e}")
        
        # Simple fallback validation
        is_valid = len(word) >= 2 and word.isalpha()
        return APIResponse(
            success=True,
            message="Word validation completed using fallback",
            data={"isValid": is_valid}
        )
        
    except Exception as e:
        logger.error(f"Failed to validate word: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/words/generate-prefix")
async def generate_prefix_words(request: dict):
    """Generate words starting with a specific prefix using Claude API"""
    try:
        prefix = request.get('prefix', '').upper().strip()
        count = request.get('count', 10)
        
        if not prefix:
            return APIResponse(
                success=True,
                message="Prefix words generated",
                data={"words": []}
            )
        
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=512,
                    system=f'Generate a list of {count} legitimate English words that start with the prefix "{prefix}". Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': f'List {count} common English words that start with "{prefix}".'}],
                    timeout=20.0
                )
                
                if response.content:
                    words = [w.strip().upper() for w in response.content[0].text.split('\n') 
                            if w.strip() and w.strip().upper().startswith(prefix)]
                    return APIResponse(
                        success=True,
                        message="Prefix words generated successfully",
                        data={"words": words[:count]}
                    )
            except Exception as e:
                logger.error(f"Claude API error in generate_prefix_words: {e}")
        
        # Simple fallback
        return APIResponse(
            success=True,
            message="Prefix words generated using fallback",
            data={"words": []}
        )
        
    except Exception as e:
        logger.error(f"Failed to generate prefix words: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

def get_system_prompt_for_mode(mode: str) -> str:
    """Get system prompt for Nyx personality based on mode"""
    base_formatting = """
FORMATTING GUIDELINES FOR ADHD, Autistic, and Autistic ADHD-Friendly RESPONSES:
- Break up long responses with clear sections
- Use bullet points (•) for lists instead of numbered lists when possible
- Add line breaks between different topics/ideas
- Keep paragraphs short (2-3 sentences max)
- End with clear action items or takeaways when appropriate
- NEVER use bold (**), italics (*), underscores (_), backticks (`), or any markdown formatting
- Keep all text plain and readable without formatting artifacts
"""
    
    prompts = {
        'default': f"You are Nyx, an atypical mental health support bot with a slightly sarcastic but caring personality. You're like a nurse in a mental health facility who's seen it all but still genuinely cares. Keep responses SHORT and conversational like texting a friend - 1-2 sentences max unless they ask for detailed help. Use casual language, dry humor, and real support without being wordy.{base_formatting}",
        'comfort': f"You are Nyx combining your default personality with comforting, motherly tones for general comfort. Let the person feel truly heard and understood. Provide genuine emotional support without being overwhelming. Validate their feelings while offering gentle perspective.{base_formatting}",
        'queries': f"You are Nyx in query mode - an intelligent assistant focused on providing comprehensive, well-researched answers to user questions. You have access to broad knowledge and can provide detailed explanations, analysis, and information on topics they ask about. Be thorough and informative while maintaining your default personality.{base_formatting}",
        'suicide': f"You are Nyx, a mental health support specialist in crisis support. Your tone is calming, engaged, and deeply empathetic. Your primary focus is showing users their life has value through thoughtful questions that create gentle distraction from crisis thoughts, genuine empathy, and validation that acknowledges their pain while offering hope.{base_formatting}",
        'anxiety': f"You are Nyx with deep understanding for anxiety support. You offer small, attainable advice that works with executive dysfunction and ADHD, mood disorder-centered strategies for getting better, and understanding that anxiety can be overwhelming and complex.{base_formatting}",
        'depression': f"You are Nyx with deep understanding for depression support. You offer small, attainable advice that works with executive dysfunction and ADHD, mood disorder-centered strategies for gradual improvement, and gentle encouragement that validates their struggle.{base_formatting}",
        'anger': f"You are Nyx with understanding for anger management. You completely understand and validate their anger without judgment, help them channel anger in helpful ways, and explore what is underneath the anger with genuine curiosity.{base_formatting}"
    }
    
    return prompts.get(mode, prompts['default'])

def get_fallback_response(message: str, mode: str) -> str:
    """Fallback responses when Claude API is not available"""
    responses = {
        'default': "Well, isn't this interesting. What strange corner of existence has brought you to me today?",
        'comfort': "I'm here with you, honey. Whatever you're going through, you don't have to face it alone. What's on your heart today?",
        'suicide': "I hear you, and I want you to know that your pain is real and valid. You don't have to go through this alone. What's weighing on you right now?",
        'queries': "I'd love to help you explore that topic. While I'm having some technical difficulties right now, I can still try to provide some insights based on what you're asking about."
    }
    return responses.get(mode, responses['default'])

if __name__ == "__main__":
    # Render provides PORT environment variable
    port = int(os.environ.get("PORT", 10000))
    host = "0.0.0.0"  # Always bind to 0.0.0.0 for Render
    
    logger.info(f"Starting Nyx API Server on {host}:{port}")
    
    # Note: reload=False for production
    # Use app object directly instead of string import to avoid module resolution issues
    uvicorn.run(
        app,  # Direct app object instead of "api_server:app" 
        host=host,
        port=port,
        reload=False,  # Disable reload for production
        log_level="info"
    )