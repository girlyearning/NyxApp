#!/usr/bin/env python3
"""
Generate 12 different pixelated cat icons for Kitty Katch game.
Each cat has a unique color scheme and slight design variation.
"""

from PIL import Image, ImageDraw
import os

# Define cat designs with poses
CAT_DESIGNS = [
    {
        'name': 'tabby',
        'colors': {'primary': '#8B4513', 'secondary': '#D2B48C', 'accent': '#654321'},
        'pattern': 'stripes',
        'pose': 'sitting'
    },
    {
        'name': 'siamese',
        'colors': {'primary': '#F5DEB3', 'secondary': '#8B4513', 'accent': '#4169E1'},
        'pattern': 'points',
        'pose': 'walking'
    },
    {
        'name': 'black',
        'colors': {'primary': '#2F2F2F', 'secondary': '#4A4A4A', 'accent': '#FFD700'},
        'pattern': 'solid',
        'pose': 'stretching'
    },
    {
        'name': 'ginger',
        'colors': {'primary': '#FF6347', 'secondary': '#FF7F50', 'accent': '#32CD32'},
        'pattern': 'solid',
        'pose': 'laying_down'
    },
    {
        'name': 'calico',
        'colors': {'primary': '#FFFFFF', 'secondary': '#FF6347', 'accent': '#2F2F2F'},
        'pattern': 'patches',
        'pose': 'portrait'
    },
    {
        'name': 'gray',
        'colors': {'primary': '#708090', 'secondary': '#C0C0C0', 'accent': '#32CD32'},
        'pattern': 'solid',
        'pose': 'sitting'
    },
    {
        'name': 'tuxedo',
        'colors': {'primary': '#2F2F2F', 'secondary': '#FFFFFF', 'accent': '#32CD32'},
        'pattern': 'tuxedo',
        'pose': 'walking'
    },
    {
        'name': 'persian',
        'colors': {'primary': '#F5F5DC', 'secondary': '#DDDDDD', 'accent': '#FF69B4'},
        'pattern': 'fluffy',
        'pose': 'laying_down'
    },
    {
        'name': 'russian_blue',
        'colors': {'primary': '#4682B4', 'secondary': '#87CEEB', 'accent': '#FFD700'},
        'pattern': 'solid',
        'pose': 'portrait'
    },
    {
        'name': 'maine_coon',
        'colors': {'primary': '#8B4513', 'secondary': '#F4A460', 'accent': '#32CD32'},
        'pattern': 'fluffy',
        'pose': 'stretching'
    },
    {
        'name': 'bengal',
        'colors': {'primary': '#CD853F', 'secondary': '#DEB887', 'accent': '#228B22'},
        'pattern': 'spots',
        'pose': 'walking'
    },
    {
        'name': 'white',
        'colors': {'primary': '#FFFFFF', 'secondary': '#F8F8FF', 'accent': '#FF1493'},
        'pattern': 'solid',
        'pose': 'sitting'
    }
]

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_cat_sprite(colors, pattern, pose, size=32):
    """Create a pixelated cat sprite with different poses."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    primary = hex_to_rgb(colors['primary'])
    secondary = hex_to_rgb(colors['secondary'])
    accent = hex_to_rgb(colors['accent'])
    
    if pose == 'sitting':
        return create_sitting_cat(draw, primary, secondary, accent, pattern, size)
    elif pose == 'walking':
        return create_walking_cat(draw, primary, secondary, accent, pattern, size)
    elif pose == 'laying_down':
        return create_laying_cat(draw, primary, secondary, accent, pattern, size)
    elif pose == 'stretching':
        return create_stretching_cat(draw, primary, secondary, accent, pattern, size)
    elif pose == 'portrait':
        return create_portrait_cat(draw, primary, secondary, accent, pattern, size)
    
    # Scale up for better visibility (32x32 -> 64x64)
    img = img.resize((64, 64), Image.NEAREST)
    return img

def create_sitting_cat(draw, primary, secondary, accent, pattern, size):
    """Create a realistic sitting cat sprite."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Head (more detailed oval)
    head_pixels = []
    for x in range(11, 21):
        for y in range(6, 15):
            # Create oval head shape
            dx = x - 16  # Center at x=16
            dy = y - 10  # Center at y=10
            if (dx*dx/16 + dy*dy/9) <= 1:
                head_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Detailed ears with inner ear
    # Left ear
    ear_left = [(12, 4), (13, 4), (14, 4), (11, 5), (12, 5), (13, 5), (14, 5), (15, 5), 
                (12, 6), (13, 6), (14, 6)]
    # Right ear
    ear_right = [(17, 5), (18, 5), (19, 5), (20, 5), (21, 5), (18, 4), (19, 4), (20, 4),
                 (18, 6), (19, 6), (20, 6)]
    
    for pixel in ear_left + ear_right:
        draw.point(pixel, primary)
    
    # Inner ears (lighter color)
    draw.point((13, 5), secondary)
    draw.point((19, 5), secondary)
    
    # Body (more cat-like proportions)
    body_pixels = []
    # Chest area
    for x in range(13, 19):
        for y in range(14, 18):
            body_pixels.append((x, y))
            draw.point((x, y), primary)
    
    # Main body (wider)
    for x in range(10, 22):
        for y in range(18, 25):
            if y < 22 or (x > 12 and x < 20):
                body_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Front legs with paws
    # Left front leg
    for y in range(22, 26):
        draw.point((12, y), primary)
        draw.point((13, y), primary)
    # Left paw
    draw.point((11, 25), primary)
    draw.point((14, 25), primary)
    
    # Right front leg
    for y in range(22, 26):
        draw.point((18, y), primary)
        draw.point((19, y), primary)
    # Right paw
    draw.point((17, 25), primary)
    draw.point((20, 25), primary)
    
    # Back legs (partially visible)
    for y in range(20, 24):
        draw.point((11, y), primary)
        draw.point((20, y), primary)
    
    # Detailed curled tail
    tail_pixels = [(22, 16), (23, 15), (24, 14), (25, 13), (26, 12), (26, 11), (25, 10), (24, 10), (23, 11)]
    for pixel in tail_pixels:
        draw.point(pixel, primary)
    
    # Apply pattern to all cat pixels
    all_pixels = head_pixels + body_pixels + ear_left + ear_right + tail_pixels
    apply_pattern(draw, pattern, secondary, all_pixels)
    
    # Detailed eyes with pupils and highlights
    # Left eye
    draw.point((13, 9), (0, 0, 0))      # Pupil
    draw.point((13, 8), accent)         # Eye color
    draw.point((14, 9), accent)         # Eye color
    draw.point((13, 8), (255, 255, 255)) # Highlight
    
    # Right eye
    draw.point((19, 9), (0, 0, 0))      # Pupil
    draw.point((19, 8), accent)         # Eye color
    draw.point((18, 9), accent)         # Eye color
    draw.point((19, 8), (255, 255, 255)) # Highlight
    
    # Nose (more detailed)
    draw.point((15, 11), (255, 105, 180))  # Dark pink
    draw.point((16, 11), (255, 105, 180))
    draw.point((15, 12), (255, 182, 193))  # Light pink
    draw.point((16, 12), (255, 182, 193))
    
    # Mouth
    draw.point((14, 13), (0, 0, 0))
    draw.point((15, 13), (0, 0, 0))
    draw.point((16, 13), (0, 0, 0))
    draw.point((17, 13), (0, 0, 0))
    
    # Whiskers
    draw.point((10, 10), (255, 255, 255))
    draw.point((9, 11), (255, 255, 255))
    draw.point((22, 10), (255, 255, 255))
    draw.point((23, 11), (255, 255, 255))
    
    img = img.resize((64, 64), Image.NEAREST)
    return img

