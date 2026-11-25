#!/usr/bin/env python3
"""Reconcile downloaded generation metadata without automatically approving photos."""
import json
from pathlib import Path
from make_catalogue import ROOT, STYLES

path = ROOT/'Art/catalogue.json'
rows = json.loads(path.read_text())
jobs = json.loads((ROOT/'Art/jobs.json').read_text())
matches = {}
for job in jobs:
    if job['id'] == '8d616be0-2d1e-485d-a8ff-4db455c0bdb1': key = 'dry_7_0'
    else:
        row = next((r for r in rows if r['clothing'][:65] in job['prompt'] and STYLES[r['style']][:35] in job['prompt']),None)
        if not row: continue
        key = row['key']
    matches.setdefault(key,[]).append(job)
for row in rows:
    candidates = matches.get(row['key'],[])
    if not candidates: continue
    previous = next((j for j in candidates if j['id'] == row['jobID']),None)
    job = previous or candidates[0]
    if row['jobID'] != job['id']: row['reviewed'] = []
    row['jobID'] = job['id']
    row['alternateJobIDs'] = [j['id'] for j in candidates if j['id'] != job['id']]
    row['status'] = 'reviewed' if row.get('reviewComplete') or row['reviewed'] else 'downloaded' if all((ROOT/'Art/Originals'/f'{job["id"]}-{v}.png').exists() for v in range(4)) else 'completed'
path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(f'{len(matches)}/64 collections generated; {sum(len(r["reviewed"]) for r in rows)}/256 photographs reviewed')
