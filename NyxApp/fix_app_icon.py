#!/usr/bin/env python3
"""
Fix app icon by creating clean foreground image without gray borders
"""
from PIL import Image
import os

def create_clean_foreground():
    """Remove gray borders and create clean foreground image"""
    
    # Load the original icon
    original_path = "assets/images/app_launcher_icon.png"
    if not os.path.exists(original_path):
        print(f"Error: {original_path} not found")
        return False
    
    # Open the image
    img = Image.open(original_path).convert("RGBA")
    width, height = img.size
    print(f"Original image size: {width}x{height}")
    
    # The tree appears to be centered in the image
    # We need to crop out the gray borders and keep just the green area with the tree
    
    # Create a new image with transparent background
    # Based on the visual, the green area starts roughly 10% in and ends 90% 
    crop_margin = int(width * 0.08)  # 8% margin to remove gray borders
    
    # Crop to remove gray borders
    cropped = img.crop((crop_margin, crop_margin, width - crop_margin, height - crop_margin))
    
    # Create final foreground image at 1024x1024 (standard app icon size)
    foreground_size = 1024
    foreground = Image.new("RGBA", (foreground_size, foreground_size), (0, 0, 0, 0))
    
    # Resize cropped image to fit with some padding for safe area
    # Android adaptive icons use 66% of the image as safe area
    safe_area = int(foreground_size * 0.66)
    cropped_resized = cropped.resize((safe_area, safe_area), Image.Resampling.LANCZOS)
    
    # Center the image
    x_offset = (foreground_size - safe_area) // 2
    y_offset = (foreground_size - safe_area) // 2
    
    foreground.paste(cropped_resized, (x_offset, y_offset), cropped_resized)
    
    # Save the clean foreground image
    foreground_path = "assets/images/app_icon_foreground.png"
    foreground.save(foreground_path, "PNG")
    print(f"Created clean foreground image: {foreground_path}")
    
    # Also create a background image with just the green color
    # Extract the dominant green color from the original
    green_color = (106, 190, 175, 255)  # The teal/green color from the icon
    background = Image.new("RGBA", (foreground_size, foreground_size), green_color)
    
    background_path = "assets/images/app_icon_background.png"
    background.save(background_path, "PNG")
    print(f"Created background image: {background_path}")
    
    return True

if __name__ == "__main__":
    if create_clean_foreground():
        print("Successfully created clean app icon assets!")
    else:
        print("Failed to create app icon assets.")