def create_walking_cat(draw, primary, secondary, accent, pattern, size):
    """Create a realistic walking cat sprite."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Head (profile view, more detailed)
    head_pixels = []
    for x in range(4, 11):
        for y in range(10, 17):
            # Create rounded head profile
            if ((x-7)**2 + (y-13)**2) <= 9:
                head_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Detailed ears (profile view)
    ear_pixels = [(6, 8), (7, 8), (8, 8), (5, 9), (6, 9), (7, 9), (8, 9), (9, 9),
                  (6, 10), (7, 10), (8, 10)]
    for pixel in ear_pixels:
        draw.point(pixel, primary)
    
    # Inner ear
    draw.point((7, 9), secondary)
    
    # Muzzle (extended forward)
    muzzle_pixels = [(3, 14), (4, 14), (3, 15), (4, 15)]
    for pixel in muzzle_pixels:
        head_pixels.append(pixel)
        draw.point(pixel, primary)
    
    # Body (elongated, walking posture)
    body_pixels = []
    for x in range(11, 24):
        for y in range(12, 18):
            if y >= 14 or (x < 18):  # Slightly arched back
                body_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Detailed walking legs
    # Front left leg (lifted)
    for y in range(16, 19):
        draw.point((13, y), primary)
    draw.point((12, 18), primary)  # Paw
    draw.point((14, 18), primary)
    
    # Front right leg (down)
    for y in range(18, 22):
        draw.point((16, y), primary)
    draw.point((15, 21), primary)  # Paw
    draw.point((17, 21), primary)
    
    # Back left leg (down)
    for y in range(18, 22):
        draw.point((19, y), primary)
    draw.point((18, 21), primary)  # Paw
    draw.point((20, 21), primary)
    
    # Back right leg (lifted)
    for y in range(16, 19):
        draw.point((22, y), primary)
    draw.point((21, 18), primary)  # Paw
    draw.point((23, 18), primary)
    
    # Curved tail (motion)
    tail_pixels = [(24, 14), (25, 13), (26, 12), (27, 11), (28, 10), (29, 11), (30, 12)]
    for pixel in tail_pixels:
        draw.point(pixel, primary)
    
    # Apply patterns
    all_pixels = head_pixels + body_pixels + ear_pixels + muzzle_pixels + tail_pixels
    apply_pattern(draw, pattern, secondary, all_pixels)
    
    # Profile eye (single eye visible)
    draw.point((6, 12), accent)         # Eye color
    draw.point((6, 13), accent)
    draw.point((5, 12), (0, 0, 0))      # Pupil
    draw.point((6, 12), (255, 255, 255)) # Highlight
    
    # Nose (profile)
    draw.point((3, 14), (255, 105, 180))
    draw.point((2, 15), (255, 105, 180))
    
    # Whiskers
    draw.point((1, 13), (255, 255, 255))
    draw.point((0, 14), (255, 255, 255))
    draw.point((1, 15), (255, 255, 255))
    
    img = img.resize((64, 64), Image.NEAREST)
    return img

def create_laying_cat(draw, primary, secondary, accent, pattern, size):
    """Create a realistic laying down cat sprite."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Head (resting on side, detailed)
    head_pixels = []
    for x in range(6, 13):
        for y in range(14, 19):
            # Create rounded head lying down
            if ((x-9)**2 + (y-16)**2) <= 6:
                head_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Ears (laying position)
    ear_pixels = [(8, 12), (9, 12), (10, 12), (7, 13), (8, 13), (9, 13), (10, 13), (11, 13),
                  (8, 14), (9, 14), (10, 14)]
    for pixel in ear_pixels:
        draw.point(pixel, primary)
    
    # Inner ears
    draw.point((9, 13), secondary)
    draw.point((10, 13), secondary)
    
    # Body (long and low, relaxed posture)
    body_pixels = []
    for x in range(13, 28):
        for y in range(16, 20):
            if x < 20 or y >= 17:  # Belly curve
                body_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Legs (folded/tucked under body)
    leg_pixels = []
    # Front legs (folded)
    for x in range(15, 17):
        draw.point((x, 19), primary)
        leg_pixels.append((x, 19))
    draw.point((14, 20), primary)  # Paw
    draw.point((17, 20), primary)  # Paw
    
    # Back legs (tucked)
    for x in range(22, 24):
        draw.point((x, 19), primary)
        leg_pixels.append((x, 19))
    draw.point((21, 20), primary)  # Paw
    draw.point((24, 20), primary)  # Paw
    
    # Detailed curled tail (wrapped around body)
    tail_pixels = [(27, 17), (28, 16), (29, 15), (30, 14), (30, 13), (29, 12), (28, 11),
                   (27, 11), (26, 11), (25, 12), (24, 12), (23, 13), (22, 14)]
    for pixel in tail_pixels:
        draw.point(pixel, primary)
    
    # Apply patterns
    all_pixels = head_pixels + body_pixels + ear_pixels + leg_pixels + tail_pixels
    apply_pattern(draw, pattern, secondary, all_pixels)
    
    # Sleepy/relaxed eyes
    draw.point((8, 15), accent)         # Left eye
    draw.point((7, 15), (0, 0, 0))      # Pupil (half-closed)
    draw.point((8, 15), (255, 255, 255)) # Highlight
    
    # Only one eye visible in laying position
    
    # Nose
    draw.point((6, 16), (255, 105, 180))
    draw.point((5, 17), (255, 105, 180))
    
    # Relaxed whiskers
    draw.point((4, 15), (255, 255, 255))
    draw.point((3, 16), (255, 255, 255))
    draw.point((4, 17), (255, 255, 255))
    
    img = img.resize((64, 64), Image.NEAREST)
    return img

