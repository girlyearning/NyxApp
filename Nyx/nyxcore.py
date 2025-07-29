# nyxcore.py

import os
import sys
import logging
import asyncio
from datetime import datetime
import discord
from discord.ext import commands
from dotenv import load_dotenv
from typing import Optional
import traceback
import queue
from threading import Lock

# ★ Load environment variables
load_dotenv()

# ★ BOT CONSTANTS
NYX_COLOR = 0x76b887
FONT = "monospace"
COG_DIRECTORY = os.path.join(os.path.dirname(__file__), "cogs")  # Simple relative path
STORAGE_PATH = "./nyxnotes"  # ★ FIXED: always relative and writeable
TOKEN = os.getenv("DISCORD_TOKEN")
LOG_CHANNEL_ID = 1388809359206780998  # ★ Discord log channel

# ★ Ensure storage directory exists
os.makedirs(STORAGE_PATH, exist_ok=True)

# ★ Validate token
if not TOKEN or TOKEN.strip() == "":
    print("❌ Error: DISCORD_TOKEN not found or empty in environment variables!")
    sys.exit(1)

# ★ Async Discord Logging Handler
class AsyncDiscordLogHandler(logging.Handler):
    """Async logging handler that sends logs to Discord channel."""
    
    def __init__(self, bot: commands.Bot, channel_id: int):
        super().__init__()
        self.bot = bot
        self.channel_id = channel_id
        self.channel = None
        self.rate_limit_count = 0
        self.last_rate_limit_reset = datetime.now()
        self.max_logs_per_minute = 15  # Rate limiting
        self._setup_complete = False
        self._lock = Lock()
        
        # ★ Log queue for async processing
        self.log_queue = asyncio.Queue(maxsize=100)
        self.processor_task = None
        
        # ★ Configure which log levels to send to Discord
        self.discord_levels = {
            logging.ERROR: True,    # Always send errors
            logging.WARNING: True,  # Send warnings
            logging.INFO: True,     # Send important info
            logging.DEBUG: False    # Skip debug messages
        }
        
        # ★ Filter patterns for noise reduction
        self.filter_patterns = [
            "PyNaCl is not installed",
            "logging in using static token",
            "Shard ID None has connected",
            "Shard ID None session has been invalidated",
            "We are being rate limited",
            "Attempting a reconnect",
            "Discord logging rate limited",
            "Discord logging HTTP error",
            "Discord logging error"
        ]
    
    async def setup_channel(self):
        """Initialize the Discord channel reference."""
        if not self.bot.is_ready():
            return False
            
        try:
            self.channel = self.bot.get_channel(self.channel_id)
            if not self.channel:
                print(f"❌ Could not find log channel with ID: {self.channel_id}")
                return False
            
            # ★ Start the log processor task
            if not self.processor_task or self.processor_task.done():
                self.processor_task = asyncio.create_task(self._process_logs())
            
            with self._lock:
                self._setup_complete = True
            
            return True
        except Exception as e:
            print(f"❌ Error setting up log channel: {e}")
            return False
    
    async def _process_logs(self):
        """Async task to process queued log records."""
        while True:
            try:
                # ★ Wait for log record with timeout
                try:
                    record = await asyncio.wait_for(self.log_queue.get(), timeout=1.0)
                except asyncio.TimeoutError:
                    continue
                
                # ★ Process the log record
                await self._send_log_to_discord(record)
                self.log_queue.task_done()
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"❌ Error in log processor: {e}")
                await asyncio.sleep(1)
    
    def should_log_to_discord(self, record: logging.LogRecord) -> bool:
        """Determine if this log record should be sent to Discord."""
        # ★ Check if setup is complete
        with self._lock:
            if not self._setup_complete:
                return False
        
        # ★ Check rate limiting
        now = datetime.now()
        if (now - self.last_rate_limit_reset).seconds >= 60:
            self.rate_limit_count = 0
            self.last_rate_limit_reset = now
        
        if self.rate_limit_count >= self.max_logs_per_minute:
            return False
        
        # ★ Check log level
        if not self.discord_levels.get(record.levelno, False):
            return False
        
        # ★ Filter out noise
        message = record.getMessage()
        for pattern in self.filter_patterns:
            if pattern in message:
                return False
        
        return True
    
    def create_log_embed(self, record: logging.LogRecord) -> discord.Embed:
        """Create a Discord embed for the log record."""
        # ★ Determine embed color based on log level
        if record.levelno >= logging.ERROR:
            color = 0xff6b6b  # Red for errors
            emoji = "❌"
        elif record.levelno >= logging.WARNING:
            color = 0xffd93d  # Yellow for warnings
            emoji = "⚠️"
        else:
            color = NYX_COLOR  # Nyx green for info
            emoji = "ℹ️"
        
        # ★ Create embed
        embed = discord.Embed(
            color=color,
            timestamp=datetime.fromtimestamp(record.created)
        )
        
        # ★ Set title based on logger name and level
        logger_name = record.name.replace("nyxcore", "Core").replace("nyxmemory", "Memory")
        title = f"{emoji} {logger_name} | {record.levelname}"
        embed.set_author(name=title)
        
        # ★ Add main message
        message = record.getMessage()
        if len(message) > 1024:
            message = message[:1021] + "..."
        
        embed.add_field(
            name="Message",
            value=f"```\n{message}\n```",
            inline=False
        )
        
        # ★ Add exception info if present
        if record.exc_info:
            exc_text = ''.join(traceback.format_exception(*record.exc_info))
            if len(exc_text) > 1024:
                exc_text = exc_text[:1021] + "..."
            
            embed.add_field(
                name="Exception",
                value=f"```py\n{exc_text}\n```",
                inline=False
            )
        
        # ★ Add context info
        if hasattr(record, 'pathname'):
            file_info = f"{record.filename}:{record.lineno}"
            if record.funcName:
                file_info += f" in {record.funcName}()"
            
            embed.set_footer(text=file_info)
        
        return embed
    
    def emit(self, record: logging.LogRecord):
        """Queue log record for async processing."""
        if not self.should_log_to_discord(record):
            return
        
        # ★ Add to queue if bot is ready and has event loop
        try:
            if (self.bot.is_ready() and 
                hasattr(self.bot, 'loop') and 
                self.bot.loop and 
                not self.bot.loop.is_closed()):
                
                # ★ Try to add to queue (non-blocking)
                try:
                    self.log_queue.put_nowait(record)
                except asyncio.QueueFull:
                    # ★ Queue is full, drop oldest and add new
                    try:
                        self.log_queue.get_nowait()
                        self.log_queue.put_nowait(record)
                    except asyncio.QueueEmpty:
                        pass
        except Exception:
            # ★ Silently fail to avoid logging loops
            pass
    
    async def _send_log_to_discord(self, record: logging.LogRecord):
        """Send log record to Discord channel."""
        try:
            # ★ Ensure channel is available
            if not self.channel:
                return
            
            # ★ Create and send embed
            embed = self.create_log_embed(record)
            await self.channel.send(embed=embed)
            
            # ★ Increment rate limit counter
            self.rate_limit_count += 1
            
        except discord.HTTPException as e:
            if e.status == 429:  # Rate limited
                # ★ Don't log rate limit errors to avoid loops
                pass
            else:
                print(f"❌ Discord logging HTTP error: {e}")
        except Exception as e:
            print(f"❌ Discord logging error: {e}")
    
    async def close(self):
        """Clean up the handler."""
        if self.processor_task and not self.processor_task.done():
            self.processor_task.cancel()
            try:
                await self.processor_task
            except asyncio.CancelledError:
                pass

