/// Help guide: an internal, read-only tour of every screen, button, panel and shortcut.
/// Each step names a screen to show, a rectangle to highlight (1920x1080 output space)
/// and a description. While the guide is open the game is paused and only the guide
/// takes input; leaving restores every screen and setting it changed.

/// Tool-surface rectangle (1280x800, drawn at 320,140) in output space.
function ln_guide_t(_x,_y,_w,_h) {return [_x+320,_y+140,_w,_h];}
function ln_guide_step_new(_cat,_screen,_title,_text,_rect=undefined) {return {cat:_cat,screen:_screen,title:_title,text:_text,rect:_rect};}

function ln_guide_steps() {
    var _s=[],T=ln_guide_t,S=ln_guide_step_new;
    // Welcome
    array_push(_s,S("Welcome","play","Help guide","This guide walks through every screen, button, panel and shortcut key, one at a time.\n\nNext (Right arrow, Enter or Space) moves on, Back (Left arrow) goes back and Esc closes the guide. Click the bar along the bottom to jump to any section.\n\nNothing is live while the guide is open: the game is paused and clicks only reach the guide."));
    // Main screen
    var C="Main screen";
    array_push(_s,S(C,"play","The game","The game runs here at four times its original size, with its own built-in HUD. Last Ninja 1, 2 and 3 all play in this area.",T(160,84,960,600)));
    array_push(_s,S(C,"play","USER INT. (U)","Hides every tool panel for a clean, centred game picture. The button lingers and then fades; press U, or Esc, to bring the panels back.",[320,96,160,28]));
    array_push(_s,S(C,"play","Background (B)","Shows or hides the artwork behind the tool.",[492,96,240,28]));
    array_push(_s,S(C,"play","EDITOR (F6)","Opens the scene editor on the room you are playing. It has its own sections later in this guide.",[748,96,180,28]));
    array_push(_s,S(C,"play","GAME/LEVELS (F11)","Opens the game, level and scene picker. The game pauses while it is open.",[940,96,238,28]));
    array_push(_s,S(C,"play","Window size","1x sets a 1920x1080 window, 2x sets 3840x2160 (limited to your desktop) and Fit picks the largest size that fits. The window size is remembered.",[1256,96,160,28]));
    array_push(_s,S(C,"play","Fullscreen (F10)","Switches borderless fullscreen on or off. F10 works on every screen, and switching off returns to your last window size.",[1424,96,176,28]));
    array_push(_s,S(C,"play","CRT ON/OFF (F9)","Turns the CRT picture effect on or off. Its settings appear while it is on; they are covered in the next section.",T(1128,36,144,36)));
    array_push(_s,S(C,"play","Saves","Ctrl+S saves the game into the top slot. There are ten slots, newest at the top. Click a filled slot to load it.",T(1128,84,144,536)));
    array_push(_s,S(C,"play","Window panel","Shows the current window size, with small 1x, 2x and Fit buttons that work like the ones at the top.",T(1128,602,144,46)));
    array_push(_s,S(C,"play","LN mode: Enhanced / Original","Each game has its own setting, saved between sessions. Enhanced adds double-tap turning; in LN3 it also gives smooth movement and slower jumps. Original plays exactly like the C64.",[320,940,280,28]));
    array_push(_s,S(C,"play","Help guide","Opens this guide.",[615,940,240,28]));
    array_push(_s,S(C,"play","Load edits","Loads a saved project file (.json) of scene and sprite edits, and switches Modified on so the game uses them.",[870,940,240,28]));
    array_push(_s,S(C,"play","Sprite viewer","Opens the sprite viewer, where every character and object can be played and edited. Covered later in this guide.",[1120,940,150,28]));
    array_push(_s,S(C,"play","Track player","Opens the track player to listen to every loader, in-game, intro and outro tune.",[1280,940,140,28]));
    array_push(_s,S(C,"play","Music ON/OFF","Turns the game music on or off. F1 does the same during play.",[1430,940,120,28]));
    array_push(_s,S(C,"play","Unsaved edits prompt","After editing, \"Unsaved edits. Save project?\" appears here. Yes saves the project to a file; No hides the prompt until your next edit.",[320,976,490,28]));
    // CRT settings
    C="CRT settings";
    array_push(_s,S(C,"crt","CRT settings","Pixel blur, Honeycomb (or Phosphors) and Scanlines, from 0 to 100%. Click or drag a track; the picture updates straight away.",T(1128,650,144,142)));
    array_push(_s,S(C,"crt","Scanline samples","Finer CRT tuning, shown under the game picture while CRT is on.",T(160,690,960,104)));
    array_push(_s,S(C,"crt","Scanline presets","Previous, Pixel edge, Soft 5 and Deep 5 set the scanlines in one click.",T(172,716,588,28)));
    array_push(_s,S(C,"crt","Phosphor / Classic","Chooses the mask: staggered RGB phosphors, or the classic honeycomb.",T(172,756,212,30)));
    array_push(_s,S(C,"crt","Spacing","Phosphor spacing, from 0.5x to 2x.",T(400,746,370,44)));
    array_push(_s,S(C,"crt","Width and Alignment","Scanline width (1 to 7 rows) and where the lines sit.",T(800,712,140,78)));
    array_push(_s,S(C,"crt","Exposure and Contrast","Brightness and contrast of the CRT picture.",T(955,712,145,78)));
    // Playing
    C="Playing";
    array_push(_s,S(C,"play","Moving and fighting","W, A, S and D move; press two together for diagonals. # is fire. Fire with a direction performs the original moves: attacks, jumps and somersaults.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Weapons, items and pause","Space: next weapon.\nF3 / F5: next / previous item.\nF1: music on or off.\nF7 or P: pause.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Saving and rewinding","Ctrl+S saves to a slot.\nHold the Left arrow to rewind, up to about ten seconds within the current scene.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Starting and restarting","1, 2 and 3 start Last Ninja 1, 2 or 3 afresh.\nHome restarts the current game.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Escape","Once: brings back a hidden UI, or closes the open panel.\nTwice quickly: restarts the app at the title screen.\nHold for a second during play: lose a life the game's own way.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Testing aids","F8: one-hit kills on or off.\nF12: the developer workbench.\nNumpad 7, 9, 1 and 3 (Num Lock on): jump through the NW, NE, SW and SE exits.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Enhanced controls","Double-tap a direction (tap, release, press again quickly) to face that way at once instead of walking backwards. A single push still walks backwards.\nFire while walking backwards somersaults backwards without turning.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Assists","Fire alone near an item lines the ninja up and picks it up.\nLN1: two quick fire presses at river crossings jump to the next safe platform.\nWith food selected (apples, burger or food), two quick fire presses restore health.\nLN2 final battle: two quick fire presses light a candle.",T(160,84,960,600)));
    array_push(_s,S(C,"play","Xbox controller","Stick or D-pad: move. A: fire. B or Start: pause. Y: music. X: CRT.\nRB / LB: next / previous item. RT / LT: next / previous weapon.\nClick the right stick to rewind. The game lists these while a pad is connected.",T(160,84,960,600)));
    // Game and level picker
    C="Game/Levels (F11)";
    array_push(_s,S(C,"menu","Games","Choose which game's levels to list.",T(160,116,944,44)));
    array_push(_s,S(C,"menu","Levels","Choose a level. In Last Ninja 3 the INTRO and OUTRO buttons play the presentations.",T(160,218,282,370)));
    array_push(_s,S(C,"menu","Scenes","Click a scene to jump straight into it. 0 starts the level from its loading screen. Items and wounds carry over; changing level restores full health.",T(480,266,604,320)));
    array_push(_s,S(C,"menu","Enemy damage","Turns enemy damage off for testing. Hazards still hurt.",T(480,610,374,48)));
    array_push(_s,S(C,"menu","LN mode","The same Enhanced / Original setting, for the game selected here.",T(480,736,300,44)));
    array_push(_s,S(C,"menu","Scene painting speed","How fast scenes paint in as you enter them, from 0.1x to 5x. Click the line below the slider to reset it to 1x.",T(860,540,270,88)));
    array_push(_s,S(C,"menu","Return to gameplay","Closes the picker. Esc and F11 do the same.",T(160,674,282,48)));
    // Scene editor
    C="Scene editor";
    array_push(_s,S(C,"editor","Scene editor","Edit any room of any game. Changes apply straight away and are kept in your project until you save it. Undo works across play-testing.",T(0,0,1280,800)));
    array_push(_s,S(C,"editor","Modified ON/OFF","Switches all your scene edits on or off in the game, so you can compare with the original.",T(24,18,180,28)));
    array_push(_s,S(C,"editor","Save file / Load file","Saves the whole project to a file, or loads one.",T(216,18,236,28)));
    array_push(_s,S(C,"editor","Undo and Redo","Undo (Ctrl+Z) and Redo (Ctrl+Y) for room edits.",T(464,18,112,28)));
    array_push(_s,S(C,"editor","Build preview","Replays the room's original build-up animation. The - and + buttons beside it set its speed.",T(588,18,502,28)));
    array_push(_s,S(C,"editor","Restore all","Puts this room's parts back to the original. It can be undone.",T(752,18,132,28)));
    array_push(_s,S(C,"editor","Editor CRT (F9)","CRT effect on the editor's room preview only.",T(1110,18,160,28)));
    array_push(_s,S(C,"editor","Game, level and room","Ninja 1, 2 and 3 pick the game; the arrows step through levels and rooms. Hold an arrow to keep stepping.",T(24,62,816,28)));
    array_push(_s,S(C,"editor","Level map","Opens the level map, showing how rooms connect. It has its own section.",T(974,62,124,28)));
    array_push(_s,S(C,"editor","Back to game (F6)","Closes the editor and returns to play.",T(1110,62,160,28)));
    array_push(_s,S(C,"editor","Room preview","The room at three times size. Drag the selected part to move it. Alt-click picks the part under the cursor. Right-drag places the preview ninja. Arrow keys nudge the part (Shift for 8).",T(24,140,720,432)));
    array_push(_s,S(C,"editor","Parts","Every part of the room in draw order; later parts draw in front. Click one to select it. The mouse wheel scrolls.",T(760,140,225,396)));
    array_push(_s,S(C,"editor","Assets","Every graphic in this level. Click one to choose it.",T(1000,140,250,396)));
    array_push(_s,S(C,"editor","Up, Down and Remove","Move the selected part earlier or later in the draw order, or remove it (Delete key).",T(760,548,224,28)));
    array_push(_s,S(C,"editor","Add selected asset","Adds the chosen asset to the room as a new part.",T(1000,548,245,28)));
    array_push(_s,S(C,"editor","Edit scenery artwork","Opens the chosen asset in the pixel editor. It has its own section.",T(1000,582,245,28)));
    array_push(_s,S(C,"editor","Part controls","For the selected part: Flip X mirrors it. The depth mode cycles Inherited, Depth, Always front and Ground. - and + change the depth, or click the number to type one (Enter applies). Up 10, Down 10, Top and Bottom move it through the draw order.",T(760,630,264,138)));
    array_push(_s,S(C,"editor","Asset preview","A close-up of the chosen asset.",T(1058,630,156,156)));
    array_push(_s,S(C,"editor","Collision overlay","Shows the room's collision lines over the preview.",T(24,104,180,28)));
    array_push(_s,S(C,"editor","Preview toggles","Ninja shows the preview ninja. Depth line shows the selected part's depth. The pulse button flashes the selected part.",T(24,594,454,28)));
    array_push(_s,S(C,"editor","Test Room (T or F5)","Plays the edited room straight away. T or F5 brings you back to the editor afterwards.",T(490,594,175,28)));
    array_push(_s,S(C,"editor","Help and status","Hints for the current mode, and the latest message.",T(24,640,720,140)));
    // Collisions
    C="Collisions";
    array_push(_s,S(C,"collision","Edit collisions","Switches the editor to collision editing and shows the overlay. Cyan lines are solid; amber rules (hazards and special cases) are locked.",T(460,104,180,28)));
    array_push(_s,S(C,"collision","Collision list","Every boundary in the room. Click one to select it; the wheel scrolls.",T(760,140,480,396)));
    array_push(_s,S(C,"collision","Add, Duplicate and Delete","Add a solid line (an area in LN3), copy the selected one, or delete it (Delete key).",T(760,548,456,28)));
    array_push(_s,S(C,"collision","Shaping collisions","In the preview, drag a yellow handle to move an end, or drag the line to move it all. Arrow keys nudge (Shift for 8). Right-drag moves the ninja probe to test.",T(24,140,720,432)));
    // Enemies
    C="Enemies";
    array_push(_s,S(C,"enemies","Enemies","Switches the editor to placing guards. Only one guard engages at a time. Scripted encounters keep their original behaviour.",T(652,104,92,28)));
    array_push(_s,S(C,"enemies","Guard list","Up to eight guards. Click one to select it.",T(760,140,480,250)));
    array_push(_s,S(C,"enemies","Add, Remove and Original","Add or copy a guard, remove the selected one, or go back to the room's original enemies.",T(760,400,484,28)));
    array_push(_s,S(C,"enemies","Guard type","The arrows step through the guard types for this level.",T(760,446,484,28)));
    array_push(_s,S(C,"enemies","Facing, patrol and route","Facing turns the guard. The patrol button cycles Native patrol, Idle and Route. Clear route removes the waypoints.",T(760,486,484,28)));
    array_push(_s,S(C,"enemies","Placing guards","In the preview, drag a guard or a waypoint to move it. Shift-click adds a waypoint. Arrow keys nudge (Shift for 8).",T(24,140,720,432)));
    // Scenery art
    C="Scenery art";
    array_push(_s,S(C,"art","Scenery art editor","A pixel editor for scenery graphics. Edits go straight into the project; editing a shared asset changes every place it is used.",T(24,116,704,552)));
    array_push(_s,S(C,"art","Save project and Back to room","Save project writes all your edits to a file. Back to room (or Esc) returns to the room editor.",T(24,18,352,28)));
    array_push(_s,S(C,"art","New asset and Duplicate","Start a blank asset, or make an independent copy of this one so you can change it in one place only.",T(388,18,272,28)));
    array_push(_s,S(C,"art","Undo and Redo","Undo (Ctrl+Z) and Redo (Ctrl+Y), kept for each asset for the whole session.",T(672,18,272,28)));
    array_push(_s,S(C,"art","Colour rules","C64 Strict, C64 Loose, C64 HiRes, 16bit AMIGA and 32bit AMIGA AGA limit which colours you can use.",T(760,82,490,172)));
    array_push(_s,S(C,"art","Pixel width","Multicolour (2x1) or Hi-res (1x1) pixels, in the C64 modes.",T(760,270,230,28)));
    array_push(_s,S(C,"art","Tools","Pencil, Eraser, Fill and Pick colour. Right-drag always erases; Alt-click picks a colour.",T(760,314,488,28)));
    array_push(_s,S(C,"art","Palette and colour","Click a colour to paint with it. The R, G and B sliders set any colour the rule allows.",T(760,358,472,204)));
    array_push(_s,S(C,"art","Flip and size","Flip horizontal or vertical. New and duplicated assets can also change width and height.",T(760,580,472,72)));
    // Level map
    C="Level map";
    array_push(_s,S(C,"map","Level map","Every room of the level and how the exits connect. The wheel zooms, right-drag pans, and middle-click resets the view. Click a room to select it, double-click to edit it, drag to move it.",T(24,170,1200,300)));
    array_push(_s,S(C,"map","Game, level and project","Choose the game and level, switch Modified on or off, and save or load the project.",T(24,66,1096,28)));
    array_push(_s,S(C,"map","Room editor","Returns to the room editor. Esc does the same.",T(1040,18,210,28)));
    array_push(_s,S(C,"map","Map actions","Edit or test the selected room, insert a blank room on a connection, remove an inserted room, and Undo or Redo.",T(24,490,1058,28)));
    array_push(_s,S(C,"map","Connections","The exits of the selected room. Click one to highlight its lane on the map; the wheel scrolls.",T(24,536,1100,206)));
    // Sprite viewer
    C="Sprite viewer";
    array_push(_s,S(C,"sprites","Sprite viewer","Every character, enemy and object from the three games, played as the original animations.",T(24,160,1226,500)));
    array_push(_s,S(C,"sprites","Game and category","Pick the game, then Ninja, Enemies or Misc.",T(24,76,1146,28)));
    array_push(_s,S(C,"sprites","Character","The arrows step through characters and objects.",T(24,116,1226,28)));
    array_push(_s,S(C,"sprites","Edit sprite (E)","Opens the sprite editor on the frame shown. It has its own section.",T(990,116,200,28)));
    array_push(_s,S(C,"sprites","Animation","The arrows step through this character's animations.",T(24,688,1226,28)));
    array_push(_s,S(C,"sprites","Playback","Pause or play. Cycle animations moves on to the next animation automatically. Mirror shows the other facing.",T(24,744,600,28)));
    array_push(_s,S(C,"sprites","Pixel size","- and + change the zoom, from 1x to 6x.",T(1010,744,240,28)));
    array_push(_s,S(C,"sprites","CRT (F9) and Back (Esc)","CRT effect on the viewer, and back to the game.",T(770,20,480,28)));
    // Sprite editor
    C="Sprite editor";
    array_push(_s,S(C,"spriteart","Sprite editor","Paint over any sprite frame. Edits show in the game once you leave the editor, and are saved with the project.",T(24,116,704,480)));
    array_push(_s,S(C,"spriteart","Save project and Back to viewer","Save project writes all edits to a file. Back to viewer (or Esc) closes the editor.",T(24,18,352,28)));
    array_push(_s,S(C,"spriteart","Undo and Redo","Undo (Ctrl+Z) and Redo (Ctrl+Y), up to 60 steps.",T(388,18,232,28)));
    array_push(_s,S(C,"spriteart","Original pieces","On: edit the original hardware-sprite pieces, so one change carries into every frame and costume that uses the piece. Off: edit whole frames.",T(632,18,220,28)));
    array_push(_s,S(C,"spriteart","Modified ON/OFF","Switches all sprite edits on or off in the game.",T(966,18,170,28)));
    array_push(_s,S(C,"spriteart","Animation and Sprite sheet","Edit the frames of the animation, or browse the whole sprite sheet as a grid; green marks edited frames.",T(760,60,490,28)));
    array_push(_s,S(C,"spriteart","Frames","Click a frame below the canvas to edit it. Left and Right arrows step frames; Space plays the animation.",T(24,606,720,102)));
    array_push(_s,S(C,"spriteart","Colour rules","The same five colour rules as the scenery editor. C64 Strict allows only the sprite's own colours.",T(760,96,490,156)));
    array_push(_s,S(C,"spriteart","Pixels and layers","Multicolour or Hi-res pixels, and the arrows choose which layer (sprite part) to paint.",T(760,260,490,28)));
    array_push(_s,S(C,"spriteart","Tools and palette","Pencil, Eraser, Fill and Pick colour, then the palette and colour sliders. Right-drag erases; Alt-click picks a colour and layer.",T(760,296,488,218)));
    array_push(_s,S(C,"spriteart","Frame tools","Flip, copy and paste frames, revert to the original, dim other layers, onion skin, and crop the canvas to the figure.",T(760,524,472,136)));
    array_push(_s,S(C,"spriteart","Mirrored twins","Mirror to twin copies every edit, flipped, into the other facing. Show twin opens it; Copy to twin now copies this frame across.",T(760,668,472,64)));
    // Track player
    C="Track player";
    array_push(_s,S(C,"tracks","Track player","All 41 tunes from the trilogy. Click a track to play it; the wheel and arrows scroll.",T(24,180,1220,448)));
    array_push(_s,S(C,"tracks","Game and group","Filter by game, then by group: loaders, in-game tunes, intros and outros.",T(24,76,540,68)));
    array_push(_s,S(C,"tracks","Playback mode","ALL plays the group in order and repeats; Single plays one track and stops.",T(850,76,300,28)));
    array_push(_s,S(C,"tracks","Transport","Previous, Play/Pause, Next and Stop. The tune keeps playing if you switch to the sprite viewer.",T(24,706,550,28)));
    array_push(_s,S(C,"tracks","Back (Esc)","Closes the track player and returns to the game.",T(1020,20,220,28)));
    // Finish
    array_push(_s,S("Finish","play","That's everything","Close the guide with Finish or Esc, and you are back in the game where you left it. Open it again any time with the Help guide button."));
    return _s;
}

