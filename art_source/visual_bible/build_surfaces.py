"""Author editable geometric material assets; no external raster or reference crop."""
from pathlib import Path
import random, json, hashlib

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'game/assets/visual_bible/surfaces'
OUT.mkdir(parents=True, exist_ok=True)
PALETTE = {'sage':'8ba782','clay':'d18b62','sand':'e5cfa9','gold':'d7aa53','violet':'aa8bbc','blue':'78a8ba'}

def shade(h, amount):
    c=[int(h[i:i+2],16) for i in (0,2,4)]
    return '#'+''.join(f'{round(v+(255-v)*amount if amount>0 else v*(1+amount)):02x}' for v in c)

def save(name, body, defs='', size=128):
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>{defs}</defs>{body}</svg>'
    (OUT/(name+'.svg')).write_text(svg,encoding='utf-8')

for index,(name,color) in enumerate(PALETTE.items()):
    defs=f'<linearGradient id="face" x2="0.25" y2="1"><stop stop-color="{shade(color,.14)}"/><stop offset=".55" stop-color="#{color}"/><stop offset="1" stop-color="{shade(color,-.09)}"/></linearGradient>'
    body='<path d="M13 6H115L123 14V115L115 124H13L5 116V14Z" fill="#171711" opacity=".45"/>'
    body+=f'<path d="M12 3H114L122 11V112L114 120H12L4 112V11Z" fill="{shade(color,-.34)}" stroke="#29241a" stroke-width="1.5"/>'
    body+=f'<path d="M12 4H114L106 15H21L5 12Z" fill="{shade(color,.48)}"/>'
    body+=f'<path d="M5 12L21 24V103L13 118 5 111Z" fill="{shade(color,.18)}"/>'
    body+=f'<path d="M114 5L121 12V111L109 103V23Z" fill="{shade(color,-.16)}"/>'
    body+=f'<path d="M13 119L23 106H106L115 118Z" fill="{shade(color,-.28)}"/>'
    body+='<path d="M22 16H105L112 23V102L104 110H22L15 102V23Z" fill="url(#face)"/>'
    # 재질 자체에서만 보이는 작은 석재 입자. 원본 구조선과 판정 윤곽은 분리한다.
    rng=random.Random(84+index)
    for _ in range(210):
        x,y=rng.uniform(18,109),rng.uniform(19,105)
        body+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rng.uniform(.25,.8):.2f}" fill="{shade(color,.65 if rng.random()>.5 else -.6)}" opacity=".11"/>'
    body+=f'<path d="M23 17H104L110 24M16 25V101L23 108H103" fill="none" stroke="{shade(color,.38)}" stroke-width="1.3"/>'
    body+=f'<path d="M111 27V103L105 110H26" fill="none" stroke="{shade(color,-.32)}" stroke-width="1.2"/>'
    seams='M5 12L28 34M114 5L96 32M115 118L94 94M13 119L32 96'
    if name in ('clay','blue'): seams+='M16 48H111M16 81H111M48 17V48M80 48V81M48 81V109'
    body+=f'<path d="{seams}" fill="none" stroke="{shade(color,-.37)}" stroke-width="1.3" opacity=".65"/>'
    body+=f'<path d="M7 12L29 33M114 8L97 33M113 115L95 93M15 116L33 97" fill="none" stroke="{shade(color,.45)}" stroke-width=".85" opacity=".7"/>'
    save('tile_'+name,body,defs)

# 독립 9-slice 패널. 글자와 상호작용은 Godot Control이 소유한다.
for name,top,bottom,edge in [('panel','554330','2b251c','a78553'),('tray','3a3023','211d17','907047'),('board','392e23','1e1b16','765c3b'),('button','efbc68','a96024','f6d99c'),('disabled','61503a','403629','967c56')]:
    defs=f'<linearGradient id="p" x2="0" y2="1"><stop stop-color="#{top}"/><stop offset="1" stop-color="#{bottom}"/></linearGradient>'
    body=f'<rect x="3" y="5" width="122" height="121" rx="8" fill="#171109" opacity=".40"/><rect x="3" y="2" width="122" height="121" rx="7" fill="url(#p)" stroke="#{edge}" stroke-width="1.2"/>'
    body+=f'<rect x="7" y="6" width="114" height="113" rx="5" fill="none" stroke="{shade(edge,-.32)}" stroke-width=".7" opacity=".6"/><path d="M15 5H113Q121 5 122 15" fill="none" stroke="{shade(edge,.35)}" opacity=".65"/>'
    rng=random.Random(22)
    for _ in range(180):
        body+=f'<circle cx="{rng.uniform(13,115):.1f}" cy="{rng.uniform(14,114):.1f}" r=".45" fill="#eadbb4" opacity=".045"/>'
    save(name,body,defs)
save('empty','<rect x="4" y="4" width="120" height="121" rx="9" fill="#211e17"/><rect x="5" y="6" width="117" height="115" rx="8" fill="#453d2e" stroke="#67563d" stroke-width="1.5"/><path d="M13 120H113Q120 120 121 112" stroke="#7a6242" opacity=".35" fill="none"/>')
icons={
 'settings':'<path d="M10 3h4l1 3 3 1 3-1 2 4-2 2v3l2 2-2 4-3-1-3 1-1 3h-4l-1-3-3-1-3 1-2-4 2-2v-3l-2-2 2-4 3 1 3-1Z"/><circle cx="12" cy="13" r="4"/>',
 'tower':'<path d="M5 23V10h14v13M3 10l9-7 9 7M3 23h18M8 13v3m4-3v3m4-3v3M10 23v-4h4v4"/>',
 'back':'<path d="M15 5 7 13l8 8M7 13h16"/>',
 # 2026-09-23 HUD: 시트 닫기, 최고 기록, 연속 묶음 표시용 선 아이콘.
 'close':'<path d="M7 7l12 12M19 7 7 19"/>',
 'best':'<path d="M8 4h10v6a5 5 0 0 1-10 0Z"/><path d="M8 6H5a3.5 3.5 0 0 0 3.6 4.6M18 6h3a3.5 3.5 0 0 1-3.6 4.6M13 15v4M9 23h8M10.5 19h5"/>',
 'streak':'<path d="M6.5 14.5l6.5-5.5 6.5 5.5M6.5 21l6.5-5.5 6.5 5.5"/>'}
for name,path in icons.items():
 (OUT/('icon_'+name+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="-1 0 27 27"><g fill="none" stroke="#f3d7a2" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'+path+'</g></svg>',encoding='utf-8')
# 설정/자동 클리어 스위치. 손잡이 위치가 상태의 형태 단서이고 색은 보조다.
for name,track,edge,knob,x in [('switch_off','1b1610','7d6546','b8ac98',14),('switch_on','8ba782','d2e8b1','f8ead2',34)]:
 (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28" viewBox="0 0 48 28"><rect x="1" y="1" width="46" height="26" rx="13" fill="#{track}" stroke="#{edge}" stroke-width="1.5"/><circle cx="{x}" cy="14" r="9.5" fill="#{knob}"/><circle cx="{x}" cy="14" r="9.5" fill="none" stroke="#21180f" stroke-opacity=".35"/></svg>',encoding='utf-8')
print('Authored',len(list(OUT.glob('*.svg'))),'editable material/icon assets.')
