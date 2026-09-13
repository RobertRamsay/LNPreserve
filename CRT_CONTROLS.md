# CRT controls

F10 toggles CRT. With CRT on, the panel beneath the game offers Phosphor and Classic.
Phosphor is the default for preferences without a saved treatment. Existing blur,
scanline and mask strengths are retained when loading an older INI.

- Phosphor: independently implemented staggered RGB Gaussian dots, inspired by
  [Cathode by nimitz](https://www.shadertoy.com/view/4lXcDH).
- Classic: the previous honeycomb mask.
- Spacing: 0.5–2 native rows per phosphor cell; 1 is the default.
- Pixel blur: Gaussian image softness. Phosphors/Honeycomb: mask strength.
- Scanlines: extra line darkness, with the existing width, alignment and four samples.

All controls and on/off state persist in LNPreserve.ini. Only the game picture and
its built-in HUD are processed. Edges stay straight; debug/editor controls are excluded.

The Shadertoy page could not be fetched directly. The public
[ReShade port](https://github.com/Matsilagi/RSRetroArch/blob/main/Shaders/Cathode.fx)
identifies the reference and describes its phosphor treatment, but is marked all rights
reserved. This implementation does not copy that shader code and does not claim pixel parity.
It combines independent Gaussian phosphor modulation with our existing Gaussian image blur;
it is not an exact reconstruction of the original shader's source-pixel accumulation.

Validation: native GPU checks exercise Classic/Phosphor and spacing differences,
all existing sliders, region exclusion, filled corners, toggle off restoration,
texture preservation, and INI round trips. Live output and 1280×800 / 2560×1600
window checks pass. Visual tuning on the user's monitor is still subjective.

In F6, Editor CRT / F10 independently toggles the scene preview (saved under the Editor INI section). F9 / Fullscreen now works throughout the project, restoring the previous window geometry when switched off.
