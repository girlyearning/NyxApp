#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw

def generate_adaptive_icons():
    # Open the source image
    source_path = '/Users/vct/MyCode/Nyx/app_icon.png'
    img = Image.open(source_path)
    
    print(f'Source image size: {img.size}')
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # For adaptive icons, we need to create background and foreground layers
    # The foreground should be the main content (scaled down to 66% to account for masking)
    # The background should be a solid color or simple pattern
    
    # Android adaptive icon sizes
    adaptive_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162, 
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432
    }
    
    android_base = '/Users/vct/MyCode/Nyx/nyx_app/android/app/src/main/res'
    
    for folder, size in adaptive_sizes.items():
        # Create background (teal gradient matching the icon)
        background = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(background)
        
        # Create a nice gradient background that matches the cyberpunk Nyx icon
        # Using the teal/cyan colors from the new icon
        draw.rectangle([0, 0, size, size], fill=(45, 175, 190, 255))  # Cyan-teal from new icon
        
        # Save background
        bg_path = f'{android_base}/{folder}/ic_launcher_background.png'
        background.save(bg_path, 'PNG')
        
        # Create foreground (your icon scaled to 66% to account for safe area)
        foreground_size = int(size * 0.66)  # Safe area for adaptive icons
        padding = (size - foreground_size) // 2
        
        # Create transparent canvas
        foreground = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        
        # Resize and paste your icon in the center
        icon_resized = img.resize((foreground_size, foreground_size), Image.Resampling.LANCZOS)
        foreground.paste(icon_resized, (padding, padding), icon_resized)
        
        # Save foreground
        fg_path = f'{android_base}/{folder}/ic_launcher_foreground.png'
        foreground.save(fg_path, 'PNG')
        
        print(f'Generated adaptive icon: {folder} ({size}x{size})')
    
    print('✅ Adaptive icons generated successfully!')
    print('✅ Your app icon will now have proper rounded corners like other Android apps!')

if __name__ == '__main__':
    generate_adaptive_icons()