"""Render isolated W4 file sessions and exercise Godot's native input dispatch."""
import argparse, subprocess, json, uuid, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='C:/DEV/tools/godot/4.7.2/Godot_v4.7.2-stable_win64.exe')
parser.add_argument('--output', default='tools/out/w4_native_'+uuid.uuid4().hex[:10])
parser.add_argument('--cases', default='basic:320x568,basic:360x800,basic:412x915,text_basic:320x568,text_basic:360x800,text_basic:412x915,inset_text_basic:320x568,settings:320x568,modal:320x568,text_settings:320x568,text_modal:320x568,gray_basic:320x568,gray_pending:412x915,gray_valid:360x800,gray_invalid:360x800,gray_clear:320x568,gray_modal:320x568,gray_settings:320x568,event_9_11:320x568,inset_text_event_9_11:320x568,event_19_21:360x800,text_event_19_21:412x915,event_multi16:320x568,inset_text_reduced_event_multi16:320x568,gray_reduced_text_event_multi16:360x800,text_event_multi16:412x915,stress:320x568')
args = parser.parse_args()
out = (ROOT/args.output).resolve()
out.mkdir(parents=True,exist_ok=True)
engine = Path(args.godot)
expected='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
assert hashlib.sha256(engine.read_bytes()).hexdigest()==expected,'Unexpected engine binary'
reports=[]
for item in args.cases.split(','):
    mode,size=item.split(':')
    name=mode+'_'+size
    directory=out/(name+'_save')
    command=[str(engine),'--path',str(ROOT/'game'),'--resolution',size,'--script',
             'res://tests/integration/presentation_probe.gd','--',mode,str(directory),str(out/name),size]
    run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=50,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    (out/(name+'.log')).write_text(run.stdout+run.stderr,encoding='utf-8')
    assert run.returncode==0 and 'SCRIPT ERROR' not in run.stdout+run.stderr and 'ERROR:' not in run.stdout+run.stderr,(name,run.stdout,run.stderr)
    report=json.loads((out/(name+'.json')).read_text(encoding='utf-8-sig'))
    assert all(c['passed'] for c in report['checks']),report
    reports.append(report)
    print('PASS',name,flush=True)
(out/'summary.json').write_text(json.dumps({'engine_sha256':expected,'reports':reports},indent=2)+'\n',encoding='utf-8')
print(out)
