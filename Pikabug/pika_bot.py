import os
import asyncio
from dotenv import load_dotenv
import discord
from discord.ext import commands, tasks
import json
import time
import pathlib
import random
from threading import Lock
from pathlib import Path

from anthropic import Anthropic
from utils import create_pikabug_embed, DiscordLogger
from datetime import datetime, timezone

# ─── Constants ─────────────────────────────────────────────
DISK_PATH = Path("data")
PIKA_FILE = DISK_PATH / "pikapoints.json"
COMFORT_HISTORY_FILE = DISK_PATH / "comfort_history.json"
MAX_COMFORT_ENTRIES = 100
COMFORT_SUMMARY_INTERVAL = 10
CONVERSATION_LIMIT = 50

# ─── Check-In State/Vars ─────────────────────────────────────────────
CHECKIN_MESSAGES_FILE = os.path.join(os.path.dirname(__file__), "checkin_messages.txt")
CHECK_IN_STATE_FILE = DISK_PATH / "check_in_state.json"
CHECK_IN_CHANNEL_ID = 1392091878748459048  # Set to your check-in channel ID
CHECK_IN_INTERVAL = 43200  # 12 hours in seconds

if os.path.exists(CHECKIN_MESSAGES_FILE):
    with open(CHECKIN_MESSAGES_FILE, encoding="utf-8") as f:
        check_in_messages = [line.strip() for line in f if line.strip()]
else:
    check_in_messages = [
        "How are you feeling today? 💙",
        "Remember to take breaks and stay hydrated! 💧",
        "You're doing great, keep going! ✨",
        "How's your mental health today? 💚",
        "Don't forget to be kind to yourself today! 🌟",
        "How are you managing stress lately? 🧘‍♀️",
        "Remember, it's okay to not be okay sometimes 💛",
        "What's something positive that happened today?"
    ]

def get_default_check_in_state():
        return {
        "last_sent": 0,
        "last_index": -1,
        "order": list(range(len(check_in_messages)))
    }

