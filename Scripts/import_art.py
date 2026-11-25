#!/usr/bin/env python3
"""Import reviewed Midjourney originals as optimized native asset-catalog images.

Usage: python3 Scripts/import_art.py
Set a collection's jobID and reviewed variant indexes in Art/catalogue.json first.
The source photographs are preserved; only encoding is changed for app size.
"""
import json
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
catalogue = json.loads((ROOT/'Art/catalogue.json').read_text())
count = 0
for row in catalogue:
    if not row['jobID']: continue
    for variant in row['reviewed']:
        original = ROOT/'Art/Originals'/f'{row["jobID"]}-{variant}.png'
        if not original.exists(): raise FileNotFoundError(original)
        name = f'{row["assetBase"]}_{variant}'
        directory = ROOT/'App/Assets.xcassets'/f'{name}.imageset'
        directory.mkdir(parents=True,exist_ok=True)
        subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','85',str(original),'--out',str(directory/'image.jpg')],check=True,stdout=subprocess.DEVNULL)
        (directory/'Contents.json').write_text(json.dumps({'images':[{'filename':'image.jpg','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
        count += 1
print(f'Imported {count} reviewed photographs')
