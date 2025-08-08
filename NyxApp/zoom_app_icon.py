#!/usr/bin/env python3
"""
Zoom in the app launcher icon by reducing padding and making the tree larger
"""

from PIL import Image
import os

def zoom_app_icon():
    """Make the app launcher icon more zoomed in by reducing padding"""
    
    # Load the current app launcher icon
    source_path = "assets/images/app_launcher_icon.png"
    
    print(f"📱 Loading current app icon from: {source_path}")
    
    with Image.open(source_path) as img:
        print(f"Original size: {img.size}")
        
        # Convert to RGBA if needed
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Get the current size
        current_size = img.size[0]  # Assuming square
        
        # Create a larger version of the tree content
        # Instead of the current padding, we'll use much less padding
        # Current appears to have ~15-20% padding, we'll reduce to ~5% padding
        
        # Calculate the zoom factor to make the tree larger
        # We want to crop the center portion and scale it up
        crop_factor = 0.75  # Use 75% of the center area
        crop_size = int(current_size * crop_factor)
        
        # Calculate crop box to center the crop
        left = (current_size - crop_size) // 2
        top = (current_size - crop_size) // 2
        right = left + crop_size
        bottom = top + crop_size
        
        # Crop the center portion
        cropped_img = img.crop((left, top, right, bottom))
        
        # Scale the cropped image back to the original size
        # This effectively "zooms in" on the tree
        zoomed_img = cropped_img.resize((current_size, current_size), Image.Resampling.LANCZOS)
        
        print(f"✅ Zoomed in app icon: cropped {crop_factor*100:.0f}% of center and scaled back up")
        
        return zoomed_img

def update_app_launcher_icon(zoomed_img):
    """Update the app launcher icon file"""
    
    # Save the zoomed version
    output_path = "assets/images/app_launcher_icon.png"
    
    # Create backup of original
    backup_path = "assets/images/app_launcher_icon_backup.png"
    if os.path.exists(output_path) and not os.path.exists(backup_path):
        # Only create backup if it doesn't exist already
        original = Image.open(output_path)
        original.save(backup_path, "PNG")
        print(f"📁 Created backup: {backup_path}")
    
    # Save the new zoomed version
    zoomed_img.save(output_path, "PNG")
    print(f"✅ Updated {output_path} with zoomed in version")

def regenerate_all_platform_icons():
    """Regenerate all platform-specific icons using the existing generator"""
    
    print("\n🔄 Regenerating all platform-specific icons...")
    
    # Use the existing generate_icons.py script
    if os.path.exists("generate_icons.py"):
        os.system("python3 generate_icons.py")
        print("✅ All platform icons regenerated")
    else:
        print("⚠️  generate_icons.py not found - platform icons not regenerated")

def main():
    print("🔍 Zooming in app launcher icon...")
    
    # Create zoomed version
    zoomed_icon = zoom_app_icon()
    
    # Update the main app launcher icon
    print("\n📁 Updating app launcher icon...")
    update_app_launcher_icon(zoomed_icon)
    
    # Regenerate all platform-specific icons with the new zoomed version
    regenerate_all_platform_icons()
    
    print("\n🎉 App icon zoom complete!")
    print("✅ App launcher icon is now more zoomed in")
    print("✅ All platform-specific icons regenerated")
    print("✅ Original backed up as app_launcher_icon_backup.png")

if __name__ == "__main__":
    main()