"""Recover LN1 weapon strip and health spiral from the supplied C64 RAM.
Only these new HUD sprites are written; consolidated character banks are untouched.
"""
from pathlib import Path
import tempfile
import build_project as builder
from export_ln1_world import ROOT, call, bitmap


def main():
    ram = (ROOT/'source/local/captures/ln1-game-ram.bin').read_bytes()
    project_path = ROOT/'LNPreserve/LNPreserve.yyp'
    project = builder.read_json(project_path)
    resources = {r['id']['name']: r for r in project['resources']}
    with tempfile.TemporaryDirectory() as temp:
        def save(name, frames):
            source = Path(temp)/(name+'.png')
            frames[0].save(source)
            resources[name] = builder.sprite_resource(name, source, 'Graphics/ln1_game_level1', frames)
        # $65bf draws five owned weapons ($03f7..$03fb), masking bit 7.
        # All five occupy the original bottom strip x96..191, y152..183.
        frames = []
        for mask in range(32):
            mem = list(ram)
            for weapon in range(5):
                mem[0x3f7+weapon] = (mask >> weapon) & 1
            call(mem, 0x65bf)
            frames.append(bitmap(mem, 320, 200).crop((96,152,192,184)))
        save('spr_ln1_weapon_inventory', frames)
        # $5586 fills one spiral cell; $55ad clears one. $c7 is the
        # displayed health, $c8 the target. Recover every settled state.
        frames = []
        for health in range(33):
            mem = list(ram)
            for cell in range(32):
                offset = ram[0x697c+cell]
                mem[0xc2f9+offset] = ram[0x699c+cell] if cell < health else 0
                colour = ram[0x69bc+cell] if cell < health else 0
                mem[0xc6f9+offset] = mem[0xdaf9+offset] = colour
            frames.append(bitmap(mem, 320, 200).crop((8,152,72,184)))
        save('spr_ln1_player_health', frames)
    project['resources'] = list(resources.values())
    # Preserve GameMaker's existing formatting and user edits.
    text = project_path.read_text()
    for name in ('spr_ln1_weapon_inventory', 'spr_ln1_player_health'):
        if not any(r['id']['name'] == name for r in builder.read_json(project_path)['resources']):
            entry = '{"id":{"name":"'+name+'","path":"sprites/'+name+'/'+name+'.yy",},},'
            text = text.replace('"resources":[', '"resources":[\n    '+entry, 1)
    project_path.write_text(text)

if __name__ == '__main__':
    main()
