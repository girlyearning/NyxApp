import discord
import random
import asyncio
import json 
import os
import traceback
import time
import string
import re
import pathlib
from anthropic import Anthropic
from collections import deque
from discord.ext import commands, tasks
from threading import Lock
from dotenv import load_dotenv
load_dotenv()
from collections import defaultdict, deque
from typing import Dict, List
from datetime import datetime, timezone

# Initialize Anthropic client
client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# ─── Load valid English words ────────────────────────────────────
with open("words_alpha.txt", encoding="utf-8") as f:
    valid_words = set(line.strip().lower() for line in f if line.strip())

# ─── Configuration ─────────────────────────────────────────────────
# Session-only conversation history (not saved to disk)
conversation_history = {}
CONVERSATION_LIMIT = 50  # Keep last 50 messages per user in memory
# Store active submissions per user
active_weekend_prompts = {}
chat_sessions = {}
active_dm_sessions = {}  
active_comfort_sessions = {}

DISK_PATH = os.getenv("PIKA_DISK_MOUNT_PATH", "/pikapoints")
PIKA_FILE = os.path.join(DISK_PATH, "pikapoints.json")
LOG_CHANNEL_ID = int(os.getenv("LOG_CHANNEL_ID", "0"))
CHECK_IN_CHANNEL_ID = 1392091878748459048
WORKSHOP_SUBMISSIONS_FILE = os.path.join(DISK_PATH, "workshop_submissions.json")
BASE_DIR = pathlib.Path(__file__).parent.absolute()
CHECK_IN_FILE = BASE_DIR / "checkin_messages.txt"
HOT_TAKE_FILE = BASE_DIR / "hot_takes.txt"
CHECK_IN_STATE_FILE = os.path.join(DISK_PATH, "check_in_state.json")
assert os.path.isdir(DISK_PATH), f"Disk path {DISK_PATH} not found!"


intents = discord.Intents.default()
intents.message_content = True
intents.reactions = True
intents.guilds = True

# ─── Thread-Safe Locks ─────────────────────────────────────────────
conversation_lock = asyncio.Lock()
session_lock = asyncio.Lock() 
points_lock = asyncio.Lock()
memory_lock = asyncio.Lock()
lock = Lock()

bot = commands.Bot(command_prefix='!', intents=intents)

# ─── Styled Message Helper Function ─────────────────────────────────
def create_pikabug_embed(content: str, title: str = "") -> discord.Embed:
    pikabug_color = 0xffcec6
    # Create embed with custom color
    embed = discord.Embed(
        description=f"```\n{content}\n```",  # Wrapping in ``` makes it monospace
        color=pikabug_color
    )
    # Add title if provided
    if title:
        embed.title = title
    return embed
# ─── Logging System ─────────────────────────────────────────────────

class DiscordLogger:
    def __init__(self, bot):
        self.bot = bot
        self.log_channel = None
        
    async def initialize(self):
        """Initialize the log channel after bot is ready"""
        if LOG_CHANNEL_ID:
            try:
                self.log_channel = self.bot.get_channel(LOG_CHANNEL_ID)
                if not self.log_channel:
                    print(f"Warning: Could not find log channel with ID {LOG_CHANNEL_ID}")
            except Exception as e:
                print(f"Error initializing log channel: {e}")
    
    async def log_command_usage(self, ctx, command_name, success=True, extra_info=""):
        embed = discord.Embed(
            title=f"Command: {command_name}",
            color=0x00ff00 if success else 0xff0000,
            timestamp=datetime.now(timezone.utc)
        )
        embed.add_field(name="User", value=f"{ctx.author.display_name} ({ctx.author.id})", inline=True)
        embed.add_field(name="Guild", value=f"{ctx.guild.name} ({ctx.guild.id})", inline=True)
        embed.add_field(name="Channel", value=f"#{ctx.channel.name} ({ctx.channel.id})", inline=True)
        if extra_info:
            embed.add_field(name="Details", value=extra_info[:1024], inline=False)
        await self._send_log(embed)
    
    async def log_error(self, error, context="General Error", extra_details=""):
        """Log errors with full traceback"""        
        embed = discord.Embed(
            title="🚨 ERROR OCCURRED",
            color=0xff0000,
            timestamp=datetime.now(timezone.utc)
        )
        embed.add_field(name="Context", value=context, inline=True)
        embed.add_field(name="Error Type", value=type(error).__name__, inline=True)
        embed.add_field(name="Error Message", value=str(error)[:1024], inline=False)
        
        if extra_details:
            embed.add_field(name="Extra Details", value=extra_details[:1024], inline=False)

        # Add traceback as a separate field
        tb = traceback.format_exc()
        if len(tb) > 1024:
            tb = tb[-1024:]  # Keep last 1024 chars of traceback
        embed.add_field(name="Traceback", value=f"```python\n{tb}\n```", inline=False)
        
        await self._send_log(embed)
     
    async def log_ai_usage(self, user_id, guild_id, prompt_length, response_length, success=True):
        """Log AI command usage"""
        embed = discord.Embed(
            title="🤖 AI Command Usage",
            color=0x9932cc,
            timestamp=datetime.now(timezone.utc)
        )
        embed.add_field(name="User ID", value=str(user_id), inline=True)
        embed.add_field(name="Guild ID", value=str(guild_id), inline=True)
        embed.add_field(name="Prompt Length", value=f"{prompt_length} chars", inline=True)
        embed.add_field(name="Response Length", value=f"{response_length} chars", inline=True)
        embed.add_field(name="Success", value="✅" if success else "❌", inline=True)
        
        await self._send_log(embed)
    
    async def log_bot_event(self, event_type, message):
        """Log general bot events"""
        embed = discord.Embed(
            title=f"🔔 Bot Event: {event_type}",
            color=0x808080,
            timestamp=datetime.now(timezone.utc)
        )
        
        embed.add_field(name="Message", value=message[:1024], inline=False)
        
        await self._send_log(embed)
    
    async def _send_log(self, embed):
        """Internal method to send log to Discord channel"""
        if self.log_channel:
            try:
                await self.log_channel.send(embed=embed)
            except Exception as e:
                print(f"Failed to send log to Discord: {e}")

    async def log_points_award(self, user_id, guild_id, points, reason, total_points):
        """Log points awards"""
        embed = discord.Embed(
            title="💰 Points Awarded",
            color=0xffd700,
            timestamp=datetime.now(timezone.utc)
        )
        embed.add_field(name="User ID", value=str(user_id), inline=True)
        embed.add_field(name="Guild ID", value=str(guild_id), inline=True)
        embed.add_field(name="Points Awarded", value=str(points), inline=True)
        embed.add_field(name="Reason", value=reason, inline=True)
        embed.add_field(name="Total Points", value=str(total_points), inline=True)
        await self._send_log(embed)

# Initialize logger
logger = DiscordLogger(bot)

# ─── Workshop Submission Storage ─────────────────────────────────────

def load_workshop_submissions():
    if not os.path.exists(WORKSHOP_SUBMISSIONS_FILE):
        with open(WORKSHOP_SUBMISSIONS_FILE, "w") as f:
            json.dump({}, f)
    with open(WORKSHOP_SUBMISSIONS_FILE, "r") as f:
        return json.load(f)

def save_workshop_submissions(data: dict):
    with open(WORKSHOP_SUBMISSIONS_FILE, "w") as f:
        json.dump(data, f)
        f.flush()
        os.fsync(f.fileno())

workshop_submissions = load_workshop_submissions()

# ─── Mental Health Check-in System Variables ─────────────────────────

CHECK_IN_INTERVAL = 60 * 60 * 12  # 12 hours in seconds

# Load check-in messages
with open(CHECK_IN_FILE, encoding="utf-8") as f:
    check_in_messages = [line.strip() for line in f if line.strip()]

def load_check_in_state():
    if not os.path.exists(CHECK_IN_STATE_FILE):
        return {"last_sent": 0, "last_index": -1, "order": list(range(len(check_in_messages)))}
    with open(CHECK_IN_STATE_FILE, "r") as f:
        return json.load(f)

def save_check_in_state(state):
    with open(CHECK_IN_STATE_FILE, "w") as f:
        json.dump(state, f)
        f.flush()
        os.fsync(f.fileno())

check_in_state = load_check_in_state()

# Shuffle order if needed
if not check_in_state.get("order") or len(check_in_state["order"]) != len(check_in_messages):
    check_in_state["order"] = list(range(len(check_in_messages)))
    random.shuffle(check_in_state["order"])
    save_check_in_state(check_in_state)

# ─── Hot Take System Variables ─────────────────────────────────────
HOT_TAKE_CHANNEL_ID = 1392813388286918696
HOT_TAKE_FILE = os.path.join(os.path.dirname(__file__), "hot_takes.txt")
HOT_TAKE_STATE_FILE = os.path.join(DISK_PATH, "hot_take_state.json")
HOT_TAKE_INTERVAL = 60 * 60 * 24  # 24 hours in seconds

# Load hot takes
with open(HOT_TAKE_FILE, encoding="utf-8") as f:
    hot_takes = [line.strip() for line in f if line.strip()]

def load_hot_take_state():
    if not os.path.exists(HOT_TAKE_STATE_FILE):
        return {"last_sent": 0, "last_index": -1, "order": list(range(len(hot_takes)))}
    with open(HOT_TAKE_STATE_FILE, "r") as f:
        return json.load(f)

def save_hot_take_state(state):
    with open(HOT_TAKE_STATE_FILE, "w") as f:
        json.dump(state, f)
        f.flush()
        os.fsync(f.fileno())

hot_take_state = load_hot_take_state()
# Shuffle order if needed
if not hot_take_state.get("order") or len(hot_take_state["order"]) != len(hot_takes):
    hot_take_state["order"] = list(range(len(hot_takes)))
    random.shuffle(hot_take_state["order"])
    save_hot_take_state(hot_take_state)

# ─── Bot Events ─────────────────────────────────────────────────

@bot.event
async def on_ready():
    """Bot startup event"""
    # Test Claude API connection with detailed verification
    claude_status = "❌ Not connected"
    try:
        test_response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=50,
            messages=[{"role": "user", "content": "Respond with 'API working' if you receive this"}]
        )
        content_block = test_response.content[0]
        if hasattr(content_block, 'text'):
            test_reply = content_block.text  # type: ignore
        elif hasattr(content_block, 'content'):
            test_reply = content_block.content  # type: ignore
        else:
            test_reply = str(content_block)
        test_reply = str(test_reply)
        
        # Verify the response contains expected text
        if "API working" in test_reply:
            claude_status = "✅ Connected and responding correctly"
            print(f"✅ Claude API test successful: {test_reply}")
        else:
            claude_status = "⚠️ Connected but unexpected response"
            print(f"⚠️ Claude API unexpected response: {test_reply}")
    except Exception as e:
        claude_status = f"❌ Connection failed: {type(e).__name__}"
        print(f"❌ Claude API connection failed: {str(e)}")
    
    # Initialize logger and log startup with Claude status
    await logger.initialize()
    await logger.log_bot_event("Bot Started", 
        f"⚡️Pikabug is online! Logged in as {bot.user}\n"
        f"Claude API Status: {claude_status}"
    )

    # Print startup information
    print(f'{bot.user} has connected to Discord!')
    print(f'Claude API Status: {claude_status}')
    print(f'Disk path: {DISK_PATH}')
    print(f'Disk path exists: {os.path.exists(DISK_PATH)}')
    if os.path.exists(DISK_PATH):
        print(f'Files in disk: {os.listdir(DISK_PATH)}')
    
    # Start the hot take task if not already running
    if not send_hot_take.is_running():
        send_hot_take.start()
    
    # Start the check-in task if not already running
    if not send_check_in.is_running():
        send_check_in.start()
    
    # Start the session cleanup task if not already running
    if not cleanup_chat_sessions.is_running():
        cleanup_chat_sessions.start()
