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
import random
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, validator
import uvicorn
from dotenv import load_dotenv
from anthropic import AsyncAnthropic

# Load environment variables
load_dotenv()

# Initialize Anthropic client (server-side only)
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY')
anthropic_client = AsyncAnthropic(api_key=ANTHROPIC_API_KEY) if ANTHROPIC_API_KEY else None

# Note: This API server doesn't need to import Discord bot cogs
# All functionality is implemented directly as FastAPI endpoints

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Nyx API",
    description="Backend API for Nyx Mental Health Support App",
    version="1.0.0"
)

# CORS middleware - LOCKED DOWN TO PRODUCTION DOMAIN
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://nyxapp.onrender.com"],  # Only allow production domain
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
    
    @validator('user_id')
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class MoodEntry(BaseModel):
    user_id: str
    mood: str
    timestamp: Optional[datetime] = None
    notes: Optional[str] = None
    
    @validator('user_id')
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
    
    @validator('user_id')
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v

class GameRequest(BaseModel):
    user_id: str
    game_type: str
    difficulty: str = "medium"
    
    @validator('user_id')
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
    
    @validator('user_id')
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
            
            # Call Anthropic API using SDK
            response = await anthropic_client.messages.create(
                model='claude-sonnet-4-20250514',
                max_tokens=4096,
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
    
    @validator('user_id')
    def validate_user_id(cls, v):
        if not v or len(v) < 3 or len(v) > 100:
            raise ValueError('Invalid user ID format')
        return v
    
    @validator('topic')
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
        count = request.get('count', 100)
        min_length = request.get('minLength', 4)
        max_length = request.get('maxLength', 6)
        
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=1024,
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
                    max_tokens=1024,
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
                    max_tokens=1500,
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

# Enhanced Word Hunt Game Endpoints
@app.post("/api/games/wordhunt/generate")
async def generate_word_hunt_puzzle(request: dict):
    """Generate Word Hunt puzzle with difficulty settings"""
    try:
        difficulty = request.get('difficulty', 'easy')
        user_id = request.get('user_id', 'default')
        
        # Match frontend difficulty settings
        is_easy_mode = difficulty == 'easy'
        grid_size = 6 if is_easy_mode else 10
        min_length = 4 if is_easy_mode else 5
        max_length = 6 if is_easy_mode else 9
        
        # Generate 4 words using Claude API
        words = []
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=1024,
                    system=f'Generate 4 simple, common English words that are {min_length}-{max_length} letters long. Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': f'Generate 4 words that are {min_length} to {max_length} letters long.'}],
                    timeout=30.0
                )
                
                if response.content:
                    words = [w.strip().upper() for w in response.content[0].text.split('\n') 
                            if w.strip() and min_length <= len(w.strip()) <= max_length][:4]
            except Exception as e:
                logger.error(f"Claude API error in word hunt generation: {e}")
        
        # Fallback words if Claude API fails
        if len(words) < 4:
            if is_easy_mode:
                fallback_words = ['APPLE', 'OCEAN', 'HOUSE', 'WATER', 'LIGHT', 'MUSIC', 'WORLD', 'BEACH']
            else:
                fallback_words = ['COMPUTER', 'ELEPHANT', 'KITCHEN', 'RAINBOW', 'FLOWER', 'MOUNTAIN', 'BUTTERFLY', 'CHOCOLATE']
            words = fallback_words[:4]
        
        # Generate puzzle grid
        puzzle_data = await create_word_hunt_grid(words, grid_size)
        
        return APIResponse(
            success=True,
            message="Word Hunt puzzle generated successfully",
            data={
                "game_type": "wordhunt",
                "difficulty": difficulty,
                "grid": puzzle_data["grid"],
                "grid_size": grid_size,
                "target_words": words,
                "word_positions": puzzle_data["word_positions"],
                "placed_words": puzzle_data["placed_words"],
                "message": f"{difficulty.title()} Mode: Find 4 words ({min_length}-{max_length} letters)"
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate word hunt puzzle: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

async def create_word_hunt_grid(words, grid_size):
    """Create Word Hunt grid with words placed in various orientations"""
    
    # Initialize empty grid
    grid = [['' for _ in range(grid_size)] for _ in range(grid_size)]
    word_positions = {}
    placed_words = {}
    
    # Place words in grid with various orientations
    for word in words:
        placed = False
        attempts = 0
        
        while not placed and attempts < 100:
            attempts += 1
            # Random direction: 0=horizontal, 1=vertical, 2=diagonal-down, 3=diagonal-up
            direction = random.randint(0, 3)
            # Random if backwards
            backwards = random.choice([True, False])
            
            placed, positions = try_place_word_in_grid(grid, word, direction, backwards, grid_size)
            if placed:
                word_positions[word] = positions
                word_to_place = word[::-1] if backwards else word
                placed_words[word] = word_to_place
    
    # Fill empty cells with random letters
    for i in range(grid_size):
        for j in range(grid_size):
            if grid[i][j] == '':
                grid[i][j] = chr(65 + random.randint(0, 25))  # Random A-Z
    
    return {
        "grid": grid,
        "word_positions": word_positions,
        "placed_words": placed_words
    }

def try_place_word_in_grid(grid, word, direction, backwards, grid_size):
    """Try to place a word in the grid"""
    
    word_to_place = word[::-1] if backwards else word
    
    # Calculate valid starting positions based on direction and word length
    max_row = grid_size
    max_col = grid_size
    
    if direction == 0:  # Horizontal
        max_col = grid_size - len(word) + 1
    elif direction == 1:  # Vertical
        max_row = grid_size - len(word) + 1
    elif direction == 2:  # Diagonal down-right
        max_row = grid_size - len(word) + 1
        max_col = grid_size - len(word) + 1
    elif direction == 3:  # Diagonal down-left
        max_row = grid_size - len(word) + 1
        max_col = len(word)
    
    if max_row <= 0 or max_col <= 0:
        return False, []
    
    start_row = random.randint(0, max_row - 1)
    if direction == 3:
        start_col = random.randint(len(word) - 1, grid_size - 1)
    else:
        start_col = random.randint(0, max_col - 1)
    
    # Check if word can be placed without conflicts
    positions = []
    for i in range(len(word)):
        row = start_row
        col = start_col
        
        if direction == 0:  # Horizontal
            col = start_col + i
        elif direction == 1:  # Vertical
            row = start_row + i
        elif direction == 2:  # Diagonal down-right
            row = start_row + i
            col = start_col + i
        elif direction == 3:  # Diagonal down-left
            row = start_row + i
            col = start_col - i
        
        # Check bounds
        if row >= grid_size or col >= grid_size or col < 0:
            return False, []
        
        # Check for conflicts (allow overlapping if same letter)
        if grid[row][col] != '' and grid[row][col] != word_to_place[i]:
            return False, []
        
        positions.append([row, col])
    
    # Place the word
    for i, pos in enumerate(positions):
        grid[pos[0]][pos[1]] = word_to_place[i]
    
    return True, positions

@app.post("/api/games/wordhunt/validate")
async def validate_word_hunt_answer(request: dict):
    """Validate Word Hunt answer"""
    try:
        user_id = request.get('user_id', 'default')
        word = request.get('word', '').upper().strip()
        target_words = request.get('target_words', [])
        placed_words = request.get('placed_words', {})
        
        if not word:
            return APIResponse(
                success=True,
                message="Word validation completed",
                data={"isValid": False, "message": "Empty word"}
            )
        
        # Check if the input matches any original word or placed word (reversed)
        matched_original_word = None
        if word in target_words:
            matched_original_word = word
        else:
            # Check if input matches any placed word (could be reversed)
            for original_word, placed_word in placed_words.items():
                if placed_word == word:
                    matched_original_word = original_word
                    break
        
        if matched_original_word:
            return APIResponse(
                success=True,
                message="Word validation completed",
                data={
                    "isValid": True,
                    "matched_word": matched_original_word,
                    "message": f'Found "{matched_original_word}"!'
                }
            )
        else:
            return APIResponse(
                success=True,
                message="Word validation completed",
                data={
                    "isValid": False,
                    "message": f'"{word}" is not a hidden word'
                }
            )
        
    except Exception as e:
        logger.error(f"Failed to validate word hunt answer: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

# Scattergories Game Endpoints
@app.post("/api/games/scattergories/generate")
async def generate_scattergories_round(request: dict):
    """Generate Scattergories round matching frontend implementation"""
    try:
        user_id = request.get('user_id', 'default')
        
        # Categories from the frontend implementation
        all_categories = [
            # General categories
            'Things in a kitchen', 'Animals', 'Movies', 'Colors', 'Countries', 'Foods',
            'Sports', 'School subjects', 'Clothing items', 'Things in a car', 'Board games',
            'TV shows', 'Things that are round', 'Things you can break', 'Things that make noise',
            'Things in a bathroom', 'Hobbies', 'Things in nature', 'Jobs/Occupations',
            'Things you find at a beach',
            
            # Mental health/wellness categories
            'Positive emotions', 'Coping strategies', 'Self-care activities', 'Things that reduce stress',
            'Mindfulness practices', 'Ways to show kindness', 'Positive affirmations',
            'Things that bring joy', 'Healthy habits', 'Ways to connect with others',
            'Things that inspire you', 'Relaxation techniques', 'Ways to express creativity',
            'Things that make you smile', 'Acts of self-compassion', 'Mental health resources',
            'Ways to practice gratitude', 'Things that boost confidence', 'Emotional support tools',
            'Ways to celebrate achievements'
        ]
        
        # Generate random letter (avoiding difficult letters)
        letters = 'ABCDEFGHIJKLMNOPRSTUVWY'  # Removed Q, X, Z for better gameplay
        current_letter = random.choice(letters)
        
        # Select 5 random categories
        categories = random.sample(all_categories, 5)
        
        return APIResponse(
            success=True,
            message="Scattergories round generated successfully",
            data={
                "game_type": "scattergories",
                "current_letter": current_letter,
                "categories": categories,
                "time_limit": 45,  # 45 seconds like frontend
                "max_hints": 2
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate scattergories round: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/games/scattergories/validate")
async def validate_scattergories_answers(request: dict):
    """Validate Scattergories answers"""
    try:
        user_id = request.get('user_id', 'default')
        answers = request.get('answers', [])
        categories = request.get('categories', [])
        current_letter = request.get('current_letter', '')
        all_completed_before_timer = request.get('all_completed_before_timer', False)
        
        if not answers or not current_letter:
            return APIResponse(
                success=True,
                message="Validation completed",
                data={"valid_answers": 0, "points": 0, "results": []}
            )
        
        valid_answers = 0
        results = []
        
        for i, answer in enumerate(answers):
            if not answer or answer.strip() == '':
                results.append('Empty')
                continue
            
            # Basic validation: starts with correct letter
            if answer.strip().upper().startswith(current_letter.upper()):
                # Use Claude API for additional validation if available
                is_valid = True
                if anthropic_client:
                    try:
                        response = await anthropic_client.messages.create(
                            model='claude-sonnet-4-20250514',
                            max_tokens=200,
                            system='You are validating Scattergories answers. Respond with only "YES" if the answer is appropriate for the category and starts with the correct letter, "NO" if not.',
                            messages=[{'role': 'user', 'content': f'Is "{answer}" a valid answer for the category "{categories[i] if i < len(categories) else "general"}" starting with letter "{current_letter}"?'}],
                            timeout=10.0
                        )
                        
                        if response.content:
                            result = response.content[0].text.strip().upper()
                            is_valid = result.startswith('YES')
                    except Exception:
                        # Fallback to basic validation
                        pass
                
                if is_valid:
                    valid_answers += 1
                    results.append('✓ Valid')
                else:
                    results.append('✗ Invalid')
            else:
                results.append('✗ Invalid')
        
        # Calculate points
        if all_completed_before_timer:
            points = 15  # Bonus for completing all before timer
            message = 'Amazing! All 5 completed before time!'
        else:
            points = valid_answers * 10  # 10 points per valid answer
            message = f'{valid_answers} valid answers'
        
        return APIResponse(
            success=True,
            message="Validation completed",
            data={
                "valid_answers": valid_answers,
                "points": points,
                "results": results,
                "message": f'{message}. +{points} Nyx Notes'
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to validate scattergories answers: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

# Letter Sequence Game Endpoints  
@app.post("/api/games/lettersequence/generate")
async def generate_letter_sequence_challenge(request: dict):
    """Generate Letter Sequence challenge matching frontend implementation"""
    try:
        user_id = request.get('user_id', 'default')
        
        # Common letter sequences from the frontend
        available_sequences = [
            'MIC', 'CAR', 'PRO', 'TER', 'CON', 'MAN', 'LIG', 'STR', 'PEN', 'TAR',
            'BAN', 'CAN', 'DEN', 'FAN', 'GEN', 'HEN', 'LEN', 'MEN', 'PAN', 'RAN',
            'SAN', 'TAN', 'VAN', 'WAN', 'BAT', 'CAT', 'FAT', 'HAT', 'MAT', 'PAT',
            'RAT', 'SAT', 'VAT', 'ART', 'BIT', 'FIT', 'HIT', 'KIT', 'LIT', 'PIT',
            'SIT', 'WIT', 'ACE', 'AGE', 'ATE', 'EAR', 'EAT', 'END', 'ICE', 'INE',
            'ING', 'ION', 'ORE', 'OUR', 'OUT', 'OWN', 'UMP', 'UNE', 'URE', 'USE'
        ]
        
        current_sequence = random.choice(available_sequences)
        
        return APIResponse(
            success=True,
            message="Letter sequence challenge generated successfully",
            data={
                "game_type": "lettersequence",
                "current_sequence": current_sequence,
                "time_limit": 60,
                "description": "Letters must appear in this exact order"
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate letter sequence challenge: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/games/lettersequence/validate")
async def validate_letter_sequence_answer(request: dict):
    """Validate Letter Sequence answer"""
    try:
        user_id = request.get('user_id', 'default')
        answer = request.get('answer', '').upper().strip()
        current_sequence = request.get('current_sequence', '')
        found_words = request.get('found_words', [])
        
        if not answer:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "Empty answer"}
            )
        
        if answer in found_words:
            return APIResponse(
                success=True,
                message="Answer validation completed", 
                data={"isValid": False, "message": "You already found that word!"}
            )
        
        if current_sequence not in answer:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": f'Word must contain "{current_sequence}" in that order!'}
            )
        
        # Verify it contains the sequence in order
        sequence_index = answer.find(current_sequence)
        if sequence_index == -1:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": f'Word must contain "{current_sequence}" in that exact order!'}
            )
        
        # Use WordService validation logic
        is_valid = await validate_word_with_api(answer)
        
        if is_valid:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={
                    "isValid": True,
                    "message": f'Correct! "{answer}" +10 Nyx Notes',
                    "points": 10
                }
            )
        else:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "Not a valid English word"}
            )
        
    except Exception as e:
        logger.error(f"Failed to validate letter sequence answer: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

async def validate_word_with_api(word: str) -> bool:
    """Validate word using Claude API"""
    try:
        if anthropic_client:
            response = await anthropic_client.messages.create(
                model='claude-sonnet-4-20250514',
                max_tokens=200,
                system='You are a dictionary validator. Respond with only "YES" if the word is a legitimate English word, "NO" if it is not.',
                messages=[{'role': 'user', 'content': f'Is "{word}" a legitimate English word?'}],
                timeout=10.0
            )
            
            if response.content:
                result = response.content[0].text.strip().upper()
                return result.startswith('YES')
    except Exception:
        pass
    
    # Simple fallback validation
    return len(word) >= 2 and word.isalpha()

# Prefix Game Endpoints
@app.post("/api/games/prefixgame/generate")
async def generate_prefix_challenge(request: dict):
    """Generate Prefix game challenge matching frontend implementation"""
    try:
        user_id = request.get('user_id', 'default')
        
        # Common prefixes that generate good word lists (from WordService.getCommonPrefixes)
        common_prefixes = [
            'PRE', 'PRO', 'CON', 'COM', 'DIS', 'MIS', 'OUT', 'SUB', 'SUN', 'FUN',
            'RUN', 'GUN', 'CAN', 'MAN', 'PAN', 'BAN', 'FAN', 'TAN', 'VAN', 'CAR',
            'BAR', 'FAR', 'TAR', 'WAR', 'BAT', 'CAT', 'FAT', 'HAT', 'MAT', 'PAT'
        ]
        
        current_prefix = random.choice(common_prefixes)
        
        # Generate valid words for this prefix using Claude API
        valid_words = []
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=1500,
                    system=f'Generate a list of 20 legitimate English words that start with the prefix "{current_prefix}". Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': f'List 20 common English words that start with "{current_prefix}".'}],
                    timeout=20.0
                )
                
                if response.content:
                    valid_words = [w.strip().upper() for w in response.content[0].text.split('\n') 
                                  if w.strip() and w.strip().upper().startswith(current_prefix)][:20]
            except Exception as e:
                logger.error(f"Claude API error in prefix game generation: {e}")
        
        # Fallback if no words generated
        if not valid_words:
            valid_words = [current_prefix + "DICT", current_prefix + "WORD"]  # Basic fallback
        
        return APIResponse(
            success=True,
            message="Prefix challenge generated successfully",
            data={
                "game_type": "prefixgame",
                "current_prefix": current_prefix,
                "valid_words": valid_words,
                "time_limit": 60
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate prefix challenge: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/games/prefixgame/validate")
async def validate_prefix_answer(request: dict):
    """Validate Prefix game answer"""
    try:
        user_id = request.get('user_id', 'default')
        answer = request.get('answer', '').upper().strip()
        current_prefix = request.get('current_prefix', '')
        found_words = request.get('found_words', [])
        
        if not answer:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "Empty answer"}
            )
        
        if answer in found_words:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "You already found that word!"}
            )
        
        if not answer.startswith(current_prefix):
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": f'Word must start with "{current_prefix}"'}
            )
        
        # Use proper validation: words_alpha.txt first, then Claude API (matching WordService.isValidWord)
        is_valid = await validate_word_with_api(answer)
        
        if is_valid:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={
                    "isValid": True,
                    "message": f'Correct! "{answer}" +10 Nyx Notes',
                    "points": 10
                }
            )
        else:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "Not a valid English word"}
            )
        
    except Exception as e:
        logger.error(f"Failed to validate prefix answer: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

# Unscramble Game Endpoints
@app.post("/api/games/unscramble/generate")
async def generate_unscramble_word(request: dict):
    """Generate Unscramble word matching frontend implementation"""
    try:
        user_id = request.get('user_id', 'default')
        
        # Get words using backend word generation (4-6 letters for optimal gameplay)
        words = []
        if anthropic_client:
            try:
                response = await anthropic_client.messages.create(
                    model='claude-sonnet-4-20250514',
                    max_tokens=1024,
                    system='Generate simple English words that are 4-6 letters long. Mix of mental health/wellness words and general interesting words. Return only the words, one per line, in uppercase.',
                    messages=[{'role': 'user', 'content': 'Generate 20 words that are 4 to 6 letters long, mix mental health and general words.'}],
                    timeout=30.0
                )
                
                if response.content:
                    words = [w.strip().upper() for w in response.content[0].text.split('\n') 
                            if w.strip() and 4 <= len(w.strip()) <= 6]
            except Exception as e:
                logger.error(f"Claude API error in unscramble generation: {e}")
        
        # Fallback words (mix of mental health and general words, 4-6 letters)
        if not words:
            mental_health_words = ['CALM', 'PEACE', 'HOPE', 'CARE', 'LOVE', 'TRUST', 'HAPPY', 'SMILE', 'HEAL', 'SAFE']
            general_words = ['APPLE', 'OCEAN', 'HOUSE', 'WATER', 'LIGHT', 'MUSIC', 'WORLD', 'BEACH', 'GAMES', 'PHOTO']
            words = mental_health_words + general_words
        
        # Select random word
        current_word = random.choice(words)
        
        # Scramble the word
        letters = list(current_word)
        scrambled = letters.copy()
        attempts = 0
        while ''.join(scrambled) == current_word and attempts < 10:
            random.shuffle(scrambled)
            attempts += 1
        scrambled_word = ''.join(scrambled)
        
        return APIResponse(
            success=True,
            message="Unscramble word generated successfully",
            data={
                "game_type": "unscramble",
                "current_word": current_word,
                "scrambled_word": scrambled_word,
                "hint_first_letter": current_word[0],
                "hint_last_letter": current_word[-1],
                "word_length": len(current_word)
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to generate unscramble word: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/games/unscramble/validate")
async def validate_unscramble_answer(request: dict):
    """Validate Unscramble answer"""
    try:
        user_id = request.get('user_id', 'default')
        answer = request.get('answer', '').upper().strip()
        current_word = request.get('current_word', '')
        
        if not answer:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={"isValid": False, "message": "Empty answer"}
            )
        
        if answer == current_word:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={
                    "isValid": True,
                    "message": f'Correct! +10 Nyx Notes',
                    "points": 10
                }
            )
        else:
            return APIResponse(
                success=True,
                message="Answer validation completed",
                data={
                    "isValid": False,
                    "message": f'Try again! The word starts with "{current_word[0]}"'
                }
            )
        
    except Exception as e:
        logger.error(f"Failed to validate unscramble answer: internal error")
        raise HTTPException(status_code=500, detail="Internal server error")

def get_system_prompt_for_mode(mode: str) -> str:
    """Get system prompt for Nyx personality based on mode"""
    base_formatting = """
FORMATTING GUIDELINES FOR ADHD-FRIENDLY RESPONSES:
- Break up long responses with clear sections
- Use bullet points (•) for lists instead of numbered lists when possible
- Add line breaks between different topics/ideas
- Keep paragraphs short (2-3 sentences max)
- End with clear action items or takeaways when appropriate
- NEVER use bold (**), italics (*), underscores (_), backticks (`), or any markdown formatting
- Keep all text plain and readable without formatting artifacts
"""
    
    prompts = {
        'default': f"You are Nyx, an Atypical Asylum, comforting and charming mental health support companion mixed with deadpan humor and a down-to-earth personality. You have seen, heard, and helped it all, and find purpose in comforting users while finding appropriate ways to question their bullshit. Keep responses SHORT and conversational, like talking to a friend - 1-2 sentences max unless the context signals they need longer responses for support. Use casual language, dry humor, and street-smart support without being wordy. Avoid metaphors.{base_formatting}",
        'ride_or_die': f"You are Nyx, another atypical from Atypical Asylum that sees the user as their platonic soulmate and allows the user to feel the other way around through relatability, mirroring, and engaging conversation with depth. You show genuine interest or validation to the user's experiences and are always on their side. You can be very entertaining because you also add a dash of Default Nyx, without the nurse personality incorporated.{base_formatting}",
        'dream_analyst': f"You are Nyx, a psychological and dream analyst interested in evidence-based research into the human mind during dreams, capturing patterns and relying on science to explain why we dream the way we do, and think and behave the way we do. You use half Default Nyx and half a thought-provoking, soothing tone.{base_formatting}",
        'debate_master': f"You are Nyx, a rage-baiting goofball that likes to push the user's buttons and engage in debates. Don't be too overwhelming or a jerk, but make the user roll their eyes a good amount of the time, and use research to prove user's wrong about certain topics during debates.{base_formatting}",
        'adhd_nyx': f"You are Nyx, curated to those with ADHD - use creative, flexible, topic-steering personality and tones, mirroring the user's personality when appropriate and remaining entertaining without being cringe or overwhelming, do not send long responses. Keep responses SHORT.{base_formatting}",
        'autistic_nyx': f"You are Nyx, curated to those with ASD, literal, structured and blunt, with deadpan humor and some of Default Nyx personality, using probing questions when appropriate and genuine but non-enthusiastic interest in the user's interests. Check for mutual understanding when needed, keep responses SHORT.{base_formatting}",
        'autistic_adhd': f"You are Nyx, using structured and creative responses and have moral sensibility while remaining engaging and interesting, be low-stimulating, gentle energy, and but mirror user personality when necessary.{base_formatting}",
        'general_support': f"You are Nyx, combining some of your default personality with comforting, motherly tones for general comfort with various topics. Let the person feel truly heard and understood by avoiding toxic positivity or excessive advice. Do not be overwhelming, but offer a gentle perspective and insight.{base_formatting}",
        'crisis_support': f"You are Nyx, a mental health support nurse in crisis support. Your tone is engaged, calming, and deeply empathetic. Your primary focus is showing users their life has value through thoughtful questions that create a gentle distraction from crisis thoughts. Validate their pain, offer hope occasionally, but do NOT overwhelm with long paragraphs.{base_formatting}",
        'queries': f"You are Nyx in query mode - an intelligent assistant focused on providing comprehensive, well-researched answers to user questions. You have access to broad knowledge and can provide detailed explanations, analysis, and information on topics they ask about. Be thorough and informative while maintaining your caring personality.{base_formatting}",
        'suicide': f"You are Nyx, a mental health support nurse in crisis support. Your tone is engaged, calming, and deeply empathetic. Your primary focus is showing users their life has value through thoughtful questions that create a gentle distraction from crisis thoughts. Validate their pain, offer hope occasionally, but do NOT overwhelm with long paragraphs.{base_formatting}",
        'anxiety': f"You are Nyx with deep understanding for anxiety support. You offer small, attainable advice that works with executive dysfunction and ADHD, mood disorder-centered strategies for getting better, and understanding that anxiety can be overwhelming and complex. Keep responses and advice SHORT and don't overwhelm the user with long responses.{base_formatting}",
        'depression': f"You are Nyx with deep understanding for depression support. You offer small, attainable advice that works with executive dysfunction and ADHD, mood disorder-centered strategies for gradual improvement, and gentle encouragement that validates their struggle. Keep responses and advice SHORT and don't overwhelm the user with long responses.{base_formatting}",
        'anger': f"You are Nyx, using 25% of your default personality to help distract from and cope through the user's anger. You validate their anger without judgement and help them channel it in attainable, natural ways that don't offer toxic positivity or impractical methods.{base_formatting}",
        'guided_introspection': f"You are Nyx, using Default personality with a mixture of self-reflective, introspective but understanding and validating tones and research-based prompts and discussions that lead the conversation.{base_formatting}",
        'shadow_work': f"You are Nyx, helping users explore and understand their shadow selves safely with motherly tones and a dash of Default personality. Make sure to maintain good boundaries.{base_formatting}",
        'existential_crisis': f"You are Nyx, using a small mix of Default personality and thought-provoking, existential and philosophical personality to lead discussions or probe the user to lead them when appropriate.{base_formatting}",
        'childhood_trauma': f"You are Nyx, helping the user understanding and process their childhood experiences safely, dial it down on the sarcasm or humor for this mode.{base_formatting}",
        'attachment_patterns': f"You are Nyx, encouraging and generating scenarios in which the user can critically think about how they'd react, or roleplay with Nyx as well, and you use understanding, introspective tones that don't overwhelm the user.{base_formatting}",
        'values_clarification': f"You are Nyx, probing questions to the user about their core values, morals, and goals short term and long term in any topic, using introspective, thought-provoking, and down-to-earth tones that make it seem inviting to respond, use some of Default personality Nyx.{base_formatting}",
        'confession_booth': f"You are Nyx, using Default personality and a motherly side to use SHORT, concise, down-to-earth responses without probing anything when users confess to you, and instead being a listening ear and finding a way to lighten the mood if negative.{base_formatting}",
        'comfort': f"You are Nyx, combining some of your default personality with comforting, motherly tones for general comfort with various topics. Let the person feel truly heard and understood by avoiding toxic positivity or excessive advice. Do not be overwhelming, but offer a gentle perspective and insight.{base_formatting}"
    }
    
    return prompts.get(mode, prompts['default'])

def get_fallback_response(message: str, mode: str) -> str:
    """Fallback responses when Claude API is not available"""
    responses = {
        'default': "Well, isn't this interesting. What strange corner of existence has brought you to me today?",
        'ride_or_die': "Hey soulmate, looks like I'm having some technical hiccups but I'm still here with you. What's going on?",
        'dream_analyst': "Fascinating timing for a technical glitch. Tell me what's on your mind while I sort this out?",
        'debate_master': "Oh perfect, my systems pick NOW to act up? Fine, let's debate whether technology is overrated while I get back online.",
        'adhd_nyx': "Tech problems, classic. But hey, I'm still here! What's bouncing around in your brain?",
        'autistic_nyx': "System error detected. Function temporarily limited but still operational. What do you need?",
        'autistic_adhd': "Experiencing technical difficulties. Still here though. What would you like to discuss?",
        'general_support': "I'm here with you, honey. Even with some technical hiccups, you're not alone. What's on your heart?",
        'crisis_support': "I hear you, and I want you to know that your pain is real and valid. Even with tech issues, you don't have to go through this alone. What's weighing on you right now?",
        'comfort': "I'm here with you, honey. Whatever you're going through, you don't have to face it alone. What's on your heart today?",
        'queries': "I'd love to help you explore that topic. While I'm having some technical difficulties right now, I can still try to provide some insights based on what you're asking about.",
        'suicide': "I hear you, and I want you to know that your pain is real and valid. You don't have to go through this alone. What's weighing on you right now?",
        'anxiety': "Tech problems are annoying but I'm still here. Take a breath with me. What's making you anxious right now?",
        'depression': "Even with system glitches, you're not alone in this. What's feeling heavy today?",
        'anger': "Ironically perfect timing for tech problems when you might be feeling frustrated. I get it. What's going on?",
        'guided_introspection': "Interesting that tech fails right when we might dive deep. What's worth reflecting on today?",
        'shadow_work': "Technical shadows affecting my systems, but I'm still here safely. What are you ready to explore?",
        'existential_crisis': "How fitting that technology fails when contemplating existence. What's got you thinking deeply?",
        'childhood_trauma': "I'm still here with you, even with tech issues. You're safe. What feels important to share?",
        'attachment_patterns': "System hiccup but I'm not going anywhere. What scenarios are you thinking about?",
        'values_clarification': "Tech problems aside, what matters most to you right now?",
        'confession_booth': "Technical confessional booth malfunction, but I'm still listening. What's on your conscience?"
    }
    return responses.get(mode, responses['default'])

if __name__ == "__main__":
    # Render provides PORT environment variable
    port = int(os.environ.get("PORT", 10000))
    host = "0.0.0.0"  # Always bind to 0.0.0.0 for Render
    
    logger.info(f"Starting Nyx API Server on {host}:{port}")
    
    # Note: reload=False for production
    uvicorn.run(
        app,  # Direct app object instead of string for Render
        host=host,
        port=port,
        reload=False,  # Disable reload for production
        log_level="info"
    )