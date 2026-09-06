"""Decode LN3 animation, part-offset and weapon-placement tables offline."""
from ln3_level_source import word,calls

def decode(ram,s):
    update=s['sprite_update'];handlers=calls(ram,update);lo=word(ram,update+32);hi=word(ram,update+37)
    sequences=[]
    for index in range(hi-lo):
        p=ram[lo+index]+256*ram[hi+index];frames=[]
        while ram[p]<254:
            frames.append(ram[p]);p+=1;assert len(frames)<256
        sequences.append(dict(frames=frames,loop=ram[p]==254,offsets=[]))
    off=handlers[3];ids=word(ram,off+13);pointers=word(ram,off+21)
    for i in range(35):
        seq=sequences[ram[ids+i]];p=word(ram,pointers+2*i)
        seq['offsets']=[list(ram[p+j*2:p+j*2+2]) for j in range(len(seq['frames']))]
    p=handlers[5];over=word(ram,p+107)
    framebase=word(ram,p+68);offsetbase=word(ram,p+84)
    positions=ram[p+92]+256*ram[p+100];animations=word(ram,p+104)
    oid=word(ram,over+5);ocursor=word(ram,over+12);oseq=word(ram,over+40)
    opos=ram[over+30]+256*ram[over+34]
    change=word(ram,p+38);throw_player=word(ram,handlers[6]+22);throw_frames=word(ram,handlers[6]+30)
    throw_enemy=word(ram,handlers[8]+27)
    order=word(ram,update+9)
    result=dict(sequences=sequences,order=list(reversed(ram[order:order+8])),
        masks=list(ram[0xff78:0xff80]),hazard_actor_exempt=bytes.fromhex('a5 54 c9 8a') in ram[update:handlers[0]],
        weapon_frames=list(ram[framebase:framebase+55]),weapon_offsets=list(ram[offsetbase:offsetbase+4]),
        weapon_poses=[dict(animation=ram[animations+i],offset=list(ram[positions+2*i:positions+2*i+2])) for i in range(165)],
        weapon_overrides=[dict(action=ram[oid+i],cursor=ram[ocursor+i],
            poses=[dict(animation=ram[oseq+i*3+j],offset=list(ram[opos+2*(i*3+j):opos+2*(i*3+j)+2])) for j in range(3)]) for i in range(12)],
        weapon_change_cursors=list(ram[change:change+2]),throw_player_actions=list(ram[throw_player:throw_player+2]),
        throw_enemy_actions=list(ram[throw_enemy:throw_enemy+2]),throw_frames=list(ram[throw_frames:throw_frames+2]))
    assert sorted(result['order'])==list(range(8))
    assert result['weapon_offsets'][1:]==[0,55,110]
    assert max(result['throw_player_actions'])<39 and max(result['throw_enemy_actions'])<61
    return result