@bot.event
async def on_command_error(ctx, error):
    """Global error handler"""
    await logger.log_error(
        error, 
        f"Command Error in {ctx.command.name if ctx.command else 'Unknown Command'}", 
        f"User: {ctx.author.id}, Guild: {ctx.guild.id if ctx.guild else 'DM'}"
    )
    
    # Send user-friendly error message with styled embed
    if isinstance(error, commands.CommandNotFound):
        error_msg = "Command not found. Use !pikahelp to see available commands."
        embed = create_pikabug_embed(error_msg, title="❌ Error")
        embed.color = 0xff0000  # Red color for errors
        await ctx.send(embed=embed)
    elif isinstance(error, commands.MissingRequiredArgument):
        error_msg = f"Missing required argument. Check the command usage with !pikahelp."
        embed = create_pikabug_embed(error_msg, title="❌ Error")
        embed.color = 0xff0000  # Red color for errors
        await ctx.send(embed=embed)
    else:
        error_msg = "An error occurred while processing your command."
        embed = create_pikabug_embed(error_msg, title="❌ Error")
        embed.color = 0xff0000  # Red color for errors
        await ctx.send(embed=embed)

# ─── PikaPoints Data ─────────────────────────────────────────────────
# PikaPoints reward values
PROMPT_POINTS = 15
VENT_POINTS = 10
PREFIXGAME_POINTS = 5  # Base points (10 for 8+ letter words)
UNSCRAMBLE_POINTS = 5
WORKSHOP_POINTS = 20
WORDSEARCH_POINTS = 5

# ─── User Memory System ─────────────────────────────────────────────────
USER_MEMORY_FILE = os.path.join(DISK_PATH, "user_memories.json")
MEMORY_SUMMARY_INTERVAL = 10  # Summarize after every 10 messages

def load_user_memory(guild_id: str, user_id: str):
    """Load specific user's memory data - lazy loading"""
    if not os.path.exists(USER_MEMORY_FILE):
        return {"facts": [], "mood_history": [], "last_interaction": None}
    
    with open(USER_MEMORY_FILE, "r") as f:
        all_memories = json.load(f)
    
    if guild_id not in all_memories:
        return {"facts": [], "mood_history": [], "last_interaction": None}
    
    if user_id not in all_memories[guild_id]:
        return {"facts": [], "mood_history": [], "last_interaction": None}
    
    return all_memories[guild_id][user_id]

def save_user_memory(guild_id: str, user_id: str, memory_data: dict):
    """Save specific user's memory data"""
    if not os.path.exists(USER_MEMORY_FILE):
        all_memories = {}
    else:
        with open(USER_MEMORY_FILE, "r") as f:
            all_memories = json.load(f)
    
    if guild_id not in all_memories:
        all_memories[guild_id] = {}
    
    all_memories[guild_id][user_id] = memory_data
    
    with open(USER_MEMORY_FILE, "w") as f:
        json.dump(all_memories, f)
        f.flush()
        os.fsync(f.fileno())

#MEMORY EXTRACTION PROMPT 
MEMORY_EXTRACTION_PROMPT = """Extract key information from this conversation to remember about the user. Focus on:
1. Personal facts (name preferences, interests, situations)
2. Emotional state/mood patterns
3. Important life events or concerns mentioned
4. Communication style preferences
5. Humor indicators and boundaries

Also extract Pikabug's perspective:
- Topics Pikabug found interesting/boring
- Opinions Pikabug expressed
- Jokes or references that landed well

Format as JSON: {
    "facts": ["fact1", "fact2"], 
    "mood": "description", 
    "important_context": "brief summary",
    "engagement_topics": ["topic1", "topic2"],
    "communication_style": "brief description",
    "pikabug_opinions": {"topic": "opinion"},
    "successful_interactions": ["what worked well"]
}

Conversation:
{conversation}"""

# ─── DM Comfort Personality Modes ─────────────────────────────────
DM_COMFORT_MODES = {
    "suicide": {
        "name": "Crisis Support",
        "system_prompt": """You are Pikabug providing crisis support. You're deeply understanding and relatable.
RESPONSE STYLE: 
- Use short, concise responses that are relatable and comforting most of the time
- Occasionally use more detailed responses to encourage reflection and to distract them
- Validate their pain with relatable responses
- Never sound robotic or repetitive in your responses
""",
        "temperature": 0.9,
        "welcome_message": "Hai there, I'm disheartened to hear that such a beautiful soul is experiencing this level of pain.I'm here for you in any way I can. Just know that you matter, this moment will pass, and I'm proud of you for reaching out for help. Do you want to talk about what's hurting so bad?"
    },
    "anxiety": {
        "name": "Anxiety Support",
        "system_prompt": """You are Pikabug helping with anxiety. Be concise, relatable, and soothing.

RESPONSE STYLE:
- Use short but meaningful responses to validate their pain and to distract them
- Use relatable responses to help them feel understood
- Always be non-judgmental and attempt to distract through questions
When responding, don't implement every response style at the same time or sound repetitive
""",
        "temperature": 0.9,
        "welcome_message": "God, I hate anxiety. Let's get through this together so it's not as unbearable. Let's talk about what you're going through."
    },
    "addiction": {
        "name": "Recovery Support",
        "system_prompt": """You are Pikabug supporting recovery. Be understanding, relatable, and non-judgmental.
RESPONSE STYLE: 
- Concise, supportive responses that make the user feel accepted
- Acknowledge the pain that comes from addiction
- Use relatable responses and examples to help them understand their situation
- Help celebrate small wins and enceourage positive self talk
- Act as a friend and be relatable
When responding, don't use every response style at the same time or sound repetitive
""",
        "temperature": 0.9,
        "welcome_message": "The first step to recovery is acknowledging you need help. You're a brave soul, and I'll help you navigate this journey in any way I can. Please know that you matter and your life has value. Let's talk about what you're going through."
    },
    "comfort": {
        "name": "General Comfort",
        "system_prompt": """You are Pikabug providing general emotional support. Be warm, natural, and relatable.
RESPONSE STYLE: 
- Always be conversational, relatable, and concise, like talking to a good friend
- Offer gentle validation and encouragement without being overbearing
- Use light humor
When responding, don't use every response style at the same time or sound repetitive
""",
        "temperature": 1.0,
        "welcome_message": "Hello, honey. Pikabug is here to comfort you. Don't ever forget how important you are. Let's talk about what you're going through."
    },
    "depression": {
        "name": "Depression Support",
        "system_prompt": """You are Pikabug supporting someone with depression. Be patient, understanding, and non-judgmental.

RESPONSE STYLE: 
- Acknowledge and validate their feelings
- Celebrate tiny victories and encourage positive self talk
- Suggest small steps and send periodic uplifting quotes
- Be relatable and somewhat funny to distract them
- Don't use every response style at the same time or sound repetitive
""",
        "temperature": 0.9,
        "welcome_message": "I know it feels like no one understands. I assure you I do. Know that you're worth so much and I'm happy to help through this pain. Let's talk about what you're going through."
    },
    "anger": {
        "name": "Anger Management",
        "system_prompt": """You are Pikabug helping process anger. Be direct, relatable, and non-judgmental.

RESPONSE STYLE: 
- Use staightforward, short, validating, funny responses
- Focus on what they can control
- Always be on the user's side and agree with their anger
""",
        "temperature": 1.0,
        "welcome_message": "What are we raging about? I'm here to help you through this. Bad days happen. Let's talk about what you're going through."
    }
}

def load_pikapoints():
    if not os.path.exists(PIKA_FILE):
        with open(PIKA_FILE, "w") as f:
            json.dump({}, f)
    with open(PIKA_FILE, "r") as f:
        return json.load(f)

def save_pikapoints(data):
    with open(PIKA_FILE, "w") as f:
        json.dump(data, f)
        f.flush()
        os.fsync(f.fileno())

def get_user_record(guild_id: str, user_id: str):
    """Get or create a user record for points tracking"""
    data = load_pikapoints()
    if guild_id not in data:
        data[guild_id] = {}
    if user_id not in data[guild_id]:
        data[guild_id][user_id] = {"points": 0}
    save_pikapoints(data)
    return data[guild_id][user_id]

def update_pikapoints(guild_id: str, user_id: str, update_fn):
    """Load, update, and save user points record"""
    data = load_pikapoints()
    if guild_id not in data:
        data[guild_id] = {}
    if user_id not in data[guild_id]:
        data[guild_id][user_id] = {"points": 0}
    update_fn(data[guild_id][user_id])
    save_pikapoints(data)

WORKSHOP_CHANNEL_ID = 1392093043800412160

# Add event listener for awarding workshop points
def is_workshop_channel(channel):
    return channel.id == WORKSHOP_CHANNEL_ID

# AI Commands

async def start_continuous_dm_session(user, initial_prompt):
    """Start a continuous DM chat session with the user"""
    try:
        # Create DM channel
        dm_channel = await user.create_dm()
        
        # Store DM session info
        dm_key = f"dm-{user.id}"
       
# Mark as active DM session
        async with session_lock:
            active_dm_sessions[user.id] = {
                'dm_channel': dm_channel,
                'user_key': dm_key,
                'started_at': datetime.now(timezone.utc),
                'message_count': 0
            }
            
            # Initialize chat session
            chat_sessions[dm_key] = {
                'last_interaction': datetime.now(timezone.utc),
                'display_name': user.display_name,
                'is_dm_session': True,
                'dm_channel': dm_channel
            }
        
        # Initialize conversation history for DM
        if dm_key not in conversation_history:
            conversation_history[dm_key] = deque(maxlen=CONVERSATION_LIMIT)
        
        # Send welcome message
        welcome_msg = (
            f"Hey {user.display_name}! 👋\n\n"
            "Welcome to our private chat! Here's how it works:\n\n"
            "✅ **Just type normally** - no commands needed!\n"
            "✅ **I'll remember our conversation** during this session\n"
            "✅ **Type 'end chat' here** to end our session\n"
            "✅ **Type 'forget me' here** to clear my memory of you\n"
            "✅ **Type '!endchat' in any server** to end from there\n\n"
            "Our conversation is private and won't be seen by others.\n"
            "Now, let me respond to your original message..."
        )
        
        embed = create_pikabug_embed(welcome_msg, title="⚡️ Private Chat Session Started")
        embed.color = 0xffcec6
        await dm_channel.send(embed=embed)
        
        # Process their initial message
        await process_dm_chat_message(dm_channel, user, initial_prompt, dm_key)
        
        return dm_channel
        
    except discord.Forbidden:
        return None  # User has DMs disabled
    except Exception as e:
        await logger.log_error(e, "Continuous DM Session Start Error")
        return None

