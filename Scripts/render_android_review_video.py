#!/usr/bin/env python3
"""Create a captioned Android reviewer guide from actual emulator screenshots."""
from pathlib import Path
import subprocess, textwrap
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
work = root / 'build/android-review-video'
work.mkdir(parents=True, exist_ok=True)
screens = root / 'Screenshots/Android/phone-final'
serif = ImageFont.truetype(str(root / 'Android/app/src/main/res/font/editorial.ttf'), 80)
body = ImageFont.truetype(str(root / 'Android/app/src/main/res/font/interface_text.ttf'), 31)
small = ImageFont.truetype(str(root / 'Android/app/src/main/res/font/interface_text.ttf'), 23)
chapters = [
    ('01-Today', 'Your forecast.\nYour outfit.', 'Free worldwide weather, daily outfits and optional approximate current location. Search cities or addresses, or enter coordinates. Sample weather is explicitly labelled.'),
    ('02-Forecast', 'See the day\nahead.', 'Hourly detail and available daily forecasts use destination local time. MET Norway supplies weather; the app derives feels-like estimates and clothing advice.'),
    ('03-Looks', 'Four occasions.\nOne forecast.', 'Everyday, Office, Evening and Active outfit suggestions remain free. Open a look for layers, fabrics, accessories, warmer or lighter options and comfort feedback.'),
    ('12-Free-Packing', 'Pack the\nessentials.', 'Basic packing lists use actual destination forecasts up to eight days ahead. Save trips, check off pieces and share a list without Pro.'),
    ('13-Pro-Paywall', 'One purchase.\nPermanent Pro.', 'US $19.99 once, with localized Google Play prices. No subscription. The local emulator has no Play billing account, so its price is unavailable. Production purchases require verified Google signatures.'),
    ('06-Pro-Studio', 'Your personal\nstyle studio.', 'Four Pro tools: Dress the Week, Your Wardrobe, Travel Capsules and the Editorial Library. Pro demonstrations here use the development preview; no real payment was made.'),
    ('07-Pro-Wardrobe', 'Wear what\nyou own.', 'Add, edit or delete pieces, optional local photos, comfort ranges, occasions, laundry status and rain readiness. Match suitable owned pieces to the weather.'),
    ('08-Pro-Week', 'Dress the\nwhole week.', 'Save a daily occasion and outfit variation for seven available forecast days. Plans remain saved for the selected city.'),
    ('09-Pro-Capsule', 'Fewer pieces.\nMore outfits.', 'Reuse suitable pieces across the destination forecast. See owned matches, suggested additions, daily combinations and a shareable packing checklist.'),
    ('10-Pro-Library', 'An editorial\ncollection.', 'All 214 original couple photographs and eight styling guides are included. Filter by weather, temperature or occasion, save inspiration and adapt an occasion to the actual forecast.'),
    ('11-Pro-Collection', 'Review every\nStudio tool.', 'In the signed release: Looks → A little more personal → Preview the sample Studio. No account, payment or special code. All tools work with sample Bucharest weather and isolated temporary data. Exit preview resets it.'),
    ('14-Live-Sydney', 'Live weather.\nPrivate wardrobe.', 'The Sydney screen uses a live MET Norway forecast. No app account, ads or analytics. Wardrobe photos and plans stay on device. Google Play handles the optional permanent purchase.'),
]
for i, (name, title, detail) in enumerate(chapters):
    panel = Image.new('RGB', (1920, 1080), '#f7f5ed')
    d = ImageDraw.Draw(panel)
    d.text((85, 80), 'DRESS BY THE WEATHER · ANDROID', font=small, fill='#6c785c')
    d.text((85, 135), 'REVIEWER GUIDE', font=small, fill='#707569')
    d.multiline_text((80, 245), title, font=serif, fill='#293330', spacing=10)
    y = 500
    for line in textwrap.wrap(detail, 59):
        d.text((85, y), line, font=body, fill='#596154'); y += 45
    d.line((85, 884, 1160, 884), fill='#d3d7cc', width=2)
    d.text((85, 915), 'Actual Android app screenshots · Sample weather unless labelled live', font=small, fill='#707569')
    d.text((85, 970), f'{i + 1:02d} / {len(chapters):02d}   ·   Free sample Studio also available in release', font=small, fill='#6c785c')
    phone = Image.open(screens / f'{name}.png').convert('RGB')
    phone.thumbnail((562, 1000), Image.Resampling.LANCZOS)
    panel.paste(phone, (1280, 40))
    panel.save(work / f'{i:02d}.png')
listing = work / 'frames.txt'
listing.write_text(''.join(f"file '{work / f'{i:02d}.png'}'\nduration 6\n" for i in range(len(chapters))) + f"file '{work / '11.png'}'\n")
out = root / 'GooglePlay/ReviewerWalkthrough.mp4'
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(listing), '-vf', 'fps=30,format=yuv420p', '-t', '72', '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '22', '-movflags', '+faststart', str(out)], check=True)
print(out)
