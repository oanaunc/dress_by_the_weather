#!/usr/bin/env python3
"""Diagnostic contact sheets only; original photos are never modified."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
rows = json.loads((ROOT/'Art/catalogue.json').read_text())
files = []
for row in rows:
    if row['status'] != 'downloaded': continue
    for variant in range(4):
        path=ROOT/'Art/Originals'/f'{row["jobID"]}-{variant}.png'
        if path.exists(): files.append((path, row['key']+' / '+str(variant)))
out=ROOT/'Art/ContactSheets';out.mkdir(exist_ok=True)
for start in range(0,len(files),12):
    canvas=Image.new('RGB',(1200,1308),'#f8f6ef');draw=ImageDraw.Draw(canvas)
    for n,(path,label) in enumerate(files[start:start+12]):
        image=Image.open(path).convert('RGB');image.thumbnail((290,405))
        x=(n%4)*300+(300-image.width)//2;y=(n//4)*436
        canvas.paste(image,(x,y));draw.text(((n%4)*300+8,y+411),label,fill='#222222')
    canvas.save(out/f'pending-{start//12}.jpg')
print(f'{len(files)} unreviewed photos in {(len(files)+11)//12} sheets')
