# session_commands.py
import os
import discord
from discord.ext import commands
from typing import Optional
import logging
from datetime import datetime, timezone

NYX_COLOR = 0x76b887

class SessionCommands(commands.Cog):
    """Commands for managing chat sessions - save, new, and view archived chats."""
    
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger = logging.getLogger("session_commands")
        
        # Import session manager
        from .session_manager import session_manager
        self.session_manager = session_manager
    
    async def cog_load(self):
        """Called when cog is loaded."""
        self.logger.info("SessionCommands cog loading...")
        self.logger.info("SessionCommands cog loaded successfully")
    
    async def cog_unload(self):
        """Called when cog is unloaded."""
        self.logger.info("SessionCommands cog unloading...")
        self.logger.info("SessionCommands cog unloaded successfully")
    
    @commands.command(name="saveforever", aliases=["savechat", "archivechat"])
    async def save_forever(self, ctx, *, session_name: Optional[str] = None):
        """Save the current chat session forever to Resident Records.
        
        Usage:
        !saveforever - Save with auto-generated name
        !saveforever My Important Chat - Save with custom name
        """
        user_id = str(ctx.author.id)
        
        # Determine chat mode from channel or last interaction
        chat_mode = await self._determine_chat_mode(ctx)
        
        if not chat_mode:
            embed = discord.Embed(
                title="❌ No Active Chat",
                description="You don't have an active chat session to save. Start chatting first!",
                color=0xff0000
            )
            await self.bot.safe_send(ctx.channel, embed=embed)
            return
        
        # Save the session
        success = await self.session_manager.save_forever(user_id, chat_mode, session_name)
        
        if success:
            embed = discord.Embed(
                title="💾 Chat Saved Forever",
                description=f"Your {chat_mode} chat has been permanently saved to Resident Records.",
                color=NYX_COLOR
            )
            if session_name:
                embed.add_field(name="Session Name", value=session_name, inline=False)
            embed.add_field(name="What's Next?", value="A new chat session has been started. Your previous messages are safely archived.", inline=False)
            embed.set_footer(text=f"Saved by {ctx.author.display_name}", icon_url=ctx.author.display_avatar.url)
        else:
            embed = discord.Embed(
                title="❌ Save Failed",
                description="Failed to save your chat session. Please try again.",
                color=0xff0000
            )
        
        await self.bot.safe_send(ctx.channel, embed=embed)
    
    @commands.command(name="newchat", aliases=["freshstart", "clearchat"])
    async def new_chat(self, ctx):
        """Start a new chat session. Previous chat will be auto-archived."""
        user_id = str(ctx.author.id)
        
        # Determine chat mode
        chat_mode = await self._determine_chat_mode(ctx)
        
        if not chat_mode:
            chat_mode = "general"  # Default to general chat
        
        # Create new session (auto-archives current)
        new_session = await self.session_manager.create_new_session(user_id, chat_mode)
        
        embed = discord.Embed(
            title="🆕 New Chat Started",
            description=f"Started a fresh {chat_mode} chat session!",
            color=NYX_COLOR
        )
        embed.add_field(
            name="Previous Chat",
            value="Your previous chat has been automatically archived and can be accessed later.",
            inline=False
        )
        embed.set_footer(text=f"New session for {ctx.author.display_name}", icon_url=ctx.author.display_avatar.url)
        
        await self.bot.safe_send(ctx.channel, embed=embed)
    
    @commands.command(name="mysessions", aliases=["savedchats", "archives"])
    async def my_sessions(self, ctx, chat_mode: Optional[str] = None):
        """View your saved chat sessions.
        
        Usage:
        !mysessions - Show all saved sessions
        !mysessions comfort - Show only comfort chat sessions
        """
        user_id = str(ctx.author.id)
        
        # Get saved sessions
        sessions = await self.session_manager.get_saved_sessions(user_id, chat_mode)
        
        if not sessions:
            embed = discord.Embed(
                title="📚 No Saved Sessions",
                description="You don't have any saved chat sessions yet.\nUse `!saveforever` to save important conversations!",
                color=NYX_COLOR
            )
            await self.bot.safe_send(ctx.channel, embed=embed)
            return
        
        # Create paginated embed (show first 10)
        embed = discord.Embed(
            title="📚 Your Saved Sessions",
            description=f"Found {len(sessions)} saved {'sessions' if len(sessions) != 1 else 'session'}",
            color=NYX_COLOR
        )
        
        for i, session in enumerate(sessions[:10]):
            # Format session info
            name = session.get("archive_name", session.get("filename", "Unknown"))
            mode = session.get("chat_mode", "unknown")
            messages = session.get("message_count", 0)
            saved_at = session.get("saved_at", "Unknown time")
            
            # Parse and format date
            try:
                dt = datetime.fromisoformat(saved_at.replace('Z', '+00:00'))
                formatted_date = dt.strftime("%b %d, %Y at %I:%M %p")
            except:
                formatted_date = "Unknown date"
            
            embed.add_field(
                name=f"{i+1}. {name}",
                value=f"**Mode:** {mode.title()}\n**Messages:** {messages}\n**Saved:** {formatted_date}",
                inline=True
            )
        
        if len(sessions) > 10:
            embed.set_footer(text=f"Showing 10 of {len(sessions)} sessions | Use !viewsession <name> to view")
        else:
            embed.set_footer(text=f"Use !viewsession <name> to view a session")
        
        await self.bot.safe_send(ctx.channel, embed=embed)
    
    @commands.command(name="viewsession", aliases=["loadsession", "getsession"])
    async def view_session(self, ctx, *, archive_name: str):
        """View a specific saved session.
        
        Usage:
        !viewsession My Important Chat
        """
        user_id = str(ctx.author.id)
        
        # Load the session
        session = await self.session_manager.load_saved_session(user_id, archive_name)
        
        if not session:
            embed = discord.Embed(
                title="❌ Session Not Found",
                description=f"Could not find a saved session matching '{archive_name}'.\nUse `!mysessions` to see your saved sessions.",
                color=0xff0000
            )
            await self.bot.safe_send(ctx.channel, embed=embed)
            return
        
        # Display session summary
        messages = session.get("messages", [])
        metadata = session.get("metadata", {})
        
        embed = discord.Embed(
            title=f"📖 Session: {metadata.get('archive_name', archive_name)}",
            description=f"**Chat Mode:** {session.get('chat_mode', 'Unknown').title()}\n**Total Messages:** {len(messages)}",
            color=NYX_COLOR
        )
        
        # Show last 3 messages as preview
        if messages:
            preview_messages = messages[-3:] if len(messages) > 3 else messages
            preview_text = ""
            
            for msg in preview_messages:
                role = msg.get("role", "unknown")
                content = msg.get("content", "")
                
                # Truncate long messages
                if len(content) > 100:
                    content = content[:97] + "..."
                
                preview_text += f"**{role.title()}:** {content}\n\n"
            
            embed.add_field(
                name="📝 Recent Messages",
                value=preview_text or "No messages to display",
                inline=False
            )
        
        # Add session info
        created_at = session.get("created_at", "Unknown")
        saved_at = metadata.get("saved_at", "Unknown")
        
        try:
            created_dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            saved_dt = datetime.fromisoformat(saved_at.replace('Z', '+00:00'))
            
            embed.add_field(
                name="📅 Session Dates",
                value=f"**Started:** {created_dt.strftime('%b %d, %Y %I:%M %p')}\n**Saved:** {saved_dt.strftime('%b %d, %Y %I:%M %p')}",
                inline=True
            )
        except:
            pass
        
        embed.set_footer(text=f"Full session contains {len(messages)} messages")
        
        await self.bot.safe_send(ctx.channel, embed=embed)
    
    @commands.command(name="sessioninfo", aliases=["chatinfo"])
    async def session_info(self, ctx):
        """Get information about your current active chat session."""
        user_id = str(ctx.author.id)
        
        # Determine chat mode
        chat_mode = await self._determine_chat_mode(ctx)
        
        if not chat_mode:
            chat_mode = "general"
        
        # Get active session
        session = await self.session_manager.get_active_session(user_id, chat_mode)
        
        if session:
            messages = session.get("messages", [])
            metadata = session.get("metadata", {})
            
            embed = discord.Embed(
                title="📊 Current Session Info",
                description=f"**Mode:** {chat_mode.title()}\n**Session ID:** {session.get('session_id', 'Unknown')}",
                color=NYX_COLOR
            )
            
            embed.add_field(name="Messages", value=str(len(messages)), inline=True)
            embed.add_field(name="Status", value="Active ✅", inline=True)
            
            # Show session start time
            created_at = session.get("created_at", "Unknown")
            try:
                dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                embed.add_field(
                    name="Started",
                    value=dt.strftime("%b %d, %Y %I:%M %p"),
                    inline=True
                )
            except:
                pass
            
            embed.set_footer(text=f"Session for {ctx.author.display_name}", icon_url=ctx.author.display_avatar.url)
        else:
            embed = discord.Embed(
                title="❌ No Active Session",
                description="You don't have an active chat session. Start chatting to create one!",
                color=0xff0000
            )
        
        await self.bot.safe_send(ctx.channel, embed=embed)
    
    async def _determine_chat_mode(self, ctx) -> Optional[str]:
        """Determine the chat mode based on context."""
        # Check channel name or recent commands
        channel_name = ctx.channel.name.lower() if hasattr(ctx.channel, 'name') else ""
        
        if "comfort" in channel_name:
            return "comfort"
        elif "asylum" in channel_name:
            return "asylum"
        elif "ask" in channel_name:
            return "asknyx"
        
        # Check last command used (would need to track this)
        # For now, default to general
        return "general"

async def setup(bot):
    await bot.add_cog(SessionCommands(bot))