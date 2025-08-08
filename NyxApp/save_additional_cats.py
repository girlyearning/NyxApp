#!/usr/bin/env python3
import os
import base64
from PIL import Image
import io

def save_cat_image(image_data, filename):
    """Save base64 image data as PNG file"""
    try:
        # Decode base64 image data
        image_bytes = base64.b64decode(image_data)
        
        # Open image and convert to RGBA
        img = Image.open(io.BytesIO(image_bytes))
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Resize to consistent size for game
        img = img.resize((48, 48), Image.Resampling.LANCZOS)
        
        # Save as PNG
        img.save(filename, 'PNG')
        print(f"Saved: {filename}")
        
    except Exception as e:
        print(f"Error saving {filename}: {e}")

def main():
    output_dir = "/Users/vct/MyCode/NyxApp/assets/images/cats"
    
    # Placeholder - these would be the actual base64 data from the images
    # For now, I'll create simple cat placeholders since I can't access the actual image data
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Since I can't directly access the image data from the conversation,
    # I'll create simple colored cat placeholders for now
    colors = [
        '#FF6B35', '#F7931E', '#FFD23F', '#06FFA5', '#118AB2',
        '#073B4C', '#EF476F', '#FFD166', '#06D6A0', '#118AB2',
        '#8E44AD', '#E74C3C', '#3498DB', '#2ECC71', '#F39C12',
        '#9B59B6'
    ]
    
    for i, color in enumerate(colors, start=17):
        if i > 32:  # Only create up to cat32
            break
            
        # Create a simple colored circle as placeholder
        img = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
        
        # Draw a simple cat face placeholder
        from PIL import ImageDraw
        draw = ImageDraw.Draw(img)
        
        # Convert hex color to RGB
        color_rgb = tuple(int(color[1:][j:j+2], 16) for j in (0, 2, 4))
        
        # Draw cat face circle
        draw.ellipse([4, 4, 44, 44], fill=color_rgb + (255,))
        
        # Draw ears
        draw.polygon([(12, 8), (20, 2), (24, 12)], fill=color_rgb + (255,))
        draw.polygon([(24, 12), (28, 2), (36, 8)], fill=color_rgb + (255,))
        
        # Draw eyes
        draw.ellipse([14, 18, 18, 22], fill=(0, 0, 0, 255))
        draw.ellipse([30, 18, 34, 22], fill=(0, 0, 0, 255))
        
        # Draw nose
        draw.polygon([(24, 26), (22, 30), (26, 30)], fill=(255, 192, 203, 255))
        
        filename = os.path.join(output_dir, f'cat{i}.png')
        img.save(filename, 'PNG')
        print(f"Created placeholder: cat{i}.png")

if __name__ == "__main__":
    main()