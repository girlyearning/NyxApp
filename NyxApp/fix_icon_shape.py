#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFilter

def create_properly_shaped_icon():
    # Open the source image
    source_path = '/Users/vct/MyCode/Nyx/nyx_app/nyx_icon_source.png'
    img = Image.open(source_path)
    
    print(f'Creating properly shaped icons from: {img.size}')
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Android icon sizes
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72, 
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    android_base = '/Users/vct/MyCode/Nyx/nyx_app/android/app/src/main/res'
    
    for folder, size in android_sizes.items():
        # Method 1: Create icon with rounded corners manually
        # This ensures it looks rounded even on devices that don't support adaptive icons
        
        # Create a mask for rounded corners
        mask = Image.new('L', (size, size), 0)
        draw = ImageDraw.Draw(mask)
        
        # Draw rounded rectangle (22% corner radius is standard for Android)
        corner_radius = int(size * 0.22)
        draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=255)
        
        # Resize your icon
        icon_resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Create output image with transparent background
        output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        
        # Apply the rounded mask
        icon_with_mask = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        icon_with_mask.paste(icon_resized, (0, 0))
        
        # Apply rounded corners by using the mask
        result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        result.paste(icon_with_mask, (0, 0))
        result.putalpha(mask)
        
        # Save the rounded icon
        output_path = f'{android_base}/{folder}/ic_launcher.png'
        result.save(output_path, 'PNG')
        print(f'Generated rounded icon: {folder}/ic_launcher.png ({size}x{size})')
    
    print('✅ Icons with forced rounded corners generated!')
    print('✅ These will look rounded even on older Android versions!')

if __name__ == '__main__':
    create_properly_shaped_icon()