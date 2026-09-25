import subprocess,json,hashlib,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
E=ROOT/'docs/implementation/gamefeel_device_evidence_2026-09-21/qa'
E.mkdir(parents=True,exist_ok=True)
BASE=[r'C:/Users/batis/AppData/Local/Android/Sdk/platform-tools/adb.exe','-s','R3CN80ZJ8SV']
def adb(*args):
 q=subprocess.run(BASE+list(args),capture_output=True,check=True);return q.stdout
def shot(name):
 (E/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def state(name):
 states=[]
 for n in ['a','b']:
  try: raw=adb('shell','run-as','com.blocktower.game.qa','cat','files/save_v1/slot_'+n+'.json')
  except subprocess.CalledProcessError: continue
  (E/(name+'_slot_'+n+'.json')).write_bytes(raw)
  e=json.loads(raw);assert hashlib.sha256(e['payload'].encode()).hexdigest()==e['checksum'];states.append(json.loads(e['payload']))
 s=max(states,key=lambda s:int(s['revision']));(E/(name+'_state.json')).write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8');return s
def tap(x,y):adb('shell','input','tap',str(x),str(y))
def swipe(x,y,tx,ty,ms=600):adb('shell','input','swipe',str(x),str(y),str(tx),str(ty),str(ms))
def back():adb('shell','input','keyevent','4')
def check(ok,name):
 f=E/'checks.json';a=json.loads(f.read_text()) if f.exists() else [];a.append({'check':name,'passed':bool(ok)});f.write_text(json.dumps(a,ensure_ascii=False,indent=2),encoding='utf-8');assert ok,name;print('PASS',name)
