/// Level maps are editor-file extensions. Native exits remain authoritative.
function ln_map_key(_game,_level) {return string(_game)+":"+string(_level);}
function ln_map_data(_game,_level) {
    var _e=global.ln_editor,_key=ln_map_key(_game,_level);
    if(!variable_struct_exists(_e.maps,_key)) variable_struct_set(_e.maps,_key,{game:_game,level:_level,rooms:[],routes:[],next_room:1000});
    return variable_struct_get(_e.maps,_key);
}
function ln_map_graph(_game,_level) {
    var _e=global.ln_editor,_key="map-world:"+ln_map_key(_game,_level);
    if(variable_struct_exists(_e.datasets,_key)) return variable_struct_get(_e.datasets,_key);
    var _path="play/ln"+string(_game)+"/"+((_game==1 && _level==1)?"":"level"+string(_level)+"/");
    var _w=ln3_data_read(_path+"world.json"),_nodes=[],_edges=[];
    for(var _i=0;_i<array_length(_w.rooms);_i++) {
        var _r=_w.rooms[_i];array_push(_nodes,{id:_r.id,sprite:asset_get_index(_r.sprite)});
        var _list=_game==2?_r.entries:_r.exits;
        for(var _j=0;_j<array_length(_list);_j++) {
            if(_game==1 && _j>0 && _r.exit_thresholds[_j-1]>=255) break;
            var _token=_list[_j],_dest=_game==1?(_token>>2):(_game==2?_w.tables.exit_destinations[_token]:_token.destination);
            if(_game==1 && _dest==0) _dest=-1;
            if(_game==2 && _dest==255) _dest=-1;
            var _x=120,_y=72;
            if(_game==1) {var _spawn=_w.entry_index[_token];if(_spawn>=0 && _spawn<array_length(_w.entry_x)) {_x=_w.entry_x[_spawn];_y=_w.entry_y[_spawn]-29;}}
            else if(_game==2) {_x=_w.tables.entry_x[_token];_y=_w.tables.entry_y[_token]-29;}
            else {_x=_token.spawn_x-24;_y=_token.spawn_y-29;}
            // The destination lies opposite its entrance in screen/isometric space.
            array_push(_edges,{key:string(_r.id)+":"+string(_j),source:_r.id,destination:_dest,token:_token,dx:_x<120?1:-1,dy:_y<72?1:-1});
        }
    }
    var _graph={nodes:_nodes,edges:_edges};variable_struct_set(_e.datasets,_key,_graph);return _graph;
}
function ln_map_edge(_graph,_key) {
    for(var _i=0;_i<array_length(_graph.edges);_i++) if(_graph.edges[_i].key==_key) return _graph.edges[_i];
    return undefined;
}
function ln_map_route(_map,_key) {
    for(var _i=0;_i<array_length(_map.routes);_i++) if(_map.routes[_i].edge==_key || _map.routes[_i].reverse==_key) return _map.routes[_i];
    return undefined;
}
function ln_map_room(_map,_id) {
    for(var _i=0;_i<array_length(_map.rooms);_i++) if(_map.rooms[_i].id==_id) return _map.rooms[_i];
    return undefined;
}
function ln_map_letter(_n) {
    return (_n>=26?chr(65+(_n div 26)-1):"")+chr(65+(_n mod 26));
}
function ln_map_insert(_game,_level,_edge_index) {
    var _graph=ln_map_graph(_game,_level),_map=ln_map_data(_game,_level);
    if(_edge_index<0 || _edge_index>=array_length(_graph.edges) || array_length(_map.rooms)>=64) return false;
    var _edge=_graph.edges[_edge_index],_target=false;
    for(var _i=0;_i<array_length(_graph.nodes);_i++) if(_graph.nodes[_i].id==_edge.destination) _target=true;
    if(!_target || _edge.destination==_edge.source) {global.ln_editor.message="Choose a connection between two rooms";return false;}
    ln_map_checkpoint();
    var _route=ln_map_route(_map,_edge.key);
    if(!is_struct(_route)) {
        var _reverse="";
        for(var _i=0;_i<array_length(_graph.edges);_i++) {
            var _back=_graph.edges[_i];
            if(_back.source==_edge.destination && _back.destination==_edge.source && !is_struct(ln_map_route(_map,_back.key))) {_reverse=_back.key;break;}
        }
        _route={edge:_edge.key,reverse:_reverse,rooms:[]};array_push(_map.routes,_route);
    }
    var _id=_map.next_room++,_source=ln_edit_source(_game,_level,_edge.source);
    array_push(_map.rooms,{id:_id,name:"New room "+string(_id-999),background:is_struct(_source)?_source.background:0});
    if(_edge.key==_route.edge) array_push(_route.rooms,_id);else array_insert(_route.rooms,0,_id);
    var _e=global.ln_editor;_e.map_room=_id;_e.enabled=true;_e.dirty=true;_e.revision++;_e.autosave_us=1000000;
    _e.message="Blank room inserted before destination. Modified ON.";return true;
}
function ln_map_remove(_game,_level,_id) {
    var _map=ln_map_data(_game,_level);
    if(!is_struct(ln_map_room(_map,_id))) return;
    ln_map_checkpoint();
    for(var _i=array_length(_map.routes)-1;_i>=0;_i--) {
        var _route=_map.routes[_i];
        for(var _j=array_length(_route.rooms)-1;_j>=0;_j--) if(_route.rooms[_j]==_id) array_delete(_route.rooms,_j,1);
        if(array_length(_route.rooms)==0) array_delete(_map.routes,_i,1);
    }
    for(var _i=array_length(_map.rooms)-1;_i>=0;_i--) if(_map.rooms[_i].id==_id) array_delete(_map.rooms,_i,1);
    var _e=global.ln_editor;_e.map_room=-1;_e.enabled=true;_e.dirty=true;_e.autosave_us=1000000;_e.revision++;
    _e.message="Inserted room removed; its neighbours are reconnected.";
}
function ln_map_validate(_maps) {
    if(!is_struct(_maps)) return false;
    var _keys=variable_struct_get_names(_maps);if(array_length(_keys)>18) return false;
    for(var _k=0;_k<array_length(_keys);_k++) {
        var _m=variable_struct_get(_maps,_keys[_k]);
        if(!is_struct(_m)) return false;
        var _fields=["game","level","rooms","routes","next_room"];
        for(var _i=0;_i<array_length(_fields);_i++) if(!variable_struct_exists(_m,_fields[_i])) return false;
        if(!array_contains([1,2,3],_m.game) || !is_real(_m.level) || _m.level!=floor(_m.level) || _m.level<1 || _m.level>(_m.game==1?6:(_m.game==2?7:5)) || _keys[_k]!=ln_map_key(_m.game,_m.level)) return false;
        if(!is_array(_m.rooms) || !is_array(_m.routes) || array_length(_m.rooms)>64 || array_length(_m.routes)>256 || !is_real(_m.next_room) || _m.next_room!=floor(_m.next_room) || _m.next_room<1000 || _m.next_room>1000000) return false;
        var _ids=[],_used=[],_edges=[],_graph=ln_map_graph(_m.game,_m.level);
        for(var _i=0;_i<array_length(_m.rooms);_i++) {
            var _r=_m.rooms[_i];
            if(!is_struct(_r) || !variable_struct_exists(_r,"id") || !variable_struct_exists(_r,"name") || !variable_struct_exists(_r,"background")) return false;
            if(!is_real(_r.id) || _r.id!=floor(_r.id) || _r.id<1000 || _r.id>=_m.next_room || array_contains(_ids,_r.id) || !is_string(_r.name) || string_length(_r.name)>64 || !is_real(_r.background) || _r.background!=floor(_r.background) || _r.background<0 || _r.background>15) return false;
            array_push(_ids,_r.id);
        }
        for(var _i=0;_i<array_length(_m.routes);_i++) {
            var _r=_m.routes[_i];
            if(!is_struct(_r) || !variable_struct_exists(_r,"edge") || !variable_struct_exists(_r,"reverse") || !variable_struct_exists(_r,"rooms") || !is_string(_r.edge) || !is_string(_r.reverse) || !is_array(_r.rooms) || array_length(_r.rooms)==0 || array_length(_r.rooms)>64) return false;
            var _f=ln_map_edge(_graph,_r.edge),_b=ln_map_edge(_graph,_r.reverse);
            if(!is_struct(_f) || _f.destination<0 || _f.destination==_f.source || array_contains(_edges,_r.edge)) return false;
            if(ln_map_node_index(_graph.nodes,_f.destination)<0) return false;
            array_push(_edges,_r.edge);
            if(_r.reverse!="") {
                if(!is_struct(_b) || _b.source!=_f.destination || _b.destination!=_f.source || array_contains(_edges,_r.reverse)) return false;
                array_push(_edges,_r.reverse);
            }
            for(var _j=0;_j<array_length(_r.rooms);_j++) {var _id=_r.rooms[_j];if(!array_contains(_ids,_id) || array_contains(_used,_id)) return false;array_push(_used,_id);}
        }
        if(array_length(_used)!=array_length(_ids)) return false;
    }
    return true;
}
function ln_map_nodes(_graph,_map) {
    var _nodes=array_create(array_length(_graph.nodes));array_copy(_nodes,0,_graph.nodes,0,array_length(_nodes));
    for(var _i=0;_i<array_length(_map.rooms);_i++) array_push(_nodes,{id:_map.rooms[_i].id,sprite:-1});
    var _revision=global.ln_editor.revision;
    if(!variable_struct_exists(_graph,"layout_revision") || _graph.layout_revision!=_revision || array_length(_graph.layout_rects)!=array_length(_nodes)) {
        _graph.layout_rects=ln_map_flow_layout(_graph,_map,_nodes);_graph.layout_revision=_revision;
    }
    global.ln_editor.map_rects=_graph.layout_rects;
    return _nodes;
}
function ln_map_flow_layout(_graph,_map,_nodes) {
    var _count=array_length(_nodes),_links=[],_positions=array_create(_count),_placed=array_create(_count,false);
    for(var _i=0;_i<_count;_i++) _positions[_i]=[0,0];
    for(var _i=0;_i<array_length(_graph.edges);_i++) {
        var _edge=_graph.edges[_i],_route=ln_map_route(_map,_edge.key),_chain=[_edge.source],_weight=.15;
        for(var _j=0;_j<array_length(_graph.edges);_j++) {
            var _back=_graph.edges[_j];
            if(_back.source==_edge.destination && _back.destination==_edge.source) {_weight=1;break;}
        }
        if(is_struct(_route)) for(var _j=0;_j<array_length(_route.rooms);_j++) array_push(_chain,_route.rooms[_edge.key==_route.edge?_j:array_length(_route.rooms)-1-_j]);
        array_push(_chain,_edge.destination);
        for(var _j=1;_j<array_length(_chain);_j++) {
            var _a=ln_map_node_index(_nodes,_chain[_j-1]),_b=ln_map_node_index(_nodes,_chain[_j]);
            if(_a<0 || _b<0 || _a==_b) continue;
            array_push(_links,{a:_a,b:_b,dx:_edge.dx,dy:_edge.dy,weight:_weight});
        }
    }
    // Seed each component from actual entrance directions, not traversal depth.
    for(var _root=0;_root<_count;_root++) {
        if(_placed[_root]) continue;
        _positions[_root]=[_root*2,0];_placed[_root]=true;
        repeat(_count) for(var _i=0;_i<array_length(_links);_i++) {
            var _l=_links[_i];if(_l.weight<1) continue;
            if(_placed[_l.a] && !_placed[_l.b]) {_positions[_l.b]=[_positions[_l.a][0]+_l.dx,_positions[_l.a][1]+_l.dy];_placed[_l.b]=true;}
            else if(_placed[_l.b] && !_placed[_l.a]) {_positions[_l.a]=[_positions[_l.b][0]-_l.dx,_positions[_l.b][1]-_l.dy];_placed[_l.a]=true;}
        }
    }
    // Reconcile loops. One-way/fallback records exert much less influence
    // than reciprocal connections; they remain visible as connection lines.
    repeat(100) {
        var _sumx=array_create(_count,0),_sumy=array_create(_count,0),_weight=array_create(_count,0);
        for(var _i=0;_i<array_length(_links);_i++) {
            var _l=_links[_i],_w=_l.weight;
            _sumx[_l.a]+=(_positions[_l.b][0]-_l.dx)*_w;_sumy[_l.a]+=(_positions[_l.b][1]-_l.dy)*_w;_weight[_l.a]+=_w;
            _sumx[_l.b]+=(_positions[_l.a][0]+_l.dx)*_w;_sumy[_l.b]+=(_positions[_l.a][1]+_l.dy)*_w;_weight[_l.b]+=_w;
        }
        for(var _i=1;_i<_count;_i++) if(_weight[_i]>0) _positions[_i]=[lerp(_positions[_i][0],_sumx[_i]/_weight[_i],.6),lerp(_positions[_i][1],_sumy[_i]/_weight[_i],.6)];
    }
    // Preserve sides where both ends agree; loop relaxation must not reverse
    // a verified pair such as Wastelands 10 -> 11 -> 12.
    repeat(100) for(var _i=0;_i<array_length(_links);_i++) {
        var _l=_links[_i],_confirmed=false;
        for(var _j=0;_j<array_length(_links);_j++) {
            var _back=_links[_j];
            if(_back.a==_l.b && _back.b==_l.a && _back.dx==-_l.dx && _back.dy==-_l.dy) {_confirmed=true;break;}
        }
        if(!_confirmed) continue;
        var _gapx=(_positions[_l.b][0]-_positions[_l.a][0])*_l.dx,_gapy=(_positions[_l.b][1]-_positions[_l.a][1])*_l.dy;
        if(_gapx<1.5) {var _fix=(1.5-_gapx)*.5*_l.dx;_positions[_l.a][0]-=_fix;_positions[_l.b][0]+=_fix;}
        // Vertical placement remains relaxed where original room loops fold.
    }
    // Snap onto a staggered diamond lattice, reserving a distinct cell per room.
    var _cells=[],_minx=infinity,_maxx=-infinity,_miny=infinity,_maxy=-infinity;
    for(var _i=0;_i<_count;_i++) {
        var _px=_positions[_i][0]*2,_py=_positions[_i][1]*2,_best=infinity,_cell=[0,0];
        for(var _x=floor(_px)-_count;_x<=ceil(_px)+_count;_x++) for(var _y=floor(_py)-_count;_y<=ceil(_py)+_count;_y++) {
            if(abs(_x+_y) mod 2!=0) continue;
            var _score=sqr(_x-_px)+sqr(_y-_py);if(_score>=_best) continue;
            var _used=false;for(var _j=0;_j<array_length(_cells);_j++) if(_cells[_j][0]==_x && _cells[_j][1]==_y) {_used=true;break;}
            if(!_used) {_best=_score;_cell=[_x,_y];}
        }
        array_push(_cells,_cell);_minx=min(_minx,_cell[0]);_maxx=max(_maxx,_cell[0]);_miny=min(_miny,_cell[1]);_maxy=max(_maxy,_cell[1]);
    }
    var _sx=1200/(_maxx-_minx+1),_sy=300/(_maxy-_miny+2),_h=max(6,min(_sx*.54,2*_sy-16)),_w=_h/.6,_rects=[];
    for(var _i=0;_i<_count;_i++) array_push(_rects,[24+(_cells[_i][0]-_minx+.5)*_sx-_w*.5,170+(_cells[_i][1]-_miny+1)*_sy-(_h+14)*.5,_w,_h]);
    return _rects;
}
function ln_map_rect(_n,_count) {return global.ln_editor.map_rects[_n];}
function ln_map_node_index(_nodes,_id) {for(var _i=0;_i<array_length(_nodes);_i++) if(_nodes[_i].id==_id) return _i;return -1;}
// Visible lanes and their hit targets use the same clipped endpoints.
function ln_map_lanes(_graph,_map,_nodes) {
    var _lanes=[];
    for(var _j=0;_j<array_length(_graph.edges);_j++) {
        var _edge=_graph.edges[_j],_route=ln_map_route(_map,_edge.key),_chain=[_edge.source];
        if(is_struct(_route)) for(var _k=0;_k<array_length(_route.rooms);_k++) array_push(_chain,_route.rooms[_edge.key==_route.edge?_k:array_length(_route.rooms)-1-_k]);
        array_push(_chain,_edge.destination);
        for(var _k=1;_k<array_length(_chain);_k++) {
            var _a=ln_map_node_index(_nodes,_chain[_k-1]),_b=ln_map_node_index(_nodes,_chain[_k]);
            if(_a<0 || _b<0 || _a==_b) continue;
            var _ra=ln_map_rect(_a,array_length(_nodes)),_rb=ln_map_rect(_b,array_length(_nodes));
            var _ax=_ra[0]+_ra[2]*.5,_ay=_ra[1]+_ra[3]*.5,_bx=_rb[0]+_rb[2]*.5,_by=_rb[1]+_rb[3]*.5;
            var _dx=_bx-_ax,_dy=_by-_ay;
            var _ta=min((_ra[2]*.5+3)/max(.001,abs(_dx)),(_ra[3]*.5+15)/max(.001,abs(_dy)));
            var _tb=min((_rb[2]*.5+3)/max(.001,abs(_dx)),(_rb[3]*.5+15)/max(.001,abs(_dy)));
            if(_ta+_tb>=1) continue;
            array_push(_lanes,{edge:_j,source:_chain[_k-1],destination:_chain[_k],x1:_ax+_dx*_ta,y1:_ay+_dy*_ta,x2:_bx-_dx*_tb,y2:_by-_dy*_tb});
        }
    }
    return _lanes;
}
function ln_map_remove_lane(_game,_level,_lane,_near_destination=true) {
    // A lane belongs to an inserted chain, never remove an original exit.
    var _map=ln_map_data(_game,_level),_graph=ln_map_graph(_game,_level);
    var _edge=_graph.edges[_lane.edge],_route=ln_map_route(_map,_edge.key);
    if(!is_struct(_route)) {global.ln_editor.message="Original connections are protected.";return false;}
    var _id=_near_destination?_lane.destination:_lane.source;
    if(_id<1000) _id=_near_destination?_lane.source:_lane.destination;
    if(_id<1000 || !array_contains(_route.rooms,_id)) return false;
    ln_map_remove(_game,_level,_id);return true;
}
function ln_map_neighbours(_graph,_map,_room) {
    var _result=[];
    for(var _i=0;_i<array_length(_graph.edges);_i++) {
        var _edge=_graph.edges[_i],_route=ln_map_route(_map,_edge.key),_chain=[_edge.source];
        if(is_struct(_route)) for(var _j=0;_j<array_length(_route.rooms);_j++) array_push(_chain,_route.rooms[_edge.key==_route.edge?_j:array_length(_route.rooms)-1-_j]);
        array_push(_chain,_edge.destination);
        for(var _j=1;_j<array_length(_chain);_j++) {
            // Highlight only destinations reachable from this room. Incoming exits
            // can be one-way or fallback records, not a way out of the selection.
            var _other=_chain[_j-1]==_room?_chain[_j]:-1;
            if(_other>=0 && _other!=_room && !array_contains(_result,_other)) array_push(_result,_other);
        }
    }
    return _result;
}
function ln_map_draw() {
    var _e=global.ln_editor,_graph=ln_map_graph(_e.game,_e.level),_map=ln_map_data(_e.game,_e.level),_nodes=ln_map_nodes(_graph,_map);
    ln_tool_clear(false);draw_set_font(font_jansina);draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_colour(c_white);
    draw_text(24,24,"LEVEL MAP / LAST NINJA "+string(_e.game)+" / LEVEL "+string(_e.level));
    ln_edit_button(1040,18,210,"Room editor");
    for(var _i=0;_i<3;_i++) ln_edit_button(24+_i*120,66,110,"Ninja "+string(_i+1),_e.game==_i+1);
    ln_edit_button(410,66,35,"<");draw_text(462,72,"Level "+string(_e.level));ln_edit_button(585,66,35,">");
    ln_edit_button(665,66,170,"Modified "+(_e.enabled?"ON":"OFF"),_e.enabled);
    ln_edit_button(850,66,130,"Save file");ln_edit_button(990,66,130,"Load file");
    draw_text(24,120,"4:1 room flow | Click lane: select | Right-click lane: remove insertion | Double click room: edit");
    var _room_focus=variable_struct_exists(_e,"map_room_focus") && _e.map_room_focus;
    var _neighbours=_room_focus?ln_map_neighbours(_graph,_map,_e.map_room):[];
    var _lanes=ln_map_lanes(_graph,_map,_nodes);
    for(var _pass=0;_pass<2;_pass++) for(var _j=0;_j<array_length(_lanes);_j++) {
        var _lane=_lanes[_j],_selected=_lane.edge==_e.map_edge;
        if(_selected!=(_pass==1)) continue;
        draw_set_colour(_selected?c_yellow:c_aqua);draw_set_alpha(_selected?1:.28);
        draw_line_width(_lane.x1,_lane.y1,_lane.x2,_lane.y2,_selected?2:1);
        draw_arrow(_lane.x1,_lane.y1,_lane.x2,_lane.y2,3);
    }
    draw_set_alpha(1);
    for(var _i=0;_i<array_length(_nodes);_i++) {
        var _n=_nodes[_i],_r=ln_map_rect(_i,array_length(_nodes));
        draw_set_colour(c_white);
        if(_n.sprite>=0) draw_sprite_stretched(_n.sprite,0,_r[0],_r[1],_r[2],_r[3]);
        else {var _room=ln_map_room(_map,_n.id);draw_set_colour(global.ln_paint_palette[_room.background]);draw_rectangle(_r[0],_r[1],_r[0]+_r[2],_r[1]+_r[3],false);}
        if(array_contains(_neighbours,_n.id)) {
            draw_set_colour(make_colour_rgb(50,140,255));draw_set_alpha(.22);
            draw_rectangle(_r[0],_r[1],_r[0]+_r[2],_r[1]+_r[3],false);draw_set_alpha(1);
            for(var _border=1;_border<=3;_border++) draw_rectangle(_r[0]-_border,_r[1]-_border,_r[0]+_r[2]+_border,_r[1]+_r[3]+_border,true);
        }
        draw_set_colour(_e.map_room==_n.id?c_yellow:(array_contains(_neighbours,_n.id)?make_colour_rgb(50,140,255):c_white));draw_rectangle(_r[0]-1,_r[1]-1,_r[0]+_r[2]+1,_r[1]+_r[3]+1,true);
        draw_text_transformed(_r[0],_r[1]+_r[3]+2,_n.id>=1000?"New "+string(_n.id-999):"Room "+string(_n.id),.6,.6,0);
    }
    // Only the two endpoints of the selected segment pulse, without artwork labels.
    var _chosen=undefined;
    for(var _j=0;_j<array_length(_lanes);_j++) if(_lanes[_j].edge==_e.map_edge) {
        if(!is_struct(_chosen)) _chosen=_lanes[_j];
        if(variable_struct_exists(_e,"map_lane_source") && _lanes[_j].source==_e.map_lane_source && _lanes[_j].destination==_e.map_lane_destination) {_chosen=_lanes[_j];break;}
    }
    if(is_struct(_chosen) && !_room_focus) {
        var _ends=[_chosen.source,_chosen.destination],_pulse=.5+.5*sin(current_time*2*pi/1600);
        for(var _i=0;_i<2;_i++) {
            var _n=ln_map_node_index(_nodes,_ends[_i]);if(_n<0) continue;
            var _r=ln_map_rect(_n,array_length(_nodes));
            draw_set_colour(c_white);draw_set_alpha(_pulse*.25);
            draw_rectangle(_r[0],_r[1],_r[0]+_r[2],_r[1]+_r[3],false);
            draw_set_colour(c_yellow);draw_set_alpha(.25+_pulse*.75);
            draw_rectangle(_r[0]-3,_r[1]-3,_r[0]+_r[2]+3,_r[1]+_r[3]+3,true);
        }
        draw_set_alpha(1);
    }
    ln_edit_button(24,490,165,"Edit selected room");ln_edit_button(201,490,165,"Test Room (T/F5)");
    ln_edit_button(380,490,230,"Insert blank on connection");ln_edit_button(624,490,200,"Remove selected blank");
    ln_edit_button(850,490,110,"Undo (^Z)");ln_edit_button(972,490,110,"Redo (^Y)");
    draw_set_colour(c_white);draw_text(24,536,"CONNECTIONS (arrows preserve one-way routes) | Scroll here for more");
    for(var _i=0;_i<6;_i++) {
        var _at=_e.map_scroll+_i;if(_at>=array_length(_graph.edges)) break;
        var _edge=_graph.edges[_at],_route=ln_map_route(_map,_edge.key);
        var _label=ln_map_letter(_at)+"   Room "+string(_edge.source)+"  ->  "+(_edge.destination<0?"Next level":"Room "+string(_edge.destination));
        if(is_struct(_route)) _label+="  via "+string(array_length(_route.rooms))+" inserted room(s)";
        ln_edit_button(24,564+_i*30,1100,_label,_at==_e.map_edge);
    }
    draw_set_colour(c_white);draw_text(24,758,_e.message);
}
function ln_map_step(_host) {
    var _e=global.ln_editor;
    if(!_e.map_open) return false;
    if(ln_edit_hit(1040,18,210,28) || keyboard_check_pressed(vk_escape)) {_e.map_open=false;return true;}
    for(var _i=0;_i<3;_i++) if(ln_edit_hit(24+_i*120,66,110,28)) {ln_edit_select(_i+1,1,ln_edit_rooms(_i+1,1)[0]);_e.map_edge=0;_e.map_scroll=0;_e.map_room=_e.room_id;}
    var _direction=ln_edit_hit(410,66,35,28)?-1:(ln_edit_hit(585,66,35,28)?1:0);
    if(_direction) {var _level=clamp(_e.level+_direction,1,_e.game==1?6:(_e.game==2?7:5));ln_edit_select(_e.game,_level,ln_edit_rooms(_e.game,_level)[0]);_e.map_edge=0;_e.map_scroll=0;_e.map_room=_e.room_id;}
    if(ln_edit_hit(665,66,170,28)) _e.enabled=!_e.enabled;
    if(ln_edit_hit(850,66,130,28)) {if(ln_edit_save(get_save_filename("JSON files|*.json","modified-scenes.json"))) _e.dirty=false;}
    if(ln_edit_hit(990,66,130,28)) ln_edit_load(get_open_filename("JSON files|*.json",""));
    var _graph=ln_map_graph(_e.game,_e.level),_map=ln_map_data(_e.game,_e.level),_nodes=ln_map_nodes(_graph,_map);
    if(mouse_wheel_down()) _e.map_scroll=min(max(0,array_length(_graph.edges)-6),_e.map_scroll+3);
    if(mouse_wheel_up()) _e.map_scroll=max(0,_e.map_scroll-3);
    for(var _i=0;_i<6;_i++) if(ln_edit_hit(24,564+_i*30,1100,28) && _e.map_scroll+_i<array_length(_graph.edges)) {_e.map_room_focus=false;_e.map_edge=_e.map_scroll+_i;_e.map_lane_source=-1;_e.map_lane_destination=-1;_e.map_room=_graph.edges[_e.map_edge].source;}
    var _over_room=false;
    for(var _i=0;_i<array_length(_nodes);_i++) {
        var _r=ln_map_rect(_i,array_length(_nodes));
        if(ln_edit_hit(_r[0],_r[1],_r[2],_r[3]+14)) {
            _e.map_room=_nodes[_i].id;_e.map_room_focus=true;_over_room=true;
            var _click_key=ln_map_key(_e.game,_e.level)+":"+string(_e.map_room);
            if(variable_struct_exists(_e,"map_left_room") && _e.map_left_room==_click_key && current_time-_e.map_left_time<=400) {
                _e.map_left_room="";
                if(_e.map_room>=1000) _e.message="Inserted rooms are blank traversal spaces; room contents come next.";
                else {_e.map_open=false;ln_edit_select(_e.game,_e.level,_e.map_room);}
                return true;
            }
            _e.map_left_room=_click_key;_e.map_left_time=current_time;
        }
        if(mouse_check_button_pressed(mb_right) && point_in_rectangle(ln_tool_mouse_x(),ln_tool_mouse_y(),_r[0],_r[1],_r[0]+_r[2],_r[1]+_r[3]+14)) {
            var _id=_nodes[_i].id,_right_key=ln_map_key(_e.game,_e.level)+":"+string(_id);
            if(variable_struct_exists(_e,"map_right_room") && _e.map_right_room==_right_key && current_time-_e.map_right_time<=400) {
                if(_id>=1000) ln_map_remove(_e.game,_e.level,_id);else _e.message="Original rooms are protected; only inserted rooms can be removed.";
                _e.map_right_room=-1;
            } else {_e.map_right_room=_right_key;_e.map_right_time=current_time;}
            return true;
        }
    }
    if(!_over_room && (mouse_check_button_pressed(mb_left) || mouse_check_button_pressed(mb_right))) {
        var _lanes=ln_map_lanes(_graph,_map,_nodes),_best=7,_chosen=-1,_chosen_lane=undefined,_chosen_t=0;
        for(var _i=0;_i<array_length(_lanes);_i++) {
            var _l=_lanes[_i],_dx=_l.x2-_l.x1,_dy=_l.y2-_l.y1;
            var _t=clamp(((ln_tool_mouse_x()-_l.x1)*_dx+(ln_tool_mouse_y()-_l.y1)*_dy)/max(.001,_dx*_dx+_dy*_dy),0,1);
            var _dist=point_distance(ln_tool_mouse_x(),ln_tool_mouse_y(),_l.x1+_dx*_t,_l.y1+_dy*_t);
            if(_dist<_best) {_best=_dist;_chosen=_l.edge;_chosen_lane=_l;_chosen_t=_t;}
        }
        if(_chosen>=0) {
            if(mouse_check_button_pressed(mb_right)) {ln_map_remove_lane(_e.game,_e.level,_chosen_lane,_chosen_t>=.5);return true;}
            _e.map_room_focus=false;_e.map_lane_source=_chosen_lane.source;_e.map_lane_destination=_chosen_lane.destination;_e.map_edge=_chosen;_e.map_scroll=min(_chosen,max(0,array_length(_graph.edges)-6));_e.message="Lane "+ln_map_letter(_chosen)+" selected. Use Insert blank on connection.";return true;}
    }
    if(ln_edit_hit(850,490,110,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Z")))) ln_map_history(false);
    if(ln_edit_hit(972,490,110,28) || (keyboard_check(vk_control) && keyboard_check_pressed(ord("Y")))) ln_map_history(true);
    if(ln_edit_hit(380,490,230,28)) ln_map_insert(_e.game,_e.level,_e.map_edge);
    if(ln_edit_hit(624,490,200,28) && _e.map_room>=1000) ln_map_remove(_e.game,_e.level,_e.map_room);
    if(ln_edit_hit(24,490,165,28)) {
        if(_e.map_room>=1000) _e.message="Inserted rooms are blank traversal spaces; room contents come next.";
        else if(_e.map_room>=0) {_e.map_open=false;ln_edit_select(_e.game,_e.level,_e.map_room);}
    }
    if(ln_edit_hit(201,490,165,28) || keyboard_check_pressed(ord("T")) || keyboard_check_pressed(vk_f5)) ln_map_test(_host);
    if(_e.autosave_us>0) {_e.autosave_us-=delta_time;if(_e.autosave_us<=0) ln_edit_save("modified-scenes.autosave.json");}
    return true;
}
function ln_map_active(_g) {return variable_struct_exists(_g,"map_transit") && is_struct(_g.map_transit);}
// Port coordinates use the same 240x144 game-area space as the blank room.
function ln_map_spawn_port(_g,_token) {
    var _x,_y;
    if(_g.game_number==1) {var _i=_g.world.entry_index[_token];_x=_g.world.entry_x[_i];_y=_g.world.entry_y[_i]-29;}
    else if(_g.game_number==2) {_x=_g.world.tables.entry_x[_token];_y=_g.world.tables.entry_y[_token]-29;}
    else {_x=_token.spawn_x-24;_y=_token.spawn_y-29;}
    var _side=0,_distance=abs(240-_x);
    if(abs(_x)<_distance) {_side=1;_distance=abs(_x);}
    if(abs(_y)<_distance) {_side=2;_distance=abs(_y);}
    if(abs(144-_y)<_distance) _side=3;
    return {side:_side,x:clamp(_x,24,216),y:clamp(_y,48,122)};
}
function ln_map_ports(_g,_route,_index) {
    var _graph=ln_map_graph(_g.game_number,_g.level),_edge=ln_map_edge(_graph,_route.edge),_reverse=ln_map_edge(_graph,_route.reverse);
    var _front=ln_map_spawn_port(_g,_edge.token);_front.side=_front.side^1;
    var _back={side:_front.side^1,x:_front.x,y:_front.y};
    if(_index==0 && is_struct(_reverse)) {_back=ln_map_spawn_port(_g,_reverse.token);_back.side=_back.side^1;}
    // Teleports can put both neighbours on one side. Give them separate ends.
    if(_back.side==_front.side) _back.side=_front.side^1;
    return {back:_back,front:_front};
}
function ln_map_port_crossed(_t,_port) {
    if(_port.side<2 && abs(_t.y-_port.y)>22) return false;
    if(_port.side>=2 && abs(_t.x-_port.x)>22) return false;
    return (_port.side==0 && _t.x>236) || (_port.side==1 && _t.x<4) || (_port.side==2 && _t.y<38) || (_port.side==3 && _t.y>134);
}
function ln_map_intercept(_g,_token) {
    if(!variable_global_exists("ln_editor") || !global.ln_editor.enabled || global.ln_editor.open || (variable_struct_exists(_g,"map_bypass") && _g.map_bypass) || ln_map_active(_g)) return false;
    var _key=ln_map_key(_g.game_number,_g.level);if(!variable_struct_exists(global.ln_editor.maps,_key)) return false;
    var _graph=ln_map_graph(_g.game_number,_g.level),_map=variable_struct_get(global.ln_editor.maps,_key),_edge=undefined;
    for(var _i=0;_i<array_length(_graph.edges);_i++) {
        var _candidate=_graph.edges[_i];
        if(_candidate.source==_g.room_id && json_stringify(_candidate.token)==json_stringify(_token)) {_edge=_candidate;break;}
    }
    if(!is_struct(_edge)) return false;
    var _route=ln_map_route(_map,_edge.key);if(!is_struct(_route)) return false;
    var _forward=_edge.key==_route.edge;
    _g.map_transit={route:json_parse(json_stringify(_route)),index:_forward?0:array_length(_route.rooms)-1,direction:_forward?1:-1,side:0,x:120,y:100,age:0,moving:false};
    ln_map_arrive(_g,true);ln_rewind_boundary();return true;
}
function ln_map_arrive(_g,_forward) {
    var _t=_g.map_transit;_t.ports=ln_map_ports(_g,_t.route,_t.index);
    var _from_back=_forward?(_t.direction==1):(_t.direction!=1),_port=_from_back?_t.ports.back:_t.ports.front;
    _t.x=_port.side==0?228:(_port.side==1?12:_port.x);
    _t.y=_port.side==2?46:(_port.side==3?126:_port.y);
    _t.side=_port.side^1;_t.age=0;_t.moving=false;
}
function ln_map_finish(_g,_key) {
    var _graph=ln_map_graph(_g.game_number,_g.level),_edge=ln_map_edge(_graph,_key);
    if(!is_struct(_edge)) return false;
    _g.map_transit=undefined;_g.map_bypass=true;
    if(_g.game_number==1) ln1_play_travel(_g,_edge.token);
    else if(_g.game_number==2) ln2_play_travel(_g,_edge.token);
    else ln3_play_enter(_g,_edge.token);
    _g.map_bypass=false;ln_rewind_boundary();return true;
}
function ln_map_tick(_g,_joy) {
    if(!ln_map_active(_g)) return false;
    var _t=_g.map_transit;
    var _map=ln_map_data(_g.game_number,_g.level);
    if(!is_struct(ln_map_room(_map,_t.route.rooms[_t.index]))) {ln_map_finish(_g,_t.direction==1?_t.route.edge:_t.route.reverse);return true;}
    if(!global.ln_editor.enabled) {ln_map_finish(_g,_t.direction==1?_t.route.edge:_t.route.reverse);return true;}
    var _dx=((_joy&8)!=0)-((_joy&4)!=0),_dy=((_joy&2)!=0)-((_joy&1)!=0);
    _t.moving=_dx!=0 || _dy!=0;_t.age++;_t.x+=_dx*1.25;_t.y+=_dy*0.75;
    if(_dx!=0) _t.side=_dx>0?0:1;else if(_dy!=0) _t.side=_dy>0?3:2;
    var _front=ln_map_port_crossed(_t,_t.ports.front),_back=ln_map_port_crossed(_t,_t.ports.back);
    if(_front || _back) {
        _t.direction=_front?1:-1;
        var _next=_t.index+_t.direction;
        if(_next>=0 && _next<array_length(_t.route.rooms)) {_t.index=_next;ln_map_arrive(_g,true);}
        else if(_next>=array_length(_t.route.rooms)) ln_map_finish(_g,_t.route.edge);
        else if(_t.route.reverse!="") ln_map_finish(_g,_t.route.reverse);
    }
    if(ln_map_active(_g)) {_t.x=clamp(_t.x,4,236);_t.y=clamp(_t.y,38,134);}
    return true;
}
function ln_map_draw_transit(_g) {
    if(!ln_map_active(_g)) return false;
    var _t=_g.map_transit,_map=ln_map_data(_g.game_number,_g.level),_room=ln_map_room(_map,_t.route.rooms[_t.index]);
    if(!is_struct(_room)) return false;
    ln_tool_clear();draw_set_colour(c_white);draw_set_font(font_jansina);draw_text(160,38,"LAST NINJA "+string(_g.game_number)+" / "+_room.name);
    draw_set_colour(global.ln_paint_palette[_room.background]);draw_rectangle(160,84,1119,659,false);draw_set_colour(c_white);
    var _v=global.ln_sprites;if(!is_struct(_v.catalog)) _v.catalog=ln3_data_read("sprite_viewer.json");
    var _entry=undefined;
    for(var _i=0;_i<array_length(_v.catalog.entries);_i++) {var _e=_v.catalog.entries[_i];if(_e.game==_g.game_number && _e.category==0 && _e.name=="Level "+string(_g.level)+" / Ninja") {_entry=_e;break;}}
    if(is_struct(_entry)) {
        var _clip=_entry.clips[0];
        if(_g.game_number==3 && _t.moving) for(var _i=0;_i<array_length(_entry.clips);_i++) if(_entry.clips[_i].name=="Weapon 0 / Action 2") {_clip=_entry.clips[_i];break;}
        var _frame=_clip.frames[_t.moving?((_t.age div 5) mod array_length(_clip.frames)):0],_flip=_t.side==1?-1:1;
        for(var _i=0;_i<array_length(_frame.parts);_i++) {
            var _p=_frame.parts[_i],_s=ln_sprite_asset(_p[0]);
            draw_sprite_ext(_s,_p[1],160+(_t.x+(_p[2]-_entry.ground_anchor[0])*_flip)*4,84+(_t.y+_p[3]-_entry.ground_anchor[1])*4,4*_flip,4,0,_p[4],1);
        }
    }
    draw_set_colour(c_white);draw_text(160,710,"Inserted room / walk through to continue, or back to return");return true;
}
function ln_map_test(_host) {
    var _e=global.ln_editor;
    if(_e.map_room<1000) {if(_e.map_room>=0) {ln_edit_select(_e.game,_e.level,_e.map_room);ln_edit_test_room(_host);}return;}
    var _map=ln_map_data(_e.game,_e.level),_route=undefined,_index=0;
    for(var _i=0;_i<array_length(_map.routes);_i++) for(var _j=0;_j<array_length(_map.routes[_i].rooms);_j++) if(_map.routes[_i].rooms[_j]==_e.map_room) {_route=_map.routes[_i];_index=_j;}
    if(!is_struct(_route)) return;
    var _edge=ln_map_edge(ln_map_graph(_e.game,_e.level),_route.edge);
    ln_edit_select(_e.game,_e.level,_edge.source);
    if(!ln_edit_test_room(_host)) return;
    _host.play.map_transit={route:json_parse(json_stringify(_route)),index:_index,direction:1,side:0,x:8,y:100,age:0,moving:false};ln_map_arrive(_host.play,true);ln_rewind_boundary();
}
function ln_map_checks() {
    var _e=global.ln_editor;_e.maps={};_e.scenes={};_e.open=false;_e.enabled=true;
    var _levels=0,_connections=0;
    var _near=ln_map_neighbours(ln_map_graph(1,1),ln_map_data(1,1),1);
    ln_check(array_length(_near)==2 && array_contains(_near,2) && array_contains(_near,14),"LN1 room 1 highlights only outgoing rooms 2 and 14");
    var _directed={edges:[{key:"a",source:1,destination:2},{key:"b",source:3,destination:1}]};
    var _near=ln_map_neighbours(_directed,{routes:[]},1);
    ln_check(array_length(_near)==1 && _near[0]==2,"incoming one-way connection is not an outgoing neighbour");
    for(var _game=1;_game<=3;_game++) for(var _level=1;_level<=(_game==1?6:(_game==2?7:5));_level++) {
        var _graph=ln_map_graph(_game,_level);ln_check(array_length(_graph.nodes)>0,"map has rooms");_levels++;_connections+=array_length(_graph.edges);
    }
    for(var _game=1;_game<=3;_game++) {
        var _g=_game==1?new LN1Play(1):(_game==2?new LN2Play(1):new LN3Play(1)),_graph=ln_map_graph(_game,1),_chosen=-1;
        for(var _i=0;_i<array_length(_graph.edges) && _chosen<0;_i++) {
            var _edge=_graph.edges[_i];if(_edge.source!=_g.room_id || _edge.destination==_edge.source || _edge.destination<0) continue;
            for(var _j=0;_j<array_length(_graph.edges);_j++) if(_graph.edges[_j].source==_edge.destination && _graph.edges[_j].destination==_edge.source) {_chosen=_i;break;}
        }
        ln_check(_chosen>=0,"bidirectional starting-room test connection");
        var _edge=_graph.edges[_chosen];
        ln_check(ln_map_insert(_game,1,_chosen) && ln_map_insert(_game,1,_chosen),"insert chain of two blank rooms");
        var _map=ln_map_data(_game,1),_route=ln_map_route(_map,_edge.key),_back=ln_map_edge(_graph,_route.reverse);
        ln_check(ln_map_validate(_e.maps),"valid inserted topology");
        var _near=ln_map_neighbours(_graph,_map,_edge.source);
        ln_check(array_contains(_near,_route.rooms[0]),"highlight immediate inserted neighbour");
        var _near=ln_map_neighbours(_graph,_map,_route.rooms[0]);
        ln_check(array_contains(_near,_edge.source) && array_contains(_near,_route.rooms[1]),"inserted bidirectional room highlights its two neighbours");
        ln_check(ln_map_intercept(_g,_edge.token),"native exit intercepted");
        ln_check(_g.map_transit.x>=4 && _g.map_transit.x<=236 && _g.map_transit.y>=38 && _g.map_transit.y<=134,"resolved spawn inside room");
        ln_map_check_walk(_g,true);
        ln_check(!ln_map_active(_g) && _g.room_id==_edge.destination,"cross all inserted rooms into original destination");
        ln_check(ln_map_intercept(_g,_back.token),"reverse exit intercepted");ln_map_check_walk(_g,false);
        ln_check(!ln_map_active(_g) && _g.room_id==_edge.source,"reverse chain reaches original source");
        _e.enabled=false;ln_check(!ln_map_intercept(_g,_edge.token),"Modified OFF retains original routes");_e.enabled=true;
        _e.game=_game;_e.level=1;_e.map_room=_route.rooms[0];_e.map_edge=_chosen;_e.map_scroll=0;
        ln_map_draw();surface_save(application_surface,"level-map-"+string(_game)+".png");
        ln_check(ln_map_intercept(_g,_edge.token),"test inserted room drawing");ln_map_draw_transit(_g);surface_save(application_surface,"level-map-room-"+string(_game)+".png");
        ln_map_finish(_g,_route.edge);
        if(surface_exists(_g.stage_surface)) surface_free(_g.stage_surface);
        if(_game==3 && surface_exists(_g.part_surface)) surface_free(_g.part_surface);
    }
    var _saved=json_stringify(_e.maps),_file="level-map-check.tmp.json";
    ln_check(ln_edit_save(_file),"map saves with editor file");_e.maps={};ln_check(ln_edit_load(_file),"map loads with editor file");
    ln_check(ln_rewind_equal(json_parse(_saved),_e.maps),"map topology roundtrip");file_delete(_file);
    var _bad=json_parse(_saved),_m=variable_struct_get(_bad,"1:1");array_push(_m.rooms,_m.rooms[0]);ln_check(!ln_map_validate(_bad),"reject duplicate room IDs");
    var _m=ln_map_data(1,1),_id=_m.rooms[0].id,_graph=ln_map_graph(1,1),_lanes=ln_map_lanes(_graph,_m,ln_map_nodes(_graph,_m)),_removed=false;
    for(var _i=0;_i<array_length(_lanes);_i++) if(_lanes[_i].source<1000 && _lanes[_i].destination==_id) {_removed=ln_map_remove_lane(1,1,_lanes[_i],true);break;}
    ln_check(_removed && ln_map_validate(_e.maps),"right-click lane removal reconnects valid chain");
    var _remaining=json_stringify(_e.maps);
    for(var _i=0;_i<array_length(_lanes);_i++) if(!is_struct(ln_map_route(_m,_graph.edges[_lanes[_i].edge].key))) {ln_check(!ln_map_remove_lane(1,1,_lanes[_i]),"original lane protected");break;}
    ln_check(_remaining==json_stringify(_e.maps),"protected original connection leaves map unchanged");
    ln_map_history(false);ln_check(ln_rewind_equal(json_parse(_saved),_e.maps),"undo room removal restores saved topology");
    ln_map_history(true);ln_check(!is_struct(ln_map_room(ln_map_data(1,1),_id)),"redo room removal");
    show_debug_message("LN_LEVEL_MAP_PASS: "+string(_levels)+" levels, "+string(_connections)+" exits; three-game bidirectional traversal, save/load and validation");
}

function ln_map_checkpoint() {
    var _e=global.ln_editor;array_push(_e.map_undo,json_stringify(_e.maps));_e.map_redo=[];
    if(array_length(_e.map_undo)>50) array_delete(_e.map_undo,0,1);
}
function ln_map_history(_redo) {
    var _e=global.ln_editor,_stack=_redo?_e.map_redo:_e.map_undo;
    if(array_length(_stack)==0) return;
    var _snapshot=json_stringify(_e.maps),_restore=array_pop(_stack);
    if(_redo) {_e.map_redo=_stack;array_push(_e.map_undo,_snapshot);}
    else {_e.map_undo=_stack;array_push(_e.map_redo,_snapshot);}
    _e.maps=json_parse(_restore);_e.map_room=-1;_e.enabled=true;_e.dirty=true;_e.autosave_us=1000000;_e.revision++;
    _e.message=_redo?"Map edit redone":"Map edit undone";
}

function ln_map_check_walk(_g,_front) {
    repeat(1600) {
        if(!ln_map_active(_g)) return;
        var _t=_g.map_transit,_p=_front?_t.ports.front:_t.ports.back;
        var _x=_p.side==0?240:(_p.side==1?0:_p.x),_y=_p.side==2?34:(_p.side==3?138:_p.y),_joy=0;
        if(abs(_x-_t.x)>1) _joy|=_x>_t.x?8:4;
        if(abs(_y-_t.y)>.5) _joy|=_y>_t.y?2:1;
        ln_map_tick(_g,_joy);
    }
    ln_check(false,"resolved exit traversal timed out");
}