def load_check_in_state():
    if CHECK_IN_STATE_FILE.exists():
        with open(CHECK_IN_STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        state = get_default_check_in_state()
        save_check_in_state(state)
        return state

def save_check_in_state(state):
    CHECK_IN_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(CHECK_IN_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        print(f"Error saving check-in state: {e}")

check_in_state = load_check_in_state()

# ─── Hot Take State/Vars ─────────────────────────────────────────────
HOT_TAKE_FILE = os.path.join(os.path.dirname(__file__), "hot_takes.txt")
if os.path.exists(HOT_TAKE_FILE):
    with open(HOT_TAKE_FILE, encoding="utf-8") as f:
        hot_takes = [line.strip() for line in f if line.strip()]

HOT_TAKE_STATE_FILE = DISK_PATH / "hot_take_state.json"
HOT_TAKE_CHANNEL_ID = 1392813388286918696
HOT_TAKE_INTERVAL = 86400  # 24 hours in seconds

def get_default_hot_take_state():
    return {
        "last_sent": 0,
        "last_index": -1,
        "order": list(range(len(hot_takes)))
    }

def load_hot_take_state():
    if HOT_TAKE_STATE_FILE.exists():
        with open(HOT_TAKE_STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        state = get_default_hot_take_state()
        save_hot_take_state(state)
        return state

def save_hot_take_state(state):
    HOT_TAKE_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(HOT_TAKE_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        print(f"Error saving hot take state: {e}")

hot_take_state = load_hot_take_state()

# ─── QOTD State/Vars ─────────────────────────────────────────────
QOTD_FILE = os.path.join(os.path.dirname(__file__), "qotd.txt")
QOTD_STATE_FILE = DISK_PATH / "qotd_state.json"
QOTD_CHANNEL_ID = 1398265205443788841  # QOTD channel ID
QOTD_INTERVAL = 86400  # 24 hours in seconds

if os.path.exists(QOTD_FILE):
    with open(QOTD_FILE, encoding="utf-8") as f:
        qotd_questions = [line.strip() for line in f if line.strip()]
else:
    qotd_questions = [
        "What version of yourself are you protecting by staying angry? What might you discover if you let that guard down for a second? Which behaviors trigger you the most—and what do they reflect about your own inner landscape?"
    ]

def get_default_qotd_state():
    return {
        "last_sent": 0,
        "last_index": -1,
        "order": list(range(len(qotd_questions)))
    }

def load_qotd_state():
    if QOTD_STATE_FILE.exists():
        with open(QOTD_STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        state = get_default_qotd_state()
        save_qotd_state(state)
        return state

def save_qotd_state(state):
    QOTD_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(QOTD_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        print(f"Error saving QOTD state: {e}")

qotd_state = load_qotd_state()

# ─── Environment & Clients ───────────────────────────────────────
load_dotenv()
token = os.getenv("DISCORD_TOKEN")
if not token:
    raise ValueError("DISCORD_TOKEN environment variable is not set")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
if not ANTHROPIC_API_KEY:
    raise ValueError("ANTHROPIC_API_KEY environment variable is not set")

client = Anthropic(api_key=ANTHROPIC_API_KEY)

# ─── Word Games Wordlist ─────────────────────────────────────────
BASE_DIR = pathlib.Path(__file__).parent
with open(BASE_DIR / "words_alpha.txt", encoding="utf-8") as f:
    valid_words = {line.strip().lower() for line in f if line.strip()}

# ─── In‐Memory Session State ─────────────────────────────────────
# Global session states shared across cogs
conversation_history      = {}
chat_sessions             = {}
active_dm_sessions        = {}
active_comfort_sessions   = {}

# ─── Thread‐Safe Locks ────────────────────────────────────────────
conversation_lock = asyncio.Lock()
session_lock      = asyncio.Lock()
memory_lock       = asyncio.Lock()
thread_lock       = Lock()

# ─── Bot & Intents ───────────────────────────────────────────────
intents = discord.Intents.default()
intents.message_content = True
intents.reactions       = True
intents.guilds          = True

LOG_CHANNEL_ID = 1388809359206780998

bot = commands.Bot(command_prefix='!', intents=intents)
bot.LOG_CHANNEL_ID = LOG_CHANNEL_ID
bot.logger = DiscordLogger(bot)

# Add global state to bot for cross-cog communication
bot.active_dm_sessions = active_dm_sessions
bot.active_comfort_sessions = active_comfort_sessions
bot.conversation_history = conversation_history
bot.chat_sessions = chat_sessions

# ─── TASKS (ALL TOGETHER FOR ORDER) ─────────────────────────────────────────

@tasks.loop(hours=4)
async def cleanup_chat_sessions():
    try:
        current_time = datetime.now(timezone.utc)
        sessions_to_remove = []
        dm_sessions_to_remove = []
        comfort_sessions_to_remove = []
        for user_key, session_data in chat_sessions.items():
            last_interaction = session_data['last_interaction']
            time_diff = current_time - last_interaction
            if time_diff.total_seconds() > 14400:
                sessions_to_remove.append(user_key)
        for user_id, session_data in active_dm_sessions.items():
            session_duration = current_time - session_data['started_at']
            if session_duration.total_seconds() > 28800:
                dm_sessions_to_remove.append(user_id)
        for user_id, session_data in active_comfort_sessions.items():
            session_duration = current_time - session_data['started_at']
            if session_duration.total_seconds() > 1800:
                comfort_sessions_to_remove.append(user_id)
        for user_key in sessions_to_remove:
            del chat_sessions[user_key]
            if user_key in conversation_history:
                del conversation_history[user_key]
        for user_id in dm_sessions_to_remove:
            if user_id in active_dm_sessions:
                dm_key = active_dm_sessions[user_id]['user_key']
                del active_dm_sessions[user_id]
                if dm_key in conversation_history:
                    del conversation_history[dm_key]
                if dm_key in chat_sessions:
                    del chat_sessions[dm_key]
        for user_id in comfort_sessions_to_remove:
            del active_comfort_sessions[user_id]
        if sessions_to_remove or dm_sessions_to_remove or comfort_sessions_to_remove:
            if bot.logger is not None:
                await bot.logger.log_bot_event(
                    "Session Cleanup", 
                    f"Cleaned up {len(sessions_to_remove)} chat sessions, {len(dm_sessions_to_remove)} DM sessions, and {len(comfort_sessions_to_remove)} comfort sessions"
                )
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "Session Cleanup Error")
        else:
            print(f"Error: {e}")

@cleanup_chat_sessions.before_loop
async def before_cleanup_chat_sessions():
    await bot.wait_until_ready() 

@tasks.loop(minutes=60)  # Check every hour, but only send every 12 hours
async def send_check_in():
    try:
        # Reload state to ensure we have the latest data
        current_state = load_check_in_state()
        
        now = time.time()
        last_sent = current_state.get("last_sent", 0)
        time_since_last = now - last_sent
        
        # Debug logging
        print(f"Check-in task: {time_since_last:.0f}s since last, need {CHECK_IN_INTERVAL}s")
        
        # CRITICAL: Always check if enough time has passed before sending
        if time_since_last < CHECK_IN_INTERVAL:
            print(f"Check-in: Not enough time passed ({time_since_last:.0f}s < {CHECK_IN_INTERVAL}s)")
            return
            
        channel = bot.get_channel(CHECK_IN_CHANNEL_ID)
        if not channel:
            print(f"Check-in channel {CHECK_IN_CHANNEL_ID} not found")
            return
            
        order = current_state["order"]
        last_index = current_state.get("last_index", -1)
        if last_index in order:
            current_position = order.index(last_index)
            next_position = (current_position + 1) % len(order)
        else:
            next_position = 0
            
        check_in_index = order[next_position]
        check_in_message = check_in_messages[check_in_index]
        embed = create_pikabug_embed(check_in_message, title="💒 Mental Health Check-in")
        embed.color = 0xffcec6
        
        if isinstance(channel, discord.abc.Messageable):
            await channel.send(embed=embed)
            
        # Update and save state
        current_state["last_sent"] = now
        current_state["last_index"] = check_in_index
        if next_position == len(order) - 1:
            random.shuffle(current_state["order"])
        save_check_in_state(current_state)
        
        if bot.logger is not None:
            await bot.logger.log_bot_event("Check-in Sent", f"Sent check-in message #{check_in_index}")
            
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "Check-in Task Error")
        else:
            print(f"Check-in Error: {e}")

@send_check_in.before_loop
async def before_send_check_in():
    await bot.wait_until_ready()
    
    # Reload state to ensure we have the latest data
    current_state = load_check_in_state()
    now = time.time()
    last_sent = current_state.get("last_sent", 0)
    time_since_last = now - last_sent
    
    print(f"Check-in startup: {time_since_last:.0f}s since last check-in")
    
    # CRITICAL: Always wait full interval if recently sent, plus buffer to prevent spam
    if time_since_last < CHECK_IN_INTERVAL:
        wait_time = CHECK_IN_INTERVAL - time_since_last + 300  # Add 5 min buffer
        print(f"Waiting {wait_time:.0f} seconds before next check-in (with safety buffer)...")
        await asyncio.sleep(wait_time)

@tasks.loop(minutes=60)  # Check every hour, but only send every 24 hours  
async def send_qotd():
    try:
        # Reload state to ensure we have the latest data
        current_state = load_qotd_state()
        
        now = time.time()
        last_sent = current_state.get("last_sent", 0)
        time_since_last = now - last_sent
        
        # Debug logging
        print(f"QOTD task: {time_since_last:.0f}s since last, need {QOTD_INTERVAL}s")
        
        # CRITICAL: Always check if enough time has passed before sending
        if time_since_last < QOTD_INTERVAL:
            print(f"QOTD: Not enough time passed ({time_since_last:.0f}s < {QOTD_INTERVAL}s)")
            return
            
        channel = bot.get_channel(QOTD_CHANNEL_ID)
        if not channel:
            print(f"QOTD channel {QOTD_CHANNEL_ID} not found")
            return
            
        order = current_state["order"]
        last_index = current_state.get("last_index", -1)
        if last_index in order:
            current_position = order.index(last_index)
            next_position = (current_position + 1) % len(order)
        else:
            next_position = 0
            
        qotd_index = order[next_position]
        question = qotd_questions[qotd_index]
        formatted_message = f"Qotd ⚡️\n\n{question}"
        embed = create_pikabug_embed(formatted_message, title="🤔 Question of the Day")
        embed.color = 0xffcec6
        
        if isinstance(channel, discord.abc.Messageable):
            await channel.send(embed=embed)
            
        # Update and save state
        current_state["last_sent"] = now
        current_state["last_index"] = qotd_index
        if next_position == len(order) - 1:
            random.shuffle(current_state["order"])
        save_qotd_state(current_state)
        
        if bot.logger is not None:
            await bot.logger.log_bot_event("QOTD Sent", f"Sent question #{qotd_index}")
            
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "QOTD Task Error")
        else:
            print(f"QOTD Task Error: {e}")

@send_qotd.before_loop
async def before_send_qotd():
    await bot.wait_until_ready()
    
    # Reload state to ensure we have the latest data
    current_state = load_qotd_state()
    now = time.time()
    last_sent = current_state.get("last_sent", 0)
    time_since_last = now - last_sent
    
    print(f"QOTD startup: {time_since_last:.0f}s since last QOTD")
    
    # CRITICAL: Always wait full interval if recently sent, plus buffer to prevent spam
    if time_since_last < QOTD_INTERVAL:
        wait_time = QOTD_INTERVAL - time_since_last + 300  # Add 5 min buffer
        print(f"Waiting {wait_time:.0f} seconds before next QOTD (with safety buffer)...")
        await asyncio.sleep(wait_time)

@tasks.loop(minutes=60)  # Check every hour, but only send every 24 hours
async def send_hot_take():
    try:
        # Reload state to ensure we have the latest data
        current_state = load_hot_take_state()
        
        now = time.time()
        last_sent = current_state.get("last_sent", 0)
        time_since_last = now - last_sent
        
        # Debug logging
        print(f"Hot take task: {time_since_last:.0f}s since last, need {HOT_TAKE_INTERVAL}s")
        
        # CRITICAL: Always check if enough time has passed before sending
        if time_since_last < HOT_TAKE_INTERVAL:
            print(f"Hot take: Not enough time passed ({time_since_last:.0f}s < {HOT_TAKE_INTERVAL}s)")
            return
            
        channel = bot.get_channel(HOT_TAKE_CHANNEL_ID)
        if not channel:
            print(f"Hot take channel {HOT_TAKE_CHANNEL_ID} not found")
            return

        order = current_state["order"]
        last_index = current_state.get("last_index", -1)
        if last_index in order:
            current_position = order.index(last_index)
            next_position = (current_position + 1) % len(order)
        else:
            next_position = 0
            
        hot_take_index = order[next_position]
        hot_take = hot_takes[hot_take_index]
        embed = create_pikabug_embed(hot_take, title="🔥 Hot Take")
        
        if isinstance(channel, discord.abc.Messageable):
            await channel.send(embed=embed)
            
        # Update and save state
        current_state["last_sent"] = now
        current_state["last_index"] = hot_take_index
        if next_position == len(order) - 1:
            random.shuffle(current_state["order"])
        save_hot_take_state(current_state)
        
        if bot.logger is not None:
            await bot.logger.log_bot_event("Hot Take Sent", f"Sent hot take #{hot_take_index}")
        
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "Hot Take Task Error")
        else:
            print(f"Hot Take Task Error: {e}")

@send_hot_take.before_loop
async def before_send_hot_take():
    await bot.wait_until_ready()
    
    # Reload state to ensure we have the latest data
    current_state = load_hot_take_state()
    now = time.time()
    last_sent = current_state.get("last_sent", 0)
    time_since_last = now - last_sent
    
    print(f"Hot take startup: {time_since_last:.0f}s since last hot take")
    
    # CRITICAL: Always wait full interval if recently sent, plus buffer to prevent spam
    if time_since_last < HOT_TAKE_INTERVAL:
        wait_time = HOT_TAKE_INTERVAL - time_since_last + 300  # Add 5 min buffer
        print(f"Waiting {wait_time:.0f} seconds before next hot take (with safety buffer)...")
        await asyncio.sleep(wait_time)

# ─── COMMAND ERROR HANDLER ─────────────────────────────────────────────
@bot.event
async def on_command_error(ctx, error):
    """Global error handler for command detection and user feedback."""
    if bot.logger:
        await bot.logger.log_error(
            error, 
            f"Command Error in {ctx.command.name if ctx.command else 'Unknown Command'}", 
            f"User: {ctx.author.id}, Guild: {ctx.guild.id if ctx.guild else 'DM'}"
        )
    
    # Send user-friendly error message with styled embed
    if isinstance(error, commands.CommandNotFound):
        error_msg = "❌ Command not found. Use `!pikahelp` to see available commands."
        embed = create_pikabug_embed(error_msg, title="❌ Command Error")
        embed.color = 0xff0000  # Red color for errors
        await ctx.send(embed=embed)
    elif isinstance(error, commands.MissingRequiredArgument):
        error_msg = f"❌ Missing required argument for `!{ctx.command.name}`. Check the command usage with `!pikahelp`."
        embed = create_pikabug_embed(error_msg, title="❌ Missing Argument")
        embed.color = 0xff0000  # Red color for errors
        await ctx.send(embed=embed)
    elif isinstance(error, commands.BadArgument):
        error_msg = f"❌ Invalid argument for `!{ctx.command.name}`. Check the command usage with `!pikahelp`."
        embed = create_pikabug_embed(error_msg, title="❌ Invalid Argument")
        embed.color = 0xff0000
        await ctx.send(embed=embed)
    elif isinstance(error, commands.CheckFailure):
        error_msg = "❌ You don't have permission to use this command."
        embed = create_pikabug_embed(error_msg, title="❌ Permission Denied")
        embed.color = 0xff0000
        await ctx.send(embed=embed)
    elif isinstance(error, commands.CommandOnCooldown):
        error_msg = f"❌ Command is on cooldown. Try again in {error.retry_after:.1f} seconds."
        embed = create_pikabug_embed(error_msg, title="❌ Cooldown")
        embed.color = 0xff0000
        await ctx.send(embed=embed)
    else:
        error_msg = "❌ An unexpected error occurred while processing your command. The error has been logged."
        embed = create_pikabug_embed(error_msg, title="❌ Error")
        embed.color = 0xff0000
        await ctx.send(embed=embed)

# ─── on_ready EVENT ─────────────────────────────────────────────
@bot.event
async def on_ready():
    print(f"{bot.user} has connected to Discord!")
    claude_status = "❌ Not connected"
    try:
        resp = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=50,
            messages=[{"role": "user", "content": "Respond with 'API working'"}]
        )
        block = resp.content[0]
        reply = getattr(block, "text", None) or getattr(block, "content", str(block))
        claude_status = (
            "✅ Connected and responding correctly"
            if "API working" in str(reply)
            else "⚠️ Connected but unexpected response"
        )
        print(f"Claude API test reply: {reply}")
    except Exception as e:
        claude_status = f"❌ Connection failed: {type(e).__name__}"
        print(f"Claude API error: {e}")
    await bot.logger.initialize()
    await bot.logger.log_bot_event("Bot Started", f"⚡️ Pikabug online as {bot.user}\nClaude API Status: {claude_status}")
    if not send_hot_take.is_running():
        send_hot_take.start()
        print("Started hot take task")
    if not send_check_in.is_running():
        send_check_in.start()
        print("Started check-in task")
    if not send_qotd.is_running():
        send_qotd.start()
        print("Started QOTD task")
    if not cleanup_chat_sessions.is_running():
        cleanup_chat_sessions.start()
        print("Started cleanup task")
    print("⚡️ Pikabug online with all tasks started")

# ─── Admin/Helper Commands ─────────────────────────────────────────────
@bot.command()
@commands.has_permissions(administrator=True)
async def sanitycheck(ctx):
    loaded = []
    for ext in bot.extensions:
        name = ext.split('.')[-1].capitalize()
        cog = bot.get_cog(name)
        if cog:
            loaded.append(f"✅ {ext}")
        else:
            loaded.append(f"⚠️ {ext} (no cog object found)")
    response = "**Sanity Check:**\n" + "\n".join(loaded)
    await ctx.send(response)

@bot.command(name="pikahelp")
async def pikahelp_command(ctx):
    try:
        pikahelp_text = """⚡️🐛 Pikabug Commands:

**AI Chat:**
!dmcomfort - Start a specialized, comforting, human-like DM session with mental health support options
!endchat - End an active DM chat session with Pikabug in the server
!memory - View what Pikabug remembers about you
!forget - Clear Pikabug's memories about you

**Journaling & Venting:**
!prompt - Get a random journaling prompt to answer for PikaPoints and mindfulness
!write [entry] - Submit your journal entry for PikaPoints and future reference
!vent - Initiate the anonymous venting session with Pikabug
!venting [message] - Submit your vent (message is deleted for privacy but PikaPoints are rewarded)

**Word Games:**
!unscramble - Start 3-round word unscrambling challenge
!guess [word] - Guess the unscrambled word
!hint - Get a hint for current unscramble
!reveal - Reveal the answer and move to next round
!prefixgame - Find the longest word with given prefix
!easywordsearch - Start easy word search (6x6 grid, 2 words, all directions)
!hardwordsearch - Start hard word search (8x8 grid, 3 words, limited directions)
!endwordsearch - Give up on current word search
!scattergories - Start Scattergories game with 8 categories

**Weekly Workshops:**
!monday [entry] - Submit Mindful Monday entry
!tuesday [entry] - Submit Trigger or Trauma Tuesday entry
!thursday [entry] - Submit Thankful Thursday entry
!friday [entry] - Submit Flourishing Friday entry
!weekend - Get Weekend Writing prompt
!weekendsubmit [entry] - Submit Weekend Writing response

**Points & Info:**
!points - View your PikaPoints balance
!pikahelp - Show Pikabug's command help message

**Admin Only:**
!grantpoints @user [amount] - Grant points (max 1000)
!removepoints @user [amount] - Remove points (max 1000)
!setpoints @user [amount] - Set exact points (max 10,000)
!clearhistory [@user] - Clear conversation history
!viewworkshop [@user] - View workshop submissions
!sanitycheck - Check loaded cogs status
!clearcache - Clear all bot cache and sessions"""
        embed = create_pikabug_embed(pikahelp_text, title="⚡️ Pikabug Help")
        await ctx.send(embed=embed)
        if bot.logger is not None:
            await bot.logger.log_command_usage(ctx, "pikahelp", success=True)
        else:
            print(f"Command usage: pikahelp, success=True, user={ctx.author}")
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "Help Command Error")
        else:
            print(f"Error: {e}")
        if bot.logger is not None:
            await bot.logger.log_command_usage(ctx, "pikahelp", success=False)