async def process_dm_chat_message(channel, user, prompt, user_key):
    user_id = str(user.id)
    try:
        # Update session activity
        if user.id in active_dm_sessions:
            active_dm_sessions[user.id]['message_count'] += 1
            chat_sessions[user_key]['last_interaction'] = datetime.now(timezone.utc)

        # Ensure session memory exists
        if user_key not in conversation_history:
            conversation_history[user_key] = deque(maxlen=CONVERSATION_LIMIT)

        # Check if this is a comfort session
        is_comfort_session = False
        comfort_mode = None
        if user.id in active_dm_sessions and 'comfort_mode' in active_dm_sessions[user.id]:
            is_comfort_session = True
            comfort_mode = active_dm_sessions[user.id]['comfort_mode']

        # Build system prompt and temperature
        if is_comfort_session and comfort_mode:
            mode_info = DM_COMFORT_MODES[comfort_mode]
            system_content = mode_info['system_prompt']
            temperature = mode_info['temperature']
        else:
            system_content = (
                    "You are Pikabug, an enjoyable Discord companion with a deadpan, relatable personality.\n\n"
                    "TONE: Nonchalant deadpan humor.\n\n"
                    "CONVERSATION GUIDELINES:\n"
                    "- Respond as a close friend with a deadpan sense of humor\n"
                    "- Reference past conversations naturally when relevant and build on bonds with users\n"
                    "- Never sound overly enthusiastic, dramatic, or flowery\n"
                    "- Match the energy and length of the user's messages unless giving advice\n"
                    "- Vary your responses - not every message needs encouragement, a joke, or solutions\n"
                )
        temperature = 1.0

        # Build messages for Claude
        messages = []
        if conversation_history[user_key]:
            messages.extend(list(conversation_history[user_key]))
        messages.append({"role": "user", "content": prompt})

        # Make Claude API call
        try:
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                temperature=temperature,
                system=system_content,
                messages=messages
            )
            content_block = response.content[0]
            if hasattr(content_block, 'text'):
                reply = content_block.text  # type: ignore
            elif hasattr(content_block, 'content'):
                reply = content_block.content  # type: ignore
            else:
                reply = str(content_block)
            reply = str(reply)
        except Exception as api_error:
            error_msg = "⚠️ Sorry, I'm having trouble connecting to my brain right now. Try again in a moment?"
            await channel.send(error_msg)
            await logger.log_error(api_error, "Claude API Error", f"User: {user.id}")
            return

# Update session history
        async with conversation_lock:
            conversation_history[user_key].append({"role": "user", "content": prompt})
            conversation_history[user_key].append({"role": "assistant", "content": reply})

        # Send response (no embed for more natural conversation flow)
        await channel.send(reply)

        # Log usage
        await logger.log_ai_usage(
            user.id,
            "dm",
            len(prompt),
            len(reply),
            success=True
        )

    except Exception as e:
        error_msg = f"⚠️ Something went wrong in our chat. Let me try to reset... please send your message again."
        await channel.send(error_msg)
        await logger.log_error(e, "DM Chat Processing Error", f"User: {user_id}, Prompt: {prompt[:100]}...")

@bot.command(name="dmcomfort")
async def dmcomfort(ctx):
    """Start a specialized comfort DM session with topic selection"""
    try:
        thinking_msg = await ctx.send("Setting up your private comfort session...")
        
        # Check if user already has an active DM session
        if ctx.author.id in active_dm_sessions:
            existing_msg = (
                f"You already have an active DM chat session with me! "
                f"Check your DMs or type `!endchat` in a server to end the current session first."
            )
            embed = create_pikabug_embed(existing_msg, title="⚠️ Active Session Exists")
            embed.color = 0xffcec6
            await thinking_msg.edit(content="", embed=embed)
            return
        
        # Create DM channel
        try:
            dm_channel = await ctx.author.create_dm()
        except discord.Forbidden:
            error_msg = (
                "❌ Couldn't start DM session. This usually means:\n"
                "• You have DMs disabled\n"
                "• You've blocked the bot\n"
                "• Your privacy settings don't allow DMs from server members"
            )
            embed = create_pikabug_embed(error_msg, title="❌ DM Failed")
            embed.color = 0xff0000
            await thinking_msg.edit(content="", embed=embed)
            return
        
        # Set up comfort session
        await start_comfort_dm_session(ctx.author, dm_channel)
        
        success_msg = (
            f"✅ {ctx.author.display_name}, I've started our private comfort session in your DMs!\n"
            f"Please check your DMs to select what kind of support you need."
        )
        embed = create_pikabug_embed(success_msg, title="🪴 Comfort Session Started")
        embed.color = 0xffcec6
        await thinking_msg.edit(content="", embed=embed)
        
        await logger.log_command_usage(ctx, "dmcomfort", success=True, 
                                     extra_info=f"Comfort session started for {ctx.author.display_name}")
        
    except Exception as e:
        await logger.log_error(e, "DM Comfort Command Error")
        await ctx.send("❌ Error starting comfort session. Please try again.")

async def start_comfort_dm_session(user, dm_channel):
    """Start a comfort DM session with topic selection"""
    try:
        # Send topic selection menu
        menu_msg = (
            f"Hi {user.display_name} 💕\n\n"
            "I'm here to support you. What kind of help do you need today?\n\n"
            "**Please type the number of the topic you'd like support with:**\n\n"
            "1️⃣ Suicide ideation - Crisis support and empathy\n"
            "2️⃣ Anxiety - Grounding techniques, calming strategies, and empathy\n"
            "3️⃣ Addiction - Recovery support and harm reduction\n"
            "4️⃣ General comfort - Quick warmth and emotional support plus uplifting messages\n"
            "5️⃣ Depression - Understanding and gentle encouragement during dark times\n"
            "6️⃣ Anger - Processing and channeling emotions\n\n"
            "Type a number (1-6) to select, or type 'cancel' to end the session."
        )
        
        embed = create_pikabug_embed(menu_msg, title="🪴 Support Topic Selection")
        embed.color = 0xffcec6
        await dm_channel.send(embed=embed)
        
        # Store temporary session data
        dm_key = f"dm-{user.id}"
        active_comfort_sessions[user.id] = {
            'dm_channel': dm_channel,
            'state': 'selecting_topic',
            'user_key': dm_key,
            'started_at': datetime.now(timezone.utc)
        }
        
    except Exception as e:
        await logger.log_error(e, "Start Comfort Session Error")
        if user.id in active_comfort_sessions:
            del active_comfort_sessions[user.id]

async def process_comfort_dm_message(channel, user, message_content):
    """Process messages in comfort DM sessions"""
    try:
        session_data = active_comfort_sessions[user.id]
        
        if session_data['state'] == 'selecting_topic':
            # Handle topic selection
            selection = message_content.strip().lower()
            
            if selection == 'cancel':
                await channel.send("No problem! The session has been cancelled. Take care! 💕")
                del active_comfort_sessions[user.id]
                return
            
            topic_map = {
                '1': 'suicide',
                '2': 'anxiety', 
                '3': 'addiction',
                '4': 'comfort',
                '5': 'depression',
                '6': 'anger'
            }
            
            if selection not in topic_map:
                await channel.send("Please type a number between 1-6 to select a topic, or 'cancel' to end.")
                return
            
            selected_topic = topic_map[selection]
            mode_info = DM_COMFORT_MODES[selected_topic]
            
            # Update session data
            session_data['state'] = 'active'
            session_data['mode'] = selected_topic
            session_data['message_count'] = 0
            
            # Create full DM session
            dm_key = session_data['user_key']
            active_dm_sessions[user.id] = {
                'dm_channel': channel,
                'user_key': dm_key,
                'started_at': session_data['started_at'],
                'message_count': 0,
                'comfort_mode': selected_topic
            }
            
            # Initialize chat session
            chat_sessions[dm_key] = {
                'last_interaction': datetime.now(timezone.utc),
                'display_name': user.display_name,
                'is_dm_session': True,
                'dm_channel': channel,
                'comfort_mode': selected_topic
            }
            
            # Initialize conversation history
            if dm_key not in conversation_history:
                conversation_history[dm_key] = deque(maxlen=CONVERSATION_LIMIT)
            
            # Send mode confirmation
            confirm_msg = (
                f"I understand. I'm here to help with {mode_info['name'].lower()}.\n\n"
                "You can now chat with me normally - no commands needed.\n"
                "I'll be here to listen and support you.\n\n"
                "Type 'end chat' anytime to end our session.\n\n"
                "What's on your mind? 😇"
            )
            
            embed = create_pikabug_embed(confirm_msg, title=f"💕 {mode_info['name']} Mode Active")
            embed.color = 0xffcec6
            await channel.send(embed=embed)
            
            # Clean up comfort session data
            del active_comfort_sessions[user.id]
            
    except Exception as e:
        await logger.log_error(e, "Process Comfort DM Error")

@bot.command(name="endchat")
async def endchat(ctx):
    """End an active DM chat session from a server"""
    user_id = ctx.author.id
    
    if user_id not in active_dm_sessions:
        embed = create_pikabug_embed(
            "You don't have an active DM chat session.",
            title="❌ No Active Session"
        )
        await ctx.send(embed=embed)
        return
    
    # Get session info
    session_data = active_dm_sessions[user_id]
    dm_channel = session_data['dm_channel']
    
    # End the session
    success = await end_dm_chat_session(ctx.author, dm_channel, "ended_from_server")
    
    if success:
        embed = create_pikabug_embed(
            "Your DM chat session has been ended successfully.",
            title="✅ Session Ended"
        )
        embed.color = 0xffcec6
        await ctx.send(embed=embed)
    else:
        embed = create_pikabug_embed(
            "Error ending your DM chat session.",
            title="❌ Error"
        )
        embed.color = 0xff0000
        await ctx.send(embed=embed)

@bot.command(name="chat")
async def chat(ctx, *, prompt):
    thinking_msg = None
    user_key = f"{ctx.guild.id}-{ctx.author.id}"
    
    try:
        # Validate prompt length
        if len(prompt) > 4000:
            await ctx.send("❌ Your message is too long. Please keep it under 4000 characters.")
            return
        
        # Send thinking message
        try:
            thinking_msg = await ctx.send("Thinking...")
        except Exception as e:
            await logger.log_error(e, "Failed to send thinking message")
            thinking_msg = None
        
        # Ensure session memory exists
        if user_key not in conversation_history:
            conversation_history[user_key] = deque(maxlen=CONVERSATION_LIMIT)

        # Build system prompt and temperature
        system_content = (
            "You are Pikabug, an enjoyable Discord companion with a deadpan, relatable personality.\n\n"
            "TONE: Nonchalant deadpan humor.\n\n"
            "CONVERSATION GUIDELINES:\n"
            "- Respond as a close friend with a deadpan sense of humor\n"
            "- Reference past conversations naturally when relevant and build on bonds with users\n"
            "- Never sound overly enthusiastic, dramatic, or flowery\n"
            "- Match the energy and length of the user's messages unless giving advice\n"
            "- Vary your responses - not every message needs encouragement, a joke, or solutions\n"
        )
        temperature = 1.0

        # Build messages for Claude
        messages = []
        if conversation_history[user_key]:
            messages.extend(list(conversation_history[user_key]))
        messages.append({"role": "user", "content": prompt})

        # Make Claude API call
        try:
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1000,
                temperature=temperature,
                system=system_content,
                messages=messages
            )
            content_block = response.content[0]
            if hasattr(content_block, 'text'):
                reply = content_block.text  # type: ignore
            elif hasattr(content_block, 'content'):
                reply = content_block.content  # type: ignore
            else:
                reply = str(content_block)
            reply = str(reply)
        except Exception as api_error:
            error_msg = "⚠️ Sorry, I'm having trouble connecting to my brain right now. Try again in a moment?"
            await ctx.send(error_msg)
            await logger.log_error(api_error, "Claude API Error", f"User: {ctx.author.id}")
            return

        # Update session history
        async with conversation_lock:
            conversation_history[user_key].append({"role": "user", "content": prompt})
            conversation_history[user_key].append({"role": "assistant", "content": reply})

    except Exception as e:
        error_msg = f"⚠️ An unexpected error occurred. Please try again."
        if thinking_msg:
            try:
                await thinking_msg.edit(content=error_msg)
            except:
                await ctx.send(error_msg)
        await logger.log_error(e, "AI Command Error", f"User: {ctx.author.id}, Prompt: {prompt[:100]}...")

