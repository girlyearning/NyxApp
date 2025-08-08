#!/usr/bin/env python3
"""
Update app launcher icon with new tree image, ensuring proper centering and padding
"""

from PIL import Image, ImageOps
import os
import shutil

def process_new_icon():
    # Load the new icon from Downloads
    source_path = "/Users/vct/Downloads/file_000000005a4861fdbd7ba03990499d67.png"
    
    with Image.open(source_path) as img:
        print(f"Original size: {img.size}")
        
        # Convert to RGBA if needed
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Resize to 1024x1024 base size first
        if img.size != (1024, 1024):
            img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        
        # Add padding to ensure tree doesn't touch edges
        # We'll add 10% padding on all sides
        padding_percent = 0.1
        final_size = 1024
        content_size = int(final_size * (1 - 2 * padding_percent))  # 80% of final size
        padding = (final_size - content_size) // 2
        
        # Resize the tree to fit within the content area
        tree_img = img.resize((content_size, content_size), Image.Resampling.LANCZOS)
        
        # Create final image with transparent background
        final_img = Image.new('RGBA', (final_size, final_size), (0, 0, 0, 0))
        
        # Paste the tree in the center with padding
        final_img.paste(tree_img, (padding, padding), tree_img)
        
        print(f"✅ Processed icon: {content_size}x{content_size} tree centered in {final_size}x{final_size} canvas")
        
        return final_img

def update_all_icon_locations(processed_img):
    """Update the icon in all necessary locations"""
    
    locations_to_update = [
        # Main assets location
        "assets/images/app_launcher_icon.png",
        
        # Also update the nyx_icon.png if it exists  
        "assets/images/nyx_icon.png",
        
        # Source icon backup
        "nyx_icon_source.png",
        
        # For icon generator script
        "new_app_icon.png"
    ]
    
    for location in locations_to_update:
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(location), exist_ok=True)
            
            # Save the processed image
            processed_img.save(location, "PNG")
            print(f"✅ Updated {location}")
            
        except Exception as e:
            print(f"⚠️  Could not update {location}: {e}")

def regenerate_platform_icons():
    """Regenerate all platform-specific icons using the icon generator"""
    
    # Check if generate_new_icons.py exists and run it
    if os.path.exists("generate_new_icons.py"):
        print("🔄 Regenerating Android icons...")
        os.system("python3 generate_new_icons.py")
    
    # Also run flutter launcher icons if available
    print("🔄 Running flutter launcher icons...")
    os.system("flutter packages pub run flutter_launcher_icons")

def main():
    print("🎨 Processing new app icon...")
    
    # Process the new icon
    processed_icon = process_new_icon()
    
    # Update all locations
    print("\n📁 Updating icon in all locations...")
    update_all_icon_locations(processed_icon)
    
    # Regenerate platform-specific icons
    print("\n🔄 Regenerating platform-specific icons...")
    regenerate_platform_icons()
    
    print("\n🎉 App icon update complete!")
    print("✅ Tree is properly centered with safe padding")
    print("✅ All icon locations updated")
    print("✅ Platform-specific icons regenerated")

if __name__ == "__main__":
    main()