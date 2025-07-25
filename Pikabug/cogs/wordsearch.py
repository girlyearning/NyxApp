import discord
import random
import string
import os
import re
from collections import deque
from discord.ext import commands
from utils import create_pikabug_embed

WORDSEARCH_POINTS = 10
EASY_WORDSEARCH_POINTS = 5

def load_wordsearch_words():
    """Load words from the root directory common_words.txt file."""
    path = 'common_words.txt'  # Load from root directory
    words = []
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            for w in f:
                w = w.strip().lower()
                if len(w) in (4, 5, 6) and w.isalpha():
                    words.append(w)
    else:
        # Fallback words if file doesn't exist
        words = [
            'word', 'game', 'play', 'test', 'love', 'hope',
            'words', 'games', 'plays', 'tests', 'loves', 'hopes',
            'worded', 'gaming', 'played', 'tested', 'loving', 'hoping'
        ]
    
    return (
        [w for w in words if len(w) == 4],
        [w for w in words if len(w) == 5],
        [w for w in words if len(w) == 6],
    )

class EasyWordSearchGame:
    """Easy word search: 6x6 grid with 2 four-letter words, all directions including backwards."""
    DIRECTIONS = [
        (0, 1),   # horizontal right
        (1, 0),   # vertical down
        (1, 1),   # diagonal down-right
        (-1, 1),  # diagonal up-right
        (0, -1),  # horizontal left (backwards)
        (-1, 0),  # vertical up (backwards)
        (-1, -1), # diagonal up-left (backwards)
        (1, -1)   # diagonal down-left (backwards)
    ]
    
    def __init__(self, word1, word2):
        self.size = 6
        self.grid = [['' for _ in range(self.size)] for _ in range(self.size)]
        self.words = [word1.lower(), word2.lower()]
        self.found_words = set()
        self._place_words()
        self._fill_grid()
    
    def _can_place_word(self, word, row, col, dr, dc):
        """Check if word can be placed at given position and direction."""
        for i, char in enumerate(word):
            new_row = row + i * dr
            new_col = col + i * dc
            if not (0 <= new_row < self.size and 0 <= new_col < self.size):
                return False
            cell = self.grid[new_row][new_col]
            if cell and cell != char.upper():
                return False
        return True
    
    def _place_words(self):
        """Place words in the grid with overlap allowed."""
        for word in self.words:
            word = word.upper()
            placed = False
            attempts = 0
            while not placed and attempts < 300:
                dr, dc = random.choice(self.DIRECTIONS)
                start_row = random.randrange(self.size)
                start_col = random.randrange(self.size)
                if self._can_place_word(word, start_row, start_col, dr, dc):
                    r, c = start_row, start_col
                    for ch in word:
                        self.grid[r][c] = ch
                        r += dr
                        c += dc
                    placed = True
                attempts += 1
            
            # Fallback placement if random placement fails
            if not placed:
                row = self.words.index(word.lower())
                for i, ch in enumerate(word):
                    if i < self.size:
                        self.grid[row][i] = ch
    
    def _fill_grid(self):
        """Fill empty cells with random letters."""
        letters = string.ascii_uppercase
        for r in range(self.size):
            for c in range(self.size):
                if not self.grid[r][c]:
                    self.grid[r][c] = random.choice(letters)
    
    def check_word(self, word: str) -> bool:
        """Check if the guessed word is correct and not already found."""
        word = word.lower()
        if word in self.words and word not in self.found_words:
            self.found_words.add(word)
            return True
        return False
    
    def is_complete(self) -> bool:
        """Check if all words have been found."""
        return len(self.found_words) == len(self.words)
    
    def get_grid_as_string(self) -> str:
        """Return grid as formatted string."""
        lines = [' '.join(row) for row in self.grid]
        return "```\n" + "\n".join(lines) + "\n```"

