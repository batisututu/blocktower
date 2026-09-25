"""Produce six original, deterministic short architectural feedback sounds."""
from pathlib import Path
import math, wave, struct, hashlib, json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'game/assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100
SOUNDS = {
    'pick': (0.065, [(880, 1.0), (1760, 0.12)], 0.16),
    'snap': (0.12, [(310, 1.0), (930, 0.26), (1560, 0.1)], 0.28),
    'reject': (0.09, [(165, 1.0), (220, 0.2)], 0.12),
    'clear': (0.30, [(523.25, 0.8), (659.25, 0.4), (783.99, 0.32)], 0.30),
    'lock': (0.36, [(261.63, 0.65), (523.25, 0.45), (783.99, 0.2)], 0.28),
    'over': (0.42, [(261.63, 0.65), (329.63, 0.28), (392, 0.2)], 0.17),
}
records = []
for name, (duration, tones, gain) in SOUNDS.items():
    count = int(RATE * duration)
    values = []
    for i in range(count):
        t = i / RATE
        attack = min(1.0, t / 0.004)
        envelope = attack * math.exp(-t * 8 / duration) * min(1, (duration-t)/0.008)
        sample = gain * envelope * sum(math.sin(2*math.pi*f*t) * a for f,a in tones)
        values.append(round(max(-1, min(1, sample))*32767))
    path = OUT / f'{name}.wav'
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, count, 'NONE', 'not compressed'))
        wav.writeframes(struct.pack('<'+'h'*count, *values))
    records.append({'file':path.relative_to(ROOT).as_posix(), 'sample_rate':RATE, 'channels':1,
                    'duration':duration, 'peak':max(abs(v) for v in values)/32767,
                    'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps({'source':'Original project additive synthesis; no external samples',
    'generator':'art_source/w4/build_audio.py','files':records}, indent=2)+'\n', encoding='utf-8')
print(f'Created {len(records)} original WAV effects.')