@bot.command(name='clearcache')
async def clear_cache(ctx):
    try:
        if not ctx.author.guild_permissions.administrator:
            await ctx.send("❌ You need administrator permissions to use this command.")
            return

        # Clear global session states
        conversation_history.clear()
        chat_sessions.clear()
        active_dm_sessions.clear()
        active_comfort_sessions.clear()
        
        # Clear cog-specific game states through Storage cog
        storage_cog = bot.get_cog("Storage")
        if storage_cog:
            storage_cog.active_wordsearch_games.clear()
            storage_cog.wordsearch_word_history.clear()
        
        # Clear other cog states
        for cog_name in ['Unscramble', 'PrefixGame', 'Scattergories']:
            cog = bot.get_cog(cog_name)
            if cog and hasattr(cog, 'sessions'):
                cog.sessions.clear()
        
        embed = create_pikabug_embed(
            "✅ Cache cleared successfully!\n"
            "• Conversation histories cleared\n"
            "• Active sessions terminated\n"
            "• Game states reset\n"
            "• Cog-specific caches cleared",
            title="🧹 Cache Cleared"
        )
        await ctx.send(embed=embed)
        if bot.logger is not None:
            await bot.logger.log_bot_event("Cache Cleared", f"Admin {ctx.author.display_name} cleared all cache")
    except Exception as e:
        if bot.logger is not None:
            await bot.logger.log_error(e, "Clear Cache Error")
        else:
            print(f"Error: {e}")
        await ctx.send("❌ Error clearing cache.")

# ─── MAIN FUNCTION ─────────────────────────────────────────────
async def main():
    # Load storage cog first
    try:
        await bot.load_extension("cogs.storageunit")
        print("Loaded cogs.storageunit")
    except Exception as e:
        print(f"Failed to load cogs.storageunit: {e}")

    # Load pikapoints cog next
    try:
        await bot.load_extension("cogs.pikapoints")
        print("Loaded cogs.pikapoints")
    except Exception as e:
        print(f"Failed to load cogs.pikapoints: {e}")

    # Then load all other cogs
    cogs_to_load = [
        "cogs.comfort",
        "cogs.journaling",
        "cogs.memory",
        "cogs.prefixgame",
        "cogs.scattergories",
        "cogs.unscramble",
        "cogs.venting",
        "cogs.wordsearch",
        "cogs.workshop",
    ]
    for cog in cogs_to_load:
        try:
            await bot.load_extension(cog)
            print(f"Loaded {cog}")
        except Exception as e:
            print(f"Failed to load {cog}: {e}")

    if not token:
        raise ValueError("Discord token not found in environment variables")
    await bot.start(token)

if __name__ == "__main__":
    if not token:
        print("❌ DISCORD_TOKEN not found in environment variables!")
        exit(1)
    asyncio.run(main())