class HardWordSearchGame:
    """Hard word search: 8x8 grid with 3 words (4, 5, 6 letters), limited directions."""
    DIRECTIONS = [(0, 1), (1, 0), (1, 1), (-1, 1)]
    
    def __init__(self, four, five, six):
        self.size = 8
        self.grid = [['' for _ in range(self.size)] for _ in range(self.size)]
        self.words = [four.lower(), five.lower(), six.lower()]
        self.found_words = set()
        self._place_words()
        self._fill_grid()
    
    def _can_place_word(self, word, row, col, dr, dc):
        """Check if word can be placed at given position and direction."""
        for char in word:
            if not (0 <= row < self.size and 0 <= col < self.size):
                return False
            cell = self.grid[row][col]
            if cell and cell != char.upper():
                return False
            row += dr
            col += dc
        return True
    
    def _place_words(self):
        """Place words in the grid."""
        for word in self.words:
            word = word.upper()
            placed = False
            attempts = 0
            while not placed and attempts < 200:
                dr, dc = random.choice(self.DIRECTIONS)
                start_row = random.randrange(self.size)
                start_col = random.randrange(self.size)
                if self._can_place_word(word, start_row, start_col, dr, dc):
                    r, c = start_row, start_col
                    for ch in word:
                        self.grid[r][c] = ch
                        r += dr
                        c += dc
                    placed = True
                attempts += 1
            
            # Fallback placement if random placement fails
            if not placed:
                row = self.words.index(word.lower())
                for i, ch in enumerate(word):
                    if i < self.size:
                        self.grid[row][i] = ch
    
    def _fill_grid(self):
        """Fill empty cells with random letters."""
        letters = string.ascii_uppercase
        for r in range(self.size):
            for c in range(self.size):
                if not self.grid[r][c]:
                    self.grid[r][c] = random.choice(letters)
    
    def check_word(self, word: str) -> bool:
        """Check if the guessed word is correct and not already found."""
        word = word.lower()
        if word in self.words and word not in self.found_words:
            self.found_words.add(word)
            return True
        return False
    
    def is_complete(self) -> bool:
        """Check if all words have been found."""
        return len(self.found_words) == len(self.words)
    
    def get_grid_as_string(self) -> str:
        """Return grid as formatted string."""
        lines = [' '.join(row) for row in self.grid]
        return "```\n" + "\n".join(lines) + "\n```"

