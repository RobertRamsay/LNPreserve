/// Original LN3 fragment masking, including the partial fourth-byte carryover.
/// Input is decoded scenery shape data; output is a 24x21 visibility mask.
function ln3_mask_bytes(_state,_shapes,_x,_y,_foot) {
    var _result=array_create(63,255),_shift=_x&6,_right=8-_shift;
    var _col=(_x+128) div 8,_line=(((_y-2)&255)+128) div 8,_phase=(_y-2)&7;
    var _spill=_state.mask_spill;
    for (var _n=0;_n<array_length(_shapes);_n++) {
        var _shape=_shapes[_n],_cx=_shape.x,_cy=_shape.y,_width=_shape.width,_height=_shape.height;
        if (_col<_cx || _line<_cy || (_shape.baseline>=0 && _foot>=_shape.baseline)) continue;
        if (_width+2+_cx<_col || _height+2+_cy<_line) continue;
        var _delta=_col-_cx,_mode=min(_delta,3),_skip=max(_delta-3,0),_count=(_width-_skip)&255;
        if (_count>=5) _count=4;
        var _row_delta=_line-_cy,_row=max(_row_delta-3,0),_source_y=_phase,_target=0;
        if (_row_delta<3) {
            _source_y=0;_target=((8-_phase)*3+(2-_row_delta)*24)&255;
            if (_target>=62) continue;
        }
        var _pointer=(_row*_width+_skip)*8;
        while (true) {
            var _raw=[0,0,0,_spill];
            for (var _i=0;_i<max(1,_count);_i++) _raw[_i]=_shape.bitmap[_pointer+_source_y+8*_i];
            var _value;
            if (_mode==0) _raw=[0,0,_raw[0]>>_right,_raw[3]];
            else if (_mode==1) {
                _value=((_raw[0]<<8)|_raw[1])>>_right;_raw=[0,(_value>>8)&255,_value&255,_raw[3]];
            } else if (_mode==2) {
                _value=((_raw[0]<<16)|(_raw[1]<<8)|_raw[2])>>_right;_raw=[(_value>>16)&255,(_value>>8)&255,_value&255,_raw[3]];
            } else {
                _value=((_raw[0]<<24)|(_raw[1]<<16)|(_raw[2]<<8)|_raw[3])<<_shift;
                _raw=[(_value>>24)&255,(_value>>16)&255,(_value>>8)&255,_value&255];
            }
            _spill=_raw[3];
            for (var _i=0;_i<3;_i++) {
                var _opaque=0;
                for (var _bit=0;_bit<=6;_bit+=2) if (_raw[_i]&(3<<_bit)) _opaque|=3<<_bit;
                _result[_target+_i]&=_opaque^255;
            }
            _target+=3;if (_target>=62) break;
            _source_y=(_source_y+1)&7;
            if (_source_y==0) {_row++;if (_row>=_height) break;_pointer+=_width*8;}
        }
    }
    _state.mask_spill=_spill;return _result;
}
