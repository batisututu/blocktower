"""Capture the B reference fixture, live states and tower boundaries on Windows."""
from pathlib import Path
import argparse, subprocess, sys, uuid

ROOT = Path(__file__).resolve().parents[1]
CASES = ('basic:360x800,basic:320x568,reference:360x800,reference:412x915,'
         'cross:412x915,input:360x800,valid:360x800,invalid:360x800,modal:320x568,'
         'settings:320x568,clear:360x800,max:360x800,tower_1:360x800,tower_9:360x800,'
         'tower_10:360x800,tower_11:360x800,tower:360x800,tower_top:360x800,large:320x568')
parser = argparse.ArgumentParser()
parser.add_argument('--output',default='tools/out/fidelity_'+uuid.uuid4().hex[:10])
args = parser.parse_args()
out = ROOT/args.output
if out.exists() and any(out.iterdir()):
    raise SystemExit('Use a fresh output directory: saved fixture state must not be reused.')
subprocess.run([sys.executable,str(ROOT/'tools/verify_presentation.py'),
                '--cases',CASES,'--output',args.output],cwd=ROOT,check=True)
