import os
import asyncio
import json
from discord.ext import commands
from collections import deque

# Persistent storage paths - use local data directory, not system root
DISK_PATH = os.getenv("PIKA_DISK_MOUNT_PATH", "data")
PIKA_FILE = os.path.join(DISK_PATH, "pikapoints.json")
WORKSHOP_SUBMISSIONS_FILE = os.path.join(DISK_PATH, "workshop_submissions.json")
USER_MEMORY_FILE = os.path.join(DISK_PATH, "user_memories.json")
COMFORT_HISTORY_FILE = os.path.join(DISK_PATH, "comfort_history.json")
VENT_SUBMISSIONS_FILE = os.path.join(DISK_PATH, "vent_submissions.json")
JOURNAL_SUBMISSIONS_FILE = os.path.join(DISK_PATH, "journal_submissions.json")


class Storage(commands.Cog):
    """
    Cog for managing all persistent storage:
    - PikaPoints data
    - Workshop submissions
    - User memories
    - DM comfort history
    - Venting submissions
    - Journal entries
    """
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.points_lock = asyncio.Lock()
        self.active_wordsearch_games = {}
        self.wordsearch_word_history = deque(maxlen=50)
        # Initialize word lists - call sync version during init
        self.four_letter_words, self.five_letter_words, self.six_letter_words = self._load_wordsearch_words_sync()

    # Core JSON helpers - these should NOT be async since they're simple file operations
    def _load_json(self, path: str):
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                json.dump({}, f)
        with open(path, "r") as f:
            return json.load(f)

    def _save_json(self, path: str, data: dict):
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())

    # PikaPoints management
    async def load_pikapoints(self):
        return self._load_json(PIKA_FILE)

    async def get_user_record(self, guild_id: str, user_id: str) -> dict:
        data = await self.load_pikapoints()  # Fix: await the async call

        # Safely create missing structure
        if guild_id not in data:
            data[guild_id] = {}
        if user_id not in data[guild_id]:
            data[guild_id][user_id] = {"points": 0}  # Fix: provide default points

        return data[guild_id][user_id]

    async def update_pikapoints(self, guild_id: str, user_id: str, update_fn):
        async with self.points_lock:
            data = await self.load_pikapoints()  # Fix: await the async call
            guild = data.setdefault(str(guild_id), {})
            record = guild.setdefault(str(user_id), {"points": 0})
            await update_fn(record)
            await self.save_pikapoints(data)  # Fix: await the async call

    async def save_pikapoints(self, data=None):
        if data is None:
            data = await self.load_pikapoints()  # Fix: await the async call
        self._save_json(PIKA_FILE, data)  # Use helper method

    # Workshop submissions storage
    async def load_workshop_submissions(self):
        """Load all workshop submissions from disk."""
        return self._load_json(WORKSHOP_SUBMISSIONS_FILE)

    async def save_workshop_submissions(self, data: dict):
        """Save all workshop submissions to disk."""
        self._save_json(WORKSHOP_SUBMISSIONS_FILE, data)

    # --- User Memory ---
    async def load_user_memory(self, guild_id: str, user_id: str):
        """Load specific user's memory data - lazy loading"""
        path = USER_MEMORY_FILE
        if not os.path.exists(path):
            return {"memories": [], "facts": [], "mood_history": [], "last_interaction": None}
        
        with open(path, "r") as f:
            all_memories = json.load(f)
        
        if guild_id not in all_memories:
            return {"memories": [], "facts": [], "mood_history": [], "last_interaction": None}
        if user_id not in all_memories[guild_id]:
            return {"memories": [], "facts": [], "mood_history": [], "last_interaction": None}
        
        return all_memories[guild_id][user_id]

    async def save_user_memory(self, guild_id: str, user_id: str, memory_data: dict):
        """Save specific user's memory data"""
        path = USER_MEMORY_FILE
        if not os.path.exists(path):
            all_memories = {}
        else:
            with open(path, "r") as f:
                all_memories = json.load(f)
        
        if guild_id not in all_memories:
            all_memories[guild_id] = {}
        all_memories[guild_id][user_id] = memory_data
        
        self._save_json(path, all_memories)

    # --- Comfort History ---
    async def load_comfort_history(self):
        """Load comfort conversation history from disk"""
        return self._load_json(COMFORT_HISTORY_FILE)

    async def save_comfort_history(self, data):
        """Save comfort conversation history to disk"""
        self._save_json(COMFORT_HISTORY_FILE, data)

    async def load_vent_submissions(self):
        """Load all vent submissions from disk."""
        return self._load_json(VENT_SUBMISSIONS_FILE)

    async def save_vent_submissions(self, data: dict):
        """Save all vent submissions to disk."""
        self._save_json(VENT_SUBMISSIONS_FILE, data)

    # Journal entries
    async def load_journal_submissions(self):
        """Load all journal submissions from disk."""
        return self._load_json(JOURNAL_SUBMISSIONS_FILE)

    async def save_journal_submissions(self, data: dict):
        """Save all journal submissions to disk."""
        self._save_json(JOURNAL_SUBMISSIONS_FILE, data)

    # Word Search Organization - sync version for __init__
    def _load_wordsearch_words_sync(self):
        """Load 4-6 letter words for word search from file (sync version for init)."""
        try:
            with open("common_words.txt") as f:
                words = [w.strip().lower() for w in f if w.strip()]
                four_letter_words = [w for w in words if len(w) == 4]
                five_letter_words = [w for w in words if len(w) == 5]
                six_letter_words = [w for w in words if len(w) == 6]
            return four_letter_words, five_letter_words, six_letter_words
        except FileNotFoundError:
            # Provide fallback words if file doesn't exist
            return (
                ["word", "game", "play", "test"],
                ["words", "games", "plays", "tests"],
                ["worded", "gamed", "played", "tested"]
            )

    async def load_wordsearch_words(self):
        """Load 4-6 letter words for word search from file (async version)."""
        return self._load_wordsearch_words_sync()

    async def get_wordsearch_words(self):
        """Get tuple of 4, 5, 6 letter words for wordsearch use."""
        return self.four_letter_words, self.five_letter_words, self.six_letter_words

    async def add_wordsearch_history(self, word):
        """Append a word to the wordsearch history."""
        self.wordsearch_word_history.append(word)

    async def get_wordsearch_history(self):
        """Return a list of the last 50 wordsearch words used."""
        return list(self.wordsearch_word_history)

async def setup(bot):
    await bot.add_cog(Storage(bot))