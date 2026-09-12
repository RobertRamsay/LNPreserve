# LN3 intro and outro selection

F11 â†’ Last Ninja 3 lists INTRO, Earth, Wind, Water, Fire, Void, OUTRO.
INTRO plays the recovered original sequence. Fire / Xbox A advances to Earth's
existing scene-0 frontend; held fire must be released first. Completion also opens
that frontend. F11 can interrupt either presentation to choose any level or scene.
OUTRO uses the existing original ending implementation. Both play their respective
intro/outro cue resources and preserve the music mute preference. Natural victory
now starts the same outro music. The movies fill the 320Ã—200 picture at 4Ã— scale;
debug save slots and controller text do not cover them.

## Intro recovery

Original MSR D81 INTRO entry $0400 through exit $10c5, captured with VICE 3.10.
10,684 PAL display samples, 1,230 unique frames. These include original credits,
story panels, sprite composition and raster colour effects. The indexed display
is mapped to the existing Pepto palette, with exact changed RGBA spans replayed
by GameMaker; no emulator is shipped or run in the game.

Reproduce with tools/capture_ln3_intro.py <MSR.d81> <output-directory>, then
tools/export_ln3_intro.py <output-directory> <MSR.d81>. Capture uses the same
local VICE setup as tools/vice_reference.py. The included intro.json records the
disk hash, format and pixel checkpoints. The intro.bin is approximately 20 MB.

## Verification

--ln3-presentation-checks verifies the entire delta stream, source pixel
checkpoints, GPU upload, held-fire protection, selection from LN1, muted music,
intro/outro switching, normal scene selection and cleanup. It saves intro, outro
and selector previews in GameMaker's save directory. Intro stream checks are also
part of the full ln3_special selftest group. Offline export compares every decoded
frame with its original indexed display sample. Music alignment and the complete
viewing experience still merit manual playtesting; this is not a full playthrough.

## Original intro audio cues

The intro now starts silently. Original driver initialization calls select:
- PAL tick 72: snd_ln3_subtune_01_unmapped_cue ($a600, A=0).
- PAL tick 624: snd_ln3_subtune_02_unmapped_cue ($a600, A=1).
- PAL tick 3681: snd_ln3_intro_cue ($b200, A=0).

Source volume bytes supply the opening cue's fade to silence and the main theme's
final fade. These three recordings play once at their cues. F11 and pause freeze
picture and audio together; mute changes volume while keeping the cue position.
The capture helper now saves audio-trace.json as well as image samples; the exporter
uses ln3_intro_audio_source.py to reproduce all 33 cue/fade events. Manual listening
is still useful to check the supplied recordings themselves for leading silence.