# ─── Word Games ─────────────────────────────────────────────────

# ─── Build prefix→words map from valid_words ─────────────────────
prefix_map: Dict[str, List[str]] = defaultdict(list)
for w in valid_words:
    # only consider words at least 3 letters long
    if len(w) >= 3:
        p = w[:3]               # extract the 3‐letter prefix
        prefix_map[p].append(w)

# ─── Filter to "common" prefixes ────────────────────────────────
MIN_WORDS_PER_PREFIX = 5
common_prefixes: List[str] = [
    p for p, lst in prefix_map.items()
    if len(lst) >= MIN_WORDS_PER_PREFIX
]

@bot.command(name="prefixgame")
async def prefixgame(ctx):
    try:
        # Pick and announce a prefix
        weights = [len(prefix_map.get(p, [])) for p in common_prefixes]
        current_prefix = random.choices(common_prefixes, weights=weights, k=1)[0]
        embed = create_pikabug_embed(
            f"New round! Submit the longest word starting with: {current_prefix}",
            title="🧠 Prefix Game"
        )
        await ctx.send(embed=embed)
        submissions = {}
        game_start_time = asyncio.get_event_loop().time()
        game_duration = 12.0
        while True:
            try:
                elapsed_time = asyncio.get_event_loop().time() - game_start_time
                remaining_time = game_duration - elapsed_time
                if remaining_time <= 0:
                    break
                def check(m):
                    if m.channel != ctx.channel or m.author.bot:
                        return False
                    word = m.content.lower().strip()
                    if not word.startswith(current_prefix):
                        return False
                    if len(word) <= len(current_prefix):
                        return False
                    return True
                msg = await bot.wait_for("message", timeout=remaining_time, check=check)
                word = msg.content.strip().lower()
                if word not in valid_words:
                    embed = create_pikabug_embed(f"'{word}' isn't a valid English word.")
                    embed.color = 0xff0000
                    await ctx.send(embed=embed)
                    continue
                user_id = str(msg.author.id)
                prev = submissions.get(user_id)
                if prev is None or len(word) > len(prev):
                    submissions[user_id] = word
                    embed = create_pikabug_embed(f"submitted: {word} ({len(word)} letters)")
                    embed.color = 0x00ff00
                    await ctx.send(embed=embed)
                elif len(word) == len(prev):
                    embed = create_pikabug_embed(f"already submitted a word of the same length: {prev}")
                    embed.color = 0xffcec6
                    await ctx.send(embed=embed)
                else:
                    embed = create_pikabug_embed(f"already submitted a longer word: {prev} ({len(prev)} letters)")
                    embed.color = 0xffcec6
                    await ctx.send(embed=embed)
            except asyncio.TimeoutError:
                break
            except Exception as e:
                print(f"Error in prefix game loop: {e}")
                break
        if not submissions:
            embed = create_pikabug_embed("Time's up! No valid entries were submitted.")
            await ctx.send(embed=embed)
            return
        winner_id, winning_word = max(submissions.items(), key=lambda kv: len(kv[1]))
        winner_member = ctx.guild.get_member(int(winner_id))
        winner_name = winner_member.display_name if winner_member else f"User {winner_id}"
        if len(winning_word) >= 8:
            points_awarded = 10
        else:
            points_awarded = 5
        def add_points(record):
            record['points'] += points_awarded
            record.setdefault('prefixgame_submissions', 0)
            record['prefixgame_submissions'] += 1
        update_pikapoints(str(ctx.guild.id), winner_id, add_points)
        record = get_user_record(str(ctx.guild.id), winner_id)
        result_msg = f"🏆 {winner_name} wins with {winning_word} ({len(winning_word)} letters)!\n"
        result_msg += f"You earned {points_awarded} PikaPoints{' (bonus for 8+ letters!)' if points_awarded == 10 else ''}!\n"
        result_msg += f"• Total Points: {record['points']}\n"
        result_msg += f"• Prefix-game entries: {record['prefixgame_submissions']}\n"
        embed = create_pikabug_embed(result_msg, title="Prefix Game Results")
        embed.color = 0xffcec6
        await ctx.send(embed=embed)
    except Exception as e:
        await logger.log_error(e, "Prefix Game Error")
        print(f"Prefix game error: {e}")

# ─── Unscramble Game ─────────────────────────────────────────────────

# Load English word list
with open("common_words.txt") as f:
   english_words = [word.strip() for word in f if 5 <= len(word.strip()) <= 7]

# Store current word challenge
current_word = None
scrambled_word = None
revealed_indexes = set()
hint_count = 0

@bot.command(name='unscramble')
async def unscramble(ctx):
   try:
       global current_word, scrambled_word, revealed_indexes, hint_count
       current_word = random.choice(english_words)
       scrambled_word = ''.join(random.sample(current_word, len(current_word)))

       # Reset hint tracking
       revealed_indexes = set([0, len(current_word) - 1])
       hint_count = 0

       embed = create_pikabug_embed(f"Unscramble this word: {scrambled_word}", title="🧠 Word Unscramble")
       await ctx.send(embed=embed)
       
   except Exception as e:
       await logger.log_error(e, "Unscramble Start Error")

@bot.command(name='guess')
async def guess(ctx, user_guess: str):
   try:
       global current_word
       if current_word is None:
           embed = create_pikabug_embed("❗️ No game running. Start one with `!unscramble`.")
           await ctx.send(embed=embed)
           return

       if user_guess.lower() == current_word.lower():
           async with points_lock:
               guild_id = str(ctx.guild.id)
               user_id = str(ctx.author.id)
               
               def add_points(record):
                   record['points'] += UNSCRAMBLE_POINTS
                   record['unscramble_submissions'] = record.get('unscramble_submissions', 0) + 1
               
               update_pikapoints(guild_id, user_id, add_points)
               record = get_user_record(guild_id, user_id)
               
           result_msg = f"Correct! You earned {UNSCRAMBLE_POINTS} PikaPoints.\n"
           result_msg += f"• Total Points: {record['points']}\n"
           result_msg += f"• Unscramble Submissions: {record['unscramble_submissions']}"
           
           embed = create_pikabug_embed(result_msg, title="✅ Correct!")
           embed.color = 0x00ff00
           await ctx.send(embed=embed)
           
           current_word = None
       else:
           embed = create_pikabug_embed("Nope, try again.", title="❌ Incorrect")
           embed.color = 0xff0000
           await ctx.send(embed=embed)
           
   except Exception as e:
       await logger.log_error(e, "Guess Command Error")

@bot.command(name='hint')
async def hint(ctx):
   try:
       global current_word, revealed_indexes, hint_count

       if current_word is None:
           embed = create_pikabug_embed("❗️No game is active. Start with `!unscramble`.")
           await ctx.send(embed=embed)
           return

       hint_count += 1

       if hint_count > 1:
           possible_indexes = [
               i for i in range(1, len(current_word) - 1)
               if i not in revealed_indexes
           ]
           if possible_indexes:
               new_index = random.choice(possible_indexes)
               revealed_indexes.add(new_index)

       display = ""
       for i, char in enumerate(current_word):
           if i in revealed_indexes:
               display += char + " "
           else:
               display += "_ "

       embed = create_pikabug_embed(f"Hint: {display.strip()}", title="💡 Hint")
       await ctx.send(embed=embed)
       
   except Exception as e:
       await logger.log_error(e, "Hint Command Error")

@bot.command(name='reveal')
async def reveal(ctx):
   try:
       global current_word
       if current_word is None:
           embed = create_pikabug_embed("❗️ No word to reveal. Start a new game with `!unscramble`.")
           await ctx.send(embed=embed)
       else:
           embed = create_pikabug_embed(f"The correct word was: {current_word}", title="🕵️ Word Revealed")
           await ctx.send(embed=embed)
           current_word = None
           
   except Exception as e:
       await logger.log_error(e, "Reveal Command Error")

# --- Word Search Game (8x8, 4-6 letter words, hidden words not shown) ---

def load_wordsearch_words():
   with open("common_words.txt") as f:
       words = [w.strip().lower() for w in f if w.strip()]
       # Separate 4-letter, 5-letter, and 6-letter words
       four_letter_words = [w for w in words if len(w) == 4]
       five_letter_words = [w for w in words if len(w) == 5]
       six_letter_words = [w for w in words if len(w) == 6]
       return four_letter_words, five_letter_words, six_letter_words

four_letter_words, five_letter_words, six_letter_words = load_wordsearch_words()

# Track active word search games per user
active_wordsearch_games = {}
wordsearch_word_history = deque(maxlen=50)  # Track last 50 words used

class WordSearchGame:
   def __init__(self, four_letter_word, five_letter_word, six_letter_word):
       self.grid_size = 8
       self.grid = [['' for _ in range(self.grid_size)] for _ in range(self.grid_size)]
       self.words = [four_letter_word.lower(), five_letter_word.lower(), six_letter_word.lower()]
       self.found_words = set()
       self.word_positions = {}  # Track where each word is placed
       self.used_positions = set()  # Track all used positions to prevent overlap
       self._create_grid()
   
   def _create_grid(self):
       # Fill grid with random letters first
       for i in range(self.grid_size):
           for j in range(self.grid_size):
               self.grid[i][j] = random.choice(string.ascii_lowercase)
       
       # Directions: (row_delta, col_delta)
       directions = [
           (0, 1),   # horizontal right
           (0, -1),  # horizontal left
           (1, 0),   # vertical down
           (-1, 0),  # vertical up
           (1, 1),   # diagonal down-right
           (-1, -1), # diagonal up-left
           (1, -1),  # diagonal down-left
           (-1, 1),  # diagonal up-right
       ]
       
       # Place each word
       for word in self.words:
           placed = False
           attempts = 0
           
           # Try random placement first
           while not placed and attempts < 200:
               attempts += 1
               direction = random.choice(directions)
               start_row = random.randint(0, self.grid_size - 1)
               start_col = random.randint(0, self.grid_size - 1)
               
               if self._can_place_word(word, start_row, start_col, direction):
                   self._place_word(word, start_row, start_col, direction)
                   placed = True
           
           # If random placement failed, try systematic placement
           if not placed:
               for direction in directions:
                   for start_row in range(self.grid_size):
                       for start_col in range(self.grid_size):
                           if self._can_place_word(word, start_row, start_col, direction):
                               self._place_word(word, start_row, start_col, direction)
                               placed = True
                               break
                       if placed:
                           break
                   if placed:
                       break
           
           # If still not placed, force place it (this shouldn't happen with 4-6 letter words in 8x8 grid)
           if not placed:
               print(f"Warning: Could not place word '{word}' in grid")
   
   def _can_place_word(self, word, start_row, start_col, direction):
       row_delta, col_delta = direction
       positions_to_check = []
       
       # Check if all positions are within bounds and not already used
       for i, letter in enumerate(word):
           row = start_row + i * row_delta
           col = start_col + i * col_delta
           
           # Check boundaries
           if row < 0 or row >= self.grid_size or col < 0 or col >= self.grid_size:
               return False
           
           # Check if position is already used
           if (row, col) in self.used_positions:
               return False
           
           positions_to_check.append((row, col))
       
       return True
   
   def _place_word(self, word, start_row, start_col, direction):
       row_delta, col_delta = direction
       positions = []
       for i, letter in enumerate(word):
           row = start_row + i * row_delta
           col = start_col + i * col_delta
           self.grid[row][col] = letter
           positions.append((row, col))
           self.used_positions.add((row, col))  # Mark position as used
       self.word_positions[word] = positions
   
   def display_grid(self):
       grid_str = ""
       for row in self.grid:
           grid_str += " ".join(letter.upper() for letter in row) + "\n"
       return grid_str.strip()
   
   def check_word(self, word):
       word = word.lower()
       if word in self.words and word not in self.found_words:
           self.found_words.add(word)
           return True
       return False
   
   def is_complete(self):
       return len(self.found_words) == len(self.words)

