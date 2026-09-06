"""Offline original ENDING loader fixture, not an ordinary-input completion.

Use the existing side-A loader-request snapshot and request the source ENDING
filename through the original loader. Stop before restored game code executes.
"""
from vice_reference import ROOT,Reference
import hashlib,json


def main():
    out=ROOT/'source/local/captures'
    with Reference(ROOT/'source/local/last_ninja_3_the_side_a/disk.d64') as ref:
        ref.socket.settimeout(50);ref.load_snapshot(out/'ln3-level2-request.vsf')
        ref.write(0x3f00,b'ENDING');ref.write(0xbb,[0,0x3f]);ref.write(0xb7,[6]);ref.write(0x288,[4])
        ref.set_registers(PC=0x338)
        ref.until(0x3be)
        ram=ref.memory(0,65535);(out/'ln3-ending-ram.bin').write_bytes(ram)
        name=str(out/'ln3-ending-loaded.vsf').encode();ref.command(0x41,bytes([0,1,len(name)])+name)
        record=dict(scope=__doc__,sha256=hashlib.sha256(ram).hexdigest(),registers=ref.registers())
        (out/'ln3-ending-capture.json').write_text(json.dumps(record,indent=2)+'\n');print(record,flush=True)


if __name__=='__main__':main()
