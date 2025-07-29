import os
import random
import asyncio
import discord
from discord.ext import commands
import aiofiles
import re
import logging
from typing import Dict, Set, Optional

# ★ Consistent color (matches nyxcore.py and memory.py)
NYX_COLOR = 0x76b887
STORAGE_PATH = "./nyxnotes"
os.makedirs(STORAGE_PATH, exist_ok=True)

# ★ File configuration - separate files for different purposes
PREFIXES_FILE = "common_words.txt"  # For generating common prefixes
VALIDATION_FILE = "words_alpha.txt"  # For validating submitted words

class PrefixGame(commands.Cog):
    """
    Cog for the Prefix Word Game in Nyx.
    Players submit words starting with given 3-letter prefixes to earn NyxNotes.
    """
    def __init__(self, bot):
        self.bot = bot
        self.nyx_color = NYX_COLOR
        self.prefix_words_cache: Optional[Set[str]] = None  # Cache for prefix generation
        self.validation_words_cache: Optional[Set[str]] = None  # Cache for word validation
        self.logger = logging.getLogger("PrefixGame")
        self.prefix_file_available = False  # Track if prefix file exists
        self.validation_file_available = False  # Track if validation file exists
        
    async def cog_load(self):
        """Called when cog is loaded - initialize data"""
        try:
            self.logger.info("PrefixGame cog loading...")
            
            # Check if prefix file exists
            if not os.path.exists(PREFIXES_FILE):
                self.logger.warning(f"⚠️ {PREFIXES_FILE} not found")
                self.logger.info("Will use fallback prefixes")
                self.prefix_file_available = False
            else:
                self.logger.info(f"✅ Found prefix file: {PREFIXES_FILE}")
                self.prefix_file_available = True
            
            # Check if validation file exists
            if not os.path.exists(VALIDATION_FILE):
                self.logger.warning(f"⚠️ {VALIDATION_FILE} not found")
                self.logger.info("Will use basic word validation")
                self.validation_file_available = False
            else:
                self.logger.info(f"✅ Found validation file: {VALIDATION_FILE}")
                self.validation_file_available = True
            
            # Create fallback word lists if needed
            if not self.prefix_file_available:
                self.prefix_words_cache = {
                    'the', 'and', 'cat', 'dog', 'run', 'car', 'tree', 'book', 'game', 'play',
                    'house', 'water', 'light', 'music', 'paper', 'phone', 'table', 'chair',
                    'computer', 'keyboard', 'elephant', 'butterfly', 'wonderful', 'beautiful',
                    'telephone', 'basketball', 'incredible', 'extraordinary', 'magnificent'
                }
                
            self.logger.info("PrefixGame cog loaded successfully")
            
        except Exception as e:
            self.logger.error(f"Error in PrefixGame cog_load: {e}")
            raise

    async def cog_unload(self):
        """Called when cog is unloaded - cleanup"""
        try:
            self.logger.info("PrefixGame cog unloading...")
            self.logger.info("PrefixGame cog unloaded successfully")
        except Exception as e:
            self.logger.error(f"Error during PrefixGame cog unload: {e}")

    async def load_prefix_words(self) -> Set[str]:
        """
        Load and cache words for prefix generation.
        
        Returns:
            Set of words to use for generating prefixes
        """
        if self.prefix_words_cache is not None:
            return self.prefix_words_cache
            
        # If prefix file is not available, return the fallback word list
        if not self.prefix_file_available:
            return self.prefix_words_cache or set()
            
        try:
            async with aiofiles.open(PREFIXES_FILE, "r", encoding="utf-8") as f:
                content = await f.read()
                
            # Extract valid words (alphabetic, 3+ characters)
            words = set()
            for line in content.split('\n'):
                word = line.strip().lower()
                if len(word) >= 3 and word.isalpha():
                    words.add(word)
                    
            self.prefix_words_cache = words
            self.logger.info(f"Loaded {len(words)} prefix words from {PREFIXES_FILE}")
            return words
            
        except Exception as e:
            self.logger.error(f"Error loading prefix words: {e}")
            # Return fallback word list on error
            fallback_words = {
                'the', 'and', 'cat', 'dog', 'run', 'car', 'tree', 'book', 'game', 'play',
                'house', 'water', 'light', 'music', 'paper', 'phone', 'table', 'chair',
                'computer', 'keyboard', 'elephant', 'butterfly', 'wonderful', 'beautiful',
                'telephone', 'basketball', 'incredible', 'extraordinary', 'magnificent'
            }
            self.prefix_words_cache = fallback_words
            return fallback_words

    async def load_validation_words(self) -> Set[str]:
        """
        Load and cache words for validation.
        
        Returns:
            Set of valid English words for validation
        """
        if self.validation_words_cache is not None:
            return self.validation_words_cache
            
        # If validation file is not available, return None (will use basic validation)
        if not self.validation_file_available:
            return set()
            
        try:
            async with aiofiles.open(VALIDATION_FILE, "r", encoding="utf-8") as f:
                content = await f.read()
                
            # Extract valid words (alphabetic, 3+ characters)
            words = set()
            for line in content.split('\n'):
                word = line.strip().lower()
                if len(word) >= 3 and word.isalpha():
                    words.add(word)
                    
            self.validation_words_cache = words
            self.logger.info(f"Loaded {len(words)} validation words from {VALIDATION_FILE}")
            return words
            
        except Exception as e:
            self.logger.error(f"Error loading validation words: {e}")
            # Return empty set on error (will use basic validation)
            self.validation_words_cache = set()
            return set()

    async def get_prefixes(self, count: int = 50) -> list:
        """
        Get unique 3-letter prefixes from the prefix word list.
        
        Args:
            count: Number of prefixes to return
            
        Returns:
            List of 3-letter prefixes
        """
        words = await self.load_prefix_words()
        
        # Extract 3-letter prefixes
        prefixes = set()
        for word in words:
            if len(word) >= 3:
                prefix = word[:3]
                if prefix.isalpha():
                    prefixes.add(prefix)
                    
        prefix_list = list(prefixes)
        random.shuffle(prefix_list)
        return prefix_list[:count]

    def is_valid_word(self, word: str, prefix: str) -> bool:
        """
        Check if a word is valid for the game.
        
        Args:
            word: Word to validate
            prefix: Required prefix
            
        Returns:
            True if valid, False otherwise
        """
        if not word or not isinstance(word, str):
            return False
            
        word = word.lower().strip()
        
        # Basic validation
        if len(word) < 3 or not word.isalpha():
            return False
            
        # Must start with prefix
        if not word.startswith(prefix.lower()):
            return False
            
        # Check against validation word list if available
        if self.validation_words_cache is not None and len(self.validation_words_cache) > 0:
            if word not in self.validation_words_cache:
                return False
        # If no validation file, accept any word that passes basic checks
            
        return True

    def calculate_points(self, word: str) -> int:
        """
        Calculate NyxNotes points for a word based on length.
        
        Args:
            word: The submitted word
            
        Returns:
            Points to award (5 or 10)
        """
        return 10 if len(word) >= 8 else 5

    async def start_prefix_game(self, ctx: commands.Context):
        """
        Start the prefix word game in a channel.
        
        Args:
            ctx: Discord command context
        """
        
        try:
            # ★ Load words and get prefixes
            try:
                await self.load_prefix_words()  # Load prefix words
                await self.load_validation_words()  # Load validation words
                prefixes = await self.get_prefixes(10)
            except Exception as e:
                embed = discord.Embed(
                    title="Error",
                    description=f"Failed to load word lists: {str(e)}",
                    color=discord.Color.red()
                )
                await ctx.send(embed=embed)
                return

            if len(prefixes) < 3:
                embed = discord.Embed(
                    title="Error",
                    description="Not enough prefixes available for the game.",
                    color=discord.Color.red()
                )
                await ctx.send(embed=embed)
                return

            # ★ Game announcement
            game_embed = discord.Embed(
                title="🎮 Prefix Word Game Started!",
                description=(
                    "**How to play:**\n"
                    "• I'll give you a 3-letter prefix\n"
                    "• Submit the longest valid English word starting with that prefix\n"
                    "• Words 8+ letters = **10 🪙**\n"
                    "• Words 3-7 letters = **5 🪙**\n"
                    "• Game ends when someone submits the longest word!"
                ),
                color=self.nyx_color
            )
            game_embed.set_footer(text="Get ready! Starting in 3 seconds...")
            await ctx.send(embed=game_embed)
            
            await asyncio.sleep(3)

            # ★ Choose random prefix
            prefix = random.choice(prefixes)
            
            # ★ Announce the round
            round_embed = discord.Embed(
                title="🔤 Find the Longest Word!",
                description=f"**Prefix:** `{prefix.upper()}`\n\nSubmit the **longest valid English word** that starts with this prefix!",
                color=self.nyx_color
            )
            round_embed.add_field(
                name="Scoring",
                value="8+ letters = **10 🪙**\n3-7 letters = **5 🪙**",
                inline=True
            )
            round_embed.add_field(
                name="Game End",
                value="Game ends when the longest word is found!",
                inline=True
            )
            round_embed.set_footer(text="You have 20 seconds to submit your words!")
            await ctx.send(embed=round_embed)

            # ★ Collect responses
            user_words: Dict[int, str] = {}
            longest_word = ""
            longest_user_id = None
            total_points_awarded = 0  # Track total points given out during game
            
            def check(msg):
                # Only messages in same channel, from real users, not bots
                # Allow multiple submissions per user (they can improve their word)
                if (msg.channel != ctx.channel or 
                    msg.author.bot):
                    return False
                
                word = msg.content.strip().lower()
                return self.is_valid_word(word, prefix)

            # ★ Game loop - collect words for exactly 20 seconds
            timeout_duration = 20  # 20 seconds to submit words
            
            try:
                # Wait for the full 20 seconds, collecting all valid submissions
                end_time = asyncio.get_event_loop().time() + timeout_duration
                
                while asyncio.get_event_loop().time() < end_time:
                    remaining_time = end_time - asyncio.get_event_loop().time()
                    if remaining_time <= 0:
                        break
                        
                    try:
                        # Wait for next valid word (but only for remaining time)
                        msg = await self.bot.wait_for('message', timeout=remaining_time, check=check)
                        word = msg.content.strip().lower()
                        user_id = msg.author.id
                        
                        # Store the word for this user (overwrites previous if they submit multiple)
                        user_words[user_id] = word
                        
                        # Update longest word tracking
                        if len(word) > len(longest_word):
                            longest_word = word
                            longest_user_id = user_id
                            
                            # React to show word was accepted as new longest
                            try:
                                await msg.add_reaction("✅")
                            except:
                                pass
                        else:
                            # React to show word was valid but not longest
                            try:
                                await msg.add_reaction("👍")
                            except:
                                pass
                            
                            # Award 5 NyxNotes for valid non-longest words
                            memory_cog = self.bot.get_cog("Memory")
                            if memory_cog:
                                try:
                                    await memory_cog.add_nyx_notes(user_id, 5)
                                    total_points_awarded += 5
                                except Exception as e:
                                    self.logger.warning(f"Failed to award NyxNotes to {user_id}: {e}")
                                
                    except asyncio.TimeoutError:
                        # Time ran out, exit the loop
                        break
                        
            except Exception as e:
                # Handle any errors during word collection
                self.logger.error(f"Error during word collection: {e}")
                    
            # ★ Game ended - announce results
            if not longest_word:
                embed = discord.Embed(
                    title="Game Ended",
                    description="No valid words were submitted. Better luck next time!",
                    color=self.nyx_color
                )
                await ctx.send(embed=embed)
                return

            # ★ Get winner and calculate points
            winner_name = "Unknown User"
            try:
                # Try to get member from guild first
                winner = ctx.guild.get_member(longest_user_id)
                if winner:
                    winner_name = winner.display_name
                else:
                    # Try fetching from Discord API
                    try:
                        winner = await ctx.guild.fetch_member(longest_user_id)
                        winner_name = winner.display_name
                    except discord.NotFound:
                        # User not in guild, try to get user object
                        try:
                            user = await self.bot.fetch_user(longest_user_id)
                            winner_name = user.display_name or user.name
                        except:
                            winner_name = "Unknown User"
                    except:
                        winner_name = "Unknown User"
            except Exception as e:
                self.logger.warning(f"Failed to get winner name for {longest_user_id}: {e}")
                winner_name = "Unknown User"
                
            points_awarded = self.calculate_points(longest_word)
            
            # ★ Award NyxNotes via Memory cog
            memory_cog = self.bot.get_cog("Memory")
            if memory_cog:
                try:
                    new_total = await memory_cog.add_nyx_notes(longest_user_id, points_awarded)
                    total_points_awarded += points_awarded  # Add longest word points to total
                    points_text = f"**{points_awarded} 🪙** awarded!\nNew total: **{new_total:,} 🪙**"
                except Exception as e:
                    points_text = f"**{points_awarded} 🪙** (failed to save: {e})"
            else:
                points_text = f"**{points_awarded} 🪙** (Memory cog not loaded)"

            # ★ Create results embed
            results_embed = discord.Embed(
                title="🏆 Game Complete!",
                color=self.nyx_color
            )
            
            results_embed.add_field(
                name="Winner",
                value=f"**{winner_name}**",
                inline=True
            )
            
            results_embed.add_field(
                name="Winning Word",
                value=f"`{longest_word.upper()}` ({len(longest_word)} letters)",
                inline=True
            )
            
            results_embed.add_field(
                name="Nyx Notes Earned",
                value=points_text,
                inline=False
            )
            
            # Show total points awarded to all players
            if total_points_awarded > points_awarded:
                other_points = total_points_awarded - points_awarded
                results_embed.add_field(
                    name="Total Game Rewards",
                    value=f"**{total_points_awarded} 🪙** awarded to all players\n({other_points} 🪙 for other valid words)",
                    inline=False
                )
            
            # Show other submissions if any
            if len(user_words) > 1:
                other_words = []
                for uid, word in user_words.items():
                    if uid != longest_user_id:
                        user_name = "Unknown User"
                        try:
                            # Try to get member from guild first
                            user = ctx.guild.get_member(uid)
                            if user:
                                user_name = user.display_name
                            else:
                                # Try fetching from Discord API
                                try:
                                    user = await ctx.guild.fetch_member(uid)
                                    user_name = user.display_name
                                except discord.NotFound:
                                    # User not in guild, try to get user object
                                    try:
                                        user = await self.bot.fetch_user(uid)
                                        user_name = user.display_name or user.name
                                    except:
                                        user_name = "Unknown User"
                                except:
                                    user_name = "Unknown User"
                        except Exception as e:
                            self.logger.warning(f"Failed to get user name for {uid}: {e}")
                            user_name = "Unknown User"
                        other_words.append(f"**{user_name}:** {word} ({len(word)})")
                
                if other_words:
                    results_embed.add_field(
                        name="Other Submissions",
                        value="\n".join(other_words[:5]),  # Limit to 5 to avoid embed limits
                        inline=False
                    )
            
            results_embed.set_footer(text=f"Prefix: {prefix.upper()} • Total players: {len(user_words)}")
            await ctx.send(embed=results_embed)
            
        except Exception as e:
            # Handle any unexpected errors
            error_embed = discord.Embed(
                title="Game Error",
                description=f"An error occurred during the game: {str(e)}",
                color=discord.Color.red()
            )
            await ctx.send(embed=error_embed)
            

    # ★ Command to start the game
    @commands.command(name='prefixgame', aliases=['pg', 'wordgame'])
    async def prefixgame_command(self, ctx: commands.Context):
        """Start the Prefix Word Game - find the longest word with the given prefix!"""
        await self.start_prefix_game(ctx)

    @commands.command(name='wordcheck', hidden=True)
    async def word_check(self, ctx: commands.Context, word: str, prefix: str = None):
        """Check if a word is valid (for testing purposes)"""
        if not prefix:
            if len(word) >= 3:
                prefix = word[:3]
            else:
                await ctx.send("Word too short or no prefix provided.")
                return
        
        try:
            # Ensure word lists are loaded
            await self.load_prefix_words()
            await self.load_validation_words()
                
            word_lower = word.lower()
            is_valid = self.is_valid_word(word, prefix)
            points = self.calculate_points(word) if is_valid else 0
            
            embed = discord.Embed(
                title="Word Check",
                color=self.nyx_color if is_valid else discord.Color.red()
            )
            embed.add_field(name="Word", value=word, inline=True)
            embed.add_field(name="Prefix", value=prefix, inline=True)
            embed.add_field(name="Valid", value="✅ Yes" if is_valid else "❌ No", inline=True)
            embed.add_field(name="Length", value=f"{len(word)} letters", inline=True)
            embed.add_field(name="Nyx Notes", value=f"{points} 🪙" if is_valid else "0 🪙", inline=True)
            
            # Show which dictionary was used
            if self.validation_words_cache and len(self.validation_words_cache) > 0:
                in_dict = word_lower in self.validation_words_cache
                embed.add_field(name="In Validation Dictionary", value="✅ Yes" if in_dict else "❌ No", inline=True)
                embed.add_field(name="Dictionary Info", value=f"Using {VALIDATION_FILE} ({len(self.validation_words_cache):,} words)", inline=False)
            else:
                embed.add_field(name="Validation Mode", value="Basic validation (no dictionary)", inline=False)
            
            await ctx.send(embed=embed)
            
        except Exception as e:
            await ctx.send(f"Error checking word: {e}")


# ★ Standard async setup for cog loader
async def setup(bot):
    await bot.add_cog(PrefixGame(bot))