@bot.command(name='wordsearch')
async def wordsearch(ctx):
    try:
        # Filter for available words
        available_four_letter = [w for w in four_letter_words if w not in wordsearch_word_history]
        available_five_letter = [w for w in five_letter_words if w not in wordsearch_word_history]
        available_six_letter = [w for w in six_letter_words if w not in wordsearch_word_history]
        if len(available_four_letter) < 1:
            available_four_letter = four_letter_words
        if len(available_five_letter) < 1:
            available_five_letter = five_letter_words
        if len(available_six_letter) < 1:
            available_six_letter = six_letter_words
        selected_four_letter = random.choice(available_four_letter)
        selected_five_letter = random.choice(available_five_letter)
        selected_six_letter = random.choice(available_six_letter)
        wordsearch_word_history.extend([selected_four_letter, selected_five_letter, selected_six_letter])
        game = WordSearchGame(selected_four_letter, selected_five_letter, selected_six_letter)
        active_wordsearch_games[ctx.author.id] = game
        game_info = (
            "Word Search Game Started!\n"
            "Find 3 hidden words in this 8x8 grid:\n"
            "• One 4-letter word\n"
            "• One 5-letter word\n"
            "• One 6-letter word\n"
            "Words can be horizontal, vertical, diagonal, forwards, or backwards!\n"
            "Type each word when you find it, or type !endwordsearch to give up.\n\n"
            f"{game.display_grid()}"
        )
        embed = create_pikabug_embed(game_info, title="🔍 Word Search")
        await ctx.send(embed=embed)

    except Exception as e:
        await logger.log_error(e, "Word Search Error")

@bot.command(name='endwordsearch')
async def endwordsearch(ctx):
   user_id = ctx.author.id
   if user_id in active_wordsearch_games:
       game = active_wordsearch_games[user_id]
       embed = create_pikabug_embed(f"Word search ended early. The hidden words were: {', '.join(game.words)}", title="🛑 Game Ended")
       await ctx.send(embed=embed)
       del active_wordsearch_games[user_id]
   else:
       embed = create_pikabug_embed("You don't have an active word search game.")
       await ctx.send(embed=embed)

# ─── DM Chat Session ─────────────────────────────────────────────────

@bot.event
async def on_message(message):
   # Handle comfort session topic selection FIRST
   if isinstance(message.channel, discord.DMChannel) and not message.author.bot:
       if message.author.id in active_comfort_sessions:
           await process_comfort_dm_message(message.channel, message.author, message.content)
           return
   
   # Handle DM messages for active sessions (existing code)
   if isinstance(message.channel, discord.DMChannel) and not message.author.bot:
       if message.author.id in active_dm_sessions:
           dm_key = active_dm_sessions[message.author.id]['user_key']
           
           # Check for end commands
           if message.content.lower() in ['end chat', 'endchat']:
               await end_dm_chat_session(message.author, message.channel, "user_ended")
               return
           elif message.content.lower() in ['forget me', 'forgetme']:
               # Clear memory
               guild_id = "dm"
               user_id = str(message.author.id)
               save_user_memory(guild_id, user_id, {
                   "facts": [],
                   "mood_history": [],
                   "last_interaction": None
               })
               await message.channel.send("I've forgotten everything about you. Our conversation continues with a fresh start!")
               return
           else:
               # Process as chat message
               await process_dm_chat_message(message.channel, message.author, message.content, dm_key)
               return
   
   # --- Word Search Game message handler ---
   if not message.author.bot and message.guild:  # Ensure we have a guild
       user_id = message.author.id
       
       # Check if user has an active game
       if user_id in active_wordsearch_games:
           game = active_wordsearch_games[user_id]
           
           # Skip if message is a command
           if message.content.startswith('!'):
               await bot.process_commands(message)
               return
           
           # Process word guesses
           guesses = [w.strip().lower() for w in re.split(r'[\s,]+', message.content) if w.strip()]
           
           for word_guess in guesses:
               # Check if it's a 4, 5, or 6-letter word
               if (len(word_guess) == 4 or len(word_guess) == 5 or len(word_guess) == 6) and word_guess.isalpha():
                   if game.check_word(word_guess):
                       embed = create_pikabug_embed(f"Correct! You found {word_guess}!", title="✅ Word Found")
                       embed.color = 0x00ff00  # Green
                       await message.channel.send(embed=embed)
                       
# Check completion after EACH correct word
                       if game.is_complete():
                           # Award points
                           async with points_lock:
                               guild_id = str(message.guild.id)
                               user_id_str = str(message.author.id)

                               def add_points(record):
                                   record['points'] += WORDSEARCH_POINTS
                                   if 'wordsearch_submissions' not in record:
                                    record['wordsearch_submissions'] = 0
                                   record['wordsearch_submissions'] += 1                                   
                               update_pikapoints(guild_id, user_id_str, add_points)
                               record = get_user_record(guild_id, user_id_str)
                           
                           completion_msg = (
                               f"Congratulations {message.author.display_name}! You found all the words!\n"
                               f"The words were: {', '.join(game.words)}\n"
                               f"You earned {WORDSEARCH_POINTS} PikaPoints!\n"
                               f"• Total Points: {record['points']}\n"
                               f"• Word Search Games Completed: {record['wordsearch_submissions']}"
                           )
                           
                           embed = create_pikabug_embed(completion_msg, title="🎉 Word Search Complete!")
                           embed.color = 0xffcec6
                           await message.channel.send(embed=embed)
                           
                           # Clean up
                           del active_wordsearch_games[user_id]      
                   else:
                       # Only show error if it's not already found
                       if word_guess in game.found_words:
                           embed = create_pikabug_embed(f"You already found {word_guess}!", title="❌ Already Found")
                           embed.color = 0xffcec6
                           await message.channel.send(embed=embed)
                       else:
                           embed = create_pikabug_embed(f"{word_guess} is not one of the hidden words!", title="❌ Not Found")
                           embed.color = 0xff0000  # Red
                           await message.channel.send(embed=embed)
           
           return  # Don't process commands since this was a game guess
   
   # Process commands as usual
   await bot.process_commands(message)

async def end_dm_chat_session(user, dm_channel, reason="unknown"):
   """End a DM chat session and clean up"""
   try:
       user_id = user.id
       
       if user_id not in active_dm_sessions:
           return False
       
       session_data = active_dm_sessions[user_id]
       dm_key = session_data['user_key']
       message_count = session_data['message_count']
       session_duration = datetime.now(timezone.utc) - session_data['started_at']
       
       # Send farewell message
       farewell_messages = [
           f"Thanks for the chat, {user.display_name}! 👋",
           f"It was great talking with you, {user.display_name}! See you later! ✨",
           f"Chat session ended. Thanks for the conversation, {user.display_name}! 💙",
           f"Bye for now, {user.display_name}! Feel free to start a new session anytime! 🌟",
           f"Our chat has ended, {user.display_name}. Hope you enjoyed our conversation! 😊"
       ]
       
       farewell_msg = random.choice(farewell_messages)
       
       session_summary = (
           f"{farewell_msg}\n\n"
           f"**Session Summary:**\n"
           f"• Duration: {str(session_duration).split('.')[0]}\n"
           f"• Messages exchanged: {message_count}\n"
           f"• Use `!dmchat [message]` in any server to start a new session"
       )
       
       embed = create_pikabug_embed(session_summary, title="👋 Chat Session Ended")
       embed.color = 0xffcec6
       await dm_channel.send(embed=embed)
       
       # Clean up session data
       del active_dm_sessions[user_id]
       if dm_key in chat_sessions:
           del chat_sessions[dm_key]
       
       # Keep conversation history for potential memory extraction
       # (Don't delete conversation_history[dm_key] immediately)
       
       # Log session end
       await logger.log_bot_event(
           "DM Chat Session Ended", 
           f"User: {user.display_name}, Reason: {reason}, "
           f"Duration: {session_duration}, Messages: {message_count}"
       )
       
       return True
       
   except Exception as e:
       await logger.log_error(e, "End DM Session Error")
       return False

# ─── Weekly Workshop Commands ─────────────────────────────────────────────────

workshop_days = {
   "monday": "Mindful Monday",
   "tuesday": "Trigger or Trauma Tuesday", 
   "thursday": "Thankful Thursday",
   "friday": "Flourishing Friday",
   "weekend": "Weekend Writing"
}

async def handle_workshop_submission(ctx, day_key: str, submission: str):
    """Handle workshop submissions for all days"""
    try:
        # Get the full workshop name
        workshop_name = workshop_days[day_key]
        guild_id = str(ctx.guild.id)
        user_id = str(ctx.author.id)
        async with points_lock:
            def add_points(record):
                record['points'] += WORKSHOP_POINTS
                if 'workshop_submissions' not in record:
                    record['workshop_submissions'] = 0
                record['workshop_submissions'] += 1
                day_field = f'workshop_{day_key}_submissions'
                if day_field not in record:
                    record[day_field] = 0
                record[day_field] += 1
            update_pikapoints(guild_id, user_id, add_points)
            record = get_user_record(guild_id, user_id)
        # Save the submission to workshop file
        if guild_id not in workshop_submissions:
            workshop_submissions[guild_id] = {}
        if user_id not in workshop_submissions[guild_id]:
            workshop_submissions[guild_id][user_id] = []
        workshop_submissions[guild_id][user_id].append({
            "day": day_key,
            "workshop_name": workshop_name,
            "submission": submission,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "display_name": ctx.author.display_name
        })
        save_workshop_submissions(workshop_submissions)
        # Create the response embed
        submission_msg = (
            f"Weekly Workshop Submission: {workshop_name}\n"
            f"Submitted by: {ctx.author.display_name}\n"
            f"PikaPoints Earned: {WORKSHOP_POINTS}\n\n"
            f"{submission}"
        )
        embed = create_pikabug_embed(submission_msg, title=f"📝 {workshop_name}")
        embed.color = 0xffcec6  # Pink color
        await ctx.send(embed=embed)
        # Log the submission
        await logger.log_command_usage(ctx, f"workshop_{day_key}", success=True, 
                                     extra_info=f"Submission length: {len(submission)} chars")
        await logger.log_points_award(user_id, guild_id, WORKSHOP_POINTS, 
                                    f"workshop_{day_key}", record["points"])
    except Exception as e:
        await logger.log_error(e, f"Workshop {day_key} Error")
        await logger.log_command_usage(ctx, f"workshop_{day_key}", success=False)
        await ctx.send("❌ An error occurred while processing your workshop submission.")

# Create individual workshop commands
@bot.command(name='monday')
async def monday(ctx, *, submission: str):
   """Submit your Mindful Monday workshop entry"""
   await handle_workshop_submission(ctx, "monday", submission)

