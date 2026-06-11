import os
from PIL import Image

logo_path = r"d:\Luan-Van\Project\app\frontend\mobile\assets\logo\Logo.png"
output_path = r"d:\Luan-Van\Project\app\frontend\mobile\assets\logo\Logo_padded.png"

if not os.path.exists(logo_path):
    print(f"Error: Logo file not found at {logo_path}")
    exit(1)

# Open original logo
orig_img = Image.open(logo_path)
width, height = orig_img.size
print(f"Original size: {width}x{height}")

# Target scale factor — smaller logo so full artwork fits inside adaptive icon mask
scale = 0.50
new_w = int(width * scale)
new_h = int(height * scale)

# Resize original image to scaled size
resized_img = orig_img.resize((new_w, new_h), Image.Resampling.LANCZOS)

# Create a new transparent background image
padded_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))

# Calculate center coordinates to paste
offset_x = (width - new_w) // 2
offset_y = (height - new_h) // 2

# Paste resized image into transparent background
padded_img.paste(resized_img, (offset_x, offset_y), resized_img if resized_img.mode == 'RGBA' else None)

# Save
padded_img.save(output_path, "PNG")
print(f"Padded logo saved successfully to {output_path}")
