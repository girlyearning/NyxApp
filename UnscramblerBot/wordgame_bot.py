import discord
import random
from discord.ext import commands

# Load English word list
with open("common_words.txt") as f:
    english_words = [word.strip() for word in f if 5 <= len(word.strip()) <= 7]


# Store current word challenge
current_word = None
scrambled_word = None

revealed_indexes = set()  # tracks which letter positions are revealed
hint_count = 0            # tracks how many hints have been used


# Enable message content intent
intents = discord.Intents.default()
intents.message_content = True

# Bot setup
bot = commands.Bot(command_prefix="!", intents=intents)

# Start the game
@bot.command(name='startgame')
async def startgame(ctx):
    global current_word, scrambled_word, revealed_indexes, hint_count
    current_word = random.choice(english_words)
    scrambled_word = ''.join(random.sample(current_word, len(current_word)))

    # Reset hint tracking
    revealed_indexes = set([0, len(current_word) - 1])  # first and last revealed first
    hint_count = 0

    await ctx.send(f"🧠 Unscramble this word: **{scrambled_word}**")


# Handle user guesses
@bot.command(name='guess')
async def guess(ctx, user_guess: str):
    global current_word
    if current_word is None:
        await ctx.send("❗ No game running. Start one with `!startgame`.")
        return

    if user_guess.lower() == current_word:
        await ctx.send("✅ Correct! Well done.")
        current_word = None  # Reset game
    else:
        await ctx.send("❌ Incorrect. Try again!")
@bot.command(name='hint')
async def hint(ctx):
    global current_word, revealed_indexes, hint_count

    if current_word is None:
        await ctx.send("❗ No game is active. Start with `!startgame`.")
        return

    hint_count += 1

    # After the first hint, start revealing middle letters randomly
    if hint_count > 1:
        # Find all indexes not already revealed and not the first/last
        possible_indexes = [
            i for i in range(1, len(current_word) - 1)
            if i not in revealed_indexes
        ]
        if possible_indexes:
            new_index = random.choice(possible_indexes)
            revealed_indexes.add(new_index)

    # Build the hint string with revealed letters
    display = ""
    for i, char in enumerate(current_word):
        if i in revealed_indexes:
            display += char + " "
        else:
            display += "_ "

    await ctx.send(f"💡 Hint: {display.strip()}")

@bot.command(name='reveal')
async def reveal(ctx):
    global current_word
    if current_word is None:
        await ctx.send("❗ No word to reveal. Start a new game with `!startgame`.")
    else:
        await ctx.send(f"🕵️ The correct word was: **{current_word}**")
        current_word = None  # end the round


# Insert your actual token below
bot.run("MTM5MzE2NDA2NTQxMjQ4MTA4Nw.GQ47fC.-8eFp0StwnHo_JEXWfaGJbw54OXHQ_QpbSbQ3Y")
