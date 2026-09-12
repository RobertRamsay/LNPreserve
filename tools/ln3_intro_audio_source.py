"""Interpret original intro SID initializations and stepped volume bytes."""
def audio_events(t):
    events=[];starts={e['tick']:e for e in t['events']};active=None;last_gain=None
    for tick,v in enumerate(t['volumes']):
     if tick in starts:
      e=starts[tick];active='snd_ln3_intro_cue' if e['entry']=='0xb200' else 'snd_ln3_subtune_0'+str(e['a']+1)+'_unmapped_cue'
      events.append(dict(tick=tick,asset=active,gain=1));last_gain=15
     if active:
      gain=min(15,v[0] if active=='snd_ln3_intro_cue' else v[3])
      if gain!=last_gain:
       events.append(dict(tick=tick,asset='',gain=gain/15));last_gain=gain
       if gain==0:active=None
    assert [(e['tick'],e['asset']) for e in events if e['asset']]==[(72,'snd_ln3_subtune_01_unmapped_cue'),(624,'snd_ln3_subtune_02_unmapped_cue'),(3681,'snd_ln3_intro_cue')]
    return events
