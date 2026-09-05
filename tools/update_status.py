"""Summarize evidence without promoting component tests to gameplay parity."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'LNPreserve'
def read(path):return json.loads(path.read_text())
def main():
    graphics=read(PROJECT/'datafiles/graphics/manifest.json');music=read(PROJECT/'datafiles/music_manifest.json')
    status=dict(schema=1,project='LNPreserve',stage='native_conversion_in_progress',
        playable_trilogy=False,complete_asset_conversion=False,cycle_accurate_gameplay_verified=False,
        runtime_contains_c64_emulator=False,
        counts=dict(scenery_png_objects=sum(len(d['objects']) for d in graphics['datasets']),
                    diagnostic_scene_previews=sum(len(d['locations']) for d in graphics['datasets']),
                    scenery_datasets=len(graphics['datasets']),ln1_character_parts=192,
                    silent_sound_assets=sum(s['status']=='silent_placeholder' for s in music['sounds'])),
        provenance={s:[d['id'] for d in graphics['datasets'] if d['provenance']['status']==s]
                    for s in sorted({d['provenance']['status'] for d in graphics['datasets']})},
        native_original_routines=[dict(name='LN1 sprite decompression',address='$7e36-$7e77',
            verification='192 byte payloads and original instruction-cycle counts; no VIC/CIA/interrupt timing'),
            dict(name='LN1 F1/F3/F5/F7 and Space selection',address='$6eac-$6f6c',
            verification='1024 key-chord transitions; state and external request order; display callees intercepted; timing not tested')],
        pending=['Native movement, collision, jumps and animation scheduling for all games',
            'Enemy AI, combat/hit resolution, puzzles, inventory use, room transitions, deaths and completion',
            'LN2/LN3 binary unpacking and source-disk verification of reference scenery datasets',
            'LN2/LN3 character and animation recovery; remaining LN1 graphical assets and composition validation',
            'Original per-room occlusion rules, LN1 masks and exact bitmap overlap/palette semantics',
            'Whole-game cycle-stamped reference traces and native comparisons',
            'Real music and sound effects; silent named placeholders are supplied'])
    for name in ('runtime_checks','structural_checks','ln1_actor_decoder_checks'):
        path=ROOT/'evidence'/f'{name}.json'
        if path.exists():status[name]=read(path)
    (ROOT/'evidence/STATUS.json').write_text(json.dumps(status,indent=2)+'\n')
    print(json.dumps(status['counts'],indent=2))
if __name__=='__main__':main()
