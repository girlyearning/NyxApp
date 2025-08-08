#!/usr/bin/env python3
"""
Generate Android app icons from the new icon image with proper centering and zoom
"""

from PIL import Image, ImageDraw
import os

def create_android_icons():
    # Load the new icon
    icon_path = "assets/images/app_launcher_icon.png"
    
    with Image.open(icon_path) as base_img:
        # Convert to RGBA to handle transparency properly
        if base_img.mode != 'RGBA':
            base_img = base_img.convert('RGBA')
        
        # Create a function to generate properly sized and centered icons
        def create_sized_icon(target_size, padding_factor=0.85):
            # Calculate the icon size with padding (zoom out effect)
            icon_size = int(target_size * padding_factor)
            
            # Create transparent background
            result = Image.new('RGBA', (target_size, target_size), (0, 0, 0, 0))
            
            # Resize the icon
            resized_icon = base_img.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            
            # Center the icon
            x = (target_size - icon_size) // 2
            y = (target_size - icon_size) // 2
            
            # Paste the icon centered
            result.paste(resized_icon, (x, y), resized_icon)
            
            return result
        
        # Android adaptive icon sizes (foreground layer)
        android_sizes = [
            (48, 'mdpi'),
            (72, 'hdpi'), 
            (96, 'xhdpi'),
            (144, 'xxhdpi'),
            (192, 'xxxhdpi'),
        ]
        
        # Create directories
        android_dir = "android/app/src/main/res"
        os.makedirs(android_dir, exist_ok=True)
        
        print("🤖 Generating Android adaptive icons...")
        
        for size, density in android_sizes:
            density_dir = os.path.join(android_dir, f"mipmap-{density}")
            os.makedirs(density_dir, exist_ok=True)
            
            # Create foreground (the actual icon with transparency)
            foreground = create_sized_icon(size, padding_factor=0.40)  # Icon takes up 40% of space, centered
            foreground_path = os.path.join(density_dir, "ic_launcher_foreground.png")
            foreground.save(foreground_path, "PNG")
            
            # Create background (solid sage green color matching the icon)
            background = Image.new('RGB', (size, size), (173, 207, 134))  # Sage green color
            background_path = os.path.join(density_dir, "ic_launcher_background.png")
            background.save(background_path, "PNG")
            
            # Also create legacy launcher icon (for older Android versions)
            # This combines foreground and background
            legacy_icon = background.convert('RGBA')
            legacy_icon.paste(foreground, (0, 0), foreground)
            legacy_icon = legacy_icon.convert('RGB')  # Remove transparency for legacy
            legacy_path = os.path.join(density_dir, "ic_launcher.png")
            legacy_icon.save(legacy_path, "PNG")
            
            print(f"✅ Generated {density}: {size}x{size}")
        
        print("🎉 All Android icons generated successfully!")

if __name__ == "__main__":
    create_android_icons()