def create_stretching_cat(draw, primary, secondary, accent, pattern, size):
    """Create a realistic stretching cat sprite."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Head (lowered in stretch position)
    head_pixels = []
    for x in range(4, 11):
        for y in range(18, 23):
            # Create rounded head
            if ((x-7)**2 + (y-20)**2) <= 6:
                head_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Ears (alert during stretch)
    ear_pixels = [(6, 16), (7, 16), (8, 16), (5, 17), (6, 17), (7, 17), (8, 17), (9, 17),
                  (6, 18), (7, 18), (8, 18)]
    for pixel in ear_pixels:
        draw.point(pixel, primary)
    
    # Inner ears
    draw.point((7, 17), secondary)
    
    # Body (dramatic arch for stretching)
    body_pixels = []
    # Front body (low)
    for x in range(11, 18):
        for y in range(16, 20):
            if y >= 18 or x < 15:  # Curved down
                body_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Arched middle
    for x in range(18, 25):
        y_offset = int(2 * abs((x-21.5)/3.5))  # Create arch
        for y in range(12 - y_offset, 16 - y_offset):
            body_pixels.append((x, y))
            draw.point((x, y), primary)
    
    # Rear body (elevated)
    for x in range(25, 30):
        for y in range(14, 18):
            body_pixels.append((x, y))
            draw.point((x, y), primary)
    
    # Front legs (extended forward in stretch)
    leg_pixels = []
    # Left front leg
    for y in range(20, 25):
        draw.point((6, y), primary)
        leg_pixels.append((6, y))
    for x in range(4, 8):
        draw.point((x, 24), primary)  # Extended paw
        leg_pixels.append((x, 24))
    
    # Right front leg
    for y in range(20, 25):
        draw.point((9, y), primary)
        leg_pixels.append((9, y))
    for x in range(7, 11):
        draw.point((x, 24), primary)  # Extended paw
        leg_pixels.append((x, 24))
    
    # Back legs (supporting stretch)
    for y in range(18, 22):
        draw.point((27, y), primary)
        draw.point((29, y), primary)
        leg_pixels.extend([(27, y), (29, y)])
    
    # Paws
    draw.point((26, 21), primary)
    draw.point((28, 21), primary)
    draw.point((30, 21), primary)
    
    # Tail (raised high during stretch)
    tail_pixels = [(29, 12), (30, 11), (31, 10), (31, 9), (30, 8), (29, 7), (28, 6)]
    for pixel in tail_pixels:
        draw.point(pixel, primary)
    
    # Apply patterns
    all_pixels = head_pixels + body_pixels + ear_pixels + leg_pixels + tail_pixels
    apply_pattern(draw, pattern, secondary, all_pixels)
    
    # Eyes (focused/alert during stretch)
    draw.point((6, 19), accent)         # Eye color
    draw.point((5, 19), (0, 0, 0))      # Pupil
    draw.point((6, 19), (255, 255, 255)) # Highlight
    
    # Nose
    draw.point((4, 21), (255, 105, 180))
    draw.point((3, 21), (255, 105, 180))
    
    # Whiskers (extended during focus)
    draw.point((2, 19), (255, 255, 255))
    draw.point((1, 20), (255, 255, 255))
    draw.point((2, 21), (255, 255, 255))
    
    img = img.resize((64, 64), Image.NEAREST)
    return img

def create_portrait_cat(draw, primary, secondary, accent, pattern, size):
    """Create a realistic portrait cat sprite (face forward)."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Head (large, detailed oval facing forward)
    head_pixels = []
    for x in range(8, 24):
        for y in range(6, 20):
            # Create large oval head
            dx = x - 16  # Center at x=16
            dy = y - 13  # Center at y=13
            if (dx*dx/49 + dy*dy/36) <= 1:
                head_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Detailed ears (both visible, facing forward)
    # Left ear
    left_ear = [(11, 4), (12, 4), (13, 4), (14, 4), (10, 5), (11, 5), (12, 5), (13, 5), (14, 5), (15, 5),
                (11, 6), (12, 6), (13, 6), (14, 6)]
    # Right ear
    right_ear = [(17, 5), (18, 5), (19, 5), (20, 5), (21, 5), (22, 5), (18, 4), (19, 4), (20, 4), (21, 4),
                 (18, 6), (19, 6), (20, 6), (21, 6)]
    
    ear_pixels = left_ear + right_ear
    for pixel in ear_pixels:
        draw.point(pixel, primary)
    
    # Inner ears (pink)
    draw.point((12, 5), secondary)
    draw.point((13, 5), secondary)
    draw.point((19, 5), secondary)
    draw.point((20, 5), secondary)
    
    # Body/chest (visible portion in portrait)
    body_pixels = []
    for x in range(10, 22):
        for y in range(20, 26):
            if y < 24 or (x > 12 and x < 20):
                body_pixels.append((x, y))
                draw.point((x, y), primary)
    
    # Apply patterns
    all_pixels = head_pixels + ear_pixels + body_pixels
    apply_pattern(draw, pattern, secondary, all_pixels)
    
    # Detailed eyes (both facing forward)
    # Left eye
    draw.point((12, 11), accent)        # Eye color
    draw.point((13, 11), accent)
    draw.point((12, 12), accent)
    draw.point((13, 12), accent)
    draw.point((12, 11), (0, 0, 0))     # Pupil
    draw.point((13, 12), (255, 255, 255)) # Highlight
    
    # Right eye
    draw.point((19, 11), accent)        # Eye color
    draw.point((20, 11), accent)
    draw.point((19, 12), accent)
    draw.point((20, 12), accent)
    draw.point((20, 11), (0, 0, 0))     # Pupil
    draw.point((19, 12), (255, 255, 255)) # Highlight
    
    # Detailed nose (triangle shape)
    draw.point((15, 14), (255, 105, 180))  # Top of nose
    draw.point((16, 14), (255, 105, 180))
    draw.point((15, 15), (255, 105, 180))  # Bottom of nose
    draw.point((16, 15), (255, 105, 180))
    draw.point((15, 16), (255, 182, 193))  # Lighter bottom
    draw.point((16, 16), (255, 182, 193))
    
    # Mouth (curved)
    draw.point((13, 17), (0, 0, 0))
    draw.point((14, 17), (0, 0, 0))
    draw.point((15, 18), (0, 0, 0))
    draw.point((16, 18), (0, 0, 0))
    draw.point((17, 17), (0, 0, 0))
    draw.point((18, 17), (0, 0, 0))
    
    # Whiskers (symmetrical)
    draw.point((8, 11), (255, 255, 255))
    draw.point((7, 12), (255, 255, 255))
    draw.point((8, 13), (255, 255, 255))
    draw.point((24, 11), (255, 255, 255))
    draw.point((25, 12), (255, 255, 255))
    draw.point((24, 13), (255, 255, 255))
    
    img = img.resize((64, 64), Image.NEAREST)
    return img

