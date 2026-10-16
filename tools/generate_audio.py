#!/usr/bin/env python3
"""Original deterministic synthesized SFX; no samples or external recordings.

--check verifies reproducibility without rewriting assets. Peak/headroom and fade
checks are run independently by tools/verify_audio.py.
"""
from pathlib import Path
import argparse, io, math, random, struct, wave

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1] / 'assets/audio'
root.mkdir(parents=True, exist_ok=True)
rate = 22050
specs = {'step': (.045, 160, .11), 'place': (.12, 340, .24), 'fuse': (.14, 1050, .22),
         'explosion': (.56, 70, .48), 'crate': (.16, 220, .19), 'pickup': (.32, 600, .25),
         'death': (.32, 350, .28), 'victory': (.78, 520, .26), 'defeat': (.64, 280, .25), 'ui': (.065, 750, .15)}
for index, (name, (duration, frequency, gain)) in enumerate(specs.items()):
    rng = random.Random(3701 + index)
    count = round(rate * duration)
    samples, phase, noise = [], 0.0, 0.0
    for i in range(count):
        t = i / rate
        u = i / (count - 1)
        # Short fades at both ends avoid digital clicks, including arpeggio edges.
        fade = min(1.0, t / .004, (duration - t - 1 / rate) / .008)
        fade = max(0.0, fade)
        if name in ('pickup', 'victory', 'defeat'):
            notes = [1, 1.25, 1.5, 2] if name != 'defeat' else [1.5, 1.25, 1, .75]
            position = u * len(notes)
            note = min(len(notes) - 1, int(position))
            local = position - note
            phase += 2 * math.pi * frequency * notes[note] / rate
            edge = min(1, local / .07, (1 - local) / .1)
            value = (.8 * math.sin(phase) + .2 * math.sin(phase * 2)) * edge * (1 - .45 * u)
        elif name == 'fuse':
            # Two dry ticks, recognizably different from a pickup or remote signal.
            local = t if t < .06 else t - .075
            value = 0.0
            if 0 <= local < .05:
                value = math.sin(2 * math.pi * frequency * local) * math.exp(-local * 85)
        else:
            f = frequency * (1 - (.68 if name == 'death' else .35) * u)
            phase += 2 * math.pi * f / rate
            noise = noise * .65 + rng.uniform(-1, 1) * .35
            value = math.sin(phase)
            if name == 'explosion':
                value = .56 * value + .28 * math.sin(phase * .5) + .5 * noise
            elif name in ('crate', 'step', 'place'):
                value = .48 * value + .52 * noise
            value *= (1 - u) ** (2 if name == 'explosion' else 3)
        samples.append(round(max(-.9, min(.9, value * gain * fade)) * 32767))
    output = io.BytesIO()
    with wave.open(output, 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
        wav.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
    data = output.getvalue()
    path = root / (name + '.wav')
    if args.check:
        assert path.read_bytes() == data, f'Non-reproducible audio: {name}'
    else:
        path.write_bytes(data)
print('Verified 10 reproducible effects.' if args.check else 'Generated 10 original mono PCM effects.')