# ★ Setup Logging with Discord Handler
def setup_logging(bot: commands.Bot) -> logging.Logger:
    """Set up logging with both file and Discord handlers."""
    
    # ★ Create formatters
    file_formatter = logging.Formatter(
        "[{asctime}] [{levelname}] {name}: {message}",
        style="{"
    )
    
    console_formatter = logging.Formatter(
        "[{levelname}] {name}: {message}",
        style="{"
    )
    
    # ★ Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    
    # ★ Clear existing handlers to avoid duplicates
    root_logger.handlers.clear()
    
    # ★ File handler (keep existing functionality)
    file_handler = logging.FileHandler("nyx.log", encoding="utf-8")
    file_handler.setFormatter(file_formatter)
    file_handler.setLevel(logging.INFO)
    
    # ★ Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(console_formatter)
    console_handler.setLevel(logging.INFO)
    
    # ★ Discord handler
    discord_handler = AsyncDiscordLogHandler(bot, LOG_CHANNEL_ID)
    discord_handler.setLevel(logging.INFO)
    
    # ★ Add handlers
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    root_logger.addHandler(discord_handler)
    
    # ★ Store discord handler reference on bot for cleanup
    bot.discord_log_handler = discord_handler
    
    # ★ Create main logger
    logger = logging.getLogger("nyxcore")
    
    return logger

# ★ Create bot instance
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)

# ★ Initialize logging system
logger = setup_logging(bot)

# ★ Add command usage logging
@bot.event
async def on_command(ctx):
    """Log successful command usage."""
    logger.info(f"Command used: {ctx.command.name} by {ctx.author.display_name} in {ctx.guild.name}/{ctx.channel.name}")

