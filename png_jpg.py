from pathlib import Path
from PIL import Image

folder = Path.home() / "Downloads" / "wedding photo"

for png_file in folder.glob("*.png"):
    output_file = png_file.with_name(png_file.stem + "_converted.jpg")
    with Image.open(png_file) as img:
        rgb_img = img.convert("RGB")
        rgb_img.save(output_file, "JPEG", quality=100,
                     subsampling=0, optimize=True)
    print(f"Converted: {png_file.name} → {output_file.name}")