function ln_guide_active() {return variable_global_exists("ln_guide") && is_struct(global.ln_guide);}
function ln_guide_visible(_host) {return ln_tool_motion_visible(_host) && !ln_guide_active();}

function ln_guide_open(_host) {
    var _e=global.ln_editor,_v=global.ln_sprites;
    global.ln_guide={steps:ln_guide_steps(),index:0,screen:"play",shown_us:0,
        saved:{ui:global.ln_tool.ui,crt:global.ln_crt_enabled,menu:_host.scene_test.menu,part:_e.part,show_collisions:_e.show_collisions,
            sprite_paused:_v.paused,sprite_cycle:_v.cycle}};
    global.ln_tool.ui=true;_host.scene_test.menu=false;
}
function ln_guide_close(_host) {
    if(!ln_guide_active()) return;
    var _g=global.ln_guide,_s=_g.saved;ln_guide_screen(_host,"play");
    global.ln_tool.ui=_s.ui;global.ln_crt_enabled=_s.crt;_host.scene_test.menu=_s.menu;
    global.ln_editor.part=_s.part;global.ln_editor.show_collisions=_s.show_collisions;
    global.ln_sprites.paused=_s.sprite_paused;global.ln_sprites.cycle=_s.sprite_cycle;
    _host.input_state=new LNInput();global.ln_guide=undefined;
}

