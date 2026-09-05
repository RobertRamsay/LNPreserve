"""Lossless D64 directory extraction. Never execute programs from the archives."""
from pathlib import Path
import argparse, hashlib, json, re, zipfile

ROOT = Path(__file__).resolve().parents[1]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def sector_offset(track, sector):
    if not 1 <= track <= 35:
        raise ValueError(f"Invalid track {track}")
    counts = [21 if t <= 17 else 19 if t <= 24 else 18 if t <= 30 else 17 for t in range(1, 36)]
    if not 0 <= sector < counts[track-1]:
        raise ValueError(f"Invalid sector {track}/{sector}")
    return (sum(counts[:track-1]) + sector) * 256

def petscii(data):
    return ''.join(chr(c) if 32 <= c <= 126 else ' ' if c == 160 else f"\\x{c:02x}" for c in data).rstrip()

def chain(data, track, sector):
    seen, blocks, payload = set(), [], bytearray()
    while track:
        if (track, sector) in seen:
            raise ValueError(f"Cyclic sector chain at {track}/{sector}")
        seen.add((track, sector))
        off = sector_offset(track, sector)
        block = data[off:off+256]
        if len(block) != 256:
            raise ValueError("Truncated sector")
        blocks.append([track, sector])
        next_track, next_sector = block[:2]
        if next_track == 0 and next_sector < 1:
            raise ValueError("Invalid final-sector byte count")
        payload.extend(block[2:256 if next_track else next_sector+1])
        track, sector = next_track, next_sector
    return bytes(payload), blocks

def directory(data):
    if len(data) not in (174848, 175531):
        raise ValueError(f"Unsupported D64 size {len(data)}")
    result, seen = [], set()
    track, sector = 18, 1
    while track:
        if (track, sector) in seen:
            raise ValueError("Cyclic directory")
        seen.add((track, sector))
        off = sector_offset(track, sector)
        for slot in range(8):
            entry = data[off+slot*32:off+(slot+1)*32]
            if entry[2] == 0:
                continue
            record = dict(index=len(result), name=petscii(entry[5:21]), name_hex=entry[5:21].hex(),
                          file_type=entry[2] & 7, closed=bool(entry[2] & 128), locked=bool(entry[2] & 64),
                          directory_sector=[track,sector], slot=slot, start=list(entry[3:5]),
                          declared_blocks=int.from_bytes(entry[30:32], 'little'))
            try:
                payload, blocks = chain(data, *entry[3:5])
                record.update(bytes=len(payload), sha256=sha(payload), sectors=blocks,
                              load_address=int.from_bytes(payload[:2], 'little') if len(payload)>=2 and record['file_type']==2 else None)
                record['_data'] = payload
            except ValueError as exc:
                record['error'] = str(exc)
            result.append(record)
        track, sector = data[off:off+2]
    return result

def extract(archive_paths):
    report = {'schema':1, 'method':'D64 linked sectors; PRG load addresses are not evidence of unpacked code', 'archives':[]}
    out = ROOT/'source/local'
    out.mkdir(parents=True, exist_ok=True)
    for archive in archive_paths:
        archive = Path(archive)
        ar = dict(name=archive.name, sha256=sha(archive.read_bytes()), disks=[])
        with zipfile.ZipFile(archive) as z:
            for info in sorted(z.infolist(), key=lambda x:x.filename):
                if not info.filename.lower().endswith('.d64'):
                    continue
                data = z.read(info)
                disk_id = re.sub('[^a-z0-9]+','_',Path(info.filename).stem.lower()).strip('_')
                folder=out/disk_id
                folder.mkdir(exist_ok=True)
                (folder/'disk.d64').write_bytes(data)
                entries=directory(data)
                for record in entries:
                    if '_data' not in record:
                        continue
                    name=re.sub('[^a-zA-Z0-9]+','_',record['name']).strip('_') or 'directory_art'
                    target=folder/f"{record['index']:03d}_{name}.bin"
                    target.write_bytes(record.pop('_data'))
                    record['path']=target.relative_to(ROOT).as_posix()
                ar['disks'].append(dict(id=disk_id, archive_member=info.filename, bytes=len(data), sha256=sha(data), entries=entries))
        report['archives'].append(ar)
    dest=ROOT/'evidence/disk_inventory.json'
    dest.parent.mkdir(exist_ok=True)
    dest.write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives',nargs='+',type=Path)
    args=parser.parse_args()
    report=extract(args.archives)
    for ar in report['archives']:
        for d in ar['disks']:
            print(d['id'])
            for e in d['entries']:
                print(f"  {e['index']:3} {e['name'][:20]:20} {e.get('bytes',0):6} {str(e.get('load_address')):6} {e.get('error','')}")
