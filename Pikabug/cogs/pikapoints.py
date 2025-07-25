from discord.ext import commands
from utils import create_pikabug_embed

class PikaPoints(commands.Cog):
    """Cog for viewing and managing PikaPoints."""

    def __init__(self, bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    @commands.command(name='points', help='Display how many PikaPoints you have')
    async def points(self, ctx):
        try:
            storage = self.get_storage_cog()
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)
            record = await storage.get_user_record(guild_id, user_id)
            user_points = record.get("points", 0)
            embed = create_pikabug_embed(
                f'{ctx.author.display_name}, you have {user_points} PikaPoints!',
                title='💰 Your Points'
            )
            await ctx.send(embed=embed)
            if self.logger is not None:
                await self.logger.log_command_usage(
                    ctx, "points", success=True, extra_info=f"User has {user_points} points"
                )
        except Exception as e:
            if self.logger is not None:
                await self.logger.log_error(e, "Points Command Error")
            await ctx.send("❌ Error retrieving your points.")
            if self.logger is not None:
                await self.logger.log_command_usage(ctx, "points", success=False)

    @commands.command(name='grantpoints')
    async def grantpoints(self, ctx, user: commands.MemberConverter, points: int):
        """Grant PikaPoints to a user (Admin only)"""
        try:
            if not ctx.author.guild_permissions.administrator:
                await ctx.send("❌ You need administrator permissions to use this command.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "grantpoints", success=False, extra_info="Insufficient permissions")
                return
            if points <= 0 or points > 1000:
                await ctx.send("❌ Points amount must be between 1 and 1000.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "grantpoints", success=False, extra_info="Invalid points amount")
                return

            storage = self.get_storage_cog()
            guild_id = str(ctx.guild.id)
            user_id = str(user.id)

            async with storage.points_lock:
                async def add_points(record):
                    record['points'] += points
                    record['admin_granted'] = record.get('admin_granted', 0) + points
                await storage.update_pikapoints(guild_id, user_id, add_points)
                record = await storage.get_user_record(guild_id, user_id)

            embed = create_pikabug_embed(
                f"{ctx.author.display_name} granted {points} PikaPoints to {user.display_name}!\n"
                f"• {user.display_name}'s Total Points: {record['points']}\n"
                f"• Points Granted by Admins: {record['admin_granted']}",
                title="✅ Points Granted"
            )
            embed.color = 0x00ff00
            await ctx.send(embed=embed)
            if self.logger:
                await self.logger.log_command_usage(ctx, "grantpoints", success=True, extra_info=f"Granted {points} points to {user.display_name} ({user.id})")
        except Exception as e:
            if self.logger is not None:
                await self.logger.log_error(e, "Grant Points Command Error")
            await ctx.send("❌ An error occurred while granting points. Please try again.")

    @commands.command(name='removepoints')
    async def removepoints(self, ctx, user: commands.MemberConverter, points: int):
        """Remove PikaPoints from a user (Admin only)"""
        try:
            if not ctx.author.guild_permissions.administrator:
                await ctx.send("❌ You need administrator permissions to use this command.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Insufficient permissions")
                return
            if points <= 0 or points > 1000:
                await ctx.send("❌ Points amount must be between 1 and 1000.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Invalid points amount")
                return

            storage = self.get_storage_cog()
            guild_id = str(ctx.guild.id)
            user_id = str(user.id)

            async with storage.points_lock:
                record = await storage.get_user_record(guild_id, user_id)
                if record["points"] < points:
                    await ctx.send(f"❌ **{user.display_name}** only has **{record['points']}** points. Cannot remove **{points}** points.")
                    if self.logger:
                        await self.logger.log_command_usage(ctx, "removepoints", success=False, extra_info="Insufficient user points")
                    return
                async def remove_points(record):
                    record["points"] -= points
                    record["admin_removed"] = record.get("admin_removed", 0) + points
                await storage.update_pikapoints(guild_id, user_id, remove_points)
                record = await storage.get_user_record(guild_id, user_id)

            embed = create_pikabug_embed(
                f"{ctx.author.display_name} removed {points} PikaPoints from {user.display_name}!\n"
                f"• {user.display_name}'s Total Points: {record['points']}\n"
                f"• Points Removed by Admins: {record['admin_removed']}",
                title="✅ Points Removed"
            )
            embed.color = 0xff0000
            await ctx.send(embed=embed)
            if self.logger:
                await self.logger.log_command_usage(ctx, "removepoints", success=True, extra_info=f"Removed {points} points from {user.display_name} ({user.id})")
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Remove Points Command Error")
                await self.logger.log_command_usage(ctx, "removepoints", success=False)
            await ctx.send("❌ An error occurred while removing points. Please try again.")

    @commands.command(name='setpoints')
    async def setpoints(self, ctx, user: commands.MemberConverter, points: int):
        """Set exact PikaPoints for a user (Admin only)"""
        try:
            if not ctx.author.guild_permissions.administrator:
                await ctx.send("❌ You need administrator permissions to use this command.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "setpoints", success=False, extra_info="Insufficient permissions")
                return
            if points < 0 or points > 10000:
                await ctx.send("❌ Points amount must be between 0 and 10,000.")
                if self.logger:
                    await self.logger.log_command_usage(ctx, "setpoints", success=False, extra_info="Invalid points amount")
                return

            storage = self.get_storage_cog()
            guild_id = str(ctx.guild.id)
            user_id = str(user.id)

            async with storage.points_lock:
                record = await storage.get_user_record(guild_id, user_id)
                old_points = record["points"]
                
                async def set_points(record):
                    record["points"] = points
                    record["admin_set"] = record.get("admin_set", 0) + 1
                await storage.update_pikapoints(guild_id, user_id, set_points)
                record = await storage.get_user_record(guild_id, user_id)

            points_change = points - old_points
            change_text = f"(+{points_change})" if points_change > 0 else f"({points_change})" if points_change < 0 else "(no change)"
            
            embed = create_pikabug_embed(
                f"{ctx.author.display_name} set {user.display_name}'s PikaPoints to {points}!\n"
                f"• Previous Points: {old_points}\n"
                f"• New Points: {points} {change_text}\n"
                f"• Admin Point Sets: {record['admin_set']}",
                title="✅ Points Set"
            )
            embed.color = 0x0099ff
            await ctx.send(embed=embed)
            if self.logger:
                await self.logger.log_command_usage(ctx, "setpoints", success=True, extra_info=f"Set {user.display_name} ({user.id}) points to {points} (was {old_points})")
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Set Points Command Error")
                await self.logger.log_command_usage(ctx, "setpoints", success=False)
            await ctx.send("❌ An error occurred while setting points. Please try again.")

async def setup(bot: commands.Bot):
    await bot.add_cog(PikaPoints(bot))