/// Opens or closes the scene editor the way F6 does, without the autosave (the guide edits nothing).
function ln_guide_editor(_host,_open) {
    var _e=global.ln_editor;if(_e.open==_open) return;
    ln_collision_finish_drag();ln_edit_finish_drag();_e.open=_open;ln_paint_free();_e.depth_edit=false;_e.depth_hold_dir=0;ln_edit_music(_host,_open);
    if(_open) {ln_edit_finish_test(_host.play);ln_edit_follow_game(_host.play);}
    else {ln_edit_restore_game_music(_host.play);_host.input_state=new LNInput();_e.context=false;}
}
function ln_guide_menu_open(_host) {
    var _t=_host.scene_test,_p=_host.play;_t.menu=true;_t.game=_p.game_number;
    for(var _i=0;_i<array_length(_t.levels);_i++) {
        var _level=_t.levels[_i];if(_level.game!=_p.game_number || _level.number!=_p.level) continue;
        _t.level_index=_i;
        for(var _j=0;_j<array_length(_level.scenes);_j++) if(_level.scenes[_j].id==_p.room_id) _t.scene_index=_j;
        break;
    }
}

/// Shows one screen: closes whatever the guide opened before, then opens the target.
function ln_guide_screen(_host,_screen) {
    var _g=global.ln_guide;if(_g.screen==_screen) return;
    var _e=global.ln_editor,_v=global.ln_sprites,_saved=_g.saved;
    if(_v.open && _v.art.open) ln_sprite_art_close();
    if(_v.open) ln_sprite_toggle(_host);
    if(global.ln_tracks.open) ln_track_toggle(_host);
    if(_e.art.open) {var _a=_e.art;_a.stroke=undefined;ln_art_flush();ln_art_keep_history();_a.open=false;if(surface_exists(_a.surface)) surface_free(_a.surface);_a.surface=-1;}
    if(_e.open) {
        _e.map_open=false;_e.enemy_edit=false;_e.collision_edit=false;_e.show_collisions=_saved.show_collisions;_e.part=_saved.part;
        ln_guide_editor(_host,false);
    }
    _host.scene_test.menu=false;global.ln_crt_enabled=_saved.crt;
    _g.screen=_screen;
    switch(_screen) {
        case "crt": global.ln_crt_enabled=true;break;
        case "menu": ln_guide_menu_open(_host);break;
        case "editor": case "collision": case "enemies": case "art": case "map":
            ln_guide_editor(_host,true);
            var _parts=is_struct(_e.scene)?_e.scene.parts:[];
            if(_screen=="editor") _e.part=array_length(_parts)>0?0:-1;
            if(_screen=="collision") {_e.collision_edit=true;_e.show_collisions=true;_e.part=-1;}
            if(_screen=="enemies") {_e.enemy_edit=true;_e.part=-1;_e.enemy_index=0;_e.enemy_waypoint=-1;}
            if(_screen=="map") {_e.map_open=true;_e.map_room=_e.room_id;}
            if(_screen=="art" && array_length(_parts)>0) ln_art_open(_parts[0].asset);
            break;
        case "sprites": case "spriteart":
            ln_sprite_toggle(_host);_v.paused=true;_v.cycle=false;
            if(_screen=="spriteart") ln_sprite_art_open();
            break;
        case "tracks": ln_track_toggle(_host);break;
    }
    ln_guide_keep_music();
}
/// The editor, sprite viewer and track player pause the game music when they open.
/// During the guide it keeps playing like a playlist: resume it and forget the pause,
/// so closing those screens later leaves the music alone too.
function ln_guide_keep_music() {
    var _lists=[global.ln_editor.paused_voices,global.ln_sprites.voices,global.ln_tracks.paused_voices];
    for(var _i=0;_i<3;_i++) for(var _j=0;_j<array_length(_lists[_i]);_j++) {
        var _voice=_lists[_i][_j];if(audio_is_paused(_voice)) audio_resume_sound(_voice);
    }
    global.ln_editor.paused_voices=[];global.ln_sprites.voices=[];global.ln_tracks.paused_voices=[];
}
function ln_guide_music_playing() {
    return variable_global_exists("ln_music_voice") && global.ln_music_voice>=0 && audio_is_playing(global.ln_music_voice) && !audio_is_paused(global.ln_music_voice);
}

