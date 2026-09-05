"""Summarize evidence without promoting component tests to gameplay parity."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1];PROJECT=ROOT/'LNPreserve'
def read(path):return json.loads(path.read_text())
def main():
    graphics=read(PROJECT/'datafiles/graphics/manifest.json');music=read(PROJECT/'datafiles/music_manifest.json')
    worlds=[read(PROJECT/'datafiles/play/ln1'/('world.json' if n==1 else f'level{n}/world.json')) for n in range(1,7)]
    room_count=sum(len(w['rooms']) for w in worlds)
    item_count=sum(len(w['items']) for w in worlds)
    levels=read(ROOT/'evidence/ln1_level_content.json')['levels']
    status=dict(schema=1,project='LNPreserve',stage='native_conversion_in_progress',
        playable_trilogy=False,complete_asset_conversion=False,cycle_accurate_gameplay_verified=False,
        runtime_contains_c64_emulator=False,
        counts=dict(scenery_source_object_records=sum(len(d['objects']) for d in graphics['datasets']),
                    diagnostic_scene_source_records=sum(len(d['locations']) for d in graphics['datasets']),
                    unique_scenery_pngs=graphics['image_deduplication']['unique_images'],
                    scenery_image_aliases=graphics['image_deduplication']['alias_records'],
                    scenery_datasets=len(graphics['datasets']),ln1_character_parts=192,
                    ln1_native_levels=6,ln1_native_room_layouts=room_count,ln1_shared_human_actor_poses=1024,
                    ln1_item_and_mechanism_placements=item_count,
                    silent_sound_assets=sum(s['status']=='silent_placeholder' for s in music['sounds'])),
        provenance={s:[d['id'] for d in graphics['datasets'] if d['provenance']['status']==s]
                    for s in sorted({d['provenance']['status'] for d in graphics['datasets']})},
        native_original_routines=[dict(name='LN1 sprite decompression',address='$7e36-$7e77',
            verification='192 byte payloads and original instruction-cycle counts; no VIC/CIA/interrupt timing'),
            dict(name='LN1 F1/F3/F5/F7 and Space selection',address='$6eac-$6f6c',
            verification='1024 key-chord transitions; state and external request order; display callees intercepted; timing not tested')],
        current_gameplay='Six connected native LN1 level prototypes; no verified complete game',
        pending=['Complete and verify LN1 puzzle sequences, special enemies, projectile combat, palette effects, death presentation and ending',
            'Translate and connect LN2/LN3 native gameplay and all objective handlers',
            'LN3 levels 2-5 source-disk verification; LN3 level 1 payload and opening background are verified',
            'Finish LN2/LN3 character and animation recovery; remaining LN1 composition validation',
            'Validate recovered LN1 composition, room masks, dynamic dashboard and palette semantics against original display captures',
            'Whole-game cycle-stamped reference traces and native comparisons',
            'Real music and sound effects; silent named placeholders are supplied'])
    status['native_original_routines'].extend([
        dict(name='LN1 player movement and animation',address='$5727/$5a12/$5b69/$7540',verification='2856 source-code updates, including 128 prayer animation samples; rendering intercepted; world and system timing excluded'),
        dict(name='LN1 enemy decisions and animation',address='$6a48/$5b54',verification='7680 source-code updates with shared random returns; dispatch and hardware read timing excluded'),
        dict(name='LN1 melee hit testing',address='$7ecc',verification='6843 valid-attack samples; damage dispatch and whole combat replay excluded'),
        dict(name='LN1 river sinking timer',address='$bee3/$56f7',verification='1536 tick/clock states including wrap; rendering and interrupt timing excluded')])
    status['scene_testing']=dict(arrow_mapping=dict(right='NE',down='SE',left='SW',up='NW'),
        playable_rooms=room_count,playable_scope='All six LN1 levels, native prototypes',level_datasets_in_picker=18,
        remaining_levels='LN2/LN3 scenery previews; native gameplay and directional exits unavailable',
        original_exit_routine_vectors=54+sum(l['navigation_vectors'] for l in levels),whole_game_test_coverage=False)
    status['native_original_routines'].extend([
        dict(name='LN1 levels 2-6 enemy action selection',verification='4480 original selector cases, including skeleton and final enemy'),
        dict(name='LN1 projectile movement and lifetime',verification='4032 original one-tick states across all six level banks; collision dispatch and display timing excluded')])
    for name in ('runtime_checks','structural_checks','ln1_actor_decoder_checks','asset_cleanup','asset_rebuild_check','ln1_level_content','ln1_level_asset_sharing','ln2_content_recovery'):
        path=ROOT/'evidence'/f'{name}.json'
        if path.exists():
            status[name]=read(path)
            if name=='asset_cleanup':status[name].pop('removed_sprite_resources',None)
    colour=ROOT/'evidence/scenery_colour_audit.json'
    if colour.exists():
        audit=read(colour)
        status['scenery_colour_check']=dict(applied_scenes=audit.get('applied_scenes',[]),
            original_ln3_level1_scene0=audit['original_ln3_level1_scene0'],
            other_candidates_applied=False,other_changed_scene_records=audit['changed_scene_records']-1)
    (ROOT/'evidence/STATUS.json').write_text(json.dumps(status,indent=2)+'\n')
    print(json.dumps(status['counts'],indent=2))
if __name__=='__main__':main()
