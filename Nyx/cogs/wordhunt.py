import os
import random
import discord
from discord.ext import commands
import aiofiles
from typing import List

# ★ Constants – align with Nyx bot style
NYX_COLOR = 0x76b887
FONT = "monospace"
STORAGE_PATH = "./nyxnotes"
WORD_LIST_FILE = os.path.join("common_words.txt")
WORDHUNT_SAVE_FILE = os.path.join(STORAGE_PATH, "wordhunt_results.json")

class WordHunt(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.active_games = {}  # {guild_id: {channel_id: game_data}}
        self.memory = None

    async def cog_load(self):
        self.memory = self.bot.get_cog("Memory")
        if not self.memory:
            raise RuntimeError("Memory cog not loaded for WordHunt.")

    # ★ Utility: Load word list (min_len/max_len inclusive)
    async def load_words(self, min_len: int, max_len: int) -> List[str]:
        async with aiofiles.open(WORD_LIST_FILE, "r") as f:
            lines = await f.readlines()
        return [w.strip().lower() for w in lines if min_len <= len(w.strip()) <= max_len]

    # ★ Utility: Build an empty grid
    def build_grid(self, size: int) -> List[List[str]]:
        return [["." for _ in range(size)] for _ in range(size)]

    # ★ Utility: Directions
    @staticmethod
    def get_directions():
        # (dx, dy)
        return [
            (1, 0),   # right
            (0, 1),   # down
            (1, 1),   # down-right
            (-1, 0),  # left
            (0, -1),  # up
            (-1, -1), # up-left
            (1, -1),  # up-right
            (-1, 1),  # down-left
        ]

    # ★ Utility: Place word into the grid
    def place_word(self, grid, word, used_positions):
        size = len(grid)
        attempts = 60
        directions = self.get_directions()
        for _ in range(attempts):
            dx, dy = random.choice(directions)
            x = random.randint(0, size - 1)
            y = random.randint(0, size - 1)
            end_x = x + dx * (len(word) - 1)
            end_y = y + dy * (len(word) - 1)
            # Bounds check
            if not (0 <= end_x < size and 0 <= end_y < size):
                continue
            # Overlap/fit check
            fits = True
            positions = []
            for i in range(len(word)):
                nx = x + dx * i
                ny = y + dy * i
                c = grid[ny][nx]
                if c != "." and c != word[i]:
                    fits = False
                    break
                positions.append((ny, nx))
            if fits:
                for idx, (ny, nx) in enumerate(positions):
                    grid[ny][nx] = word[idx]
                used_positions[word] = positions
                return True
        return False

    # ★ Utility: Fill grid with random letters
    def fill_grid_randomly(self, grid):
        alphabet = "abcdefghijklmnopqrstuvwxyz"
        for y in range(len(grid)):
            for x in range(len(grid[y])):
                if grid[y][x] == ".":
                    grid[y][x] = random.choice(alphabet)

    # ★ Utility: Format grid for embed
    def format_grid(self, grid):
        # Use monospace, grid lines joined by spaces
        return "```\n" + "\n".join(" ".join(row) for row in grid) + "\n```"

    # ★ Utility: Save finished games to disk
    async def save_wordhunt_result(self, user_id, mode, found_words, success):
        # Save to disk with append mode (basic log, not a database)
        async with aiofiles.open(WORDHUNT_SAVE_FILE, "a") as f:
            line = f"{user_id},{mode},{'|'.join(found_words)},{success}\n"
            await f.write(line)

    # ★ Command: !easywordhunt
    @commands.command(name="easywordhunt")
    async def easy_wordhunt(self, ctx):
        """Start an easy word hunt (5x5, 3 hidden 4-letter words)"""
        # Only allow one active game per channel
        if ctx.channel.id in self.active_games.get(ctx.guild.id, {}):
            await ctx.reply("An Easy Word Hunt is already active in this channel.", mention_author=False)
            return

        words = await self.load_words(4, 4)
        selected = random.sample(words, 3)
        grid_size = 5
        grid = self.build_grid(grid_size)
        used_positions = {}

        # Place words
        for word in selected:
            if not self.place_word(grid, word, used_positions):
                await ctx.reply("Failed to generate a valid board. Please try again.", mention_author=False)
                return

        self.fill_grid_randomly(grid)
        formatted = self.format_grid(grid)
        game_data = {
            "mode": "easy",
            "words": selected,
            "found": [],
            "grid": grid,
            "positions": used_positions,
            "started_by": ctx.author.id
        }
        if ctx.guild.id not in self.active_games:
            self.active_games[ctx.guild.id] = {}
        self.active_games[ctx.guild.id][ctx.channel.id] = game_data

        embed = discord.Embed(
            title="🟩 Easy Word Hunt",
            description=f"Find **3 hidden 4-letter words** in the 5x5 grid!\nType your guesses (one at a time).\nUse `!easyreveal` to reveal the answers (no points).\n\n{formatted}",
            color=NYX_COLOR
        )
        embed.set_footer(text="Font: monospace")
        await ctx.send(embed=embed)

    # ★ Command: !easyreveal
    @commands.command(name="easyreveal")
    async def easy_reveal(self, ctx):
        """Reveal the answers for easy word hunt (forfeits the game)"""
        game = self.active_games.get(ctx.guild.id, {}).get(ctx.channel.id)
        if not game or game["mode"] != "easy":
            await ctx.reply("No active Easy Word Hunt in this channel.", mention_author=False)
            return
        embed = discord.Embed(
            title="🟩 Easy Word Hunt Revealed",
            description=f"Game ended with no winner. The hidden words were:\n- **{'**, **'.join(game['words'])}**",
            color=NYX_COLOR
        )
        await ctx.send(embed=embed)
        await self.save_wordhunt_result(ctx.author.id, "easy", game["words"], False)
        del self.active_games[ctx.guild.id][ctx.channel.id]

    # ★ Command: !hardwordhunt
    @commands.command(name="hardwordhunt")
    async def hard_wordhunt(self, ctx):
        """Start a hard word hunt (9x9, 4 hidden 4-8 letter words)"""
        if ctx.channel.id in self.active_games.get(ctx.guild.id, {}):
            await ctx.reply("A Word Hunt is already active in this channel.", mention_author=False)
            return

        words = await self.load_words(4, 8)
        selected = random.sample(words, 4)
        grid_size = 9
        grid = self.build_grid(grid_size)
        used_positions = {}

        for word in selected:
            if not self.place_word(grid, word, used_positions):
                await ctx.reply("Failed to generate a valid board. Please try again.", mention_author=False)
                return

        self.fill_grid_randomly(grid)
        formatted = self.format_grid(grid)
        game_data = {
            "mode": "hard",
            "words": selected,
            "found": [],
            "grid": grid,
            "positions": used_positions,
            "started_by": ctx.author.id
        }
        if ctx.guild.id not in self.active_games:
            self.active_games[ctx.guild.id] = {}
        self.active_games[ctx.guild.id][ctx.channel.id] = game_data

        embed = discord.Embed(
            title="🟦 Hard Word Hunt",
            description=f"Find **4 hidden words (4-8 letters)** in the 9x9 grid!\nType your guesses (one at a time).\nUse `!hardreveal` to reveal the answers (no points).\n\n{formatted}",
            color=NYX_COLOR
        )
        embed.set_footer(text="Font: monospace")
        await ctx.send(embed=embed)

    # ★ Command: !hardreveal
    @commands.command(name="hardreveal")
    async def hard_reveal(self, ctx):
        """Reveal the answers for hard word hunt (forfeits the game)"""
        game = self.active_games.get(ctx.guild.id, {}).get(ctx.channel.id)
        if not game or game["mode"] != "hard":
            await ctx.reply("No active Hard Word Hunt in this channel.", mention_author=False)
            return
        embed = discord.Embed(
            title="🟦 Hard Word Hunt Revealed",
            description=f"Game ended with no winner. The hidden words were:\n- **{'**, **'.join(game['words'])}**",
            color=NYX_COLOR
        )
        await ctx.send(embed=embed)
        await self.save_wordhunt_result(ctx.author.id, "hard", game["words"], False)
        del self.active_games[ctx.guild.id][ctx.channel.id]

    # ★ Event: Message listener for guesses
    @commands.Cog.listener()
    async def on_message(self, message):
        # Ignore bot/self
        if message.author.bot or not message.guild:
            return
        channel = message.channel
        game = self.active_games.get(message.guild.id, {}).get(channel.id)
        if not game:
            return
        guess = message.content.strip().lower()
        if guess in game["found"]:
            await channel.send(f"Already found **{guess}**.")
            return
        if guess in game["words"]:
            game["found"].append(guess)
            await channel.send(f"✅ Correct! **{guess.upper()}** is one of the hidden words.")
            if len(game["found"]) == len(game["words"]):
                # Award points, finish game
                user_id = message.author.id
                try:
                    await self.memory.add_nyx_notes(user_id, 15)
                    pts = await self.memory.get_nyx_notes(user_id)
                except Exception as e:
                    await channel.send(f"Error awarding Nyx Notes: {e}")
                    pts = "?"
                await self.save_wordhunt_result(user_id, game["mode"], game["found"], True)
                embed = discord.Embed(
                    title="🏆 Word Hunt Complete",
                    description=f"All hidden words found!\nWinner: <@{user_id}>\nWords: **{'**, **'.join(game['words'])}**\n\nYou earned **15 Nyx Notes** (Total: {pts}).",
                    color=NYX_COLOR
                )
                await channel.send(embed=embed)
                del self.active_games[message.guild.id][channel.id]
            return

# ★ Cog setup (async for compatibility with your main file)
async def setup(bot):
    await bot.add_cog(WordHunt(bot))