function ln_guide_go(_host,_index) {
    var _g=global.ln_guide;_g.index=clamp(_index,0,array_length(_g.steps)-1);_g.shown_us=0;
    ln_guide_screen(_host,_g.steps[_g.index].screen);
}

/// Layout of the info box and the section bar, shared by drawing and clicks.
function ln_guide_layout() {
    var _g=global.ln_guide,_st=_g.steps[_g.index],_w=640,_pad=20;
    draw_set_font(font_jansina);
    var _h=_pad*2+30+string_height_ext(_st.text,-1,_w-_pad*2)+56,_x,_y,_r=_st.rect;
    if(is_undefined(_r)) {_x=(1920-_w)/2;_y=(1020-_h)/2;}
    else {
        var _cx=_r[0]+_r[2]/2;_x=clamp(_cx-_w/2,20,1900-_w);
        if(_r[1]+_r[3]+16+_h<=1020) _y=_r[1]+_r[3]+16;
        else if(_r[1]-16-_h>=20) _y=_r[1]-16-_h;
        else {
            _y=clamp(_r[1]+_r[3]/2-_h/2,20,1020-_h);
            _x=_r[0]+_r[2]+16+_w<=1900?_r[0]+_r[2]+16:max(20,_r[0]-16-_w);
            if(_r[0]+_r[2]+16+_w>1900 && _r[0]-16-_w<20) {_x=(1920-_w)/2;_y=1020-_h;}
        }
    }
    return {x:_x,y:_y,w:_w,h:_h,pad:_pad,buttons_y:_y+_h-_pad-28};
}
function ln_guide_sections() {
    var _g=global.ln_guide,_out=[],_n=array_length(_g.steps);
    for(var _i=0;_i<_n;_i++) {
        var _c=_g.steps[_i].cat;
        if(array_length(_out)==0 || _out[array_length(_out)-1].cat!=_c) array_push(_out,{cat:_c,first:_i,count:0});
        _out[array_length(_out)-1].count++;
    }
    var _x=40,_span=1840;
    for(var _k=0;_k<array_length(_out);_k++) {_out[_k].x=_x;_out[_k].w=_span*_out[_k].count/_n;_x+=_out[_k].w;}
    return _out;
}

