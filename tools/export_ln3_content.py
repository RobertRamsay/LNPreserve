"""Recover LN3's own room, boundary, actor and animation records offline.

Only decoded records and original PNG pixels are produced. This does not
connect or certify native LN3 gameplay; the handlers still require translation.
"""
import hashlib,json
from PIL import Image
from build_project import ROOT,write_json
from ln3_level_source import level_memory,layout,word,calls
from export_ln1_world import call
from decode_graphics import PALETTE
from extract_ln1_actors import sprite_image

NAMES=['Earth','Wind','Water','Fire','Void']

def bitmap(mem):
    pixels=[]
    for y in range(144):
        for x in range(240):
            cell=y//8*40+x//8;code=(mem[0xe000+cell*8+y%8]>>(6-(x%8//2)*2))&3
            colour=[mem[0xc0],mem[0xcc00+cell]>>4,mem[0xcc00+cell]&15,mem[0xd800+cell]&15][code]
            pixels.append((*PALETTE[colour&15],255))
    image=Image.new('RGBA',(240,144));image.putdata(pixels);return image

def render_scene(ram,s,scene):
    mem=list(ram)
    for address,size in [(0xcc00,1000),(0xd000,1000),(0xd800,1000),(0xe000,8000)]:mem[address:address+size]=[0]*size
    call(mem,s['scene_draw'],a=scene)
    return bitmap(mem)

def actor_state(mem):
    return dict(parts=[dict(x=mem[0x40+i*2],y=mem[0x41+i*2],animation=mem[0x50+i],cursor=mem[0x58+i],
                           move_mode=mem[0x2a6+i],direction=mem[0x2b6+i],dx=mem[0x2be+i],dy=mem[0x2c6+i],
                           colour=mem[0x29e+i]) for i in range(8)],
        mirror=mem[0xde],enabled=mem[0xe1],player_action=mem[0xe6],player_action_flags=mem[0xe7],
        enemy_action=mem[0xec],enemy_action_flags=mem[0xed],player_x=mem[0xf7],player_y=mem[0xf8],
        enemy_x=mem[0xf9],enemy_y=mem[0xfa],enemy_dead=mem[0xfc],player_dead=mem[0xfb],
        enemy_health=mem[0x2d9],player_health=mem[0x1c],honour=mem[0x1b],lives=mem[0x3c],
        player_weapon=mem[0x321],enemy_weapon=mem[0x322],enemy_costume=mem[0x318],enemy_behavior=mem[0x317])

