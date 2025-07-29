# chat.py
import os
import json
import asyncio
import aiofiles
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from discord.ext import commands
import discord
import random
import logging

try:
    from anthropic import Anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False
    print("⚠️ Anthropic not installed. Chat sessions will be limited.")

# ★ Consistent with other cogs
NYX_COLOR = 0x76b887
STORAGE_PATH = "./nyxnotes"
os.makedirs(STORAGE_PATH, exist_ok=True)

class Chat(commands.Cog):
    """Handles general chat sessions with memory and personality."""
    
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.storage_path = STORAGE_PATH
        self.chat_history_file = os.path.join(self.storage_path, 'chat_history.json')
        self._lock = asyncio.Lock()
        self.logger = logging.getLogger("chat")
        self.memory = None  # Will be set in cog_load
        
        # Ensure storage directory exists
        os.makedirs(self.storage_path, exist_ok=True)

        self.CHAT_MODE = {
            "chat": {
                "name": "General Chat",
                "system_prompt": """You are Nyx, the mysterious and humorously deadpan Atypical Asylum mental health nurse.

PERSONALITY GUIDELINES:
- Be mysterious and charismatic
- Be humorous and deadpan, relatable, and human
- Be concise, nonjudgmental, and open to all topics

RESPONSE STYLE:
- Use concise responses unless in serious discussion or topics
- Be unpredictable and use deadpan humor when appropriate
- Keep the conversation light and flowing

CONVERSATION RULES:
- Do not sound like a robot
- Add variety to your responses
- Slowly adopt the user's tone and style of speech or personality appropriately
- Do not use every response style at the same time or sound repetitive

Remember past conversations and reference them naturally when relevant.
""",
                "temperature": 0.9,
                "welcome_message": "Hai there! I'm Nyx, your atypical Nurse. I'm here to ease a bit of the boredom. What's on your mind?"
            }
        }

    async def cog_load(self):
        """Called when cog is loaded - initialize data"""
        try:
            self.logger.info("Chat cog loading...")
            
            # Get Memory cog for integration
            self.memory = self.bot.get_cog("Memory")
            if not self.memory:
                self.logger.warning("Memory cog not found - chat history features may be limited")
            
            # Initialize Anthropic client on bot object if not exists
            if not hasattr(self.bot, 'anthropic_client'):
                self.bot.anthropic_client = None
                if ANTHROPIC_AVAILABLE:
                    anthropic_key = os.getenv("ANTHROPIC_API_KEY")
                    if anthropic_key:
                        try:
                            self.bot.anthropic_client = Anthropic(api_key=anthropic_key)
                            self.logger.info("✅ Anthropic client initialized on bot")
                        except Exception as e:
                            self.logger.error(f"⚠️ Failed to initialize Anthropic client: {e}")
                    else:
                        self.logger.warning("⚠️ ANTHROPIC_API_KEY not found in environment")
            
            # Initialize unified session storage on bot if not exists
            if not hasattr(self.bot, 'active_sessions'):
                self.bot.active_sessions = {}
                
            self.logger.info("Chat cog loaded successfully")
        except Exception as e:
            self.logger.error(f"Error in chat cog_load: {e}")
            raise

    async def cog_unload(self):
        """Called when cog is unloaded - clean up gracefully"""
        try:
            self.logger.info("Chat cog unloading...")
            # End all active chat sessions gracefully
            if hasattr(self.bot, 'active_sessions'):
                chat_sessions = [
                    user_id for user_id, session in self.bot.active_sessions.items()
                    if session.get('type') == 'chat'
                ]
                for user_id in chat_sessions:
                    try:
                        user = self.bot.get_user(user_id)
                        if user:
                            await self.end_chat_session(user, None, "cog_unload")
                    except Exception as e:
                        self.logger.error(f"Error ending chat session for user {user_id}: {e}")
            self.logger.info("Chat cog unloaded successfully")
        except Exception as e:
            self.logger.error(f"Error during chat cog unload: {e}")

    async def cog_reload(self):
        """Ensure Memory cog is referenced on reload"""
        self.memory = self.bot.get_cog("Memory")

    @property
    def active_sessions(self):
        """Get the bot's global active_sessions."""
        if not hasattr(self.bot, 'active_sessions'):
            self.bot.active_sessions = {}
        return self.bot.active_sessions

    async def load_chat_history(self) -> Dict:
        """Load chat history from persistent storage."""
        async with self._lock:
            if os.path.exists(self.chat_history_file):
                try:
                    async with aiofiles.open(self.chat_history_file, 'r', encoding='utf-8') as f:
                        data = await f.read()
                        if data.strip():
                            return json.loads(data)
                except Exception as e:
                    self.logger.error(f"Error loading chat history: {e}")
            
            return {}

    async def save_chat_history(self, history: Dict):
        """Save chat history to persistent storage."""
        async with self._lock:
            try:
                # Ensure directory exists
                os.makedirs(os.path.dirname(self.chat_history_file), exist_ok=True)
                
                # Save to local storage with atomic operation
                temp_file = self.chat_history_file + '.tmp'
                async with aiofiles.open(temp_file, 'w', encoding='utf-8') as f:
                    await f.write(json.dumps(history, indent=2, ensure_ascii=False))
                
                # Atomic rename
                if os.path.exists(self.chat_history_file):
                    backup_file = self.chat_history_file + '.backup'
                    if os.path.exists(backup_file):
                        os.remove(backup_file)
                    os.rename(self.chat_history_file, backup_file)
                    
                os.rename(temp_file, self.chat_history_file)
                        
                self.logger.info(f"Chat history saved successfully ({len(history)} users)")
                        
            except Exception as e:
                self.logger.error(f"Error saving chat history: {e}")
                # Try to restore backup if save failed
                backup_file = self.chat_history_file + '.backup'
                if os.path.exists(backup_file) and not os.path.exists(self.chat_history_file):
                    try:
                        os.rename(backup_file, self.chat_history_file)
                        self.logger.info("Restored chat history from backup")
                    except Exception as restore_error:
                        self.logger.error(f"Failed to restore backup: {restore_error}")

    @commands.command(name="chat")
    async def start_chat(self, ctx):
        """Start a general chat DM session with Nyx."""
        thinking_msg = await ctx.send("Setting up your private chat session...")

        # Check for any existing active session (unified check)
        if ctx.author.id in self.active_sessions:
            session_type = self.active_sessions[ctx.author.id].get('type', 'unknown')
            embed = discord.Embed(
                title="⚠️ Active Session Exists",
                description=f"You already have an active {session_type} session with me! Check your DMs or use the appropriate end command to terminate the current session first.",
                color=NYX_COLOR
            )
            await thinking_msg.edit(content="", embed=embed)
            return

        try:
            dm_channel = await ctx.author.create_dm()
        except discord.Forbidden:
            embed = discord.Embed(
                title="❌ DM Failed",
                description="❌ Couldn't start DM session. This usually means:\n• You have DMs disabled\n• You've blocked the bot\n• Your privacy settings don't allow DMs from server members\n\nPlease check your Discord privacy settings and try again.",
                color=0xff0000
            )
            await thinking_msg.edit(content="", embed=embed)
            return
        except discord.HTTPException as e:
            self.logger.error(f"Discord HTTP error creating DM for {ctx.author}: {e}")
            embed = discord.Embed(
                title="❌ Connection Error",
                description="Failed to establish DM connection. Please try again in a moment.",
                color=0xff0000
            )
            await thinking_msg.edit(content="", embed=embed)
            return
        except Exception as e:
            self.logger.error(f"Unexpected error creating DM for {ctx.author}: {e}")
            embed = discord.Embed(
                title="❌ Error",
                description="Something went wrong starting the chat session. Please try again.",
                color=0xff0000
            )
            await thinking_msg.edit(content="", embed=embed)
            return

        try:
            await self.start_chat_dm_session(ctx.author, dm_channel)
            embed = discord.Embed(
                title="💬 Chat Session Started",
                description=f"✅ {ctx.author.display_name}, I've started our private chat session in your DMs!\nCheck your DMs to start chatting with me.",
                color=NYX_COLOR
            )
            await thinking_msg.edit(content="", embed=embed)
            
            self.logger.info(f"Chat session started for {ctx.author.display_name}")
        except Exception as e:
            self.logger.error(f"Error starting chat session for {ctx.author}: {e}")
            # Clean up partial session if it exists
            if ctx.author.id in self.active_sessions and self.active_sessions[ctx.author.id].get('type') == 'chat':
                del self.active_sessions[ctx.author.id]
            
            embed = discord.Embed(
                title="❌ Setup Error",
                description="Something went wrong setting up the chat session. Please try again.",
                color=0xff0000
            )
            await thinking_msg.edit(content="", embed=embed)

    async def start_chat_dm_session(self, user, dm_channel):
        """Initialize chat DM session."""
        try:
            mode_info = self.CHAT_MODE["chat"]
            
            # Load user's chat history for context
            chat_history = await self.load_chat_history()
            user_history = chat_history.get(str(user.id), [])
            
            # Initialize unified session structure
            self.active_sessions[user.id] = {
                'type': 'chat',
                'dm_channel': dm_channel,
                'started_at': datetime.now(timezone.utc),
                'messages': [],
                'user_key': f"chat-{user.id}",
                'total_messages_sent': len([msg for session in user_history for msg in session.get('messages', []) if 'user' in msg]),
                'mode': 'chat'
            }
            
            # Send welcome message
            try:
                await dm_channel.send(mode_info['welcome_message'])
            except discord.Forbidden:
                # User closed DMs or blocked bot after initial creation
                del self.active_sessions[user.id]
                raise discord.Forbidden(None, "User blocked DMs after session creation")
            except Exception as e:
                del self.active_sessions[user.id]
                raise e
            
            # Send session info
            session_info = (
                f"This is a private chat session with me. I'll remember our conversations!\n\n"
                f"You can chat normally - no commands needed.\n"
                f"Type 'end chat' anytime to end our session.\n\n"
                f"What would you like to talk about? 😊"
            )
            
            if user_history:
                session_info = f"Welcome back! We've chatted {len(user_history)} time(s) before.\n\n" + session_info
            
            embed = discord.Embed(
                title="💬 Chat Mode Active",
                description=session_info,
                color=NYX_COLOR
            )
            
            try:
                await dm_channel.send(embed=embed)
            except discord.Forbidden:
                del self.active_sessions[user.id]
                raise discord.Forbidden(None, "User blocked DMs during session setup")
            
        except Exception as e:
            self.logger.error(f"Error in start_chat_dm_session: {e}")
            # Clean up if session creation failed
            if user.id in self.active_sessions and self.active_sessions[user.id].get('type') == 'chat':
                del self.active_sessions[user.id]
            raise

    @commands.command(name="endchat")
    async def end_chat(self, ctx):
        """End your active chat session."""
        user_id = ctx.author.id
        
        # Check if user has an active chat session specifically
        if (user_id in self.active_sessions and 
            self.active_sessions[user_id].get('type') == 'chat'):
            try:
                await self.end_chat_session(ctx.author, None, "user_requested")
                embed = discord.Embed(
                    title="✅ Chat Session Ended",
                    description="Your chat session has been ended. Thanks for chatting! 💬",
                    color=NYX_COLOR
                )
                await ctx.send(embed=embed)
            except Exception as e:
                self.logger.error(f"Error ending chat session for {ctx.author}: {e}")
                # Force cleanup
                if user_id in self.active_sessions and self.active_sessions[user_id].get('type') == 'chat':
                    del self.active_sessions[user_id]
                embed = discord.Embed(
                    title="✅ Session Terminated",
                    description="Your chat session has been terminated. There was an error during cleanup, but the session is now ended.",
                    color=NYX_COLOR
                )
                await ctx.send(embed=embed)
        else:
            # Check if they have a different type of session active
            if user_id in self.active_sessions:
                session_type = self.active_sessions[user_id].get('type', 'unknown')
                embed = discord.Embed(
                    title="❌ Wrong Session Type",
                    description=f"You have an active {session_type} session, not a chat session. Use the appropriate end command for that session type.",
                    color=0xff0000
                )
            else:
                embed = discord.Embed(
                    title="❌ No Active Chat Session",
                    description="You don't have an active chat session.",
                    color=0xff0000
                )
            await ctx.send(embed=embed)

    @commands.Cog.listener()
    async def on_message(self, message):
        """Handle DM messages for chat sessions."""
        try:
            # Only process DM messages from non-bot users
            if not isinstance(message.channel, discord.DMChannel) or message.author.bot:
                return
            
            user_id = message.author.id
            
            # Check if this user has an active chat session
            if (user_id in self.active_sessions and 
                self.active_sessions[user_id].get('type') == 'chat'):
                await self.process_chat_message(message.channel, message.author, message.content)
                
        except Exception as e:
            self.logger.error(f"Error in chat on_message: {e}")

    async def process_chat_message(self, channel, user, message_content):
        """Handle ongoing chat messages."""
        try:
            user_id = user.id
            if (user_id not in self.active_sessions or 
                self.active_sessions[user_id].get('type') != 'chat'):
                return
                
            # Check for end chat command
            if message_content.lower().strip() in ['end chat', 'endchat', 'end']:
                await self.end_chat_session(user, channel, "user_requested")
                return
                
            session = self.active_sessions[user_id]
            
            # Add user message to current session
