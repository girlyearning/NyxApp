from discord.ext import commands
from utils import create_pikabug_embed
from datetime import datetime, timezone
import random

class Journaling(commands.Cog):
    """Handles journaling prompts, journal entry submissions, and related commands."""
    def __init__(self, bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        self.PROMPT_POINTS = 15

    @property
    def prompt_prompts(self):
        """Get the bot's global prompt_prompts."""
        return getattr(self.bot, 'prompt_prompts', [
            "What's something that made you smile today?",
            "Describe a challenge you overcame recently.",
            "What's a goal you're working towards?",
            "Share a memory that always makes you laugh.",
            "What's something you're grateful for right now?",
            "Describe your ideal day from start to finish.",
            "What's a skill you'd like to learn?",
            "Share something that's been on your mind lately."
        ])

    @property
    def last_prompt_prompt(self):
        """Get the bot's global last_prompt_prompt."""
        return getattr(self.bot, 'last_prompt_prompt', None)

    @last_prompt_prompt.setter
    def last_prompt_prompt(self, value):
        """Set the bot's global last_prompt_prompt."""
        self.bot.last_prompt_prompt = value

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name="prompt")
    async def prompt(self, ctx):
        """Send a random journaling prompt."""
        try:
            choices = self.prompt_prompts.copy()
            if self.last_prompt_prompt in choices:
                choices.remove(self.last_prompt_prompt)
            if not choices:
                choices = self.prompt_prompts.copy()
            prompt = random.choice(choices)
            self.last_prompt_prompt = prompt
            
            embed = create_pikabug_embed(
                f"{prompt}\n\n"
                f"💡 Use `!write [your entry]` to submit your journal entry and earn {self.PROMPT_POINTS} PikaPoints!",
                title="📝 Journaling Prompt"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)
            
            if self.logger is not None:
                await self.logger.log_command_usage(ctx, "prompt", success=True, extra_info=f"Prompt: {prompt[:50]}...")
        except Exception as e:
            if self.logger is not None:
                await self.logger.log_error(e, "Journal Prompt Command Error")
                await self.logger.log_command_usage(ctx, "prompt", success=False)
            await ctx.send("❌ Error sending prompt.")

    @commands.command(name="write")
    async def write(self, ctx, *, entry: str):
        """Submit a journal entry and earn PikaPoints."""
        try:
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            storage = self.get_storage_cog()

            # Save the journal entry
            journal_data = await storage.load_journal_submissions()
            journal_data.setdefault(guild_id, {})
            journal_data[guild_id].setdefault(user_id, [])
            
            journal_entry = {
                "entry": entry,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "display_name": ctx.author.display_name,
                "prompt": getattr(self.bot, 'last_prompt_prompt', None)
            }
            journal_data[guild_id][user_id].append(journal_entry)
            await storage.save_journal_submissions(journal_data)

            # Award points
            async def add_points(record):
                record['points'] += self.PROMPT_POINTS
                record.setdefault('prompt_submissions', 0)
                record['prompt_submissions'] += 1

            async with storage.points_lock:
                await storage.update_pikapoints(guild_id, user_id, add_points)
                record = await storage.get_user_record(guild_id, user_id)

            result_msg = (
                f"📝 Journal Entry Submitted!\n"
                f"✨ You earned {self.PROMPT_POINTS} PikaPoints!\n\n"
                f"• Total Points: {record['points']}\n"
                f"• Journal Entries: {record['prompt_submissions']}\n\n"
                f"Keep reflecting and growing! 🌱"
            )
            embed = create_pikabug_embed(result_msg, title="✅ Journal Entry Saved")
            embed.color = 0x00ff00
            await ctx.send(embed=embed)

            if self.logger is not None:
                await self.logger.log_command_usage(ctx, "write", success=True, extra_info=f"Entry length: {len(entry)} chars")
                await self.logger.log_points_award(user_id, guild_id, self.PROMPT_POINTS, "journal_entry", record["points"])

        except Exception as e:
            if self.logger is not None:
                await self.logger.log_error(e, "Journal Write Command Error")
                await self.logger.log_command_usage(ctx, "write", success=False)
            await ctx.send("❌ Error submitting journal entry. Please try again.")

async def setup(bot: commands.Bot):
    await bot.add_cog(Journaling(bot))