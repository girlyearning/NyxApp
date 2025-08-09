# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This repository contains multiple Discord bot projects:

### Primary Project: Nyx Bot (`/Nyx/`)

A comprehensive Discord bot focused on mental health support with multiple interactive features:

- **Core file**: `nyxcore.py` - Main bot initialization and core functionality
- **Cogs directory**: `cogs/` - Modular bot functionality
- **Data storage**: `nyxnotes/` - User data and persistent storage
- **Dependencies**: See `requirements.txt`

### Secondary Projects

- **ReplyBot** (`/ReplyBot/`) - Simple utility bot that deletes reply messages in specific channels
- **NyxBackup** (`/NyxBackup/`) - Legacy backup files and previous versions

## Development Commands

### Running Nyx Bot

```bash
cd Nyx
python nyxcore.py
```

### Environment Setup

```bash
cd Nyx
pip install -r requirements.txt
```

### Required Environment Variables

Create `.env` file in the Nyx directory:

```
DISCORD_TOKEN=your_discord_bot_token
ANTHROPIC_API_KEY=your_anthropic_api_key
STORAGE_PATH=./nyxnotes  # Optional, defaults to ./nyxnotes
```

## Nyx Bot Architecture

### Core Systems

**Bot Initialization** (`nyxcore.py`):

- Uses discord.py with minimal intents for efficiency
- Global rate limiting system to prevent API abuse
- Conservative cog loading with delays between loads
- Comprehensive logging to `nyx.log`
- Safe message sending with error handling

**Memory System** (`cogs/memory.py`):

- Manages user points ("Nyx Notes") in JSON storage
- Atomic file operations with backup system
- Thread-safe operations using asyncio locks

**Storage Architecture**:

- All data stored in `STORAGE_PATH` directory (default: `./nyxnotes/`)
- JSON-based persistence for user data
- Backup files created automatically
- File structure:
  - `nyxnotes.json` - User points data
  - `chat_history.json` - Chat session history
  - `comfort_history.json` - Comfort chat history
  - Various game result files

### Cog Architecture

All cogs follow consistent patterns:

- Inherit from `commands.Cog`
- Use shared constants (`NYX_COLOR`, `STORAGE_PATH`)
- Implement `cog_load()` and `cog_unload()` for setup/cleanup
- Use asyncio locks for thread safety
- Consistent error handling and logging

**Available Cogs**:

- `memory.py` - Points system and user data
- `chat.py` - General AI chat with Anthropic Claude
- `comfort.py` - Mental health support chat
- `prefixgame.py` - Word prefix guessing game
- `unscramble.py` - Word unscrambling game
- `wordhunt.py` - Word finding puzzles
- `workshop.py` - Daily creative writing prompts
- `asylumchat.py` - Multi-personality chat system

### Key Design Patterns

**Rate Limiting**:

- Global rate limiter (`GlobalRateLimiter` class) prevents API abuse
- Minimum 2-second intervals between Discord API calls
- Conservative cog loading with 5-second delays

**Error Handling**:

- All API calls wrapped in try-catch blocks
- Silent failures for rate limit errors
- Comprehensive logging for debugging

**Data Persistence**:

- JSON-based storage with atomic operations
- Backup files created before modifications
- Thread-safe file operations using async locks

## Common Development Patterns

### Adding New Cogs

1. Create new `.py` file in `cogs/` directory
2. Follow existing cog patterns (inherit from `commands.Cog`)
3. Use shared constants and storage patterns
4. Add to cog loading list in `nyxcore.py:183`
5. Implement proper `cog_load()` and `cog_unload()` methods

### Working with User Data

- Always use the Memory cog for points/user data
- Use async locks for thread safety
- Create backups before modifying data
- Follow atomic operation patterns

### Bot Commands

- Prefix: `!` (exclamation mark)
- Help command: `!nyxhelp`
- Admin commands available for emergency management
- All commands should use `safe_send_message()` for output

## Dependencies

**Core Dependencies**:

- `discord.py>=2.3.0` - Discord API wrapper
- `python-dotenv>=1.0.0` - Environment variable management
- `anthropic>=0.58.2` - AI chat functionality (optional)
- `aiofiles>=23.0.0` - Async file operations

## File Structure Conventions

```
Nyx/
├── nyxcore.py              # Main bot file
├── requirements.txt        # Python dependencies
├── .env                   # Environment variables (create manually)
├── .gitignore            # Git ignore patterns
├── cogs/                 # Bot functionality modules
│   ├── memory.py         # Points and user data
│   ├── chat.py          # AI chat functionality
│   └── ...              # Other game/feature cogs
├── nyxnotes/            # Data storage directory
│   ├── nyxnotes.json    # User points data
│   └── ...              # Other persistent data files
└── words_alpha.txt      # Word list for games
```

## Important Notes

- The bot uses conservative loading patterns to avoid Discord API rate limits
- All user data is stored locally in JSON files
- The Memory cog must be loaded first as other cogs depend on it
- Use `safe_send_message()` for all Discord message sending
- Bot automatically creates necessary storage directories
- Logging goes to both console and `nyx.log` file