/// Returns true while the guide is open; the rest of the frame (game, editors) is skipped.
function ln_guide_step(_host) {
    if(!ln_guide_active()) return false;
    var _g=global.ln_guide,_n=array_length(_g.steps);_g.shown_us+=delta_time;
    if(keyboard_check_pressed(vk_escape)) {ln_guide_close(_host);return true;}
    if(keyboard_check_pressed(vk_f10)) ln_fullscreen_toggle(_host);
    if(keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        if(_g.index>=_n-1) {ln_guide_close(_host);return true;}
        ln_guide_go(_host,_g.index+1);
    }
    if(keyboard_check_pressed(vk_left) || keyboard_check_pressed(vk_backspace)) ln_guide_go(_host,_g.index-1);
    if(keyboard_check_pressed(vk_home)) ln_guide_go(_host,0);
    if(keyboard_check_pressed(vk_end)) ln_guide_go(_host,_n-1);
    if(mouse_check_button_pressed(mb_left)) {
        var _l=ln_guide_layout(),_mx=mouse_x,_my=mouse_y,_by=_l.buttons_y;
        if(_my>=_by && _my<_by+28) {
            if(_mx>=_l.x+_l.pad && _mx<_l.x+_l.pad+120 && _g.index>0) ln_guide_go(_host,_g.index-1);
            else if(_mx>=_l.x+_l.pad+130 && _mx<_l.x+_l.pad+250) {
                if(_g.index>=_n-1) {ln_guide_close(_host);return true;}
                ln_guide_go(_host,_g.index+1);
            }
            else if(_mx>=_l.x+_l.w-_l.pad-150 && _mx<_l.x+_l.w-_l.pad) {ln_guide_close(_host);return true;}
        }
        if(_my>=1036 && _my<1068 && _mx>=40 && _mx<1880) {
            var _sec=ln_guide_sections();
            for(var _k=0;_k<array_length(_sec);_k++) {
                var _s=_sec[_k];
                if(_mx>=_s.x && _mx<_s.x+_s.w) {ln_guide_go(_host,_s.first+min(_s.count-1,floor((_mx-_s.x)/_s.w*_s.count)));break;}
            }
        }
    }
    return true;
}

