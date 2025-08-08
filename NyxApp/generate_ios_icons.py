#!/usr/bin/env python3
"""
Generate iOS app icons from the new icon image
"""

from PIL import Image
import os

def create_ios_icons():
    # Load the new icon
    icon_path = "new_app_icon.png"
    with Image.open(icon_path) as base_img:
        # Convert to RGBA first to handle transparency
        if base_img.mode != 'RGBA':
            base_img = base_img.convert('RGBA')
        
        # Create a function to generate properly sized and centered icons
        def create_sized_icon(target_size, padding_factor=0.85):
            # Calculate the icon size with padding (zoom out effect)
            icon_size = int(target_size * padding_factor)
            
            # Create sage green background (same as the icon background)
            result = Image.new('RGB', (target_size, target_size), (173, 207, 134))
            
            # Resize the icon
            resized_icon = base_img.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            
            # Center the icon
            x = (target_size - icon_size) // 2
            y = (target_size - icon_size) // 2
            
            # Paste the icon centered (using alpha channel if available)
            if resized_icon.mode == 'RGBA':
                result.paste(resized_icon, (x, y), resized_icon)
            else:
                result.paste(resized_icon, (x, y))
            
            return result
        
        # iOS icon sizes (actual pixel sizes)
        ios_sizes = [
            (20, 1),   # 20pt @1x
            (40, 2),   # 20pt @2x
            (60, 3),   # 20pt @3x
            (29, 1),   # 29pt @1x
            (58, 2),   # 29pt @2x
            (87, 3),   # 29pt @3x
            (40, 1),   # 40pt @1x
            (80, 2),   # 40pt @2x
            (120, 3),  # 40pt @3x
            (50, 1),   # 50pt @1x
            (100, 2),  # 50pt @2x
            (57, 1),   # 57pt @1x
            (114, 2),  # 57pt @2x
            (120, 2),  # 60pt @2x
            (180, 3),  # 60pt @3x
            (72, 1),   # 72pt @1x
            (144, 2),  # 72pt @2x
            (76, 1),   # 76pt @1x
            (152, 2),  # 76pt @2x
            (167, 2),  # 83.5pt @2x
            (1024, 1), # 1024pt @1x
        ]
        
        ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
        
        print("🍎 Generating iOS icons...")
        
        for size, scale in ios_sizes:
            # Calculate point size
            point_size = size // scale if scale > 1 else size
            
            # Create icon with proper centering and zoom
            ios_icon = create_sized_icon(size, padding_factor=0.75)
            
            # Determine filename
            if scale == 1:
                filename = f"Icon-App-{point_size}x{point_size}@1x.png"
            else:
                if point_size == 83:  # Special case for 83.5
                    filename = f"Icon-App-83.5x83.5@2x.png"
                else:
                    filename = f"Icon-App-{point_size}x{point_size}@{scale}x.png"
            
            # Save icon
            icon_path = os.path.join(ios_dir, filename)
            ios_icon.save(icon_path, "PNG")
            
            print(f"✅ Generated {filename}: {size}x{size}")
        
        print("🎉 All iOS icons generated successfully!")

if __name__ == "__main__":
    create_ios_icons()