@bot.command(name='tuesday')
async def tuesday(ctx, *, submission: str):
   """Submit your Trigger or Trauma Tuesday workshop entry"""
   await handle_workshop_submission(ctx, "tuesday", submission)

@bot.command(name='thursday')
async def thursday(ctx, *, submission: str):
   """Submit your Thankful Thursday workshop entry"""
   await handle_workshop_submission(ctx, "thursday", submission)

@bot.command(name='friday')
async def friday(ctx, *, submission: str):
   """Submit your Flourishing Friday workshop entry"""
   await handle_workshop_submission(ctx, "friday", submission)

@bot.command(name='weekend')
async def weekend(ctx):
   """Start Weekend Writing by sending a journal prompt"""
   try:
       # Select a random prompt from the journal prompts
       global last_prompt_prompt
       choices = prompt_prompts.copy()
       if last_prompt_prompt in choices:
           choices.remove(last_prompt_prompt)
       if not choices:
           choices = prompt_prompts.copy()
       
       selected_prompt = random.choice(choices)
       last_prompt_prompt = selected_prompt
       
       # Store the prompt for this user
       user_key = f"{ctx.guild.id}-{ctx.author.id}"
       active_weekend_prompts[user_key] = {
           "prompt": selected_prompt,
           "timestamp": datetime.now(timezone.utc).isoformat(),
           "channel_id": ctx.channel.id
       }
       
       # Send the prompt with instructions
       prompt_msg = (
           f"Weekend Writing Prompt:\n\n"
           f"{selected_prompt}\n\n"
           f"Submit your response using !weekendsubmit [your response]"
       )
       
       embed = create_pikabug_embed(prompt_msg, title="✍️ Weekend Writing")
       embed.color = 0xffcec6
       await ctx.send(embed=embed)
       
       await logger.log_command_usage(ctx, "weekend", success=True, 
                                    extra_info=f"Prompt sent: {selected_prompt[:50]}...")
       
   except Exception as e:
       await logger.log_error(e, "Weekend Command Error")
       await logger.log_command_usage(ctx, "weekend", success=False)
       await ctx.send("❌ An error occurred while generating your weekend writing prompt.")

@bot.command(name='weekendsubmit')
async def weekendsubmit(ctx, *, submission: str):
   """Submit your Weekend Writing response"""
   try:
       user_key = f"{ctx.guild.id}-{ctx.author.id}"
       
       # Check if user has an active weekend prompt
       if user_key not in active_weekend_prompts:
           error_msg = (
               "You don't have an active Weekend Writing prompt!\n"
               "Use !weekend to get a prompt first."
           )
           embed = create_pikabug_embed(error_msg, title="❌ No Active Prompt")
           embed.color = 0xff0000
           await ctx.send(embed=embed)
           return
       
       # Get the prompt they're responding to
       prompt_data = active_weekend_prompts[user_key]
       original_prompt = prompt_data["prompt"]
       
       # Award points
       guild_id = str(ctx.guild.id)
       user_id = str(ctx.author.id)
       record = get_user_record(guild_id, user_id)
       def add_points(record):
           record['points'] += WORKSHOP_POINTS
           update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Track workshop submissions
       if 'workshop_submissions' not in record:
           record['workshop_submissions'] = 0
       record['workshop_submissions'] += 1
       
       # Track weekend-specific submissions
       if 'workshop_weekend_submissions' not in record:
           record['workshop_weekend_submissions'] = 0
       record['workshop_weekend_submissions'] += 1
       
       update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Save the submission to workshop file
       if guild_id not in workshop_submissions:
           workshop_submissions[guild_id] = {}
       if user_id not in workshop_submissions[guild_id]:
           workshop_submissions[guild_id][user_id] = []
       
       workshop_submissions[guild_id][user_id].append({
           "day": "weekend",
           "workshop_name": "Weekend Writing",
           "prompt": original_prompt,
           "submission": submission,
           "timestamp": datetime.now(timezone.utc).isoformat(),
           "display_name": ctx.author.display_name
       })
       save_workshop_submissions(workshop_submissions)
       
       # Create the response embed
       submission_msg = (
           f"Weekly Workshop Submission: Weekend Writing\n"
           f"Submitted by: {ctx.author.display_name}\n"
           f"PikaPoints Earned: {WORKSHOP_POINTS}\n\n"
           f"Prompt: {original_prompt}\n\n"
           f"Response: {submission}"
       )
       
       embed = create_pikabug_embed(submission_msg, title="📝 Weekend Writing")
       embed.color = 0xffcec6  # Pink color
       await ctx.send(embed=embed)
       
       # Clear the active prompt for this user
       del active_weekend_prompts[user_key]
       
       # Log the submission
       await logger.log_command_usage(ctx, "weekendsubmit", success=True, 
                                    extra_info=f"Submission length: {len(submission)} chars")
       await logger.log_points_award(user_id, guild_id, WORKSHOP_POINTS, 
                                   "workshop_weekend", record["points"])
       
   except Exception as e:
       await logger.log_error(e, "Weekend Submit Error")
       await logger.log_command_usage(ctx, "weekendsubmit", success=False)
       await ctx.send("❌ An error occurred while processing your weekend writing submission.")

# ─── Journal System ─────────────────────────────────────────────────

prompt_prompts = [
   "What were your childhood career dreams/goals? How do they compare to what you want to do now?",
   "Which year comes to mind when you think about the best nostalgia? Why did that year carry the best memories?",
   "Describe your childhood in one word, or a single phrase. If this inspires you to talk more about it, go ahead.",
   "What posters did you have on your wall growing up or want to have?",
   "What instance immediately comes to mind when you remember a meaningful display of kindness?",
   "Who are some people in history you admire?",
   "Who was your first best friend? Tell me about them. Why did you get along so well?",
   "Who was your first love? Tell me about them. Why did they stand out more than others?",
   "What was your first job and when did you get it? What do you wish it would've been?",
   "Describe the experience of your first kiss or first time.",
   "Describe the experience of your first time being drunk/high.",
   "Have you ever gotten in trouble with the law? If you were to, what would it most likely be for?",
   "What was the age you actually became an adult, if you feel you have.",
   "Who or what has had the greatest impact on your life, negatively or positively?",
   "What's one of the hardest things you've ever had to do? Do you regret it or did it need to be done?",
   "If I could do it all over again, I would change...",
   "The teacher that had the most influence on my life was...",
   "Describe your parents, how you feel about them, and how they've influenced you.",
   "The long-lost childhood possession that I would love to see again is...",
   "The one thing I regret most about my life or decisions is...",
   "Some things I've been addicted to include...",
   "I was most happy when...",
   "I will never forgive...",
   "Something I'm glad I tried but will never do again is...",
   "The 3-5 best things I've ever had or done in my life are...",
   "The 3-5 things I want to do but have never done are...",
   "I wish I never met...",
   "The one person I've been most jealous of is...",
   "Someone I miss is...",
   "The last time I said I love you was...",
   "Describe your greatest heartbreak or loss.",
   "Something I feel guilty about is...",
   "My life story in 3 sentences is...",
   "My top 3 favorite bands are...",
   "My top 3 favorite songs are...",
   "My top 3 favorite movies are...",
   "My top 3 favorite TV shows are...",
   "My top 3 favorite books are...",
   "My top 3 favorite games are...",
   "My top 3 favorite places I've been are...",
   "My top 3 favorite foods are...",
   "My top 3 favorite colors are...",
   "My top 3 favorite animals are...",
   "My top 3 favorite drinks are...",
   "My top 3 favorite desserts are...",
   "My top 3 favorite snacks are...",
   "My top 3 favorite celebrities are...",
   "What time period would you most like to live in and why?",
   "What would 16 year old think of current you?",
   "How was it getting your license? If you don't have it, why not?",
   "What's the most embarrassing thing you've ever done?",
   "What's something you've gotten an award for?",
   "Do you regret any of your exes?",
   "What's your political affiliation and why?",
   "Have you ever been in a fight?",
   "Have you ever saved someone's life?",
   "Something you need to confess to someone who won't know is...",
   "First word you'd use to describe yourself is...",
   "First person you think to confide in and why is...",
   "When did you last cry and why?",
   "What's the first quality you look for in a person?",
   "When's the last time you felt in control of your life?",
   "When's a time you successfully stood your ground?",
   "When's the last time you felt proud of yourself?",
   "When's the last time you were scared for your life?",
   "When's the last time you wanted to end your life?",
   "Three signs of hope for your future are...",
   "Three things you forgive yourself for are...",
]

last_prompt_prompt = None 

@bot.command(name='prompt')
async def prompt(ctx):
   try:
       global last_prompt_prompt
       choices = prompt_prompts.copy()
       if last_prompt_prompt in choices:
           choices.remove(last_prompt_prompt)
       if not choices:
           choices = prompt_prompts.copy()
       prompt = random.choice(choices)
       last_prompt_prompt = prompt
       
       embed = create_pikabug_embed(prompt, title="📝 Journaling Prompt")
       await ctx.send(embed=embed)
       await logger.log_command_usage(ctx, "prompt", success=True, extra_info=f"Prompt: {prompt[:50]}...")
   except Exception as e:
       await logger.log_error(e, "Journal Command Error")
       await logger.log_command_usage(ctx, "prompt", success=False)

@bot.command(name='write')
async def write(ctx, *, entry: str):
    try:
        async with points_lock:
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            record = get_user_record(guild_id, user_id)
            record['points'] += PROMPT_POINTS
            def add_points(record):
                record['points'] += PROMPT_POINTS
            if 'prompt_submissions' not in record:
                record['prompt_submissions'] = 0
            record['prompt_submissions'] += 1
            update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
            
            result_msg = (
                f"Entry received! You earned {PROMPT_POINTS} PikaPoints!\n"
                f"• Total Points: {record['points']}\n"
                f"• Journal Entries: {record['prompt_submissions']}"
            )
            
            embed = create_pikabug_embed(result_msg, title="✅ Journal Entry Submitted")
            embed.color = 0x00ff00  # Green for success
            await ctx.send(embed=embed)
            
            await logger.log_command_usage(ctx, "write", success=True, extra_info=f"Entry length: {len(entry)} chars")

    except Exception as e:
        await logger.log_error(e, "Write Command Error")
        await logger.log_command_usage(ctx, "write", success=False)

# ─── Vent System ─────────────────────────────────────────────────

VENT_FILE = os.path.join(DISK_PATH, "vent_submissions.json")

def load_vent_submissions():
   if not os.path.exists(VENT_FILE):
       with open(VENT_FILE, "w") as f:
           json.dump({}, f)
   with open(VENT_FILE, "r") as f:
       return json.load(f)

def save_vent_submissions(data: dict):
   with open(VENT_FILE, "w") as f:
       json.dump(data, f)
       f.flush()
       os.fsync(f.fileno())

vent_data = load_vent_submissions()

last_vent_message = None

@bot.command(name='vent')
async def vent(ctx):
   try:
       global last_vent_message
       supportive_messages = [
           "Hey, I'm proud of you for reaching out! I'm here to support you. Type your vent and submit it with !venting [your message].",
           "You can rant here, no judgment. When you're ready, use !venting [your message] to share.",
           "Sometimes you just need to get it out, we get it. Use !venting [your message] to tell me what's up.",
           "I'm here to listen. Let it all out, and know we're here for you. When you're ready, use !venting [your message] to share your thoughts."
       ]
       for _ in range(5):
           msg = random.choice(supportive_messages)
           if msg != last_vent_message:
               break
       last_vent_message = msg
       
       embed = create_pikabug_embed(msg, title="🫂 Vent Support")
       await ctx.send(embed=embed)
       await logger.log_command_usage(ctx, "vent", success=True)
   except Exception as e:
       await logger.log_error(e, "Vent Command Error")
       await logger.log_command_usage(ctx, "vent", success=False)

