from discord.ext import commands
from datetime import datetime, timezone
from utils import create_pikabug_embed
import random

WORKSHOP_POINTS = 20
WEEKEND_POINTS = 20

class Workshop(commands.Cog):
    """Manages weekly workshop submissions and weekend writing."""
    def __init__(self, bot):
        self.bot = bot
        self.logger = getattr(bot, "logger", None)
        self.active_weekend_prompts = {}  # user_key -> {prompt, timestamp, channel_id}
        self.last_prompt_prompt = None
        self.prompt_prompts = [
            "What's something that made you smile today?",
            "Describe a challenge you overcame recently.",
            "What's a goal you're working towards?",
            "Share a memory that always makes you laugh.",
            "What's something you're grateful for right now?",
            "Describe your ideal day from start to finish.",
            "What's a skill you'd like to learn?",
            "Share something that's been on your mind lately.",
            "What's one thing you're proud of accomplishing recently?",
            "Describe a place where you feel most at peace.",
            "What advice would you give to your younger self?",
            "Share a moment when you felt truly connected to someone.",
            "What's a small act of kindness you've witnessed or experienced?",
            "Describe a time when you stepped out of your comfort zone.",
            "What were your childhood career dreams/goals? How do they compare to what you want to do now?",
            "Which year comes to mind when you think about the best nostalgia? Why did that year carry the best memories?",
            "Describe your childhood in one word, or a single phrase. If this inspires you to talk more about it, go ahead.",
            "What posters did you have on your wall growing up or want to have?",
            "What instance immediately comes to mind when you remember a meaningful display of kindness?",
            "Who are some people in history you admire?",
            "Who was your first best friend? Tell me about them. Why did you get along so well?",
            "Who was your first love? Tell me about them. Why did they stand out more than others?",
            "What was your first job and when did you get it? What do you wish it would've been?",
            "Describe the experience of your first kiss or first time.",
            "Describe the experience of your first time being drunk/high.",
            "Have you ever gotten in trouble with the law? If you were to, what would it most likely be for?",
            "What was the age you actually became an adult, if you feel you have.",
            "Who or what has had the greatest impact on your life, negatively or positively?",
            "What's one of the hardest things you've ever had to do? Do you regret it or did it need to be done?",
            "If I could do it all over again, I would change...",
            "The teacher that had the most influence on my life was...",
            "Describe your parents, how you feel about them, and how they've influenced you.",
            "The long-lost childhood possession that I would love to see again is...",
            "The one thing I regret most about my life or decisions is...",
            "Some things I've been addicted to include...",
            "I was most happy when...",
            "I will never forgive...",
            "Something I'm glad I tried but will never do again is...",
            "The 3-5 best things I've ever had or done in my life are...",
            "The 3-5 things I want to do but have never done are...",
            "I wish I never met...",
            "The one person I've been most jealous of is...",
            "Someone I miss is...",
            "The last time I said I love you was...",
            "Describe your greatest heartbreak or loss.",
            "Something I feel guilty about is...",
            "My life story in 3 sentences is...",
            "My top 3 favorite bands are...",
            "My top 3 favorite songs are...",
            "My top 3 favorite movies are...",
            "My top 3 favorite TV shows are...",
            "My top 3 favorite books are...",
            "My top 3 favorite games are...",
            "My top 3 favorite places I've been are...",
            "My top 3 favorite foods are...",
            "My top 3 favorite colors are...",
            "My top 3 favorite animals are...",
            "My top 3 favorite drinks are...",
            "My top 3 favorite desserts are...",
            "My top 3 favorite snacks are...",
            "My top 3 favorite celebrities are...",
            "What time period would you most like to live in and why?",
            "What would 16 year old you think of current you?",
            "How was it getting your license? If you don't have it, why not?",
            "What's the most embarrassing thing you've ever done?",
            "What's something you've gotten an award for?",
            "Do you regret any of your exes?",
            "What's your political affiliation and why?",
            "Have you ever been in a fight?",
            "Have you ever saved someone's life?",
            "Something you need to confess to someone who won't know is...",
            "First word you'd use to describe yourself is...",
            "First person you think to confide in and why is...",
            "When did you last cry and why?",
            "What's the first quality you look for in a person?",
            "When's the last time you felt in control of your life?",
            "When's a time you successfully stood your ground?",
            "When's the last time you felt proud of yourself?",
            "When's the last time you were scared for your life?",
            "When's the last time you wanted to end your life?",
            "Three signs of hope for your future are...",
            "Three things you forgive yourself for are..."
        ]

    def get_storage_cog(self):
        storage_cog = self.bot.get_cog("Storage")
        if storage_cog is None:
            raise RuntimeError("Storage cog not loaded.")
        return storage_cog

    async def handle_workshop_submission(self, ctx, day_key: str, submission: str):
        """Handle workshop submissions for all days."""
        try:
            workshop_name = day_key.capitalize() if day_key != "weekend" else "Weekend Writing"
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)

            storage = self.get_storage_cog()
            
            # Award points with proper locking
            async with storage.points_lock:
                # Get current record
                record = await storage.get_user_record(guild_id, user_id)
                
                # Update points and counts
                record['points'] += WORKSHOP_POINTS
                record.setdefault('workshop_submissions', 0)
                record['workshop_submissions'] += 1
                day_field = f'workshop_{day_key}_submissions'
                record.setdefault(day_field, 0)
                record[day_field] += 1

                # Save the updated record
                data = await storage.load_pikapoints()
                data.setdefault(guild_id, {})[user_id] = record
                await storage.save_pikapoints(data)

            # Save the submission to workshop file
            submissions = await storage.load_workshop_submissions()
            submissions.setdefault(guild_id, {})
            submissions[guild_id].setdefault(user_id, [])
            entry = {
                "day": day_key,
                "workshop_name": workshop_name,
                "submission": submission,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "display_name": ctx.author.display_name
            }
            submissions[guild_id][user_id].append(entry)
            await storage.save_workshop_submissions(submissions)

            # Create the response embed
            submission_msg = (
                f"🎯 **{workshop_name} Submission Received!**\n\n"
                f"✨ You earned **{WORKSHOP_POINTS} PikaPoints**!\n\n"
                f"📊 **Your Stats:**\n"
                f"• Total Points: {record['points']}\n"
                f"• Workshop Submissions: {record['workshop_submissions']}\n"
                f"• {workshop_name} Submissions: {record.get(f'workshop_{day_key}_submissions', 1)}\n\n"
                f"📝 **Your Submission:**\n{submission}"
            )
            embed = create_pikabug_embed(submission_msg, title=f"📝 {workshop_name}")
            embed.color = 0x9966cc
            await ctx.send(embed=embed)

            # Log the submission and points award
            if self.logger:
                await self.logger.log_command_usage(
                    ctx, f"workshop_{day_key}", success=True,
                    extra_info=f"Submission length: {len(submission)} chars"
                )
                await self.logger.log_points_award(user_id, guild_id, WORKSHOP_POINTS, f"workshop_{day_key}", record["points"])
                
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, f"Workshop {day_key} Error")
                await self.logger.log_command_usage(ctx, f"workshop_{day_key}", success=False)
            await ctx.send("❌ An error occurred while processing your workshop submission. Please try again.")

    @commands.command(name="monday")
    async def monday(self, ctx, *, submission: str):
        """Submit your Mindful Monday workshop entry."""
        await self.handle_workshop_submission(ctx, "monday", submission)

    @commands.command(name="tuesday")
    async def tuesday(self, ctx, *, submission: str):
        """Submit your Trigger or Trauma Tuesday workshop entry."""
        await self.handle_workshop_submission(ctx, "tuesday", submission)

    @commands.command(name="thursday")
    async def thursday(self, ctx, *, submission: str):
        """Submit your Thankful Thursday workshop entry."""
        await self.handle_workshop_submission(ctx, "thursday", submission)

    @commands.command(name="friday")
    async def friday(self, ctx, *, submission: str):
        """Submit your Flourishing Friday workshop entry."""
        await self.handle_workshop_submission(ctx, "friday", submission)

    @commands.command(name="weekend")
    async def weekend(self, ctx):
        """Start Weekend Writing by sending a journal prompt."""
        try:
            choices = self.prompt_prompts.copy()
            if self.last_prompt_prompt in choices:
                choices.remove(self.last_prompt_prompt)
            if not choices:
                choices = self.prompt_prompts.copy()
            selected_prompt = random.choice(choices)
            self.last_prompt_prompt = selected_prompt

            user_key = f"{ctx.guild.id}-{ctx.author.id}"
            self.active_weekend_prompts[user_key] = {
                "prompt": selected_prompt,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "channel_id": ctx.channel.id
            }

            prompt_msg = (
                f"✍️ **Weekend Writing Prompt**\n\n"
                f"📝 **Your Prompt:**\n{selected_prompt}\n\n"
                f"💡 **Instructions:**\n"
                f"• Take your time to reflect on this prompt\n"
                f"• Submit your response with `!weekendsubmit [your response]`\n"
                f"• Earn **{WEEKEND_POINTS} PikaPoints** for your thoughtful writing!\n\n"
                f"🌟 Remember: There's no right or wrong answer - just express yourself!"
            )
            embed = create_pikabug_embed(prompt_msg, title="✍️ Weekend Writing")
            embed.color = 0xffa500
            await ctx.send(embed=embed)

            if self.logger:
                await self.logger.log_command_usage(ctx, "weekend", success=True, 
                    extra_info=f"Prompt sent: {selected_prompt[:50]}...")
                    
        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Weekend Command Error")
                await self.logger.log_command_usage(ctx, "weekend", success=False)
            await ctx.send("❌ An error occurred while generating your weekend writing prompt. Please try again.")

    @commands.command(name="weekendsubmit")
    async def weekendsubmit(self, ctx, *, submission: str):
        """Submit your Weekend Writing response."""
        user_key = f"{ctx.guild.id}-{ctx.author.id}"
        try:
            prompt_data = self.active_weekend_prompts.get(user_key)
            if not prompt_data:
                embed = create_pikabug_embed(
                    "❌ You don't have an active weekend writing prompt.\n"
                    "Use `!weekend` to get a new prompt first!",
                    title="No Active Prompt"
                )
                await ctx.send(embed=embed)
                if self.logger:
                    await self.logger.log_command_usage(ctx, "weekendsubmit", success=False, extra_info="No active prompt")
                return

            original_prompt = prompt_data["prompt"]
            guild_id = str(ctx.guild.id)
            user_id = str(ctx.author.id)

            storage = self.get_storage_cog()

            # Award points with proper locking
            async with storage.points_lock:
                # Get current record
                record = await storage.get_user_record(guild_id, user_id)
                
                # Update points and counts
                record['points'] += WEEKEND_POINTS
                record.setdefault('workshop_submissions', 0)
                record['workshop_submissions'] += 1
                record.setdefault('workshop_weekend_submissions', 0)
                record['workshop_weekend_submissions'] += 1

                # Save the updated record
                data = await storage.load_pikapoints()
                data.setdefault(guild_id, {})[user_id] = record
                await storage.save_pikapoints(data)

            # Save submission to persistent storage
            submissions = await storage.load_workshop_submissions()
            submissions.setdefault(guild_id, {})
            submissions[guild_id].setdefault(user_id, [])
            submissions[guild_id][user_id].append({
                "day": "weekend",
                "workshop_name": "Weekend Writing",
                "prompt": original_prompt,
                "submission": submission,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "display_name": ctx.author.display_name
            })
            await storage.save_workshop_submissions(submissions)

            submission_msg = (
                f"📝 **Weekend Writing Submission Received!**\n\n"
                f"✨ You earned **{WEEKEND_POINTS} PikaPoints**!\n\n"
                f"📊 **Your Stats:**\n"
                f"• Total Points: {record['points']}\n"
                f"• Workshop Submissions: {record['workshop_submissions']}\n"
                f"• Weekend Writing Submissions: {record['workshop_weekend_submissions']}\n\n"
                f"💭 **Your Prompt:**\n{original_prompt}\n\n"
                f"📝 **Your Response:**\n{submission}"
            )
            embed = create_pikabug_embed(submission_msg, title="📝 Weekend Writing Complete")
            embed.color = 0x00ff00
            await ctx.send(embed=embed)

            # Clean up the active prompt
            del self.active_weekend_prompts[user_key]

            if self.logger:
                await self.logger.log_command_usage(ctx, "weekendsubmit", success=True, extra_info=f"Submission length: {len(submission)} chars")
                await self.logger.log_points_award(user_id, guild_id, WEEKEND_POINTS, "workshop_weekend", record["points"])

        except Exception as e:
            if self.logger:
                await self.logger.log_error(e, "Weekend Submit Error")
                await self.logger.log_command_usage(ctx, "weekendsubmit", success=False)
            await ctx.send("❌ An error occurred while processing your weekend writing submission. Please try again.")

async def setup(bot: commands.Bot):
    await bot.add_cog(Workshop(bot))