function ln_guide_draw(_host) {
    if(!ln_guide_active()) return;
    var _g=global.ln_guide,_st=_g.steps[_g.index],_r=_st.rect,_n=array_length(_g.steps);
    draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);
    // Dim everything except the highlighted rectangle.
    draw_set_colour(c_black);draw_set_alpha(0.62);
    if(is_undefined(_r)) draw_rectangle(0,0,1920,1080,false);
    else {
        var _x0=_r[0]-6,_y0=_r[1]-6,_x1=_r[0]+_r[2]+6,_y1=_r[1]+_r[3]+6;
        draw_rectangle(0,0,1920,_y0,false);draw_rectangle(0,_y1,1920,1080,false);
        draw_rectangle(0,_y0,_x0,_y1,false);draw_rectangle(_x1,_y0,1920,_y1,false);
        // Thick yellow frame with a black edge, gently pulsing.
        var _pulse=0.75+0.25*sin(_g.shown_us/1000000*pi*2);
        draw_set_alpha(1);draw_set_colour(c_black);
        for(var _k=0;_k<2;_k++) draw_rectangle(_x0-5-_k,_y0-5-_k,_x1+5+_k,_y1+5+_k,true);
        draw_set_alpha(_pulse);draw_set_colour(make_colour_rgb(255,220,40));
        for(var _k=0;_k<4;_k++) draw_rectangle(_x0-1-_k,_y0-1-_k,_x1+1+_k,_y1+1+_k,true);
    }
    draw_set_alpha(1);
    // Info box.
    var _l=ln_guide_layout();
    draw_set_colour(make_colour_rgb(16,18,26));draw_rectangle(_l.x,_l.y,_l.x+_l.w,_l.y+_l.h,false);
    draw_set_colour(make_colour_rgb(255,220,40));draw_rectangle(_l.x,_l.y,_l.x+_l.w,_l.y+_l.h,true);draw_rectangle(_l.x+1,_l.y+1,_l.x+_l.w-1,_l.y+_l.h-1,true);
    draw_set_colour(make_colour_rgb(150,210,220));
    draw_text(_l.x+_l.pad,_l.y+_l.pad-4,string_upper(_st.cat)+"   "+string(_g.index+1)+" / "+string(_n));
    draw_set_colour(make_colour_rgb(255,220,40));draw_text(_l.x+_l.pad,_l.y+_l.pad+18,_st.title);
    draw_set_colour(c_white);draw_text_ext(_l.x+_l.pad,_l.y+_l.pad+44,_st.text,-1,_l.w-_l.pad*2);
    ln_edit_button(_l.x+_l.pad,_l.buttons_y,120,"< Back",_g.index>0);
    ln_edit_button(_l.x+_l.pad+130,_l.buttons_y,120,_g.index>=_n-1?"Finish":"Next >");
    ln_edit_button(_l.x+_l.w-_l.pad-150,_l.buttons_y,150,"Close (Esc)");
    // Section bar along the bottom: one block per section, click to jump.
    var _sec=ln_guide_sections();
    draw_set_colour(c_black);draw_set_alpha(0.85);draw_rectangle(30,1028,1890,1076,false);draw_set_alpha(1);
    for(var _k=0;_k<array_length(_sec);_k++) {
        var _s=_sec[_k],_here=_g.index>=_s.first && _g.index<_s.first+_s.count,_done=_g.index>=_s.first+_s.count;
        var _hover=mouse_y>=1036 && mouse_y<1068 && mouse_x>=_s.x && mouse_x<_s.x+_s.w;
        draw_set_colour(_here?make_colour_rgb(255,220,40):(_done?make_colour_rgb(70,120,90):make_colour_rgb(55,60,72)));
        if(_hover && !_here) draw_set_colour(make_colour_rgb(110,120,140));
        draw_rectangle(_s.x+1,1036,_s.x+_s.w-2,1067,false);
        draw_set_colour(_here?c_black:c_white);
        var _label=_s.cat;
        if(string_width(_label)>_s.w-8) _label=string_copy(_label,1,max(1,floor((_s.w-8)/9)));
        if(_s.w>18) draw_text(_s.x+5,1042,_label);
        if(_here) {
            var _mx=_s.x+(_g.index-_s.first+0.5)/_s.count*_s.w;
            draw_set_colour(c_black);draw_rectangle(_mx-2,1062,_mx+2,1067,false);
        }
        if(_hover) {
            draw_set_colour(c_white);var _tip=_s.cat+" ("+string(_s.count)+")";
            var _tx=clamp(_s.x,34,1886-string_width(_tip)-12);
            draw_set_colour(c_black);draw_rectangle(_tx,1000,_tx+string_width(_tip)+12,1026,false);
            draw_set_colour(c_white);draw_text(_tx+6,1004,_tip);
        }
    }
    draw_set_colour(c_white);draw_flush();
}