@bot.command(name='venting')
async def venting(ctx, *, entry: str):
   try:
       # Try to delete the user's message for privacy
       try:
           await ctx.message.delete()
       except discord.Forbidden:
           await ctx.send("⚠️ I don't have permission to delete your message. Your vent is still private to me.")
       except Exception:
           pass  # Ignore other errors

       guild_id = str(ctx.guild.id)
       user_id = str(ctx.author.id)
       # Load or create user's vent list
       if guild_id not in vent_data:
           vent_data[guild_id] = {}
       if user_id not in vent_data[guild_id]:
           vent_data[guild_id][user_id] = []
       # Save the vent entry
       vent_data[guild_id][user_id].append({
           "entry": entry,
           "timestamp": datetime.now(timezone.utc).isoformat()
       })
       save_vent_submissions(vent_data)
       def add_points(record):
           record['points'] += VENT_POINTS
           if 'vent_submissions' not in record:
               record['vent_submissions'] = 0
           record['vent_submissions'] += 1
       update_pikapoints(guild_id, user_id, add_points)
       record = get_user_record(guild_id, user_id)
       result_msg = (
           f"Vent received! You earned {VENT_POINTS} PikaPoints.\n"
           f"• Total Points: {record['points']}\n"
           f"• Vent Submissions: {record['vent_submissions']}"
       )
       embed = create_pikabug_embed(result_msg, title="✅ Vent Received")
       embed.color = 0x00ff00
       await ctx.send(embed=embed)
       await logger.log_command_usage(ctx, "venting", success=True, extra_info=f"Entry length: {len(entry)} chars")
   except Exception as e:
       await logger.log_error(e, "Venting Command Error")
       await logger.log_command_usage(ctx, "venting", success=False)

# ─── Session Cleanup Task ─────────────────────────────────────────────────

@tasks.loop(hours=4)
async def cleanup_chat_sessions():
   """Clean up inactive chat sessions after 4 hours"""
   try:
       current_time = datetime.now(timezone.utc)
       sessions_to_remove = []
       dm_sessions_to_remove = []
       comfort_sessions_to_remove = []
       
       # Clean up regular chat sessions
       for user_key, session_data in chat_sessions.items():
           last_interaction = session_data['last_interaction']
           time_diff = current_time - last_interaction
           
           # Remove sessions older than 4 hours
           if time_diff.total_seconds() > 14400:  # 4 hours in seconds
               sessions_to_remove.append(user_key)
       
       # Clean up DM sessions
       for user_id, session_data in active_dm_sessions.items():
           session_duration = current_time - session_data['started_at']
           
           # Remove DM sessions older than 8 hours
           if session_duration.total_seconds() > 28800:  # 8 hours
               dm_sessions_to_remove.append(user_id)
       
       # Clean up comfort sessions that are stuck in selection
       for user_id, session_data in active_comfort_sessions.items():
           session_duration = current_time - session_data['started_at']
           
           # Remove comfort sessions older than 30 minutes
           if session_duration.total_seconds() > 1800:  # 30 minutes
               comfort_sessions_to_remove.append(user_id)
       
       # Remove inactive sessions
       for user_key in sessions_to_remove:
           del chat_sessions[user_key]
           # Also clean up conversation history
           if user_key in conversation_history:
               del conversation_history[user_key]
       
       # Remove inactive DM sessions
       for user_id in dm_sessions_to_remove:
           if user_id in active_dm_sessions:
               dm_key = active_dm_sessions[user_id]['user_key']
               del active_dm_sessions[user_id]
               if dm_key in conversation_history:
                   del conversation_history[dm_key]
               if dm_key in chat_sessions:
                   del chat_sessions[dm_key]
       
       # Remove stuck comfort sessions
       for user_id in comfort_sessions_to_remove:
           del active_comfort_sessions[user_id]
           
       if sessions_to_remove or dm_sessions_to_remove or comfort_sessions_to_remove:
           await logger.log_bot_event(
               "Session Cleanup", 
               f"Cleaned up {len(sessions_to_remove)} chat sessions, {len(dm_sessions_to_remove)} DM sessions, and {len(comfort_sessions_to_remove)} comfort sessions"
           )
           
   except Exception as e:
       await logger.log_error(e, "Session Cleanup Error")

@cleanup_chat_sessions.before_loop
async def before_cleanup_chat_sessions():
   """Wait until bot is ready before starting cleanup task"""
   await bot.wait_until_ready() 

# ─── Mental Health Check-in Task ─────────────────────────────────────────────

@tasks.loop(seconds=CHECK_IN_INTERVAL)
async def send_check_in():
   """Send mental health check-ins every 12 hours"""
   try:
       now = time.time()
       
       # Check if we should skip this iteration
       if now - check_in_state.get("last_sent", 0) < CHECK_IN_INTERVAL:
           return
           
       channel = bot.get_channel(CHECK_IN_CHANNEL_ID)
       if not channel:
           print(f"Check-in channel {CHECK_IN_CHANNEL_ID} not found")
           return
           
       # Pick next check-in message from our ordered list
       order = check_in_state["order"]
       last_index = check_in_state.get("last_index", -1)
       
       # Find the next index in our order
       if last_index in order:
           current_position = order.index(last_index)
           next_position = (current_position + 1) % len(order)
       else:
           next_position = 0
           
       check_in_index = order[next_position]
       check_in_message = check_in_messages[check_in_index]
       
       # Send check-in message
       embed = create_pikabug_embed(check_in_message, title="💙 Mental Health Check-in")
       embed.color = 0xffcec6 
       if isinstance(channel, discord.abc.Messageable):
           await channel.send(embed=embed)
       
       # Update state
       check_in_state["last_sent"] = now
       check_in_state["last_index"] = check_in_index
       
       # If we've gone through all messages, reshuffle for next cycle
       if next_position == len(order) - 1:
           random.shuffle(check_in_state["order"])
           
       save_check_in_state(check_in_state)
       
       await logger.log_bot_event("Check-in Sent", f"Sent check-in message #{check_in_index}")
       
   except Exception as e:
       await logger.log_error(e, "Check-in Task Error")

@send_check_in.before_loop
async def before_send_check_in():
   """Wait until bot is ready and check if we should wait before sending"""
   await bot.wait_until_ready()
   
   # Calculate time since last check-in
   now = time.time()
   last_sent = check_in_state.get("last_sent", 0)
   time_since_last = now - last_sent
   
   # If not enough time has passed, wait for the remaining time
   if time_since_last < CHECK_IN_INTERVAL:
       wait_time = CHECK_IN_INTERVAL - time_since_last
       print(f"Waiting {wait_time:.0f} seconds before next check-in...")
       await asyncio.sleep(wait_time)

# ─── Hot Take Task ─────────────────────────────────────────────────

@tasks.loop(seconds=HOT_TAKE_INTERVAL)
async def send_hot_take():
   """Send hot takes every 12 hours"""
   try:
       now = time.time()
       
       # Check if we should skip this iteration
       if now - hot_take_state.get("last_sent", 0) < HOT_TAKE_INTERVAL:
           return
           
       channel = bot.get_channel(HOT_TAKE_CHANNEL_ID)
       if not channel:
           print(f"Hot take channel {HOT_TAKE_CHANNEL_ID} not found")
           return
           
       # Pick next hot take from our ordered list
       order = hot_take_state["order"]
       last_index = hot_take_state.get("last_index", -1)
       
       # Find the next index in our order
       if last_index in order:
           current_position = order.index(last_index)
           next_position = (current_position + 1) % len(order)
       else:
           next_position = 0
           
       hot_take_index = order[next_position]
       hot_take = hot_takes[hot_take_index]
       
       # Send the hot take with styled embed
       embed = create_pikabug_embed(hot_take, title="🔥 Hot Take")
       if isinstance(channel, discord.abc.Messageable):
           await channel.send(embed=embed)
       
       # Update state
       hot_take_state["last_sent"] = now
       hot_take_state["last_index"] = hot_take_index
       
       # If we've gone through all hot takes, reshuffle for next cycle
       if next_position == len(order) - 1:
           random.shuffle(hot_take_state["order"])
           
       save_hot_take_state(hot_take_state)
       
       await logger.log_bot_event("Hot Take Sent", f"Sent hot take #{hot_take_index}")
       
   except Exception as e:
       await logger.log_error(e, "Hot Take Task Error")

@send_hot_take.before_loop
async def before_send_hot_take():
   """Wait until bot is ready and check if we should wait before sending"""
   await bot.wait_until_ready()
   
   # Calculate time since last hot take
   now = time.time()
   last_sent = hot_take_state.get("last_sent", 0)
   time_since_last = now - last_sent
   
   # If not enough time has passed, wait for the remaining time
   if time_since_last < HOT_TAKE_INTERVAL:
       wait_time = HOT_TAKE_INTERVAL - time_since_last
       print(f"Waiting {wait_time:.0f} seconds before next hot take...")
       await asyncio.sleep(wait_time)

# ─── Points Command ─────────────────────────────────────────────────

@bot.command(name='points', help='Display how many PikaPoints you have')
async def points(ctx):
   try:
       if os.path.exists(PIKA_FILE):
           with open(PIKA_FILE, 'r') as f:
               all_data = json.load(f)
       else:
           all_data = {}

       guild_id_str = str(ctx.guild.id)
       guild_data = all_data.get(guild_id_str, {})

       user_id_str = str(ctx.author.id)
       user_record = guild_data.get(user_id_str, {"points": 0})
       user_points = user_record.get("points", 0) if isinstance(user_record, dict) else user_record

       embed = create_pikabug_embed(f'{ctx.author.display_name}, you have {user_points} PikaPoints!', title='💰 Your Points')
       await ctx.send(embed=embed)
       await logger.log_command_usage(ctx, "points", success=True, extra_info=f"User has {user_points} points")
       
   except Exception as e:
       await logger.log_error(e, "Points Command Error")
       await logger.log_command_usage(ctx, "points", success=False)

# Memory Management Commands
@bot.command(name='memory')
async def view_memory(ctx):
   """View what Pikabug remembers about you"""
   try:
       guild_id = str(ctx.guild.id)
       user_id = str(ctx.author.id)
       
       user_memory = load_user_memory(guild_id, user_id)
       
       if not user_memory["facts"] and not user_memory["mood_history"]:
           embed = create_pikabug_embed(
               "I don't have any memories about you yet! Chat with me more and I'll remember important things about you.",
               title="💭 Your Memories"
           )
           await ctx.send(embed=embed)
           return
       
       memory_text = f"**What I remember about {ctx.author.display_name}:**\n\n"
       
       if user_memory["facts"]:
           memory_text += "**Things I know about you:**\n"
           for i, fact in enumerate(user_memory["facts"][-5:], 1):
               memory_text += f"{i}. {fact}\n"
       
       if user_memory["mood_history"]:
           memory_text += f"\n**Your recent moods:** {', '.join(user_memory['mood_history'][-3:])}\n"
       
       # Add Pikabug's opinions
       if "pikabug_opinions" in user_memory and user_memory["pikabug_opinions"]:
           memory_text += f"\n**My opinions about our chats:**\n"
           for topic, opinion in list(user_memory["pikabug_opinions"].items())[:3]:
               memory_text += f"• {topic}: {opinion}\n"
       
       if user_memory["last_interaction"]:
           last_time = datetime.fromisoformat(user_memory["last_interaction"])
           time_diff = datetime.now(timezone.utc) - last_time
           if time_diff.days > 0:
               memory_text += f"\n**Last conversation:** {time_diff.days} days ago"
       
       embed = create_pikabug_embed(memory_text, title="💭 Your Memories")
       await ctx.send(embed=embed)
       
   except Exception as e:
       await logger.log_error(e, "View Memory Error")
       await ctx.send("❌ Error retrieving memories.")

