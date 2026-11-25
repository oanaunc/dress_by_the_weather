#!/usr/bin/env python3
"""Generate the explicit 64-collection / 256-photo production manifest.

No external requests or image generation: these prompts are submitted in Midjourney's UI.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = 'https://cdn.midjourney.com/8d616be0-2d1e-485d-a8ff-4db455c0bdb1/0_2.png'
BANDS = ['Below −15°C', '−15 to −5°C', '−5 to 5°C', '5 to 10°C', '10 to 15°C', '15 to 20°C', '20 to 25°C', '25 to 30°C', '30 to 35°C', '35°C and above']
CLOTHES = [
    'heavy insulated expedition parkas, thermal base layers beneath chunky wool knits, insulated snow trousers, thick gloves, warm beanies, scarves, insulated winter boots, extreme cold alpine setting',
    'warm down winter coats over thick wool sweaters, lined trousers, knitted gloves, wool scarves and hats, insulated boots, snowy winter city',
    'lined wool overcoats over merino sweaters and base layers, warm trousers, scarves, gloves, lined ankle boots, crisp winter street',
    'medium weight camel and charcoal wool coats, cashmere sweaters, long wool trousers, leather ankle boots, subtle scarves, cool autumn city',
    'light trench coats and fine knit sweaters, cotton twill trousers, closed leather sneakers, mild cloudy spring street',
    'light cotton overshirts over long sleeve shirts, light trousers, breathable closed sneakers, pleasantly mild spring street',
    'cotton tees and airy cotton blouses, light linen blend trousers, breathable sneakers, warm sunny city',
    'airy cream linen shirts, relaxed ivory linen trousers, tan sandals, raffia tote, sunny Mediterranean terrace',
    'loose lightweight linen tops, breathable shorts and airy midi skirt, comfortable sandals, sunglasses and sun hats, hot sunny Mediterranean street',
    'very light loose sun protective long sleeve linen shirts, loose pale linen trousers, ventilated sandals, wide brim sun hats, sunglasses, refillable water bottles, shaded terrace on extremely hot day',
]
STYLES = [
    'refined everyday casual quiet luxury',
    'polished professional office tailoring adapted to the weather',
    'sophisticated evening date night styling adapted to the weather',
    'luxury technical sportswear with wicking active fabrics, supportive trainers for an active outdoor walk, weather appropriate protective layers',
]
RAIN = {
    3: 'warm waterproof hooded coats over merino knits, full length warm trousers, waterproof grippy ankle boots, cold rainy city street',
    4: 'light waterproof trench coats over fine knits, long cotton trousers, water resistant closed shoes, umbrella, mild rainy city',
    6: 'breathable lightweight rain shells over cotton shirts, lightweight full length trousers, waterproof closed shoes, umbrella, warm rainy city',
    8: 'ultralight breathable rain shells over airy linen shirts, loose light trousers, lightweight water resistant closed shoes, umbrella, humid hot rainy city',
}
SNOW = {
    1: 'heavy waterproof insulated hooded winter coats over wool knits and thermal base layers, insulated full length trousers, waterproof insulated grippy snow boots, warm beanies, gloves and scarves, heavy snow in a winter city',
    2: 'waterproof insulated coats over merino sweaters, warm lined trousers, waterproof snow boots, hats gloves scarves, light snowfall in a city',
}

def main():
    path = ROOT / 'Art/catalogue.json'
    corrections_path = ROOT / 'Art/sports-corrections.json'
    sports = json.loads(corrections_path.read_text()) if corrections_path.exists() else {}
    existing = {r['key']: r for r in json.loads(path.read_text())} if path.exists() else {}
    rows = []
    for weather, bands in [('dry', dict(enumerate(CLOTHES))), ('rain', RAIN), ('snow', SNOW)]:
        for band, clothes in bands.items():
            for style, direction in enumerate(STYLES):
                if weather == 'dry' and style == 3 and str(band) in sports:
                    clothes = sports[str(band)]
                key = f'{weather}_{band}_{style}'
                prompt = f'Full length weather wardrobe editorial photograph of the same stylish adult couple, handsome dark wavy haired man and elegant blonde woman, both wearing {clothes}, {direction}, standing side by side, entire figures including shoes visible, natural skin texture, detailed fabrics, luxury fashion magazine photography, neutral palette, cinematic daylight --ar 3:4 --v 7 --raw --relax --oref {REFERENCE} --ow 60 --no text watermark logo collage'
                rows.append({'key':key, 'weather':weather, 'temperatureBand':band, 'temperatureRange':BANDS[band], 'style':style, 'occasion':['Everyday','Office','Evening','Active'][style], 'models':['man','woman'], 'prompt':prompt, 'clothing':clothes, 'variants':4, 'assetBase':f'couple_{key}', 'jobID':existing.get(key,{}).get('jobID'), 'reviewed':existing.get(key,{}).get('reviewed',[]), 'status':existing.get(key,{}).get('status','planned')})
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'Art/prompts.txt').write_text('\n\n'.join(r['key']+'\n'+r['prompt'] for r in rows)+'\n')
    print(f'{len(rows)} collections; {sum(r["variants"] for r in rows)} couple photographs')
if __name__ == '__main__': main()
