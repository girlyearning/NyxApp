# This module provides only utility/logging helpers and NEVER handles persistent storage.
import datetime
import discord
import traceback
from datetime import timezone

def create_pikabug_embed(content: str, title: str = "") -> discord.Embed:
    pikabug_color = 0xffcec6
    embed = discord.Embed(
        description=f"```\n{content}\n```",
        color=pikabug_color
    )
    if title:
        embed.title = title
    return embed

class DiscordLogger:
    def __init__(self, bot):
        self.bot = bot
        self.log_channel = None
        
    async def initialize(self):
        """Initialize the log channel after bot is ready."""
        # LOG_CHANNEL_ID should be imported or set in pika_bot.py, not utils.py.
        if hasattr(self.bot, "LOG_CHANNEL_ID") and self.bot.LOG_CHANNEL_ID:
            try:
                self.log_channel = self.bot.get_channel(self.bot.LOG_CHANNEL_ID)
                if not self.log_channel:
                    print(f"Warning: Could not find log channel with ID {self.bot.LOG_CHANNEL_ID}")
            except Exception as e:
                print(f"Error initializing log channel: {e}")

    async def log_command_usage(self, ctx, command_name, success=True, extra_info=""):
        embed = discord.Embed(
            title=f"Command: {command_name}",
            color=0x00ff00 if success else 0xff0000,
            timestamp=datetime.datetime.now(timezone.utc)
        )
        embed.add_field(name="User", value=f"{ctx.author.display_name} ({ctx.author.id})", inline=True)
        embed.add_field(name="Guild", value=f"{ctx.guild.name} ({ctx.guild.id})", inline=True)
        embed.add_field(name="Channel", value=f"#{ctx.channel.name} ({ctx.channel.id})", inline=True)
        if extra_info:
            embed.add_field(name="Details", value=extra_info[:1024], inline=False)
        await self._send_log(embed)

    async def log_error(self, error, context="General Error", extra_details=""):
        """Log errors with full traceback."""
        embed = discord.Embed(
            title="🚨 ERROR OCCURRED",
            color=0xff0000,
            timestamp=datetime.datetime.now(timezone.utc)
        )
        embed.add_field(name="Context", value=context, inline=True)
        embed.add_field(name="Error Type", value=type(error).__name__, inline=True)
        embed.add_field(name="Error Message", value=str(error)[:1024], inline=False)

        if extra_details:
            embed.add_field(name="Extra Details", value=extra_details[:1024], inline=False)

        tb = traceback.format_exc()
        if len(tb) > 1024:
            tb = tb[-1024:]  # Keep last 1024 chars of traceback
        embed.add_field(name="Traceback", value=f"```python\n{tb}\n```", inline=False)

        await self._send_log(embed)
    
    async def log_ai_usage(self, user_id, guild_id, prompt_length, response_length, success=True):
        """Log AI command usage."""
        embed = discord.Embed(
            title="🤖 AI Command Usage",
            color=0x9932cc,
            timestamp=datetime.datetime.now(timezone.utc)
        )
        embed.add_field(name="User ID", value=str(user_id), inline=True)
        embed.add_field(name="Guild ID", value=str(guild_id), inline=True)
        embed.add_field(name="Prompt Length", value=f"{prompt_length} chars", inline=True)
        embed.add_field(name="Response Length", value=f"{response_length} chars", inline=True)
        embed.add_field(name="Success", value="✅" if success else "❌", inline=True)

        await self._send_log(embed)
    
    async def log_bot_event(self, event_type, message):
        """Log general bot events."""
        embed = discord.Embed(
            title=f"🔔 Bot Event: {event_type}",
            color=0x808080,
            timestamp=datetime.datetime.now(timezone.utc)
        )
        embed.add_field(name="Message", value=message[:1024], inline=False)
        await self._send_log(embed)
    
    async def _send_log(self, embed):
        """Internal method to send log to Discord channel."""
        if self.log_channel:
            try:
                await self.log_channel.send(embed=embed)
            except Exception as e:
                print(f"Failed to send log to Discord: {e}")

    async def log_points_award(self, user_id, guild_id, points, reason, total_points):
        """Log points awards."""
        embed = discord.Embed(
            title="💰 Points Awarded",
            color=0xffd700,
            timestamp=datetime.datetime.now(timezone.utc)
        )
        embed.add_field(name="User ID", value=str(user_id), inline=True)
        embed.add_field(name="Guild ID", value=str(guild_id), inline=True)
        embed.add_field(name="Points Awarded", value=str(points), inline=True)
        embed.add_field(name="Reason", value=reason, inline=True)
        embed.add_field(name="Total Points", value=str(total_points), inline=True)
        await self._send_log(embed)

async def setup(bot):
    """Setup for utils.py to attach DiscordLogger to the bot if not present."""
    if not hasattr(bot, "logger") or bot.logger is None:
        bot.logger = DiscordLogger(bot)
