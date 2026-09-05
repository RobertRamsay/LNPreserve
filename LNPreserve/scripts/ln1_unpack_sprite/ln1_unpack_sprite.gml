/// Native translation of LN1 $7e36-$7e77, used to verify the PNG conversion.
/// No CPU interpreter. Runtime drawing uses editable PNG sprites.
/// Cost is original instruction cycles; VIC DMA and interrupts are not included.
function ln1_unpack_sprite(_encoded, _pointer, _index) {
    var _bytes = [], _y = 0;
    var _cycles = 18 + (_index >= 64 ? 1 : 0);
    while (array_length(_bytes) < 63) {
        if (_y >= array_length(_encoded)) show_error("Truncated LN1 sprite",true);
        var _value = _encoded[_y];
        _cycles += 12 + (((_pointer & 255) + _y) > 255 ? 1 : 0);
        if (_value >= $a0) {
            _cycles += 3;
            if (_value == $a0) {
                _y++;
                if (_y >= array_length(_encoded)) show_error("Truncated LN1 escape",true);
                _value = _encoded[_y];
                _cycles += 18 + (((_pointer & 255) + _y) > 255 ? 1 : 0);
                array_push(_bytes,_value);
                _cycles += 2;
            } else if (_value >= $b0) {
                _cycles += 7;
                array_push(_bytes,_value);
                _cycles += 2;
            } else {
                var _run = _value & 15;
                _cycles += 15 + 12*_run - 1 + 6;
                repeat (_run) array_push(_bytes,0);
            }
        } else {
            _cycles += 2;
            array_push(_bytes,_value);
            _cycles += 2;
        }
        _y++;
        _cycles += 4 + (array_length(_bytes) < 63 ? 3 : 2);
    }
    // The original checks the output length after a complete zero run.
    // Parts 189/190 include padding beyond the 63 displayed bytes.
    array_resize(_bytes,63);
    return {bytes:_bytes, instruction_cycles:_cycles+8};
}
