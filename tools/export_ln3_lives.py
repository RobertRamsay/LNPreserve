from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(Path('audit_python_deps').resolve()),str(root/'tools')]
# Use the existing C64 RAM/colour-RAM decoder without running its HUD exporter.
src=(root/'tools/export_ln3_hud.py').read_text().split('res={};meta={};')[0]
scope={'__file__':str(root/'tools/export_ln3_hud.py')};exec(src,scope)
Mem,call,pic,b,register=[scope[k] for k in ['Mem','call','pic','b','register_project']]
frames=[]
for code in range(32,91):
 m=Mem()
 # $35 exposes colour RAM; $34 inside $6de9 exposes the font beneath I/O.
 m[1]=0x35
 for p in range(0xe000,0xe000+18*320):m[p]=0
 m[0x7e05]=0;m[0x7e0a]=0x30
 for i,v in enumerate([0,0,code,36]):m[0x3000+i]=v
 call(m,0x6da2)
 assert code==36 or (m.r[0xcc00]==0xa8 and m.c[0]==7), "Original message palette must be light red/orange/yellow"
 frames.append(pic(m).crop((0,0,8,8)))
b.REFRESH_GRAPHICS=True
tmp=root/'build/ln3-lives-font.png';frames[0].save(tmp)
name='spr_ln3_lives_font'
register({name:b.sprite_resource(name,tmp,'Graphics/ln3_game_actors',frames)},[])
