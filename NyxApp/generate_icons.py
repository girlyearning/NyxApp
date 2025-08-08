#!/usr/bin/env python3
import os
from PIL import Image

def generate_icons():
    # Open the source image
    source_path = '/Users/vct/MyCode/NyxApp/assets/images/app_launcher_icon.png'
    img = Image.open(source_path)
    
    print(f'Source image size: {img.size}')
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Android icon sizes needed
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72, 
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192
    }
    
    # Generate Android icons
    android_base = '/Users/vct/MyCode/NyxApp/android/app/src/main/res'
    for folder, size in android_sizes.items():
        # Resize image
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save to appropriate folder
        output_path = f'{android_base}/{folder}/ic_launcher.png'
        resized.save(output_path, 'PNG')
        print(f'Generated: {folder}/ic_launcher.png ({size}x{size})')
        
        # Also generate round icon
        output_path_round = f'{android_base}/{folder}/ic_launcher_round.png'
        resized.save(output_path_round, 'PNG')
        print(f'Generated: {folder}/ic_launcher_round.png ({size}x{size})')
    
    # iOS icon sizes needed
    ios_sizes = [
        ('Icon-App-20x20@1x.png', 20),
        ('Icon-App-20x20@2x.png', 40),
        ('Icon-App-20x20@3x.png', 60),
        ('Icon-App-29x29@1x.png', 29),
        ('Icon-App-29x29@2x.png', 58),
        ('Icon-App-29x29@3x.png', 87),
        ('Icon-App-40x40@1x.png', 40),
        ('Icon-App-40x40@2x.png', 80),
        ('Icon-App-40x40@3x.png', 120),
        ('Icon-App-60x60@2x.png', 120),
        ('Icon-App-60x60@3x.png', 180),
        ('Icon-App-76x76@1x.png', 76),
        ('Icon-App-76x76@2x.png', 152),
        ('Icon-App-83.5x83.5@2x.png', 167),
        ('Icon-App-1024x1024@1x.png', 1024)
    ]
    
    # Generate iOS icons
    ios_base = '/Users/vct/MyCode/NyxApp/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for filename, size in ios_sizes:
        # Resize image
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save to iOS folder
        output_path = f'{ios_base}/{filename}'
        resized.save(output_path, 'PNG')
        print(f'Generated: {filename} ({size}x{size})')
    
    # macOS icon sizes needed
    macos_sizes = [
        ('app_icon_16.png', 16),
        ('app_icon_32.png', 32),
        ('app_icon_64.png', 64),
        ('app_icon_128.png', 128),
        ('app_icon_256.png', 256),
        ('app_icon_512.png', 512),
        ('app_icon_1024.png', 1024)
    ]
    
    # Generate macOS icons
    macos_base = '/Users/vct/MyCode/NyxApp/macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for filename, size in macos_sizes:
        # Resize image
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save to macOS folder
        output_path = f'{macos_base}/{filename}'
        resized.save(output_path, 'PNG')
        print(f'Generated: {filename} ({size}x{size})')
    
    # Web icon sizes needed
    web_icons = [
        ('/Users/vct/MyCode/NyxApp/web/favicon.png', 192),
        ('/Users/vct/MyCode/NyxApp/web/icons/Icon-192.png', 192),
        ('/Users/vct/MyCode/NyxApp/web/icons/Icon-512.png', 512),
        ('/Users/vct/MyCode/NyxApp/web/icons/Icon-maskable-192.png', 192),
        ('/Users/vct/MyCode/NyxApp/web/icons/Icon-maskable-512.png', 512)
    ]
    
    # Generate Web icons
    for output_path, size in web_icons:
        # Resize image
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save web icon
        resized.save(output_path, 'PNG')
        print(f'Generated: {os.path.basename(output_path)} ({size}x{size})')

    print('✅ All icons generated successfully!')
    print('✅ Android icons: 10 files generated (5 regular + 5 round)')
    print('✅ iOS icons: 15 sizes generated')
    print('✅ macOS icons: 7 sizes generated')
    print('✅ Web icons: 5 sizes generated')

if __name__ == '__main__':
    generate_icons()