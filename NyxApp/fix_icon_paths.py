#!/usr/bin/env python3
"""
Fix icon paths and ensure all locations are properly updated
"""

from PIL import Image
import os
import shutil

def fix_icon_paths():
    # Source the properly processed icon
    main_icon_path = "assets/images/app_launcher_icon.png"
    
    if not os.path.exists(main_icon_path):
        print(f"❌ Main icon not found at {main_icon_path}")
        return False
    
    with Image.open(main_icon_path) as img:
        # Create all the missing files in the root directory
        root_files = [
            "nyx_icon_source.png",
            "new_app_icon.png"
        ]
        
        for file_path in root_files:
            img.save(file_path, "PNG")
            print(f"✅ Created {file_path}")
    
    return True

def update_pubspec_paths():
    """Ensure pubspec.yaml points to the correct icon path"""
    pubspec_path = "pubspec.yaml"
    
    try:
        with open(pubspec_path, 'r') as f:
            content = f.read()
        
        # Make sure all paths point to our updated icon
        icon_path = "assets/images/app_launcher_icon.png"
        
        # Update the flutter_launcher_icons section
        lines = content.split('\n')
        updated_lines = []
        in_launcher_icons = False
        
        for line in lines:
            if 'flutter_launcher_icons:' in line:
                in_launcher_icons = True
            elif line.startswith('  ') and in_launcher_icons:
                if 'image_path:' in line and 'adaptive_icon_foreground:' not in line:
                    line = f'  image_path: "{icon_path}"'
                elif 'adaptive_icon_foreground:' in line:
                    line = f'  adaptive_icon_foreground: "{icon_path}"'
            elif not line.startswith('  ') and line.strip():
                in_launcher_icons = False
            
            updated_lines.append(line)
        
        # Write back the updated content
        with open(pubspec_path, 'w') as f:
            f.write('\n'.join(updated_lines))
        
        print(f"✅ Updated {pubspec_path} with correct icon paths")
        return True
        
    except Exception as e:
        print(f"⚠️  Could not update {pubspec_path}: {e}")
        return False

def main():
    print("🔧 Fixing icon paths and ensuring consistency...")
    
    # Fix missing icon files
    if fix_icon_paths():
        print("✅ All icon files created")
    
    # Update pubspec.yaml
    update_pubspec_paths()
    
    # Now try to regenerate icons again
    print("\n🔄 Regenerating icons with fixed paths...")
    
    try:
        # Run the icon generators
        if os.path.exists("generate_new_icons.py"):
            os.system("python3 generate_new_icons.py")
        
        os.system("flutter packages pub run flutter_launcher_icons")
        print("✅ Icons regenerated successfully")
        
    except Exception as e:
        print(f"⚠️  Icon generation issue: {e}")
    
    print("\n🎉 Icon path fixes complete!")

if __name__ == "__main__":
    main()