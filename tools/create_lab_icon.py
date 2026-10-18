"""Generate a simple R.L icon for the isolated Android/Windows testing app."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys

root = Path(__file__).resolve().parents[1]

def icon(size):
    im = Image.new("RGBA", (size, size), (14, 20, 34, 255))
    d = ImageDraw.Draw(im)
    pad = round(size * .06)
    d.rounded_rectangle((pad,pad,size-pad,size-pad), radius=round(size*.22),
                        fill=(22,35,59,255), outline=(77,226,170,255), width=max(2,size//38))
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
    ]
    font = None
    for path in candidates:
        if Path(path).exists():
            font = ImageFont.truetype(path, round(size*.34))
            break
    if font is None:
        font = ImageFont.load_default()
    box = d.textbbox((0,0), "R.L", font=font)
    x = (size - (box[2]-box[0]))/2 - box[0]
    y = (size - (box[3]-box[1]))/2 - box[1]
    d.text((x,y), "R.L", font=font, fill=(255,255,255,255))
    return im

platform = sys.argv[1]
if platform == "android":
    sizes = {"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}
    for suffix,size in sizes.items():
        target=root/f"android/app/src/main/res/mipmap-{suffix}/ic_launcher.png"
        target.parent.mkdir(parents=True,exist_ok=True)
        icon(size).save(target)
    manifest=root/"android/app/src/main/AndroidManifest.xml"
    data=manifest.read_text()
    import re
    data=re.sub(r'android:icon="[^"]+"','android:icon="@mipmap/ic_launcher"',data)
    data=re.sub(r'android:roundIcon="[^"]+"','android:roundIcon="@mipmap/ic_launcher"',data)
    data=data.replace('android:label="Rocha+"','android:label="R.L Laboratorio"')
    manifest.write_text(data)
elif platform == "windows":
    target=root/"windows/runner/resources/app_icon.ico"
    target.parent.mkdir(parents=True,exist_ok=True)
    icon(256).save(target,format="ICO",sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
    runner=root/"windows/runner/main.cpp"
    if runner.exists():
        runner.write_text(runner.read_text().replace('L"rocha_plus"', 'L"R.L Laboratorio"'))
    cmake=root/"windows/CMakeLists.txt"
    if cmake.exists():
        cmake.write_text(cmake.read_text().replace('set(BINARY_NAME "rocha_plus")','set(BINARY_NAME "RL_Laboratorio")'))
else:
    raise SystemExit("Expected android or windows")
print(f"R.L icon ready for {platform}")
