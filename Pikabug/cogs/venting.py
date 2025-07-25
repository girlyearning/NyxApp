from discord.ext import commands
import discord
from utils import create_pikabug_embed
from datetime import datetime, timezone
import random

VENT_POINTS = 10

class Venting(commands.Cog):
    """Handles vent support messages and vent submissions."""
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        self.last_vent_message = None

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name="vent")
    async def vent(self, ctx):
        """Send a supportive venting message."""
        try:
            supportive_messages = [
                "Hey, I'm proud of you for reaching out! I'm here to support you. Type your vent and submit it with !venting [your message].",
                "You can rant here, no judgment. When you're ready, use !venting [your message] to share.",
                "Sometimes you just need to get it out, we get it. Use !venting [your message] to tell me what's up.",
                "I'm here to listen. Let it all out, and know we're here for you. When you're ready, use !venting [your message] to share your thoughts.",
                "This is a safe space to express yourself. Use !venting [your message] when you're ready to share what's on your mind.",
                "I understand you might be going through a tough time. Use !venting [your message] to let it all out - I'm here for you."
            ]
            
            # Ensure we don't repeat the last message
            for _ in range(5):
                msg = random.choice(supportive_messages)
                if msg != self.last_vent_message:
                    break
            self.last_vent_message = msg
            
            embed = create_pikabug_embed(
                f"{msg}\n\n"
                f"🌟 **Privacy:** Your message will be deleted for privacy!\n"
                f"💝 **Reward:** You'll earn {VENT_POINTS} PikaPoints for sharing\n"
                f"🔒 **Safe:** This is a judgment-free zone",
                title="🫂 Vent Support"
            )
            embed.color = 0xffcec6
            await ctx.send(embed=embed)
            
            if self.logger:
                await self.logger.log_command_usage(ctx, "vent", success=True)
                
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Vent Command Error")
                await self.logger.log_command_usage(ctx, "vent", success=False)
            await ctx.send("❌ Error sending vent support message. Please try again.")

    @commands.command(name="venting")
    async def venting(self, ctx, *, entry: str):
        """Submit a vent entry and earn PikaPoints."""
        try:
            # Try to delete the user's message for privacy
            message_deleted = False
            try:
                await ctx.message.delete()
                message_deleted = True
            except discord.Forbidden:
                # Send a warning about privacy
                privacy_warning = await ctx.send("⚠️ I don't have permission to delete your message for privacy. Your vent will still be saved securely.")
                # Delete the warning after 10 seconds
                await privacy_warning.delete(delay=10)
            except Exception:
                pass  # Ignore other errors

            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            storage = self.get_storage_cog()

            # Save the vent entry
            vent_data = await storage.load_vent_submissions()
            vent_data.setdefault(guild_id, {})
            vent_data[guild_id].setdefault(user_id, [])
            
            vent_entry = {
                "entry": entry,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "display_name": ctx.author.display_name,
                "message_deleted": message_deleted
            }
            vent_data[guild_id][user_id].append(vent_entry)
            await storage.save_vent_submissions(vent_data)

            # Award points with proper locking
            async with storage.points_lock:
                async def add_points(record):
                    record['points'] += VENT_POINTS
                    record.setdefault('vent_submissions', 0)
                    record['vent_submissions'] += 1

                await storage.update_pikapoints(guild_id, user_id, add_points)
                record = await storage.get_user_record(guild_id, user_id)

            result_msg = (
                f"🫂 **Vent Received & Saved Securely**\n\n"
                f"Thank you for sharing. Your feelings are valid.\n"
                f"✨ You earned {VENT_POINTS} PikaPoints for reaching out!\n\n"
                f"📊 **Your Stats:**\n"
                f"• Total Points: {record['points']}\n"
                f"• Vent Submissions: {record['vent_submissions']}\n\n"
                f"🤗 Remember: You're not alone, and it's okay to not be okay.\n"
                f"Use `!vent` anytime you need support."
            )
            
            embed = create_pikabug_embed(result_msg, title="✅ Vent Safely Received")
            embed.color = 0x00ff00
            response_msg = await ctx.send(embed=embed)
            
            # Delete the response after 30 seconds for privacy
            await response_msg.delete(delay=30)

            if self.logger:
                await self.logger.log_command_usage(ctx, "venting", success=True, extra_info=f"Entry length: {len(entry)} chars, Privacy: {message_deleted}")
                await self.logger.log_points_award(user_id, guild_id, VENT_POINTS, "vent_submission", record["points"])
                
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Venting Command Error")
                await self.logger.log_command_usage(ctx, "venting", success=False)
            await ctx.send("❌ Error submitting vent entry. Please try again - your privacy is important to us.")

async def setup(bot: commands.Bot):
    await bot.add_cog(Venting(bot))