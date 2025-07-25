from discord.ext import commands
import random
import os
from utils import create_pikabug_embed

class Unscramble(commands.Cog):
    """Unscramble word game with 3-round sessions and PikaPoints rewards."""
    
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        
        # Load English word list (use common_words.txt from root directory)
        word_file = 'common_words.txt'
        if os.path.exists(word_file):
            with open(word_file, encoding='utf-8') as f:
                self.words = [w.strip().lower() for w in f if 5 <= len(w.strip()) <= 7]
        else:
            self.words = []
            
        # Active sessions: channel_id -> session dict
        self.sessions: dict[int, dict] = {}
        self.UNSCRAMBLE_POINTS = 10  # Points per correct word
        self.ROUND_BONUS = 5  # Bonus for completing all 3 rounds

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    def _get_scrambled_word(self, word):
        """Generate a scrambled version of the word."""
        # Keep scrambling until we get a different arrangement
        scrambled = word
        attempts = 0
        while scrambled == word and attempts < 10:
            scrambled = ''.join(random.sample(word, len(word)))
            attempts += 1
        return scrambled

    @commands.command(name='unscramble')
    async def start(self, ctx: commands.Context):
        """Begin a new 3-round unscramble challenge."""
        try:
            if ctx.guild is None:
                embed = create_pikabug_embed(
                    "This command can only be used in a server.", 
                    title="❗️ Server Only"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "unscramble", success=False, extra_info="DM attempt")
                return

            if not self.words:
                embed = create_pikabug_embed(
                    "❌ Unscramble game is not available - word list not loaded properly.",
                    title="🧠 Unscramble Error"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "unscramble", success=False, extra_info="No word list")
                return

            # Check if there's already an active session
            if ctx.channel.id in self.sessions:
                session = self.sessions[ctx.channel.id]
                embed = create_pikabug_embed(
                    f"🧠 **Round {session['current_round']}/3 in progress!**\n\n"
                    f"Current word: **{session['current_scrambled'].upper()}**\n"
                    f"Completed: {session['completed_rounds']}/3 rounds\n\n"
                    f"Use `!guess <word>` to submit your answer!",
                    title="🧠 Unscramble in Progress"
                )
                embed.color = 0xffcec6
                await ctx.send(embed=embed)
                return

            # Start new 3-round session
            words_for_session = random.sample(self.words, 3)
            first_word = words_for_session[0]
            first_scrambled = self._get_scrambled_word(first_word)
            
            self.sessions[ctx.channel.id] = {
                'words': words_for_session,
                'current_round': 1,
                'completed_rounds': 0,
                'current_word': first_word,
                'current_scrambled': first_scrambled,
                'revealed': {0, len(first_word) - 1},
                'hints_used': 0,
                'player_scores': {},  # user_id -> score
                'started_by': ctx.author.id
            }
            
            embed = create_pikabug_embed(
                f"🧠 **3-Round Unscramble Challenge Started!**\n\n"
                f"**Round 1/3**\n"
                f"Unscramble this word: **{first_scrambled.upper()}**\n\n"
                f"📝 Use `!guess <word>` to submit your answer\n"
                f"💡 Use `!hint` for a letter hint\n"
                f"🔍 Use `!reveal` to give up and see the answer\n\n"
                f"🏆 **Scoring:**\n"
                f"• {self.UNSCRAMBLE_POINTS} points per correct word\n"
                f"• +{self.ROUND_BONUS} bonus for completing all 3 rounds",
                title="🧠 Unscramble Challenge"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "unscramble", success=True, extra_info="Started 3-round session")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Unscramble Start Error")
                await self.logger.log_command_usage(ctx, "unscramble", success=False)
            await ctx.send("❌ An error occurred while starting the unscramble game. Please try again.")

    @commands.command(name='guess')
    async def guess(self, ctx: commands.Context, *, user_guess: str):
        """Submit your guess for the current unscramble challenge."""
        try:
            if ctx.guild is None:
                embed = create_pikabug_embed(
                    "This command can only be used in a server.", 
                    title="❗️ Server Only"
                )
                await ctx.send(embed=embed)
                return

            session = self.sessions.get(ctx.channel.id)
            if not session:
                embed = create_pikabug_embed(
                    "❗️ No unscramble game is running. Start one with `!unscramble`.",
                    title="🧠 No Active Game"
                )
                await ctx.send(embed=embed)
                return

            user_id = str(ctx.author.id)
            current_word = session['current_word']
            
            if user_guess.lower().strip() == current_word:
                # Correct answer!
                session['completed_rounds'] += 1
                
                # Track player score
                if user_id not in session['player_scores']:
                    session['player_scores'][user_id] = 0
                session['player_scores'][user_id] += self.UNSCRAMBLE_POINTS

                # Award points immediately
                storage = self.get_storage_cog()
                async with storage.points_lock:
                    async def add_points(record):
                        record['points'] += self.UNSCRAMBLE_POINTS
                        record.setdefault('unscramble_submissions', 0)
                        record['unscramble_submissions'] += 1

                    await storage.update_pikapoints(str(ctx.guild.id), user_id, add_points)
                    record = await storage.get_user_record(str(ctx.guild.id), user_id)

                # Check if this was the final round
                if session['completed_rounds'] >= 3:
                    # Game complete! Award bonus points
                    bonus_awarded = False
                    if user_id in session['player_scores'] and session['player_scores'][user_id] >= self.UNSCRAMBLE_POINTS * 3:
                        # Player got all 3 words correct, award bonus
                        async with storage.points_lock:
                            async def add_bonus(record):
                                record['points'] += self.ROUND_BONUS

                            await storage.update_pikapoints(str(ctx.guild.id), user_id, add_bonus)
                            record = await storage.get_user_record(str(ctx.guild.id), user_id)
                            bonus_awarded = True

                    embed = create_pikabug_embed(
                        f"🎉 **FINAL ROUND COMPLETE!**\n\n"
                        f"✅ **{current_word.upper()}** is correct!\n"
                        f"🏆 {ctx.author.display_name} earned {self.UNSCRAMBLE_POINTS} points!\n"
                        f"{'🌟 +' + str(self.ROUND_BONUS) + ' BONUS for completing all 3 rounds!' if bonus_awarded else ''}\n\n"
                        f"📊 **Final Stats:**\n"
                        f"• Total Points: {record['points']}\n"
                        f"• Unscramble Games: {record['unscramble_submissions']}\n\n"
                        f"🎮 Start a new game with `!unscramble`!",
                        title="🎉 Challenge Complete!"
                    )
                    embed.color = 0x00ff00
                    await ctx.send(embed=embed)

                    # Clean up session
                    del self.sessions[ctx.channel.id]

                    if self.logger:
                        await self.logger.log_command_usage(ctx, "guess", success=True, extra_info="Completed 3-round session")
                        await self.logger.log_points_award(user_id, str(ctx.guild.id), 
                                                         self.UNSCRAMBLE_POINTS + (self.ROUND_BONUS if bonus_awarded else 0), 
                                                         "unscramble_complete", record["points"])
                else:
                    # Move to next round
                    next_round = session['completed_rounds'] + 1
                    session['current_round'] = next_round
                    next_word = session['words'][next_round - 1]
                    next_scrambled = self._get_scrambled_word(next_word)
                    
                    session['current_word'] = next_word
                    session['current_scrambled'] = next_scrambled
                    session['revealed'] = {0, len(next_word) - 1}
                    session['hints_used'] = 0

                    embed = create_pikabug_embed(
                        f"✅ **{current_word.upper()}** is correct!\n"
                        f"🏆 {ctx.author.display_name} earned {self.UNSCRAMBLE_POINTS} points!\n\n"
                        f"🧠 **Round {next_round}/3**\n"
                        f"Next word: **{next_scrambled.upper()}**\n\n"
                        f"• Total Points: {record['points']}\n"
                        f"• Session Progress: {session['completed_rounds']}/3 completed",
                        title="✅ Correct! Next Round"
                    )
                    embed.color = 0x00ff00
                    await ctx.send(embed=embed)

                    if self.logger:
                        await self.logger.log_command_usage(ctx, "guess", success=True, extra_info=f"Round {session['completed_rounds']}/3")
                        await self.logger.log_points_award(user_id, str(ctx.guild.id), self.UNSCRAMBLE_POINTS, "unscramble_word", record["points"])

            else:
                # Incorrect guess
                embed = create_pikabug_embed(
                    f"❌ **{user_guess}** is not correct.\n\n"
                    f"Current word: **{session['current_scrambled'].upper()}**\n"
                    f"Round: {session['current_round']}/3\n\n"
                    f"Try again, or use `!hint` for help!",
                    title="❌ Incorrect Guess"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Unscramble Guess Error")
                await self.logger.log_command_usage(ctx, "guess", success=False)
            await ctx.send("❌ An error occurred while processing your guess. Please try again.")

    @commands.command(name='hint')
    async def hint(self, ctx: commands.Context):
        """Reveal an additional letter as a hint."""
        try:
            if ctx.guild is None:
                embed = create_pikabug_embed(
                    "This command can only be used in a server.", 
                    title="❗️ Server Only"
                )
                await ctx.send(embed=embed)
                return

            session = self.sessions.get(ctx.channel.id)
            if not session:
                embed = create_pikabug_embed(
                    "❗️ No unscramble game is active. Start one with `!unscramble`.",
                    title="🧠 No Active Game"
                )
                await ctx.send(embed=embed)
                return

            session['hints_used'] += 1
            answer = session['current_word']
            
            # Reveal more letters based on number of hints used
            if session['hints_used'] > 1:
                candidates = [i for i in range(1, len(answer) - 1) if i not in session['revealed']]
                if candidates:
                    session['revealed'].add(random.choice(candidates))
            
            display = ' '.join(
                answer[i].upper() if i in session['revealed'] else '_'
                for i in range(len(answer))
            )
            
            embed = create_pikabug_embed(
                f"💡 **Hint #{session['hints_used']}**\n\n"
                f"Pattern: {display}\n"
                f"Scrambled: **{session['current_scrambled'].upper()}**\n"
                f"Round: {session['current_round']}/3\n\n"
                f"Keep trying with `!guess <word>`!",
                title="💡 Hint"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "hint", success=True, extra_info=f"Hint #{session['hints_used']}")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Unscramble Hint Error")
                await self.logger.log_command_usage(ctx, "hint", success=False)
            await ctx.send("❌ An error occurred while providing a hint. Please try again.")

    @commands.command(name='reveal')
    async def reveal(self, ctx: commands.Context):
        """Reveal the current word and move to next round (no points for current word)."""
        try:
            if ctx.guild is None:
                embed = create_pikabug_embed(
                    "This command can only be used in a server.", 
                    title="❗️ Server Only"
                )
                await ctx.send(embed=embed)
                return

            session = self.sessions.get(ctx.channel.id)
            if not session:
                embed = create_pikabug_embed(
                    "❗️ No word to reveal. Start a game with `!unscramble`.",
                    title="🧠 No Active Game"
                )
                await ctx.send(embed=embed)
                return

            current_word = session['current_word']
            current_round = session['current_round']
            
            if current_round >= 3:
                # This was the final round
                embed = create_pikabug_embed(
                    f"🕵️ **Word Revealed:** {current_word.upper()}\n\n"
                    f"🎮 **3-Round Challenge Complete!**\n"
                    f"No points awarded for this word.\n\n"
                    f"Start a new challenge with `!unscramble`!",
                    title="🕵️ Final Word Revealed"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)
                
                # Clean up session
                del self.sessions[ctx.channel.id]
            else:
                # Move to next round
                next_round = current_round + 1
                session['current_round'] = next_round
                next_word = session['words'][next_round - 1]
                next_scrambled = self._get_scrambled_word(next_word)
                
                session['current_word'] = next_word
                session['current_scrambled'] = next_scrambled
                session['revealed'] = {0, len(next_word) - 1}
                session['hints_used'] = 0

                embed = create_pikabug_embed(
                    f"🕵️ **Word Revealed:** {current_word.upper()}\n"
                    f"No points awarded for this word.\n\n"
                    f"🧠 **Round {next_round}/3**\n"
                    f"Next word: **{next_scrambled.upper()}**\n\n"
                    f"Try again with `!guess <word>`!",
                    title="🕵️ Word Revealed - Next Round"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "reveal", success=True, extra_info=f"Round {current_round}/3")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Unscramble Reveal Error")
                await self.logger.log_command_usage(ctx, "reveal", success=False)
            await ctx.send("❌ An error occurred while revealing the word. Please try again.")

async def setup(bot: commands.Bot):
    """Async setup for Unscramble cog."""
    await bot.add_cog(Unscramble(bot))