import os, discord
from discord.ext import commands
from dotenv import load_dotenv
import sys, time
print("starting", file=sys.stderr)
time.sleep(0.5) 
load_dotenv()
TOKEN = os.getenv("DISCORD_TOKEN")
print("DEBUG-TOKEN-LEN:", len(TOKEN) if TOKEN else "None")

TOKEN = os.getenv("DISCORD_TOKEN")

TARGET_CHANNEL_ID = 1388165084794322964

intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(command_prefix="!", intents=intents)
@bot.event
async def on_ready():
    print(f'✅ Logged in as {bot.user} — ready to delete replies.')
def is_reply(msg: discord.Message) -> bool:
    return msg.reference is not None

@bot.event
async def on_message(msg):
    if msg.channel.id == TARGET_CHANNEL_ID and is_reply(msg) and not msg.author.bot:
        await msg.delete()
        return
    await bot.process_commands(msg)

@bot.command(name="purgeReplies")
@commands.has_permissions(manage_messages=True)
async def purge_replies(ctx, limit: int = 1000):
    deleted = await ctx.channel.purge(limit=limit, check=is_reply, bulk=True)
    await ctx.send(f"Deleted {len(deleted)} replies.", delete_after=5)

bot.run(TOKEN)
