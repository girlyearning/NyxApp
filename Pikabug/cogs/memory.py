import discord
from discord.ext import commands
from utils import create_pikabug_embed, DiscordLogger
from datetime import datetime, timezone

class Memory(commands.Cog):
    """Handles user memory storage and retrieval commands."""
    def __init__(self, bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        self.MEMORY_POINTS = 5  # Points for using memory features

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog
    
    @commands.command(name="remember")
    async def remember(self, ctx, *, message: str):
        """Store a memory for the user."""
        try:
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            storage = self.get_storage_cog()

            # Load user's existing memories
            user_memory_data = await storage.load_user_memory(guild_id, user_id)
            if 'memories' not in user_memory_data:
                user_memory_data['memories'] = []

            # Add new memory with timestamp
            memory_entry = {
                "content": message,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "display_name": ctx.author.display_name
            }
            user_memory_data['memories'].append(memory_entry)
            await storage.save_user_memory(guild_id, user_id, user_memory_data)

            # Award points for using memory feature
            async def add_points(record):
                record['points'] += self.MEMORY_POINTS
                record.setdefault('memories_stored', 0)
                record['memories_stored'] += 1

            async with storage.points_lock:
                await storage.update_pikapoints(guild_id, user_id, add_points)
                record = await storage.get_user_record(guild_id, user_id)

            result_msg = (
                f"📌 Memory saved successfully!\n"
                f"✨ You earned {self.MEMORY_POINTS} PikaPoints!\n\n"
                f"• Total Points: {record['points']}\n"
                f"• Memories Stored: {record['memories_stored']}\n\n"
                f"Use `!memories` to view all your saved memories."
            )
            embed = create_pikabug_embed(result_msg, title="🧠 Memory Stored")
            embed.color = 0x00ff00
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "remember", success=True, extra_info=f"Memory length: {len(message)} chars")
                await self.logger.log_points_award(user_id, guild_id, self.MEMORY_POINTS, "memory_stored", record["points"])

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Remember Command Error")
                await self.logger.log_command_usage(ctx, "remember", success=False)
            await ctx.send("❌ Error saving memory. Please try again.")

    @commands.command(name="memories")
    async def memories(self, ctx):
        """List all saved memories."""
        try:
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            storage = self.get_storage_cog()

            # Load user memories
            user_memory_data = await storage.load_user_memory(guild_id, user_id)
            user_memories = user_memory_data.get('memories', [])

            if not user_memories:
                embed = create_pikabug_embed(
                    "🧠 You don't have any saved memories yet.\n\n"
                    "Use `!remember [message]` to store your first memory!",
                    title="📚 Your Memories"
                )
                embed.color = 0xffcec6
                await ctx.send(embed=embed)
                return

            # Format memories with timestamps
            formatted_memories = []
            for i, memory in enumerate(user_memories[-10:], 1):  # Show last 10 memories
                content = memory.get('content', memory) if isinstance(memory, dict) else memory
                timestamp = memory.get('timestamp', '') if isinstance(memory, dict) else ''
                
                if timestamp:
                    try:
                        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        date_str = dt.strftime('%m/%d/%y')
                        formatted_memories.append(f"{i}. {content} *(saved {date_str})*")
                    except:
                        formatted_memories.append(f"{i}. {content}")
                else:
                    formatted_memories.append(f"{i}. {content}")

            memory_text = "\n".join(formatted_memories)
            if len(user_memories) > 10:
                memory_text += f"\n\n*... and {len(user_memories) - 10} more memories*"
            
            memory_text += f"\n\n**Total Memories:** {len(user_memories)}"
            
            embed = create_pikabug_embed(memory_text, title="🧠 Your Memories")
            embed.color = 0x9f7aea
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "memories", success=True, extra_info=f"Displayed {len(user_memories)} memories")

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Memories Command Error")
                await self.logger.log_command_usage(ctx, "memories", success=False)
            await ctx.send("❌ Error retrieving memories. Please try again.")

    @commands.command(name="forget")
    async def forget(self, ctx, index: int = None):
        """Forget a specific memory by its number, or all if no index given."""
        try:
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            storage = self.get_storage_cog()

            # Load user memories
            user_memory_data = await storage.load_user_memory(guild_id, user_id)
            user_memories = user_memory_data.get('memories', [])

            if not user_memories:
                embed = create_pikabug_embed(
                    "🗃️ No memories to forget.\n\n"
                    "Use `!remember [message]` to store some memories first!",
                    title="🧠 Memory Management"
                )
                embed.color = 0xffcec6
                await ctx.send(embed=embed)
                return

            if index is None:
                # Clear all memories
                user_memory_data['memories'] = []
                await storage.save_user_memory(guild_id, user_id, user_memory_data)
                
                embed = create_pikabug_embed(
                    f"🧽 All {len(user_memories)} memories have been forgotten.\n\n"
                    "Your memory slate is now clean!",
                    title="🗑️ Memories Cleared"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)
                
                if self.logger:
                    await self.logger.log_command_usage(ctx, "forget", success=True, extra_info=f"Cleared {len(user_memories)} memories")
                    
            elif 1 <= index <= len(user_memories):
                # Remove specific memory (adjusting for 1-based indexing)
                removed_memory = user_memories.pop(index - 1)
                user_memory_data['memories'] = user_memories
                await storage.save_user_memory(guild_id, user_id, user_memory_data)
                
                # Handle both old and new memory formats
                content = removed_memory.get('content', removed_memory) if isinstance(removed_memory, dict) else removed_memory
                preview = content[:50] + "..." if len(content) > 50 else content
                
                embed = create_pikabug_embed(
                    f"🗑️ Memory #{index} forgotten:\n\n"
                    f"*{preview}*\n\n"
                    f"Remaining memories: {len(user_memories)}",
                    title="🧠 Memory Deleted"
                )
                embed.color = 0xff6b6b
                await ctx.send(embed=embed)
                
                if self.logger:
                    await self.logger.log_command_usage(ctx, "forget", success=True, extra_info=f"Removed memory #{index}")
                    
            else:
                embed = create_pikabug_embed(
                    f"❌ Invalid memory number: {index}\n\n"
                    f"Please choose a number between 1 and {len(user_memories)}.\n"
                    f"Use `!memories` to see your memory list.",
                    title="🧠 Invalid Memory Number"
                )
                embed.color = 0xff0000
                await ctx.send(embed=embed)

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Forget Command Error")
                await self.logger.log_command_usage(ctx, "forget", success=False)
            await ctx.send("❌ Error managing memories. Please try again.")

async def setup(bot: commands.Bot):
    await bot.add_cog(Memory(bot))