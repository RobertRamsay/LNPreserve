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
    ln2=[read(PROJECT/f'datafiles/play/ln2/level{n}/world.json') for n in range(1,8)]
    ln2_rooms=sum(sum(r['spawn_entry']>=0 for r in w['rooms']) for w in ln2)
    ln3=[read(PROJECT/f'datafiles/play/ln3/level{n}/world.json') for n in range(1,6)]
    ln3_rooms=sum(sum(r['playable'] for r in w['rooms']) for w in ln3)
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
                    ln2_native_levels=7,ln2_native_selectable_scenes=ln2_rooms,
                    ln2_scene_records=sum(len(w['rooms']) for w in ln2),
                    ln2_enemy_placements=sum(sum(r['enemy']['active']>=128 for r in w['rooms']) for w in ln2),
                    ln2_item_and_mechanism_records=sum(len(w['items']) for w in ln2),
                    silent_sound_assets=sum(s['status']=='silent_placeholder' for s in music['sounds'])),
        provenance={s:[d['id'] for d in graphics['datasets'] if d['provenance']['status']==s]
                    for s in sorted({d['provenance']['status'] for d in graphics['datasets']})},
        native_original_routines=[dict(name='LN1 sprite decompression',address='$7e36-$7e77',
            verification='192 byte payloads and original instruction-cycle counts; no VIC/CIA/interrupt timing'),
            dict(name='LN1 F1/F3/F5/F7 and Space selection',address='$6eac-$6f6c',
            verification='1024 key-chord transitions; state and external request order; display callees intercepted; timing not tested')],
        current_gameplay='Native prototypes in all 18 levels across LN1, LN2 and LN3; no verified complete game',
        pending=['Complete and verify LN1 puzzle sequences, special enemies, projectile combat, palette effects, death presentation and ending',
            'Complete LN2 boundary hazards, projectile combat and remaining object details; verify the final encounter and ending with original input replays',
            'Complete LN3 high-score program, dashboard/portrait, raster ending presentation and remaining palette effects; verify full objectives and encounters against original input replays',
            'Verify LN3 multicolour/expanded special actors and full composition; validate LN1/LN2 composition, palette changes and missing special effects',
            'LN2 original dashboard/eyes, item flashing, keypad pre-poll delay, complete score-event dispatch and death/game-over presentation',
            'Validate recovered LN1 composition, room masks, dynamic dashboard and palette semantics against original display captures',
            'Whole-game cycle-stamped reference traces and native comparisons',
            'Real music and sound effects; silent named placeholders are supplied'])
    status['native_original_routines'].extend([
        dict(name='LN1 player movement and animation',address='$5727/$5a12/$5b69/$7540',verification='2856 source-code updates, including 128 prayer animation samples; rendering intercepted; world and system timing excluded'),
        dict(name='LN1 enemy decisions and animation',address='$6a48/$5b54',verification='7680 source-code updates with shared random returns; dispatch and hardware read timing excluded'),
        dict(name='LN1 melee hit testing',address='$7ecc',verification='6843 valid-attack samples; damage dispatch and whole combat replay excluded'),
        dict(name='LN1 river sinking timer',address='$bee3/$56f7',verification='1536 tick/clock states including wrap; rendering and interrupt timing excluded')])
    status['scene_testing']=dict(arrow_mapping=dict(right='NE',down='SE',left='SW',up='NW'),
        playable_rooms=room_count+ln2_rooms+ln3_rooms,playable_scope='All 18 levels across the three games, native prototypes',level_datasets_in_picker=18,
        remaining_levels='No scenery-only level; complete gameplay content remains unfinished in all three games',
        original_exit_routine_vectors=54+sum(l['navigation_vectors'] for l in levels)+191,whole_game_test_coverage=False)
    status['native_original_routines'].extend([
        dict(name='LN1 levels 2-6 enemy action selection',verification='4480 original selector cases, including skeleton and final enemy'),
        dict(name='LN1 projectile movement and lifetime',verification='4032 original one-tick states across all six level banks; collision dispatch and display timing excluded')])
    status['native_original_routines'].extend([
        dict(name='LN2 player movement/animation',verification='34664 original updates across seven banks; world dispatch, vehicles and system timing excluded'),
        dict(name='LN2 enemy decisions/animation',verification='50432 original updates with shared random returns; combat dispatch and hardware random phase excluded'),
        dict(name='LN2 melee ranges',verification='21000 original attack-window comparisons; complete combat replay excluded'),
        dict(name='LN2 entrance hooks',verification='784 original actor/vehicle/inventory-gate states; drawing side effects excluded'),
        dict(name='LN2 automatic entrance motion',verification='11136 original states and requested poses across seven banks'),
        dict(name='LN2 moving-world handlers',verification='3520 original state comparisons; rendering requests intercepted'),
        dict(name='LN2 Mansion helicopter',verification='256 original attachment/drop states and poses; world event dispatch excluded')])
    status['native_original_routines'].extend([
        dict(name='LN3 sprite-part movement',verification='6000 original part-movement states across five banks; scene collision and system timing excluded'),
        dict(name='LN3 player/enemy action setup',verification='5490 original action states, including mutable movement directions'),
        dict(name='LN3 input selection',verification='3510 original input states, including weapon selection and climbing exits; world interactions and timing excluded'),
        dict(name='LN3 animation and weapon placement',verification='10925 original animation updates and body/weapon placements; bitmap compositor intercepted'),
        dict(name='LN3 sprite visibility masks',verification='4224 original 24x21 masks across 66 scenery records, including retained fragment data'),
        dict(name='LN3 scene collision',verification='7191 original boundary responses across five banks'),
        dict(name='LN3 enemy decisions',verification='6000 original decision/attack/patrol/recovery states with shared random input'),
        dict(name='LN3 combat',verification='6000 melee/projectile states; score display and level loading intercepted; complete special encounters excluded'),
        dict(name='LN3 room/hazard/climbing state',verification='3064 original room reset, enemy entry, climbing and falling states'),
        dict(name='LN3 ordinary sprite GPU composition',verification='66528 alpha/tint pixels from 132 original decompressed and masked ordinary sprite parts; expanded/multicolour special actors excluded')])
    status['counts'].update(ln3_recovered_level_banks=5,ln3_recovered_scene_records=66,ln3_native_playable_levels=5,
        ln3_native_selectable_scenes=ln3_rooms,ln3_unique_actor_part_frames=1158,ln3_ordinary_enemy_placements=57,
        ln3_special_entry_actor_scenes=6)
    status['ln3_integration']=dict(scene_ticks=6500,destination_records=201,complete_gameplay_parity=False,
        special_final_entrance='Void reflected-bolt gateway connects the final fight; the native ENDING picture sequence and text reach the high-score request boundary. High-score program remains pending.',
        unselectable_record='Fire scene 12: partial scenery without ordinary entry, exit or enemy')
    status['counts'].update(ln3_item_and_mechanism_records=29,ln3_scenery_animation_steps=49,
        ln3_unique_animation_overlays=50,ln3_unique_mechanism_overlays=52,
        ln3_ending_unique_picture_frames=10,ln3_ending_unique_font_frames=22,
        ln2_latent_final_enemy_placements=1,ln2_final_enemy_pose_mirror_images=208)
    status['ln3_integration'].update(item_states=3480,special_states=3520,curtain_motion_states=1260,
        scenery_selector_states=1176,scenery_gpu_samples=6028,mechanism_gpu_samples=5280,
        full_interrupt_timing_verified=False,ending_scroll_states=1736,ending_scroll_gpu_pixels=58368)
    status['native_original_routines'].extend([
        dict(name='LN2 keypad input/acceptance',verification='4096 original states; temporary display and pre-poll delay excluded'),
        dict(name='LN2 candle/final-defeat rules',verification='3840 original states and drawing/animation requests'),
        dict(name='LN2 final enemy release',verification='384 original states, plus 1916928 unmasked pose/mirror GPU pixels'),
        dict(name='LN2 post-item animation',verification='12544 original action/countdown states across seven banks'),
        dict(name='LN2 score, clock and health display',verification='6144 original states; raster and complete score-event dispatch excluded'),
        dict(name='LN2 victory loop and spirit motion',verification='3072 victory, 2048 palette and 2048 motion states; 30720 game/ending bitmap samples')])
    status['ln2_final_content']=dict(keypad=True,boss_release=True,five_candles=True,both_defeat_entrances=True,
        final_item=True,native_ending=True,original_picture_and_digit_pngs=True,
        first_and_repeated_palette_states=12,palette_loop_return=4,
        original_full_playthrough_verified=False,raster_timing_verified=False)
    for name in ('runtime_checks','structural_checks','ln1_actor_decoder_checks','asset_cleanup','asset_rebuild_check','ln1_level_content','ln1_level_asset_sharing','ln2_content_recovery','ln3_content_recovery','ln3_mask_checks','ln3_asset_import'):
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