class WordSearch(commands.Cog):
    """Cog for Word Search game commands and guess handling."""
    
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        
        # Load word lists with error handling
        try:
            self.four_letter_words, self.five_letter_words, self.six_letter_words = load_wordsearch_words()
            if not self.four_letter_words:
                raise ValueError("No four-letter words loaded")
        except Exception as e:
            if self.logger:
                print(f"Error loading word lists: {e}")
            # Fallback word lists
            self.four_letter_words = ['word', 'game', 'play', 'test', 'love', 'hope']
            self.five_letter_words = ['words', 'games', 'plays', 'tests', 'loves', 'hopes']
            self.six_letter_words = ['worded', 'gaming', 'played', 'tested', 'loving', 'hoping']
        
        self.active_games = {}
        self.word_history = deque(maxlen=50)

    def get_storage_cog(self):
        """Get the storage cog for points management."""
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name='easywordsearch')
    async def easy_wordsearch(self, ctx: commands.Context):
        """Start a new easy word search (6x6 grid, 2 four-letter words, all directions)."""
        try:
            if ctx.author.id in self.active_games:
                embed = create_pikabug_embed(
                    "❌ You already have an active word search! Use `!endwordsearch` to end it first.",
                    title="Game Already Active"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "easywordsearch", success=False, extra_info="Game already active")
                return

            # Select words avoiding recent history
            available_words = [w for w in self.four_letter_words if w not in self.word_history] or self.four_letter_words
            
            if len(available_words) < 2:
                available_words = self.four_letter_words
            
            selected_words = random.sample(available_words, 2)
            self.word_history.extend(selected_words)

            game = EasyWordSearchGame(selected_words[0], selected_words[1])
            self.active_games[ctx.author.id] = {
                'game': game,
                'type': 'easy',
                'started_by': ctx.author.display_name
            }

            info = (
                f"🔍 **Easy Word Search Started!**\n"
                f"Find **2 four-letter words** hidden in this 6×6 grid.\n"
                f"Words can be placed in **any direction** (including backwards and diagonally)!\n\n"
                f"{game.get_grid_as_string()}\n"
                f"💡 **How to play:**\n"
                f"• Type your guesses separated by spaces or commas\n"
                f"• Example: `word game` or `word,game`\n"
                f"• Earn **{EASY_WORDSEARCH_POINTS} PikaPoints** when you find both words!\n"
                f"• Use `!endwordsearch` to give up and see the answers"
            )
            embed = create_pikabug_embed(info, title="🔍 Easy Word Search")
            embed.color = 0x90EE90
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "easywordsearch", success=True, extra_info=f"Words: {', '.join(selected_words)}")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Easy WordSearch Command Error")
                await self.logger.log_command_usage(ctx, "easywordsearch", success=False)
            await ctx.send("❌ Error starting easy word search. Please try again.")

    @commands.command(name='hardwordsearch')
    async def hard_wordsearch(self, ctx: commands.Context):
        """Start a new hard word search (8x8 grid, 3 words of different lengths)."""
        try:
            if ctx.author.id in self.active_games:
                embed = create_pikabug_embed(
                    "❌ You already have an active word search! Use `!endwordsearch` to end it first.",
                    title="Game Already Active"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "hardwordsearch", success=False, extra_info="Game already active")
                return

            # Select words avoiding recent history
            avail4 = [w for w in self.four_letter_words if w not in self.word_history] or self.four_letter_words
            avail5 = [w for w in self.five_letter_words if w not in self.word_history] or self.five_letter_words
            avail6 = [w for w in self.six_letter_words if w not in self.word_history] or self.six_letter_words

            sel4 = random.choice(avail4)
            sel5 = random.choice(avail5)
            sel6 = random.choice(avail6)
            self.word_history.extend([sel4, sel5, sel6])

            game = HardWordSearchGame(sel4, sel5, sel6)
            self.active_games[ctx.author.id] = {
                'game': game,
                'type': 'hard',
                'started_by': ctx.author.display_name
            }

            info = (
                f"🔍 **Hard Word Search Started!**\n"
                f"Find **3 hidden words** (lengths 4, 5, 6) in this 8×8 grid.\n"
                f"Words are placed horizontally, vertically, or diagonally (forward only).\n\n"
                f"{game.get_grid_as_string()}\n"
                f"💡 **How to play:**\n"
                f"• Type your guesses separated by spaces or commas\n"
                f"• Example: `cat fish apple` or `cat,fish,apple`\n"
                f"• Earn **{WORDSEARCH_POINTS} PikaPoints** when you find all words!\n"
                f"• Use `!endwordsearch` to give up and see the answers"
            )
            embed = create_pikabug_embed(info, title="🔍 Hard Word Search")
            embed.color = 0xffcec6
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "hardwordsearch", success=True, extra_info=f"Words: {sel4}, {sel5}, {sel6}")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Hard WordSearch Command Error")
                await self.logger.log_command_usage(ctx, "hardwordsearch", success=False)
            await ctx.send("❌ Error starting hard word search. Please try again.")

    @commands.command(name='endwordsearch')
    async def end_wordsearch(self, ctx: commands.Context):
        """End your current word search and reveal words."""
        try:
            uid = ctx.author.id
            if uid in self.active_games:
                game_data = self.active_games.pop(uid)
                game = game_data['game']
                game_type = game_data['type']
                
                embed = create_pikabug_embed(
                    f"🛑 **{game_type.title()} Word Search Ended**\n\n"
                    f"The hidden words were: **{', '.join(game.words)}**\n"
                    f"You found: {', '.join(game.found_words) if game.found_words else 'None'}\n\n"
                    f"Better luck next time! Try `!{game_type}wordsearch` again.",
                    title="Word Search Ended"
                )
                embed.color = 0xFFA500
                await ctx.send(embed=embed)
                
                if self.logger:
                    await self.logger.log_command_usage(ctx, "endwordsearch", success=True, extra_info=f"Type: {game_type}, Found: {len(game.found_words)}/{len(game.words)}")
            else:
                embed = create_pikabug_embed(
                    "❌ You don't have an active word search game.\n"
                    "Start one with `!easywordsearch` or `!hardwordsearch`!",
                    title="No Active Game"
                )
                await ctx.send(embed=embed)
                
                if self.logger:
                    await self.logger.log_command_usage(ctx, "endwordsearch", success=False, extra_info="No active game")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "End WordSearch Command Error")
                await self.logger.log_command_usage(ctx, "endwordsearch", success=False)
            await ctx.send("❌ Error ending word search. Please try again.")

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        """Handle word search guesses."""
        if message.author.bot or not message.guild:
            return

        uid = message.author.id
        if uid not in self.active_games:
            return

        if message.content.startswith('!'):
            return

        try:
            game_data = self.active_games[uid]
            game = game_data['game']
            game_type = game_data['type']
            
            # Parse guesses
            guesses = [w.strip().lower() for w in re.split(r'[\s,]+', message.content) if w.strip()]

            found_any = False
            for guess in guesses:
                if len(guess) >= 4 and guess.isalpha():
                    if game.check_word(guess):
                        found_any = True
                        embed = create_pikabug_embed(
                            f"✅ **Found it!** You discovered **{guess.upper()}**!\n"
                            f"Words found: {len(game.found_words)}/{len(game.words)}",
                            title="🎉 Word Found!"
                        )
                        embed.color = 0x00ff00
                        await message.channel.send(embed=embed)

                        # Check if game is complete
                        if game.is_complete():
                            points = WORDSEARCH_POINTS if game_type == 'hard' else EASY_WORDSEARCH_POINTS
                            
                            storage = self.get_storage_cog()
                            async with storage.points_lock:
                                guild_id = str(message.guild.id)
                                user_id = str(uid)
                                
                                async def add_points(record):
                                    record['points'] += points
                                    record.setdefault(f'{game_type}_wordsearch_completions', 0)
                                    record[f'{game_type}_wordsearch_completions'] += 1
                                
                                await storage.update_pikapoints(guild_id, user_id, add_points)
                                record = await storage.get_user_record(guild_id, user_id)

                            completion_msg = (
                                f"🎉 **{game_type.title()} Word Search Complete!**\n\n"
                                f"**All words found:** {', '.join(game.words)}\n"
                                f"🏆 You earned **{points} PikaPoints**!\n\n"
                                f"📊 **Your Stats:**\n"
                                f"• Total Points: {record['points']}\n"
                                f"• {game_type.title()} Word Searches: {record[f'{game_type}_wordsearch_completions']}"
                            )
                            embed = create_pikabug_embed(completion_msg, title="🎉 Congratulations!")
                            embed.color = 0xFFD700
                            await message.channel.send(embed=embed)
                            
                            if self.logger:
                                await self.logger.log_points_award(user_id, guild_id, points, f"{game_type}_wordsearch_completion", record["points"])
                            
                            del self.active_games[uid]
                            return

            # Handle incorrect guesses
            if not found_any and guesses:
                valid_guesses = [g for g in guesses if len(g) >= 4 and g.isalpha()]
                if valid_guesses:
                    embed = create_pikabug_embed(
                        f"❌ **Not found:** {', '.join(valid_guesses)}\n"
                        f"Keep looking! Words found: {len(game.found_words)}/{len(game.words)}",
                        title="🔍 Keep Searching"
                    )
                    embed.color = 0xFF6B6B
                    await message.channel.send(embed=embed)

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "WordSearch Message Handler Error")

async def setup(bot: commands.Bot):
    await bot.add_cog(WordSearch(bot))