import subprocess,json,hashlib,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
E=ROOT/'docs/implementation/w5_device_evidence_2026-09-23'
E.mkdir(parents=True,exist_ok=True)
BASE=['C:/Users/batis/AppData/Local/Android/Sdk/platform-tools/adb.exe','-s','R3CN80ZJ8SV']
MAIN='com.blocktower.game'
QA='com.blocktower.game.qa'
def adb(*args,check=True):
    r=subprocess.run(BASE+list(args),capture_output=True,timeout=45)
    if check and r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout
def stop(pkg): adb('shell','am','force-stop',pkg)
def launch(pkg):
    adb('shell','input','keyevent','KEYCODE_WAKEUP')
    adb('shell','wm','dismiss-keyguard')
    return adb('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',pkg)
def shot(name):
    (E/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def state(pkg,name):
    values=[]
    for slot in ['a','b']:
        raw=adb('exec-out','run-as',pkg,'cat','files/save_v1/slot_'+slot+'.json',check=False)
        (E/(name+'_slot_'+slot+'.json')).write_bytes(raw)
        try:
            e=json.loads(raw)
            assert hashlib.sha256(e['payload'].encode()).hexdigest()==e['checksum']
            values.append(json.loads(e['payload']))
        except (ValueError,KeyError): pass
    assert values,name+' has no valid slot'
    s=max(values,key=lambda x:int(x['revision']))
    (E/(name+'_state.json')).write_text(json.dumps(s,indent=2,ensure_ascii=False),encoding='utf-8')
    return s
def prefs(pkg,name):
    raw=adb('exec-out','run-as',pkg,'cat','files/save_v1/presentation.json',check=False)
    (E/(name+'_preferences.json')).write_bytes(raw)
    return raw
def check(value,name):
    path=E/'checks.json'
    checks=json.loads(path.read_text()) if path.exists() else []
    checks.append({'check':name,'passed':bool(value)})
    path.write_text(json.dumps(checks,indent=2,ensure_ascii=False),encoding='utf-8')
    assert value,name
    print('PASS',name,flush=True)
def tap(x,y): adb('shell','input','tap',str(x),str(y))
def motion(action,x,y): adb('shell','input','touchscreen','motionevent',action,str(x),str(y))
def home(): adb('shell','input','keyevent','KEYCODE_HOME')
def back(): adb('shell','input','keyevent','KEYCODE_BACK')
def put_qa(relative,data):
    # Injection is hard-coded to the isolated UI QA package.
    local=ROOT/'tools/out/w5_qa_transfer'
    local.write_bytes(data if isinstance(data,bytes) else data.encode())
    adb('push',str(local),'/data/local/tmp/blocktower_lifecycle_qa_transfer')
    adb('shell','run-as',QA,'cp','/data/local/tmp/blocktower_lifecycle_qa_transfer','files/save_v1/'+relative)
