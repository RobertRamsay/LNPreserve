"""Edit the LN3 Fire stepping-stone room's lava mask as a picture.

  python tools/ln3_lava_mask.py export   writes build/lava_mask/:
      fire_scene.png         the scene at 4x, to put underneath as a reference layer
      fire_lava_mask.png     the lava: green on transparent, same size; paint this layer
      fire_lava_preview.png  both together, for a quick look
  python tools/ln3_lava_mask.py import [mask.png]
      reads the painted mask back into datafiles/play/ln3/jump_pads.json.

Paint where the ninja's FEET (the bottom of his sprite) must die. Any opaque pixel counts
as lava, whatever its colour; erase to transparent for safe ground. Rebuild the game after
an import. The mask is in screen space: a pixel at (x, y) of the 4x scene is the feet
position x/4+12, y/4+29 in the game's coordinates.
"""
from pathlib import Path
import argparse, json, re, sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'LNPreserve'
PADS = PROJECT / 'datafiles/play/ln3/jump_pads.json'
OUT = ROOT / 'build/lava_mask'
LEVEL, ROOM, SCALE = 4, 3, 4
GREEN = (0, 255, 0, 150)
LANDINGS_AND_ENTRIES = [(24, 92), (24, 148), (236, 168)]


def scene_art():
    """The room's background with its first scenery frame, as drawn in game (240x144)."""
    sprite = PROJECT / 'sprites/spr_ln3_scenery_animation'
    names = re.findall(r'GMSpriteFrame":"v1","%Name":"([0-9a-f-]+)"', (sprite / 'spr_ln3_scenery_animation.yy').read_text())
    scenery = json.loads((PROJECT / f'datafiles/play/ln3/level{LEVEL}/scenery_animation.json').read_text())
    frame = next(r for r in scenery['rooms'] if r['id'] == ROOM)['first'][0]['frame']
    return Image.open(sprite / f'{names[frame]}.png').convert('RGBA').resize((240, 144), Image.NEAREST)


def load_pads():
    data = json.loads(PADS.read_text())
    room = next(r for r in data['rooms'] if r['level'] == LEVEL and r['room'] == ROOM)
    return data, room


def export(out):
    out.mkdir(parents=True, exist_ok=True)
    _, room = load_pads()
    art = scene_art().resize((240 * SCALE, 144 * SCALE), Image.NEAREST)
    mask = Image.new('RGBA', art.size, (0, 0, 0, 0))
    px = mask.load()
    # Each lava run covers feet x0..x1 on row y; feet (x, y) is drawn at stage (x-12, y-29).
    for y, x0, x1 in room.get('lava', []):
        for x in range(x0, x1 + 1):
            sx, sy = (x - 12) * SCALE, (y - 29) * SCALE
            for dx in range(SCALE):
                for dy in range(SCALE):
                    if 0 <= sx + dx < mask.width and 0 <= sy + dy < mask.height:
                        px[sx + dx, sy + dy] = GREEN
    art.save(out / 'fire_scene.png')
    mask.save(out / 'fire_lava_mask.png')
    Image.alpha_composite(art, mask).save(out / 'fire_lava_preview.png')
    print(f'wrote {out}')


def import_mask(path):
    mask = Image.open(path).convert('RGBA')
    if mask.size != (240 * SCALE, 144 * SCALE):
        sys.exit(f'{path} is {mask.size}; expected {(240 * SCALE, 144 * SCALE)}')
    alpha = mask.getchannel('A').load()
    runs = []
    # Feet cells are 2 pixels wide in game x; a cell is lava when most of its block is painted.
    for y in range(29, 29 + 144):
        start = None
        for x in range(12, 12 + 240, 2):
            sx, sy = (x - 12) * SCALE, (y - 29) * SCALE
            block = [alpha[sx + dx, sy + dy] > 127 for dx in range(2 * SCALE) for dy in range(SCALE)
                     if sx + dx < mask.width]
            lava = sum(block) * 2 >= len(block)
            if lava and start is None:
                start = x
            if not lava and start is not None:
                runs.append([y, start, x - 1]); start = None
        if start is not None:
            runs.append([y, start, 12 + 240 - 1])
    data, room = load_pads()
    room['lava'] = runs
    text = PADS.read_text()
    PADS.write_text(re.sub(r'"lava": \[\[.*\]\]', '"lava": ' + json.dumps(runs, separators=(',', ':')), text))
    json.loads(PADS.read_text())
    lava = lambda x, y: any(r[0] == y and r[1] <= x <= r[2] for r in runs)
    spots = [(r['x'], r['y']) for r in room['routes']] + LANDINGS_AND_ENTRIES
    bad = sorted({p for p in spots if lava(*p)})
    print(f'imported {len(runs)} lava runs into {PADS.relative_to(ROOT)}')
    if bad:
        print('WARNING: these landing spots or scene entries are now lava:', bad)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('command', choices=['export', 'import'])
    p.add_argument('mask', nargs='?', type=Path, default=OUT / 'fire_lava_mask.png')
    a = p.parse_args()
    export(OUT) if a.command == 'export' else import_mask(a.mask)
