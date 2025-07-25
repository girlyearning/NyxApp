import random
import asyncio
import string
import os
from discord.ext import commands
from utils import create_pikabug_embed

class Scattergories(commands.Cog):
    """Scattergories word game with categories and PikaPoints rewards."""
    
    def __init__(self, bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        
        # Load word list (use words_alpha.txt from root directory)
        word_file = 'words_alpha.txt'
        if os.path.exists(word_file):
            with open(word_file, encoding='utf-8') as f:
                self.words = set(w.strip().upper() for w in f if w.strip())
        else:
            self.words = set()

        # Updated categories as requested
        self.categories = [
            'Animal', 'Activity', 'Food', 'Country', 
            'Profession', 'Color', 'Media', 'Social Trend'
        ]

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name='scattergories')
    async def scattergories(self, ctx):
        """Start a Scattergories game with 8 categories and a random letter."""
        try:
            if not self.words:
                embed = create_pikabug_embed(
                    "❌ Scattergories is not available - word list not loaded properly.",
                    title="🎯 Scattergories Error"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "scattergories", success=False, extra_info="No word list")
                return

            letter = random.choice(string.ascii_uppercase)
            categories = self.categories.copy()

            desc = f"🎯 **Scattergories Challenge!**\n\n"
            desc += f"**Letter:** {letter}\n\n"
            desc += "**Categories:**\n"
            for i, cat in enumerate(categories, start=1):
                desc += f"{i}. {cat}\n"
            desc += f"\n⏰ You have 30 seconds to submit answers!\n"
            desc += f"📝 Format: `!answer <category_number> <word>`\n"
            desc += f"🏆 **Scoring:**\n"
            desc += f"• 10 points for answering all 8 categories\n"
            desc += f"• 5 points for answering fewer categories\n"
            desc += f"• +5 bonus points for each extra word per category"

            embed = create_pikabug_embed(desc, title="🎯 Scattergories")
            embed.color = 0xffcec6
            await ctx.send(embed=embed)

            submissions = {}  # {user_id: {cat_idx: set(words)}}

            def check(m):
                return m.channel == ctx.channel and m.content.startswith('!answer') and not m.author.bot

            end_time = asyncio.get_event_loop().time() + 30
            while True:
                timeout = end_time - asyncio.get_event_loop().time()
                if timeout <= 0:
                    break
                try:
                    msg = await self.bot.wait_for('message', timeout=timeout, check=check)
                except asyncio.TimeoutError:
                    break
                    
                parts = msg.content.split()
                if len(parts) >= 3 and parts[1].isdigit():
                    idx = int(parts[1])
                    word = parts[2].upper()
                    uid = str(msg.author.id)
                    
                    if 1 <= idx <= len(categories) and word.startswith(letter) and word in self.words:
                        submissions.setdefault(uid, {}).setdefault(idx, set()).add(word)
                        await msg.add_reaction('✅')
                        
                        # Give feedback
                        category_name = categories[idx-1]
                        feedback = create_pikabug_embed(
                            f"✅ {msg.author.display_name} submitted **{word}** for {category_name}!",
                            title="Valid Answer"
                        )
                        feedback.color = 0x00ff00
                        await ctx.send(embed=feedback)
                    else:
                        await msg.add_reaction('❌')

            if not submissions:
                embed = create_pikabug_embed(
                    f"⏰ Time's up! No valid submissions for letter **{letter}**.\n\n"
                    f"Try again with `!scattergories`!",
                    title="🎯 No Entries"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "scattergories", success=True, extra_info=f"No submissions for letter {letter}")
                return

            # Calculate scores and determine winners
            storage = self.get_storage_cog()
            scores = {}
            
            for uid, user_submissions in submissions.items():
                categories_answered = len(user_submissions)
                base_points = 10 if categories_answered >= 8 else 5
                
                # Bonus points for extra words (5 points per extra word)
                bonus_points = 0
                for cat_words in user_submissions.values():
                    if len(cat_words) > 1:
                        bonus_points += (len(cat_words) - 1) * 5
                
                total_points = base_points + bonus_points
                scores[uid] = {
                    'categories': categories_answered,
                    'base_points': base_points,
                    'bonus_points': bonus_points,
                    'total_points': total_points
                }

            # Award points and create results
            result_lines = []
            async with storage.points_lock:
                for uid, score_data in scores.items():
                    async def add_points(record):
                        record['points'] += score_data['total_points']
                        record.setdefault('scattergories_submissions', 0)
                        record['scattergories_submissions'] += 1

                    await storage.update_pikapoints(str(ctx.guild.id), uid, add_points)
                    record = await storage.get_user_record(str(ctx.guild.id), uid)

                    member = ctx.guild.get_member(int(uid))
                    name = member.display_name if member else f"User {uid}"
                    
                    result_lines.append(
                        f"**{name}:** {score_data['categories']} categories, "
                        f"{score_data['total_points']} points "
                        f"({score_data['base_points']} base + {score_data['bonus_points']} bonus)"
                    )

            # Find winner(s) by highest score
            max_points = max(score['total_points'] for score in scores.values())
            winners = [uid for uid, score in scores.items() if score['total_points'] == max_points]
            
            winner_names = []
            for uid in winners:
                member = ctx.guild.get_member(int(uid))
                if member:
                    winner_names.append(member.display_name)
            
            winners_str = ', '.join(winner_names)
            result_desc = (
                f"⏰ **Time's up!**\n\n"
                f"🏆 **Winner(s):** {winners_str} with {max_points} points!\n\n"
                f"📊 **Final Scores:**\n" + "\n".join(result_lines) + 
                f"\n\nPlay again with `!scattergories`!"
            )
            
            embed = create_pikabug_embed(result_desc, title="🎯 Scattergories Results")
            embed.color = 0x00ff00
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "scattergories", success=True, extra_info=f"Letter: {letter}, {len(scores)} players")
                for uid in winners:
                    await self.logger.log_points_award(uid, str(ctx.guild.id), scores[uid]['total_points'], "scattergories_win", record["points"])

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Scattergories Error")
                await self.logger.log_command_usage(ctx, "scattergories", success=False)
            await ctx.send("❌ An error occurred during the Scattergories game. Please try again.")

async def setup(bot: commands.Bot):
    await bot.add_cog(Scattergories(bot))