/// --guide-test: walks every step on real frames, saving guide-NNN.png for each,
/// then checks that closing restores every screen and setting.
function ln_guide_test_step(_host) {
    _host.guide_frame++;
    try {
        if(_host.guide_frame==2) {
            global.ln_crt_enabled=false;_host.guide_music=ln_guide_music_playing();_host.guide_music_ok=true;ln_guide_open(_host);
            ln_check(!global.ln_editor.open && !global.ln_sprites.open && !global.ln_tracks.open,"guide starts from the game");
            return;
        }
        if(!ln_guide_active() || _host.guide_frame mod 3!=2) return;
        var _g=global.ln_guide;
        if(_g.index<array_length(_g.steps)-1) {
            ln_guide_go(_host,_g.index+1);
            if(_host.guide_music && !ln_guide_music_playing()) _host.guide_music_ok=false;
            return;
        }
        var _count=array_length(_g.steps);ln_guide_go(_host,10);ln_guide_go(_host,_count-1);ln_guide_close(_host);
        ln_check(!ln_guide_active(),"guide closes");
        ln_check(_host.guide_music_ok && (!_host.guide_music || ln_guide_music_playing()),"guide keeps the music playing on every screen and after closing");
        ln_check(!global.ln_editor.open && !global.ln_editor.art.open && !global.ln_editor.map_open && !global.ln_editor.enemy_edit && !global.ln_editor.collision_edit,"guide leaves the editor closed");
        ln_check(!global.ln_sprites.open && !global.ln_sprites.art.open && !global.ln_tracks.open,"guide leaves the viewer and track player closed");
        ln_check(!_host.scene_test.menu && !global.ln_crt_enabled && global.ln_tool.ui,"guide restores the menu, CRT and UI settings");
        show_debug_message("LN_GUIDE_PASS: "+string(_count)+" steps shown and restored"+(_host.guide_music?", music kept playing":", no music playing to check")+"; captures in "+game_save_id);
        game_end();
    } catch(_failure) {show_debug_message("LN_GUIDE_FAILURE: "+string(_failure));game_end();}
}
