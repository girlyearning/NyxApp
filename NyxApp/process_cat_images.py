#!/usr/bin/env python3
import os
from PIL import Image
import glob

def make_transparent_and_resize(input_path, output_path, size=(48, 48)):
    """
    Process image: make white background transparent and resize
    """
    try:
        # Open the image
        img = Image.open(input_path)
        
        # Convert to RGBA if not already
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Get image data
        data = img.getdata()
        new_data = []
        
        # Make white (and near-white) pixels transparent
        for item in data:
            # Check if pixel is white or near-white (allowing for slight variations)
            if len(item) >= 3:
                r, g, b = item[0], item[1], item[2]
                if r > 240 and g > 240 and b > 240:  # White or near-white
                    new_data.append((r, g, b, 0))  # Transparent
                else:
                    if len(item) == 4:
                        new_data.append(item)  # Keep original alpha
                    else:
                        new_data.append((r, g, b, 255))  # Fully opaque
            else:
                new_data.append(item)
        
        # Update image data
        img.putdata(new_data)
        
        # Resize to target size using nearest neighbor for pixel art
        img = img.resize(size, Image.NEAREST)
        
        # Save as PNG
        img.save(output_path, 'PNG')
        print(f"Processed: {input_path} -> {output_path}")
        
    except Exception as e:
        print(f"Error processing {input_path}: {e}")

def main():
    # Input directory (Downloads folder)
    input_dir = "/Users/vct/Downloads"
    
    # Output directory (NyxApp cats folder)
    output_dir = "/Users/vct/MyCode/NyxApp/assets/images/cats"
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # List of input files (based on your provided list)
    input_files = [
        "b0e76d12-48ea-4a44-a289-d3d1b6069a1d.jpeg",
        "8cdedc8a-202c-43b5-96a4-98506d1bae64.jpeg", 
        "cat laying down from stardew valley _3.jpeg",
        "c5d597de-d50c-4d08-99c6-b44da53d1010.jpeg",
        "182ff066-880c-4ecd-a27d-8e8344e7c6ff.jpeg",
        "0c027e01-addf-464b-bf54-9657fa120451.jpeg",
        "b6ab2e30-6b9d-4b97-8929-ba7b08d82c2e.jpeg",
        "بكسل ارت_بيكسل ارت_Pixel Art.jpeg",
        "▞      🫀     ☆      𝗛𝗬𝗨𝗝𝗜𝗡          ⊃ο_      🤟🏻.jpeg",
        "489ba2a5-15bd-4755-b55b-ac25753222b9.jpeg",
        "f3b6934b-c632-4051-a67c-2bc63a9b6a31.jpeg",
        "Cute Pixel Black Cat - Digital Download _ Retro Style Kitty Clipart for Stickers, Planner, Crafts.jpeg",
        "d21029ce-e3cb-4187-b4e2-b6213ac45235.jpeg",
        "Nyan Cat Pixel Art YouTube Tenor PNG.jpeg",
        "ecdb830e-11bf-4c10-a862-30cbae979459.jpeg",
        "f5e86262-047f-486b-ae80-6e356944f67b.gif"
    ]
    
    # Process each file
    processed_count = 0
    for i, filename in enumerate(input_files, 1):
        if processed_count >= 15:  # Only process first 15 images
            break
            
        input_path = os.path.join(input_dir, filename)
        
        if os.path.exists(input_path):
            output_filename = f"cat{i}.png"
            output_path = os.path.join(output_dir, output_filename)
            
            make_transparent_and_resize(input_path, output_path)
            processed_count += 1
        else:
            print(f"File not found: {input_path}")
    
    print(f"\nProcessed {processed_count} cat images for Kitty Katch game!")

if __name__ == "__main__":
    main()