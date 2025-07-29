# Unscramble game for Nyx
import discord
from discord.ext import commands
import random
import aiofiles
import os

NYX_COLOR = 0x76b887
FONT = "monospace"
COMMON_WORDS_FILE = "./common_words.txt"  # Ensure path is correct for your project
ROUNDS_PER_GAME = 3
NYX_NOTES_PER_CORRECT = 5

class UnscrambleGame:
    def __init__(self, channel_id, word_list):
        self.channel_id = channel_id
        self.word_list = word_list
        self.words = []
        self.scrambled = []
        self.current_round = 0
        self.correct_count = 0
        self.active = True
        self.used_words = set()

    def pick_word(self):
        # Pick a random unused word between 5 and 9 letters
        eligible = [w for w in self.word_list if 5 <= len(w) <= 9 and w not in self.used_words]
        if not eligible:
            return None
        word = random.choice(eligible)
        self.used_words.add(word)
        return word

    def scramble_word(self, word):
        chars = list(word)
        while True:
            random.shuffle(chars)
            scrambled = ''.join(chars)
            if scrambled != word:
                return scrambled

class Unscramble(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.active_games = {}  # channel_id: UnscrambleGame instance
        self.word_list = []
        self.memory = None  # Will be set in cog_load

    async def cog_load(self):
        # Load words from common_words.txt on cog load
        self.word_list = await self.load_words()
        # Get Memory cog for points
        self.memory = self.bot.get_cog("Memory")
        if not self.memory:
            raise RuntimeError("Memory cog not loaded - Unscramble requires persistent storage.")

    async def load_words(self):
        words = []
        if not os.path.exists(COMMON_WORDS_FILE):
            raise FileNotFoundError("common_words.txt not found")
        async with aiofiles.open(COMMON_WORDS_FILE, "r") as f:
            async for line in f:
                word = line.strip().lower()
                if 5 <= len(word) <= 9 and word.isalpha():
                    words.append(word)
        return words

    @commands.command(name="unscramble")
    async def start_unscramble(self, ctx):
        channel_id = ctx.channel.id
        if channel_id in self.active_games and self.active_games[channel_id].active:
            await ctx.reply("An unscramble game is already running in this channel. Use `!endunscramble` to end it.", mention_author=False)
            return

        if len(self.word_list) < ROUNDS_PER_GAME:
            await ctx.reply("Not enough words available to start the game.")
            return

        # Start a new game
        game = UnscrambleGame(channel_id, self.word_list)
        self.active_games[channel_id] = game
        await self.next_round(ctx)

    async def next_round(self, ctx):
        channel_id = ctx.channel.id
        game = self.active_games[channel_id]
        if game.current_round >= ROUNDS_PER_GAME:
            await self.end_game(ctx)
            return

        word = game.pick_word()
        if not word:
            await ctx.send("No more eligible words to use. Ending game.")
            await self.end_game(ctx)
            return
        scrambled = game.scramble_word(word)
        game.words.append(word)
        game.scrambled.append(scrambled)
        game.current_word = word
        game.current_scrambled = scrambled
        game.current_round += 1

        embed = discord.Embed(
            title=f"Round {game.current_round}/{ROUNDS_PER_GAME} - Unscramble This Word!",
            description=f"```{scrambled}```",
            color=NYX_COLOR,
        )
        embed.set_footer(text="Type your guess in chat!")
        await ctx.send(embed=embed)

    @commands.command(name="endunscramble")
    async def end_unscramble(self, ctx):
        channel_id = ctx.channel.id
        if channel_id not in self.active_games or not self.active_games[channel_id].active:
            await ctx.reply("No active unscramble game to end in this channel.", mention_author=False)
            return
        await self.end_game(ctx, aborted=True)

    @commands.command(name="hint")
    async def get_hint(self, ctx):
        channel_id = ctx.channel.id
        if channel_id not in self.active_games or not self.active_games[channel_id].active:
            await ctx.reply("No active unscramble game in this channel to get a hint for.", mention_author=False)
            return
        
        game = self.active_games[channel_id]
        if not hasattr(game, "current_word") or not game.current_word:
            await ctx.reply("No current word to give a hint for.", mention_author=False)
            return
        
        word = game.current_word
        if len(word) <= 2:
            hint = word  # For very short words, just show the whole thing
        else:
            hint = word[0] + "_" * (len(word) - 2) + word[-1]
        
        embed = discord.Embed(
            title="💡 Hint",
            description=f"```{hint}```",
            color=NYX_COLOR,
        )
        embed.set_footer(text="The first and last letters are revealed!")
        await ctx.send(embed=embed)

    async def end_game(self, ctx, aborted=False):
        channel_id = ctx.channel.id
        game = self.active_games[channel_id]
        game.active = False
        msg = (
            f"🟢 Game ended by user. You solved {game.correct_count} out of {game.current_round} rounds."
            if aborted
            else f"🏁 Unscramble game complete! You solved {game.correct_count} out of {ROUNDS_PER_GAME} words."
        )
        embed = discord.Embed(
            title="Unscramble Game Over",
            description=msg + f"\n**Total Nyx Notes awarded:** {game.correct_count * NYX_NOTES_PER_CORRECT}",
            color=NYX_COLOR,
        )
        embed.set_footer(text="Thanks for playing!")
        await ctx.send(embed=embed)
        del self.active_games[channel_id]

    @commands.Cog.listener()
    async def on_message(self, message):
        # Only process guesses if a game is active in the channel
        if message.author.bot or not message.guild:
            return

        channel_id = message.channel.id
        if channel_id not in self.active_games:
            return
        game = self.active_games[channel_id]
        if not game.active or not hasattr(game, "current_word"):
            return

        guess = message.content.strip().lower()
        if guess == game.current_word:
            game.correct_count += 1
            user_id = message.author.id
            display_name = message.author.display_name
            # Award Nyx Notes
            if self.memory:
                await self.memory.add_nyx_notes(user_id, NYX_NOTES_PER_CORRECT)
                total_points = await self.memory.get_nyx_notes(user_id)
            else:
                total_points = "N/A"

            embed = discord.Embed(
                title="Correct! 🎉",
                description=(
                    f"**{display_name}** unscrambled the word: ```{game.current_word}```\n"
                    f"**+{NYX_NOTES_PER_CORRECT} Nyx Notes** | Total: {total_points}"
                ),
                color=NYX_COLOR,
            )
            await message.channel.send(embed=embed)
            # Proceed to next round after a brief pause
            ctx = await self.bot.get_context(message)
            await self.next_round(ctx)

    # Ensure Memory cog is referenced on reload
    async def cog_reload(self):
        self.memory = self.bot.get_cog("Memory")

async def setup(bot):
    await bot.add_cog(Unscramble(bot))