@bot.event
async def on_command_error(ctx, error):
    """Log command errors."""
    # Filter out common/expected errors that aren't actually problems
    ignored_errors = (
        commands.CommandNotFound,     # User typed invalid command
        commands.DisabledCommand,     # Command is disabled
        commands.NoPrivateMessage,    # Command used in DM when not allowed
    )
    
    # Don't log these common errors
    if isinstance(error, ignored_errors):
        return
    
    # Log permission errors but don't spam
    if isinstance(error, (commands.MissingPermissions, commands.MissingRequiredArgument)):
        logger.warning(f"Permission/argument error in '{ctx.command}' by {ctx.author}: {str(error)}")
        return
    
    # Log actual serious errors
    logger.error(f"Error in command '{ctx.command}' by {ctx.author} in {ctx.guild.name if ctx.guild else 'DM'}: {str(error)}")
    
    # Optionally send error to user (uncomment if you want this)
    # await ctx.send("Something went wrong with that command. Please try again!")

# ★ Async Cog Loader
async def load_cogs():
    """Load all cogs from the cogs directory."""
    if not os.path.exists(COG_DIRECTORY):
        logger.error(f"❌ Cogs directory not found: {COG_DIRECTORY}")
        return
        
    loaded_cogs = []
    failed_cogs = []
    
    for filename in os.listdir(COG_DIRECTORY):
        if filename.endswith(".py"):
            cog_name = filename[:-3]
            try:
                await bot.load_extension(f"cogs.{cog_name}")
                logger.info(f"✅ Loaded cog: {cog_name}")
                loaded_cogs.append(cog_name)
            except Exception as e:
                logger.error(f"❌ Failed to load cog {cog_name}: {e}")
                failed_cogs.append(cog_name)
                # Log full traceback for debugging
                logger.error(traceback.format_exc())
    
    # ★ Summary log
    if loaded_cogs:
        logger.info(f"🎯 Successfully loaded {len(loaded_cogs)} cogs: {', '.join(loaded_cogs)}")
    if failed_cogs:
        logger.warning(f"⚠️ Failed to load {len(failed_cogs)} cogs: {', '.join(failed_cogs)}")

@bot.event
async def on_ready():
    """Called when bot is ready and connected."""
    logger.info(f"🤖 Logged in as {bot.user} (ID: {bot.user.id})")
    logger.info(f"📚 Discord.py version: {discord.__version__}")
    logger.info(f"🎯 Bot is ready and operational!")
    
    # ★ Set up Discord logging channel
    if hasattr(bot, 'discord_log_handler'):
        if await bot.discord_log_handler.setup_channel():
            logger.info("✅ Discord logging channel connected")
        else:
            logger.warning("⚠️ Discord logging channel not available")

@bot.command(name='nyxhelp')
async def nyx_help(ctx):
    """Display available Nyx commands."""
    
    embed = discord.Embed(
        title="🌙 Nyx Commands",
        color=NYX_COLOR
    )
    
    embed.add_field(
        name="Commands",
        value=(
            "`!nyxnotes` - View your points\n"
            "`!leaderboard` - Top users\n"
            "`!prefixgame` - Word game (earn points)\n"
            "`!easywordhunt` - Easy word search (earn points)\n"
            "`!hardwordhunt` - Hard word search (earn points)\n"
            "`!chat` - Private general chat\n"
            "`!endchat` - End chat session\n"
            "`!dmcomfort` - Private support chat\n"
            "`!endcomfort` - End support session\n"
            "`!monday` - Submit your Monday response\n"
            "`!tuesday` - Submit your Tuesday response\n"
            "`!thursday` - Submit your Thursday response\n"
            "`!friday` - Submit your Friday response\n"
            "`!weekend` - Get a new weekend prompt\n"
            "`!weekendsubmit` - Submit your weekend response\n"
        ),
        inline=False
    )
    
    embed.set_footer(text="Bot prefix: !")
    
    await ctx.send(embed=embed)

async def main():
    """Main bot startup function."""
    try:
        logger.info("🚀 Starting Nyx bot...")
        # Load cogs before starting the bot
        logger.info("🔄 Loading cogs...")
        await load_cogs()
        logger.info("✅ All cogs loaded!")
        # Start the bot
        await bot.start(TOKEN)
    except KeyboardInterrupt:
        logger.info("⏹️ Bot shutdown requested")
    except Exception as e:
        logger.error(f"💥 Bot startup failed: {e}")
        logger.error(traceback.format_exc())
    finally:
        logger.info("👋 Bot shutting down...")
        
        # ★ Clean up Discord handler
        if hasattr(bot, 'discord_log_handler'):
            await bot.discord_log_handler.close()
        
        await bot.close()

if __name__ == "__main__":
    asyncio.run(main())