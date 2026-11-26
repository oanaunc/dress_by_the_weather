#!/usr/bin/env python3
"""Caption a real simulator recording using chapter markers from the UI walkthrough.
Usage: python3 Scripts/render_review_video.py RAW.mp4 TEST.log recording.json
Requires Pillow and ffmpeg. Raw captures stay in ignored build/.
"""
from pathlib import Path
import json, re, subprocess, sys, textwrap
from PIL import Image, ImageDraw, ImageFont
raw, log, metadata = map(Path, sys.argv[1:4])
r = Path(__file__).resolve().parent.parent
work = r/'build/review-render'; work.mkdir(exist_ok=True)
out = r/'AppStore/ReviewerWalkthrough.mp4'
normalized = work/'capture-cfr.mp4'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw),'-vf','fps=30','-an','-c:v','libx264','-preset','fast','-crf','20',str(normalized)],check=True)
raw = normalized
started = json.loads(metadata.read_text())['started']
markers = [(float(t)-started, title) for t,title in re.findall(r'REVIEW_CHAPTER: ([\d.]+): (.*)', log.read_text())]
copy = [
 ('Your weather.\nYour daily outfit.', 'Free global forecasts, optional current location and worldwide city search. Outfit advice follows temperature, rain, snow, wind and your comfort.'),
 ('Understand\nevery layer.', 'Open an outfit to see the clothing checklist and why those pieces suit the forecast. Save and share your daily looks for free.'),
 ('See the day\nahead.', 'Explore hourly and available daily forecasts in the destination’s local time. Sample mode is clearly labeled; live weather uses MET Norway.'),
 ('Pack the\nessentials.', 'Basic destination packing lists remain free, alongside weather, daily styling, saved looks, reminders and widgets.'),
 ('One purchase.\nPermanent Pro.', 'US $19.99 once, localized by Apple. No subscription. Purchase and restore use verified StoreKit 2 transactions. No external checkout or app account.'),
 ('Your personal\nstyle studio.', 'Pro brings four practical tools together: Dress the Week, Your Wardrobe, Travel Capsules and the Editorial Library.'),
 ('Wear what\nyou own.', 'Add pieces, optional local photos, comfort ranges, occasions, laundry availability and rain readiness. Find suitable owned pieces for the forecast.'),
 ('Dress the\nwhole week.', 'Save an occasion and outfit variation for each of the next seven available forecast days. Plans stay saved for the selected city.'),
 ('Plan the\nnext escape.', 'Choose a destination, dates within the available forecast, and an occasion. Build a capsule for the destination’s changing weather.'),
 ('Fewer pieces.\nMore outfits.', 'Reuse suitable wardrobe pieces across daily combinations. Review suggested additions, tick your packing checklist and share the capsule.'),
 ('An editorial\ncollection.', 'Browse 214 original couple photographs by temperature, weather and occasion. Save inspiration and explore eight original styling guides.'),
 ('Style with\npurpose.', 'Original guides cover office, evenings, weekends, travel, rain, winter, linen and active days. Adapt inspiration to the actual forecast.'),
]
font_root=Path('/System/Library/Fonts/Supplemental')
heading=ImageFont.truetype(str(font_root/'Georgia.ttf'),76)
body=ImageFont.truetype(str(font_root/'Arial.ttf'),32)
small=ImageFont.truetype(str(font_root/'Arial.ttf'),23)
label=ImageFont.truetype(str(font_root/'Arial Bold.ttf'),24)
chapters=[]; total=0
for i, ((start,_),(title,detail)) in enumerate(zip(markers,copy)):
 next_start=markers[i+1][0] if i+1<len(markers) else start+6
 duration=min(8,max(3,next_start-start-.25))
 if i==4: duration=3 # Exclude the Debug-only relaunch between free and Pro demonstrations.
 bg=Image.new('RGB',(1920,1080),'#f7f5ec'); draw=ImageDraw.Draw(bg)
 draw.text((90,88),'DRESS BY THE WEATHER',font=label,fill='#6b785d')
 draw.text((90,150),'APP REVIEW WALKTHROUGH',font=small,fill='#6e7269')
 draw.multiline_text((85,270),title,font=heading,fill='#26322d',spacing=16)
 y=510
 for line in textwrap.wrap(detail,55): draw.text((90,y),line,font=body,fill='#555e54'); y+=46
 draw.line((90,855,1110,855),fill='#d3d6cb',width=2)
 draw.text((90,884),'Real app recording · iPhone Simulator · Sample forecast',font=small,fill='#6e7269')
 draw.text((90,925),'Pro demo uses Debug preview; Release verifies Apple purchases.',font=small,fill='#6e7269')
 draw.text((90,982),f'{i+1:02d} / {len(markers):02d}',font=small,fill='#6b785d')
 panel=work/f'panel-{i:02d}.png'; bg.save(panel)
 clip=work/f'clip-{i:02d}.mp4'
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(start),'-i',str(raw),'-loop','1','-i',str(panel),'-t',str(duration),'-filter_complex','[0:v]setpts=PTS-STARTPTS,scale=-2:1000,setsar=1[phone];[1:v]setpts=PTS-STARTPTS[bg];[bg][phone]overlay=1350:40:shortest=1,fps=30,format=yuv420p[v]','-map','[v]','-an','-c:v','libx264','-preset','fast','-crf','23',str(clip)],check=True)
 chapters.append((total,title.replace('\n',' '))); total+=duration
(work/'concat.txt').write_text(''.join(f"file '{(work/f'clip-{i:02d}.mp4').as_posix()}'\n" for i in range(len(markers))))
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(work/'concat.txt'),'-c','copy','-movflags','+faststart',str(out)],check=True)
notes=['# App Review walkthrough','','[Watch ReviewerWalkthrough.mp4](ReviewerWalkthrough.mp4)','','Actual app screen recording, with captions explaining free features and the optional Pro upgrade. Recorded on iPhone Simulator with clearly labeled sample weather; Pro tools use the Debug preview. The submitted Release build has no purchase bypass. StoreKit purchase, cancellation, restore, relaunch and refund revocation were separately verified with Apple’s local test catalog. No real payment was made.','','## Chapters','']
for seconds,title in chapters: notes.append(f'- {int(seconds)//60:02d}:{int(seconds)%60:02d} — {title}')
notes+=['','Reproduce the capture with `AppFlowTests/testReviewerWalkthrough`, `simctl io recordVideo`, and `Scripts/render_review_video.py`. Raw video and intermediate panels are ignored build artifacts.','']
(r/'AppStore/REVIEW_VIDEO.md').write_text('\n'.join(notes))
print(out,round(total,1),'seconds',round(out.stat().st_size/1_000_000,1),'MB')