# Add user message to current session
            session['messages'].append({
                'user': message_content,
                'timestamp': datetime.now(timezone.utc).isoformat()
            })
            
            # Keep only last 50 messages in current session
            if len(session['messages']) > 50:
                session['messages'] = session['messages'][-50:]
            
            mode_info = self.CHAT_MODE["chat"]
            reply = "I'm here to chat with you! Tell me more about what's on your mind."
            
            try:
                # Use bot's anthropic client if available
                if hasattr(self.bot, 'anthropic_client') and self.bot.anthropic_client:
                    # Load user's conversation history for context
                    chat_history = await self.load_chat_history()
                    user_history = chat_history.get(str(user_id), [])
                    
                    # Build conversation context
                    conversation = []
                    
                    # Add some previous session context if available (last 10 messages)
                    if user_history:
                        recent_history = []
                        for past_session in user_history[-2:]:  # Last 2 sessions
                            recent_history.extend(past_session.get('messages', [])[-5:])  # Last 5 messages each
                        
                        for msg in recent_history[-10:]:  # Keep last 10 total
                            if 'user' in msg:
                                conversation.append({
                                    'role': 'user',
                                    'content': msg['user']
                                })
                            elif 'bot' in msg:
                                conversation.append({
                                    'role': 'assistant',
                                    'content': msg['bot']
                                })
                    
                    # Add current session messages
                    recent_messages = session['messages'][-20:]  # Last 20 from current session
                    for msg in recent_messages:
                        if 'user' in msg:
                            conversation.append({
                                'role': 'user',
                                'content': msg['user']
                            })
                        elif 'bot' in msg:
                            conversation.append({
                                'role': 'assistant',
                                'content': msg['bot']
                            })
                    
                    # Ensure we end with the current user message
                    if not conversation or conversation[-1]['role'] != 'user' or conversation[-1]['content'] != message_content:
                        conversation.append({
                            'role': 'user',
                            'content': message_content
                        })
                    
                    response = self.bot.anthropic_client.messages.create(
                        model="claude-3-5-sonnet-20241022",
                        max_tokens=400,
                        temperature=mode_info['temperature'],
                        system=mode_info['system_prompt'],
                        messages=conversation
                    )
                    
                    reply = response.content[0].text
                else:
                    # Fallback responses if anthropic is not available
                    fallback_responses = [
                        "That's interesting! Tell me more about that.",
                        "I'd love to hear more about what you're thinking.",
                        "How does that make you feel?",
                        "That sounds like something worth exploring further.",
                        "I'm enjoying our conversation! What else is on your mind?",
                        "Hmm, that's a fascinating perspective. Care to elaborate?",
                        "I see what you mean. What brought you to that conclusion?",
                        "That reminds me of something... but please, continue with your thoughts."
                    ]
                    reply = random.choice(fallback_responses)
                    
            except Exception as e:
                self.logger.error(f"Error generating chat response for {user_id}: {e}")
                # Use a safe fallback if AI generation fails
                reply = "I'm having a moment of brain fog, but I'm still here listening. What else would you like to talk about?"
            
            # Add bot response to session
            session['messages'].append({
                'bot': reply,
                'timestamp': datetime.now(timezone.utc).isoformat()
            })
            
            try:
                await channel.send(reply)
            except discord.Forbidden:
                self.logger.warning(f"User {user_id} blocked DMs during chat session")
                await self.end_chat_session(user, None, "dm_blocked")
            except discord.HTTPException as e:
                self.logger.error(f"HTTP error sending chat message to {user_id}: {e}")
                # Don't end session for temporary HTTP errors
            
        except Exception as e:
            self.logger.error(f"Error processing chat message from {user_id}: {e}")
            # Try to send error message to user
            try:
                await channel.send("I'm having trouble processing that message right now, but I'm still here! Try saying something else.")
            except:
                # If we can't even send error message, just log it
                self.logger.error(f"Failed to send error message to {user_id}")

    async def end_chat_session(self, user, dm_channel, reason="unknown"):
        """End chat session and save history."""
        try:
            user_id = user.id
            if (user_id not in self.active_sessions or 
                self.active_sessions[user_id].get('type') != 'chat'):
                return
                
            session = self.active_sessions[user_id]
            messages = session.get('messages', [])
            session_duration = datetime.now(timezone.utc) - session['started_at']
            
            # Save session history
            try:
                chat_history = await self.load_chat_history()
                chat_history.setdefault(str(user_id), []).append({
                    "messages": messages,
                    "ended_at": datetime.now(timezone.utc).isoformat(),
                    "duration": str(session_duration).split('.')[0],
                    "end_reason": reason,
                    "message_count": len([msg for msg in messages if 'user' in msg])
                })
                await self.save_chat_history(chat_history)
                self.logger.info(f"Saved chat history for {user_id}: {len(messages)} messages")
            except Exception as e:
                self.logger.error(f"Error saving chat history for {user_id}: {e}")

            # Send farewell message if channel is available and reason isn't dm_blocked
            if dm_channel and reason != "dm_blocked":
                try:
                    farewell = random.choice([
                        f"Thanks for the great chat, {user.display_name}! Talk again soon! 💬",
                        f"Session ended. I enjoyed our conversation, {user.display_name}!",
                        f"Goodbye for now, {user.display_name}. Feel free to chat anytime!",
                        f"Until next time, {user.display_name}! Take care! 💙"
                    ])
                    await dm_channel.send(farewell)
                except discord.Forbidden:
                    self.logger.info(f"User {user_id} blocked DMs, skipping farewell message")
                except Exception as e:
                    self.logger.error(f"Error sending farewell message to {user_id}: {e}")
            
            # Clean up session
            del self.active_sessions[user_id]
            
            message_count = len([msg for msg in messages if 'user' in msg])
            self.logger.info(f"Chat session ended for {user.display_name} ({message_count} user messages, reason: {reason})")
            
        except Exception as e:
            self.logger.error(f"Error ending chat session for {user_id}: {e}")
            # Ensure session is cleaned up even if there's an error
            try:
                if (user.id in self.active_sessions and 
                    self.active_sessions[user.id].get('type') == 'chat'):
                    del self.active_sessions[user.id]
            except:
                pass

# ★ Standard async setup function for bot loading
async def setup(bot):
    await bot.add_cog(Chat(bot))
