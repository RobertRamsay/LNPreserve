"""Clear untouched bogus LN1 ninja poses without moving any frame or user edit.
Uses the opt-in legacy compositor only to identify unchanged faulty images.
"""
from collections import defaultdict
from pathlib import Path
from PIL import Image
from build_project import ROOT, read_json
from export_ln1_play import composition


def main():
    data=read_json(ROOT/'LNPreserve/datafiles/graphics/characters.json')
    refs=defaultdict(list)
    for bank,record in data['banks'].items():
        for logical,index in enumerate(record['poses']):
            pose=data['poses'][index]
            refs[(pose['sprite'],pose['frame'])].append((bank,logical))
    ram=(ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    cleared=[];preserved=[]
    for (name,index),links in refs.items():
        if name!='spr_char_ln1_ninja':continue
        if not all(bank.startswith(('spr_ln1_player_weapon_','spr_ln1_enemy_weapon_')) and 56<=logical%64<64 for bank,logical in links):continue
        bank,logical=links[0]
        expected=composition(ram,logical%64,logical>=64,int(bank[-1]),'_enemy_' in bank,legacy_unused=True)
        folder=ROOT/'LNPreserve/sprites'/name;resource=read_json(folder/(name+'.yy'))
        frame=resource['frames'][index]['name']
        files=[folder/(frame+'.png'),*sorted((folder/'layers'/frame).glob('*.png'))]
        if len(files)!=2 or any(Image.open(p).convert('RGBA').tobytes()!=expected.tobytes() for p in files):
            preserved.append(index);continue
        blank=Image.new('RGBA',expected.size)
        for path in files:blank.save(path)
        cleared.append(index)
    print('Cleared untouched unused ninja frames (zero based):',cleared)
    print('Preserved edited/different frames:',preserved)

if __name__=='__main__':main()