def apply_pattern(draw, pattern, secondary, all_pixels):
    """Apply color patterns to the cat."""
    if pattern == 'stripes':
        # Horizontal stripes
        for x, y in all_pixels:
            if y % 3 == 0:
                draw.point((x, y), secondary)
    
    elif pattern == 'spots':
        # Random spots
        spots = [(x, y) for x, y in all_pixels if (x + y) % 7 == 0]
        for spot in spots:
            draw.point(spot, secondary)
    
    elif pattern == 'patches':
        # Large patches
        for x, y in all_pixels:
            if x > 16:
                draw.point((x, y), secondary)
    
    elif pattern == 'tuxedo':
        # White chest/belly
        for x, y in all_pixels:
            if 13 <= x <= 18 and y >= 14:
                draw.point((x, y), secondary)
    
    elif pattern == 'points':
        # Darker extremities (ears, face outline)
        for x, y in all_pixels:
            if y <= 12 or x <= 11 or x >= 20:
                draw.point((x, y), secondary)

def generate_all_cats():
    """Generate all 12 cat sprites."""
    output_dir = "/Users/vct/MyCode/NyxApp/assets/images/cats"
    
    for i, cat in enumerate(CAT_DESIGNS):
        sprite = create_cat_sprite(cat['colors'], cat['pattern'], cat['pose'])
        filename = f"cat_{i+1:02d}_{cat['name']}.png"
        filepath = os.path.join(output_dir, filename)
        sprite.save(filepath)
        print(f"Generated {filename} ({cat['pose']})")
    
    print(f"\nAll 12 cat icons generated in {output_dir}")

if __name__ == "__main__":
    generate_all_cats()