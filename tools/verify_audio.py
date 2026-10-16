#!/usr/bin/env python3
"""Check delivered PCM for clipping, silence, format and abrupt file boundaries."""
from pathlib import Path
import array, hashlib, json, math, subprocess, sys, wave
root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / 'tools/generate_audio.py'), '--check'], check=True)
report = {}
for path in sorted((root / 'assets/audio').glob('*.wav')):
    with wave.open(str(path), 'rb') as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 22050), path
        pcm = array.array('h', wav.readframes(wav.getnframes()))
        if sys.byteorder != 'little': pcm.byteswap()
        duration = len(pcm) / wav.getframerate()
    peak = max(abs(x) for x in pcm) / 32768
    rms = math.sqrt(sum(x*x for x in pcm) / len(pcm)) / 32768
    assert .02 < duration < 1 and .02 < peak < .8 and rms > .005, path
    assert pcm[0] == pcm[-1] == 0, path
    report[path.stem] = {'duration': round(duration, 4), 'peak': round(peak, 4), 'rms': round(rms, 4), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
assert len(report) == 10
(root / 'docs/qa/audio_assets.json').write_text(json.dumps(report, indent=2)+'\n')
print('Audio asset QA: 10 PCM assets PASS (headroom, signal, fade boundaries).')
