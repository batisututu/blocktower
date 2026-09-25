"""Original layered feedback, deterministic synthesis with no external samples."""
from pathlib import Path
import math, wave, struct, hashlib, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'game/assets/audio/gamefeel'
OUT.mkdir(parents=True,exist_ok=True)
RATE=44100
rows=[]
for name,duration in [('button',.075),('snap',.16),('clear',.32),('air',.32),('chime',.42)]:
    values=[]
    for i in range(int(RATE*duration)):
        t=i/RATE; attack=min(1,t/.003)
        noise=math.sin(i*78.233)*43758.5453;noise=(noise-math.floor(noise))*2-1
        if name=='button': v=(math.sin(2*math.pi*520*t)*.15+noise*.025)*math.exp(-t*70)
        elif name=='snap': v=(math.sin(2*math.pi*(230*t+35*t*t))*.32+math.sin(2*math.pi*920*t)*.08+noise*.05)*math.exp(-t*35)
        elif name=='clear': v=(math.sin(2*math.pi*330*t)*.27+math.sin(2*math.pi*660*t)*.08)*math.exp(-t*15)
        elif name=='air': v=noise*.065*math.sin(min(1,t/.32)*math.pi)**2
        else:
            age=max(0,t-.06)
            v=sum(math.sin(2*math.pi*f*age)*a for f,a in [(1046.5,.09),(1318.5,.07),(1568,.05)])*min(1,age/.008)*math.exp(-age*12)
        values.append(round(max(-1,min(1,v*attack))*32767))
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,RATE,len(values),'NONE','not compressed'))
        f.writeframes(struct.pack('<'+'h'*len(values),*values))
    rows.append({'path':path.relative_to(ROOT).as_posix(),'seconds':duration,'peak':max(map(abs,values))/32767,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps({'origin':'Original procedural synthesis; no external samples','generator':'art_source/gamefeel/build_audio.py','files':rows},indent=2)+'\n')
print('Created',len(rows),'original WAV files')
