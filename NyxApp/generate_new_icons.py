#!/usr/bin/env python3
"""
Generate Android app icons from the new icon image
Maintains consistency with adaptive icon requirements
"""

from PIL import Image, ImageDraw
import os

def create_adaptive_icons():
    # Load the new icon
    icon_path = "new_app_icon.png"
    with Image.open(icon_path) as base_img:
        # Ensure it's 1024x1024
        if base_img.size != (1024, 1024):
            base_img = base_img.resize((1024, 1024), Image.Resampling.LANCZOS)
        
        # Convert to RGBA if needed
        if base_img.mode != 'RGBA':
            base_img = base_img.convert('RGBA')
        
        # Android adaptive icon sizes
        sizes = {
            'mdpi': 48,
            'hdpi': 72, 
            'xhdpi': 96,
            'xxhdpi': 144,
            'xxxhdpi': 192
        }
        
        # Generate foreground icons (108dp safe area)
        foreground_sizes = {
            'mdpi': 108,
            'hdpi': 162,
            'xhdpi': 216, 
            'xxhdpi': 324,
            'xxxhdpi': 432
        }
        
        print("🎨 Generating adaptive icons...")
        
        for density, size in foreground_sizes.items():
            # Create foreground icon (the main icon content)
            fg_icon = base_img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Save foreground
            fg_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png"
            os.makedirs(os.path.dirname(fg_path), exist_ok=True)
            fg_icon.save(fg_path, "PNG")
            
            # Also save to drawable for compatibility
            drawable_path = f"android/app/src/main/res/drawable-{density}/ic_launcher_foreground.png"
            os.makedirs(os.path.dirname(drawable_path), exist_ok=True)
            fg_icon.save(drawable_path, "PNG")
            
            print(f"✅ Generated {density} foreground: {size}x{size}")
        
        # Generate regular launcher icons
        for density, size in sizes.items():
            # Create regular launcher icon
            launcher_icon = base_img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Save launcher icon
            launcher_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
            launcher_icon.save(launcher_path, "PNG")
            
            # Create round version
            round_icon = create_round_icon(launcher_icon, size)
            round_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png"
            round_icon.save(round_path, "PNG")
            
            print(f"✅ Generated {density} launcher: {size}x{size}")
        
        # Generate solid color background for adaptive icons
        generate_backgrounds()
        
        print("🎉 All icons generated successfully!")

def create_round_icon(img, size):
    """Create a round version of the icon"""
    # Create a circular mask
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size, size), fill=255)
    
    # Apply the mask to create round icon
    round_icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    round_icon.paste(img, (0, 0))
    round_icon.putalpha(mask)
    
    return round_icon

def generate_backgrounds():
    """Generate solid color backgrounds for adaptive icons"""
    # Use a clean white background for adaptive icons
    background_color = (255, 255, 255, 255)  # White
    
    background_sizes = {
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432
    }
    
    for density, size in background_sizes.items():
        # Create solid background
        bg_img = Image.new('RGBA', (size, size), background_color)
        
        bg_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_background.png"
        bg_img.save(bg_path, "PNG")
        
        print(f"✅ Generated {density} background: {size}x{size}")

if __name__ == "__main__":
    create_adaptive_icons()