def main():
    reports=[]
    for level in range(1,6):
        ram=level_memory(level);s=layout(ram);out=ROOT/f'source/local/recovered/ln3/level{level}';out.mkdir(parents=True,exist_ok=True)
        lo=word(ram,s['exit']+8);hi=word(ram,s['exit']+13);count=hi-lo
        assert 1<=count<=32,count
        # Boundary-table selection is the first call made by the collision walk.
        boundary_setup=calls(ram,s['collision'])[0]
        blo=word(ram,boundary_setup+3);bhi=word(ram,boundary_setup+8)
        mlo=word(ram,s['mask']+3);mhi=word(ram,s['mask']+8)
        # Variable-size masks can finish with a shared-list jump ($fe).
        link=None
        for pc in range(s['mask'],s['mask']+180):
            if ram[pc]==0xa9 and ram[pc+2:pc+5]==bytes.fromhex('85 7a a9') and ram[pc+6:pc+8]==bytes.fromhex('85 7b'):
                link=ram[pc+1]+256*ram[pc+5]
        rooms=[];unused_scenes=[]
        exit_calls=calls(ram,s['exit']);actor_reset=exit_calls[exit_calls.index(s['scene_enter'])-1]
        for scene in range(count):
            if ram[0x803+scene*2]==255:
                unused_scenes.append(scene);continue
            exits=[];p=ram[lo+scene]+256*ram[hi+scene]
            while ram[p]!=255:
                flag=ram[p];size=8+((flag>>6)&3)+((flag>>5)&1);raw=list(ram[p:p+size])
                rectangle=flag>=128 or not(flag&12);dest_index=5 if rectangle else 3
                exits.append(dict(source_address=p,flags=flag,raw=raw,destination=raw[dest_index],
                                  spawn_x=raw[dest_index+1],spawn_y=raw[dest_index+2],
                                  facing=raw[dest_index+3],action=raw[dest_index+4]))
                p+=size;assert len(exits)<20,(level,scene,exits)
            boundaries=[];p=ram[blo+scene]+256*ram[bhi+scene]
            while ram[p]!=255:
                size=5+bool(ram[p+4]&32);boundaries.append(dict(source_address=p,raw=list(ram[p:p+size])))
                p+=size;assert len(boundaries)<100,(level,scene)
            masks=[];p=ram[mlo+scene]+256*ram[mhi+scene];seen=set()
            while ram[p]!=255:
                assert p not in seen,(level,scene,p);seen.add(p)
                if ram[p]==254:
                    assert link is not None;p=link;continue
                flag=ram[p];size=4 if flag>=128 else 3
                masks.append(dict(source_address=p,x=flag&127,y=ram[p+1],part=ram[p+2],
                                  baseline=ram[p+3] if size==4 else -1))
                p+=size;assert len(masks)<100
            mem=list(ram);mem[0xe3]=scene;mem[0xfc]=0
            # The real exit path resets enabled parts before enemy entry. A
            # room without an encounter must not inherit the previous guard.
            call(mem,actor_reset);call(mem,s['enemy_enter'])
            image=render_scene(ram,s,scene);image.save(out/f'room-{scene:02}.png')
            rooms.append(dict(id=scene,exits=exits,boundaries=boundaries,masks=masks,initial=actor_state(mem),
                              image_sha256=hashlib.sha256(image.tobytes()).hexdigest()))
        # Four-byte definitions select each actor's three sprite sequences and
        # movement flags. There are 39 player and 22 enemy definitions; the
        # following bytes are pose/offset tables, not extra enemy actions.
        action_lookup=calls(ram,s['player_action'])[0]
        assert ram[action_lookup:action_lookup+3]==bytes.fromhex('0a 0a 69')
        base=ram[action_lookup+3]+256*ram[action_lookup+7]
        definitions=[list(ram[base+i*4:base+i*4+4]) for i in range(61)]
        # The sprite-update loop indexes the sequence tables in RAM below I/O.
        update=s['sprite_update'];seqlo=word(ram,update+32);seqhi=word(ram,update+37)
        assert 1<=seqhi-seqlo<=256,(level,hex(seqlo),hex(seqhi))
        scripts=[];frames=set()
        for index in range(seqhi-seqlo):
            p=ram[seqlo+index]+256*ram[seqhi+index];start=p;poses=[]
            while ram[p]<254:
                poses.append(ram[p]);frames.add(ram[p]);p+=1;assert len(poses)<256,(level,index,start)
            scripts.append(dict(id=index,source_address=start,frames=poses,loop=ram[p]==254))
        raw=next((ROOT/'tools/vendor/integrator-ln3').rglob(f'int-level{level}-tape.prg')).read_bytes();base=word(raw,0)
        match=ram[base:base+len(raw)-2]==raw[2:]
        world=dict(game=3,level=level,title=NAMES[level-1],source_layout=s,rooms=rooms,unused_scenes=unused_scenes,
                   initial=actor_state(ram),inventory=list(ram[2:0x20]),source_sha256=hashlib.sha256(ram).hexdigest(),
                   scenery_payload_matches_supplied_game=match,actions=definitions,animations=scripts,frame_ids=sorted(frames))
        write_json(out/'world.json',world)
        report=dict(level=level,title=NAMES[level-1],rooms=len(rooms),exits=sum(len(r['exits']) for r in rooms),
                    boundary_records=sum(len(r['boundaries']) for r in rooms),animations=len(scripts),
                    source_sha256=world['source_sha256'],scenery_payload_matches_supplied_game=match,native_gameplay_connected=False)
        reports.append(report);print(report,flush=True)
    write_json(ROOT/'evidence/ln3_content_recovery.json',dict(levels=reports,scope=__doc__,full_gameplay_parity=False))

if __name__=='__main__':main()