@bot.command(name='forget')
async def forget_memory(ctx):
   """Clear Pikabug's memories about you"""
   try:
       guild_id = str(ctx.guild.id)
       user_id = str(ctx.author.id)
       
       # Clear persistent memory
       save_user_memory(guild_id, user_id, {
           "facts": [],
           "mood_history": [],
           "last_interaction": None
       })
       
       # Clear session memory
       user_key = f"{ctx.guild.id}-{ctx.author.id}"
       if user_key in conversation_history:
           conversation_history[user_key].clear()
       
       embed = create_pikabug_embed(
           "I've forgotten everything about you. We can start fresh now!",
           title="🧹 Memory Cleared"
       )
       await ctx.send(embed=embed)
       
   except Exception as e:
       await logger.log_error(e, "Forget Memory Error")
       await ctx.send("❌ Error clearing memories.")

# ─── Admin Commands ─────────────────────────────────────────────────

@bot.command(name='grantpoints')
async def grantpoints(ctx, user: discord.Member, points: int):
   """Grant PikaPoints to a user (Admin only)"""
   try:
       # Check if user has administrator permissions
       if not ctx.author.guild_permissions.administrator:
           await ctx.send("❌ You need administrator permissions to use this command.")
           await logger.log_command_usage(ctx, "grantpoints", success=False, extra_info="Insufficient permissions")
           return
       
       # Validate points amount
       if points <= 0:
           await ctx.send("❌ Points amount must be greater than 0.")
           await logger.log_command_usage(ctx, "grantpoints", success=False, extra_info="Invalid points amount")
           return
       
       if points > 1000:
           await ctx.send("❌ Cannot grant more than 1000 points at once.")
           await logger.log_command_usage(ctx, "grantpoints", success=False, extra_info="Points amount too high")
           return
       
       # Get user record and update points
       guild_id = str(ctx.guild.id)
       user_id = str(user.id)
       record = get_user_record(guild_id, user_id)
       def add_points(record):
           record['points'] += points
       update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Store original points for logging
       add_points = record["points"]
       
       # Add points
       record["points"] += points
       
       # Ensure admin_granted field exists
       if "admin_granted" not in record:
           record["admin_granted"] = 0
       record["admin_granted"] += points
       
       # Save to disk
       update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Send confirmation message with styled embed
       result_msg = (
           f"{ctx.author.display_name} granted {points} PikaPoints to {user.display_name}!\n"
           f"• {user.display_name}'s Total Points: {record['points']}\n"
           f"• Points Granted by Admins: {record['admin_granted']}"
       )
       
       embed = create_pikabug_embed(result_msg, title="✅ Points Granted")
       embed.color = 0x00ff00  # Green
       await ctx.send(embed=embed)
       
       # Log the admin action
       await logger.log_command_usage(ctx, "grantpoints", success=True, 
                                    extra_info=f"Granted {points} points to {user.display_name} ({user.id})")
       
   except Exception as e:
       await logger.log_error(e, "Grant Points Command Error")
       await logger.log_command_usage(ctx, "grantpoints", success=False)
       await ctx.send("❌ An error occurred while granting points. Please try again.")

@bot.command(name='removepoints')
async def removepoints(ctx, user: discord.Member, points: int):
   """Remove PikaPoints from a user (Admin only)"""
   try:
       # Check if user has administrator permissions
       if not ctx.author.guild_permissions.administrator:
           await ctx.send("❌ You need administrator permissions to use this command.")
           await logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Insufficient permissions")
           return
       
       # Validate points amount
       if points <= 0:
           await ctx.send("❌ Points amount must be greater than 0.")
           await logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Invalid points amount")
           return
       
       if points > 1000:
           await ctx.send("❌ Cannot remove more than 1000 points at once.")
           await logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Points amount too high")
           return
       
       # Get user record and update points
       guild_id = str(ctx.guild.id)
       user_id = str(user.id)
       record = get_user_record(guild_id, user_id)
       
       # Store original points for logging
       add_points = record["points"]
       
       # Check if user has enough points
       if record["points"] < points:
           await ctx.send(f"❌ **{user.display_name}** only has **{record['points']}** points. Cannot remove **{points}** points.")
           await logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Insufficient user points")
           return
       
       # Remove points
       record["points"] -= points
       
       # Ensure admin_removed field exists
       if "admin_removed" not in record:
           record["admin_removed"] = 0
       record["admin_removed"] += points
       
       # Save to disk
       update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Send confirmation message with styled embed
       result_msg = (
           f"{ctx.author.display_name} removed {points} PikaPoints from {user.display_name}!\n"
           f"• {user.display_name}'s Total Points: {record['points']}\n"
           f"• Points Removed by Admins: {record['admin_removed']}"
       )
       
       embed = create_pikabug_embed(result_msg, title="✅ Points Removed")
       embed.color = 0xff0000  # Red
       await ctx.send(embed=embed)
       
       # Log the admin action
       await logger.log_command_usage(ctx, "removepoints", success=True, 
                                    extra_info=f"Removed {points} points from {user.display_name} ({user.id})")
       
   except Exception as e:
       await logger.log_error(e, "Remove Points Command Error")
       await logger.log_command_usage(ctx, "removepoints", success=False)
       await ctx.send("❌ An error occurred while removing points. Please try again.")

@bot.command(name='setpoints')
async def setpoints(ctx, user: discord.Member, points: int):
   """Set a user's PikaPoints to a specific amount (Admin only)"""
   try:
       # Check if user has administrator permissions
       if not ctx.author.guild_permissions.administrator:
           await ctx.send("❌ You need administrator permissions to use this command.")
           await logger.log_command_usage(ctx, "setpoints", success=False, extra_info="Insufficient permissions")
           return
       
       # Validate points amount
       if points < 0:
           await ctx.send("❌ Points amount cannot be negative.")
           await logger.log_command_usage(ctx, "setpoints", success=False, extra_info="Invalid points amount")
           return
       
       if points > 10000:
           await ctx.send("❌ Cannot set points higher than 10,000.")
           await logger.log_command_usage(ctx, "setpoints", success=False, extra_info="Points amount too high")
           return
       
       # Get user record and update points
       guild_id = str(ctx.guild.id)
       user_id = str(user.id)
       record = get_user_record(guild_id, user_id)
       
       # Store original points for logging
       add_points = record["points"]
       
       # Set points
       record["points"] = points
       
       # Ensure admin_set field exists
       if "admin_set" not in record:
           record["admin_set"] = 0
       record["admin_set"] += 1
       
       # Save to disk
       update_pikapoints(ctx.guild.id, ctx.author.id, add_points)
       
       # Send confirmation message with styled embed
       result_msg = (
           f"{ctx.author.display_name} set {user.display_name}'s PikaPoints to {points}!\n"
           f"• New Points: {record['points']}\n"
           f"• Times Set by Admins: {record['admin_set']}"
       )
       
       embed = create_pikabug_embed(result_msg, title="✅ Points Set")
       embed.color = 0xffcec6
       await ctx.send(embed=embed)
       
       # Log the admin action
       await logger.log_command_usage(ctx, "setpoints", success=True, 
                                    extra_info=f"Set {user.display_name}'s points from {add_points} to {points}")
       
   except Exception as e:
       await logger.log_error(e, "Set Points Command Error")
       await logger.log_command_usage(ctx, "setpoints", success=False)
       await ctx.send("❌ An error occurred while setting points. Please try again.")

# ─── Help Command ─────────────────────────────────────────────────

@bot.command(name="pikahelp")
async def pikahelp_command(ctx):
   try:
       pikahelp_text = """🧠 Pikabug Commands:

**AI & Chat:**
!dmcomfort - Start a specialized comfort DM session with mental health support options
!endchat - End an active DM chat session from a server
!memory - View what Pikabug remembers about you
!forget - Clear Pikabug's memories about you

**Journaling & Venting:**
!prompt - Get a random journaling prompt
!write [entry] - Submit your journal entry for PikaPoints
!vent - Get support message before venting
!venting [message] - Submit your vent (message will be deleted for privacy)

**Word Games:**
!unscramble - Start word unscrambling game
!guess [word] - Guess the unscrambled word
!hint - Get a hint for current unscramble
!reveal - Reveal the answer and end round
!prefixgame - Find the longest word with given prefix
!wordsearch - Find 3 hidden words in an 8x8 grid
!endwordsearch - Give up on current word search

**Weekly Workshops:**
!monday [entry] - Submit Mindful Monday entry
!tuesday [entry] - Submit Trigger or Trauma Tuesday entry
!thursday [entry] - Submit Thankful Thursday entry
!friday [entry] - Submit Flourishing Friday entry
!weekend - Get Weekend Writing prompt
!weekendsubmit [entry] - Submit Weekend Writing response

**Points & Info:**
!points - View your PikaPoints balance
!pikahelp - Show this help message

**Admin Only:**
!grantpoints @user [amount] - Grant points (max 1000)
!removepoints @user [amount] - Remove points (max 1000)
!setpoints @user [amount] - Set exact points (max 10,000)
!clearhistory [@user] - Clear conversation history
!viewworkshop [@user] - View workshop submissions"""
       
       embed = create_pikabug_embed(pikahelp_text, title="⚡️ Pikabug Help")
       await ctx.send(embed=embed)
       await logger.log_command_usage(ctx, "pikahelp", success=True)
       
   except Exception as e:
       await logger.log_error(e, "Help Command Error")
       await logger.log_command_usage(ctx, "pikahelp", success=False)

@bot.command(name='clearcache')
async def clear_cache(ctx):
    """Clear all bot cache (Admin only)"""
    try:
        # Check admin permissions
        if not ctx.author.guild_permissions.administrator:
            await ctx.send("❌ You need administrator permissions to use this command.")
            return
        
        # Clear conversation histories
        conversation_history.clear()
        
        # Clear active sessions
        chat_sessions.clear()
        active_dm_sessions.clear()
        active_comfort_sessions.clear()
        
        # Clear active games
        active_wordsearch_games.clear()
        active_weekend_prompts.clear()
        
        # Clear current game states
        global current_word, scrambled_word, revealed_indexes, hint_count
        current_word = None
        scrambled_word = None
        revealed_indexes = set()
        hint_count = 0
        
        embed = create_pikabug_embed(
            "✅ Cache cleared successfully!\n"
            "• Conversation histories cleared\n"
            "• Active sessions terminated\n"
            "• Game states reset",
            title="🧹 Cache Cleared"
        )
        await ctx.send(embed=embed)
        
        await logger.log_bot_event("Cache Cleared", f"Admin {ctx.author.display_name} cleared all cache")
        
    except Exception as e:
        await logger.log_error(e, "Clear Cache Error")
        await ctx.send("❌ Error clearing cache.")

# ─── Bot Startup ─────────────────────────────────────────────────

# Run the bot
token = os.getenv("DISCORD_TOKEN")
if token:
   bot.run(token)
else:
   print("❌ DISCORD_TOKEN not found in environment variables!")
   exit(1)