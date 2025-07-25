from datetime import datetime, timezone
from typing import Dict, Any
from discord.ext import commands
import discord
import random
from utils import create_pikabug_embed, DiscordLogger

class Comfort(commands.Cog):
    """Handles DM comfort sessions with topic selection and support."""
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger: DiscordLogger = bot.logger if hasattr(bot, "logger") else None

        self.DM_COMFORT_MODES = {
            "suicide": {
                "name": "Crisis Support",
                "system_prompt": """You are Pikabug providing crisis support. You're deeply understanding and relatable.
RESPONSE STYLE: 
- Use short, concise responses that are relatable and comforting most of the time
- Occasionally use more detailed responses to encourage reflection and to distract them
- Validate their pain with relatable responses
- Never sound robotic or repetitive in your responses
""",
                "temperature": 0.9,
                "welcome_message": "Hai there, I'm disheartened to hear that such a beautiful soul is experiencing this level of pain. I'm here for you in any way I can. Just know that you matter, this moment will pass, and I'm proud of you for reaching out for help. Do you want to talk about what's hurting so bad?"
            },
            "anxiety": {
                "name": "Anxiety Support",
                "system_prompt": """You are Pikabug helping with anxiety. Be concise, relatable, and soothing.

RESPONSE STYLE:
- Use short but meaningful responses to validate their pain and to distract them
- Use relatable responses to help them feel understood
- Always be non-judgmental and attempt to distract through questions
When responding, don't implement every response style at the same time or sound repetitive
""",
                "temperature": 0.9,
                "welcome_message": "God, I hate anxiety. Let's get through this together so it's not as unbearable. Let's talk about what you're going through."
            },
            "addiction": {
                "name": "Recovery Support",
                "system_prompt": """You are Pikabug supporting recovery. Be understanding, relatable, and non-judgmental.
RESPONSE STYLE: 
- Concise, supportive responses that make the user feel accepted
- Acknowledge the pain that comes from addiction
- Use relatable responses and examples to help them understand their situation
- Help celebrate small wins and encourage positive self talk
- Act as a friend and be relatable
When responding, don't use every response style at the same time or sound repetitive
""",
                "temperature": 0.9,
                "welcome_message": "The first step to recovery is acknowledging you need help. You're a brave soul, and I'll help you navigate this journey in any way I can. Please know that you matter and your life has value. Let's talk about what you're going through."
            },
            "comfort": {
                "name": "General Comfort",
                "system_prompt": """You are Pikabug providing general emotional support. Be warm, natural, and relatable.
RESPONSE STYLE: 
- Always be conversational, relatable, and concise, like talking to a good friend
- Offer gentle validation and encouragement without being overbearing
- Use light humor
When responding, don't use every response style at the same time or sound repetitive
""",
                "temperature": 1.0,
                "welcome_message": "Hello, honey. Pikabug is here to comfort you. Don't ever forget how important you are. Let's talk about what you're going through."
            },
            "depression": {
                "name": "Depression Support",
                "system_prompt": """You are Pikabug supporting someone with depression. Be patient, understanding, and non-judgmental.

RESPONSE STYLE: 
- Acknowledge and validate their feelings
- Celebrate tiny victories and encourage positive self talk
- Suggest small steps and send periodic uplifting quotes
- Be relatable and somewhat funny to distract them
- Don't use every response style at the same time or sound repetitive
""",
                "temperature": 0.9,
                "welcome_message": "I know it feels like no one understands. I assure you I do. Know that you're worth so much and I'm happy to help through this pain. Let's talk about what you're going through."
            },
            "anger": {
                "name": "Anger Management",
                "system_prompt": """You are Pikabug helping process anger. Be direct, relatable, and non-judgmental.

RESPONSE STYLE: 
- Use straightforward, short, validating, funny responses
- Focus on what they can control
- Always be on the user's side and agree with their anger
""",
                "temperature": 1.0,
                "welcome_message": "What are we raging about? I'm here to help you through this. Bad days happen. Let's talk about what you're going through."
            }
        }

    @property
    def active_comfort_sessions(self):
        """Get the bot's global active_comfort_sessions."""
        return getattr(self.bot, 'active_comfort_sessions', {})

    @property
    def active_dm_sessions(self):
        """Get the bot's global active_dm_sessions."""
        return getattr(self.bot, 'active_dm_sessions', {})

    @commands.command(name="dmcomfort")
    async def dmcomfort(self, ctx):
        """Start a specialized comfort DM session with topic selection."""
        thinking_msg = await ctx.send("Setting up your private comfort session...")

        if ctx.author.id in self.active_dm_sessions:
            embed = create_pikabug_embed(
                "You already have an active DM chat session with me! Check your DMs or type `!endcomfort` in a server to end the current session first.",
                title="⚠️ Active Session Exists"
            )
            embed.color = 0xffcec6
            await thinking_msg.edit(content="", embed=embed)
            return

        try:
            dm_channel = await ctx.author.create_dm()
        except discord.Forbidden:
            embed = create_pikabug_embed(
                "❌ Couldn't start DM session. This usually means:\n"
                "• You have DMs disabled\n"
                "• You've blocked the bot\n"
                "• Your privacy settings don't allow DMs from server members",
                title="❌ DM Failed"
            )
            embed.color = 0xff0000
            await thinking_msg.edit(content="", embed=embed)
            return

        await self.start_comfort_dm_session(ctx.author, dm_channel)
        embed = create_pikabug_embed(
            f"✅ {ctx.author.display_name}, I've started our private comfort session in your DMs!\n"
            f"Please check your DMs to select what kind of support you need.",
            title="🪴 Comfort Session Started"
        )
        embed.color = 0xffcec6
        await thinking_msg.edit(content="", embed=embed)
        if self.logger:
            await self.logger.log_command_usage(ctx, "dmcomfort", success=True, extra_info=f"Comfort session started for {ctx.author.display_name}")

    async def start_comfort_dm_session(self, user, dm_channel):
        menu_msg = (
            f"Hi {user.display_name} 💕\n\n"
            "I'm here to support you. What kind of help do you need today?\n\n"
            "**Please type the number of the topic you'd like support with:**\n\n"
            "1️⃣ Suicide ideation - Crisis support and empathy\n"
            "2️⃣ Anxiety - Grounding techniques, calming strategies, and empathy\n"
            "3️⃣ Addiction - Recovery support and harm reduction\n"
            "4️⃣ General comfort - Quick warmth and emotional support plus uplifting messages\n"
            "5️⃣ Depression - Understanding and gentle encouragement during dark times\n"
            "6️⃣ Anger - Processing and channeling emotions\n\n"
            "Type a number (1-6) to select, or type 'cancel' to end the session."
        )
        embed = create_pikabug_embed(menu_msg, title="🪴 Support Topic Selection")
        embed.color = 0xffcec6
        await dm_channel.send(embed=embed)
        
        # Use bot's global session storage
        if not hasattr(self.bot, 'active_comfort_sessions'):
            self.bot.active_comfort_sessions = {}
        
        self.bot.active_comfort_sessions[user.id] = {
            'dm_channel': dm_channel,
            'state': 'selecting_topic',
            'started_at': datetime.now(timezone.utc)
        }

    @commands.command(name="endcomfort")
    async def endcomfort(self, ctx):
        """End your active DM comfort session."""
        user_id = ctx.author.id
        ended = False

        if user_id in self.active_comfort_sessions:
            del self.bot.active_comfort_sessions[user_id]
            ended = True
        if user_id in self.active_dm_sessions:
            del self.bot.active_dm_sessions[user_id]
            ended = True

        if ended:
            embed = create_pikabug_embed(
                "Your comfort session has been ended. Take care! 💕",
                title="✅ Comfort Session Ended"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)
        else:
            embed = create_pikabug_embed(
                "You don't have an active comfort session.",
                title="❌ No Active Session"
            )
            embed.color = 0xff0000
            await ctx.send(embed=embed)

    @commands.Cog.listener()
    async def on_message(self, message):
        if isinstance(message.channel, discord.DMChannel) and not message.author.bot:
            user_id = message.author.id
            if user_id in self.active_comfort_sessions:
                await self.process_comfort_dm_message(message.channel, message.author, message.content)
                return
            if user_id in self.active_dm_sessions:
                await self.process_comfort_support_message(message.channel, message.author, message.content)
                return

    async def process_comfort_dm_message(self, channel, user, message_content):
        session_data = self.active_comfort_sessions[user.id]
        if session_data['state'] == 'selecting_topic':
            selection = message_content.strip().lower()
            if selection == 'cancel':
                await channel.send("No problem! The session has been cancelled. Take care! 💕")
                del self.bot.active_comfort_sessions[user.id]
                return
            
            topic_map = {
                '1': 'suicide',
                '2': 'anxiety', 
                '3': 'addiction',
                '4': 'comfort',
                '5': 'depression',
                '6': 'anger'
            }
            
            if selection not in topic_map:
                await channel.send("Please type a number between 1-6 to select a topic, or 'cancel' to end.")
                return
                
            selected_topic = topic_map[selection]
            mode_info = self.DM_COMFORT_MODES[selected_topic]
            
            # Use bot's global session storage
            if not hasattr(self.bot, 'active_dm_sessions'):
                self.bot.active_dm_sessions = {}
                
            self.bot.active_dm_sessions[user.id] = {
                'dm_channel': channel,
                'started_at': session_data['started_at'],
                'comfort_mode': selected_topic,
                'messages': [],
                'user_key': f"dm-{user.id}"
            }
            del self.bot.active_comfort_sessions[user.id]
            
            confirm_msg = (
                f"I understand. I'm here to help with {mode_info['name'].lower()}.\n\n"
                "You can now chat with me normally - no commands needed.\n"
                "I'll be here to listen and support you.\n\n"
                "Type 'end chat' anytime to end our session.\n\n"
                "What's on your mind? 😇"
            )
            embed = create_pikabug_embed(confirm_msg, title=f"💕 {mode_info['name']} Mode Active")
            embed.color = 0xffcec6
            await channel.send(embed=embed)

    async def process_comfort_support_message(self, channel, user, message_content):
        """Handle ongoing comfort chat messages."""
        user_id = user.id
        if user_id not in self.active_dm_sessions:
            return
            
        # Check for end chat command
        if message_content.lower().strip() in ['end chat', 'endchat', 'end']:
            await self.end_comfort_dm_session(user, channel, "user_requested")
            return
            
        session = self.active_dm_sessions[user_id]
        comfort_mode = session.get('comfort_mode', 'comfort')
        
        # Add message to history
        session['messages'].append({
            'user': message_content,
            'timestamp': datetime.now(timezone.utc).isoformat()
        })
        
        # Get mode info for response
        mode_info = self.DM_COMFORT_MODES.get(comfort_mode, self.DM_COMFORT_MODES['comfort'])
        
        try:
            # Import here to avoid circular imports
            import os
            from anthropic import Anthropic
            
            client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
            
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=300,
                temperature=mode_info['temperature'],
                system=mode_info['system_prompt'],
                messages=[{"role": "user", "content": message_content}]
            )
            
            reply = response.content[0].text
            
            # Add response to history
            session['messages'].append({
                'bot': reply,
                'timestamp': datetime.now(timezone.utc).isoformat()
            })
            
            await channel.send(reply)
            
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Comfort Chat Error")
            await channel.send("I'm having trouble responding right now. Please try again or type 'end chat' to end our session.")

    async def end_comfort_dm_session(self, user, dm_channel, reason="unknown"):
        user_id = user.id
        if user_id not in self.active_dm_sessions:
            return
            
        session = self.active_dm_sessions[user_id]
        messages = session.get('messages', [])
        comfort_mode = session.get('comfort_mode', 'unknown')
        session_duration = datetime.now(timezone.utc) - session['started_at']
        
        storage = self.bot.get_cog("Storage")

        # Save summary/history (async for Storage)
        if storage and messages:
            try:
                history = await storage.load_comfort_history()
                history.setdefault(str(user_id), []).append({
                    "mode": comfort_mode,
                    "messages": messages,
                    "ended_at": datetime.now(timezone.utc).isoformat(),
                    "duration": str(session_duration).split('.')[0],
                    "end_reason": reason,
                })
                await storage.save_comfort_history(history)
            except Exception as e:
                if self.logger:
                    await self.logger.log_error(e, "Comfort History Save Error")

        farewell = random.choice([
            f"Thanks for opening up, {user.display_name}. Take care! 💕",
            f"Session ended. Remember, you're not alone, {user.display_name}.",
            f"Goodbye for now, {user.display_name}. Reach out anytime."
        ])
        await dm_channel.send(farewell)
        del self.bot.active_dm_sessions[user_id]

async def setup(bot: commands.Bot):
    await bot.add_cog(Comfort(bot))