import os
import random
import asyncio
from collections import defaultdict
from discord.ext import commands
from utils import create_pikabug_embed

class PrefixGame(commands.Cog):
    """
    Prefix-game word challenge with hint, reveal, and PikaPoints rewards.
    """
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        
        # Load your word list (from root directory, not cogs folder)
        word_file = 'common_words.txt'
        if os.path.exists(word_file):
            with open(word_file, encoding='utf-8') as f:
                words = [w.strip().lower() for w in f if w.strip()]
        else:
            words = []
            
        # Build prefix→words map
        self.prefix_map = defaultdict(list)
        for w in words:
            if len(w) >= 3:
                pref = w[:3]
                self.prefix_map[pref].append(w)
                
        # Keep only prefixes with at least 5 words
        MIN_WORDS_PER_PREFIX = 5
        self.common_prefixes = [
            p for p, lst in self.prefix_map.items()
            if len(lst) >= MIN_WORDS_PER_PREFIX
        ]

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name="prefixgame")
    async def prefixgame(self, ctx):
        """Start a prefix game where players find the longest word with a given prefix."""
        try:
            if not self.common_prefixes:
                embed = create_pikabug_embed(
                    "❌ Prefix game is not available - word list not loaded properly.",
                    title="🧠 Prefix Game Error"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "prefixgame", success=False, extra_info="No word list")
                return
                
            # Pick and announce a prefix
            weights = [len(self.prefix_map[p]) for p in self.common_prefixes]
            current_prefix = random.choices(self.common_prefixes, weights=weights, k=1)[0]
            
            embed = create_pikabug_embed(
                f"🧠 **New round started!**\n\n"
                f"Submit the longest word starting with: **{current_prefix}**\n\n"
                f"⏰ You have 12 seconds to submit words!\n"
                f"🏆 Longest word wins PikaPoints!",
                title="🧠 Prefix Game"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)

            submissions = {}
            game_start = asyncio.get_event_loop().time()
            duration = 12.0

            # Collect submissions until time's up
            while True:
                elapsed = asyncio.get_event_loop().time() - game_start
                remaining = duration - elapsed
                if remaining <= 0:
                    break

                def check(m):
                    if m.channel != ctx.channel or m.author.bot:
                        return False
                    w = m.content.lower().strip()
                    return w.startswith(current_prefix) and len(w) > len(current_prefix)

                try:
                    msg = await self.bot.wait_for('message', timeout=remaining, check=check)
                except asyncio.TimeoutError:
                    break

                user_id = str(msg.author.id)
                word = msg.content.lower().strip()
                prev = submissions.get(user_id)

                if prev is None or len(word) > len(prev):
                    submissions[user_id] = word
                    feedback = create_pikabug_embed(
                        f"✅ {msg.author.display_name} submitted: **{word}** ({len(word)} letters)",
                        title="Word Submitted"
                    )
                    feedback.color = 0x00FF00
                    await ctx.send(embed=feedback)
                elif len(word) == len(prev):
                    feedback = create_pikabug_embed(
                        f"⚠️ {msg.author.display_name} already submitted a word of the same length: **{prev}**",
                        title="Same Length"
                    )
                    feedback.color = 0xFFCEC6
                    await ctx.send(embed=feedback)
                else:
                    feedback = create_pikabug_embed(
                        f"📏 {msg.author.display_name} already submitted a longer word: **{prev}** ({len(prev)} letters)",
                        title="Shorter Word"
                    )
                    feedback.color = 0xFFCEC6
                    await ctx.send(embed=feedback)

            # No valid entries?
            if not submissions:
                embed = create_pikabug_embed(
                    f"⏰ Time's up! No valid entries were submitted for prefix **{current_prefix}**.\n\n"
                    f"Try again with `!prefixgame`!",
                    title="🧠 No Entries"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "prefixgame", success=True, extra_info=f"No submissions for prefix {current_prefix}")
                return

            # Determine winner and award points
            winner_id, winning_word = max(
                submissions.items(),
                key=lambda kv: len(kv[1])
            )
            member = ctx.guild.get_member(int(winner_id))
            name = member.display_name if member else f"User {winner_id}"
            pts = 10 if len(winning_word) >= 8 else 5

            storage = self.get_storage_cog()

            async with storage.points_lock:
                async def add_points(record):
                    record['points'] += pts
                    record.setdefault('prefixgame_submissions', 0)
                    record['prefixgame_submissions'] += 1

                await storage.update_pikapoints(str(ctx.guild.id), winner_id, add_points)
                record = await storage.get_user_record(str(ctx.guild.id), winner_id)

            result = (
                f"🏆 **{name}** wins with **{winning_word}** ({len(winning_word)} letters)!\n"
                f"✨ You earned **{pts}** PikaPoints"
                f"{' (bonus for 8+ letters!)' if pts == 10 else ''}!\n\n"
                f"• Total Points: {record['points']}\n"
                f"• Prefix-game entries: {record['prefixgame_submissions']}\n\n"
                f"Play again with `!prefixgame`!"
            )
            final_embed = create_pikabug_embed(result, title="🎉 Prefix Game Results")
            final_embed.color = 0x00ff00
            await ctx.send(embed=final_embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "prefixgame", success=True, extra_info=f"Winner: {name}, word: {winning_word}")
                await self.logger.log_points_award(winner_id, str(ctx.guild.id), pts, "prefixgame_win", record["points"])

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Prefix Game Error")
                await self.logger.log_command_usage(ctx, "prefixgame", success=False)
            await ctx.send("❌ An error occurred during the prefix game. Please try again.")

async def setup(bot: commands.Bot):
    """Async setup for PrefixGame cog."""
    await bot.add_cog(PrefixGame(bot))