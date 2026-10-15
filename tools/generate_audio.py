#!/usr/bin/env python3
"""Original deterministic synthesized placeholder SFX; no samples or external assets."""
from pathlib import Path
import math, random, struct, wave
root = Path(__file__).resolve().parents[1] / 'assets/audio'
root.mkdir(parents=True, exist_ok=True)
rate = 22050
specs = {'step': (.045, 160), 'place': (.10, 340), 'fuse': (.055, 1050),
         'explosion': (.46, 70), 'crate': (.12, 220), 'pickup': (.26, 600),
         'death': (.28, 350), 'victory': (.55, 520), 'defeat': (.48, 280), 'ui': (.06, 750)}
for index, (name, (duration, frequency)) in enumerate(specs.items()):
    rng = random.Random(3701 + index)
    count = int(rate * duration)
    samples = []
    phase = 0.0
    for i in range(count):
        u = i / (count - 1)
        if name in ('pickup', 'victory'):
            f = frequency * [1, 1.25, 1.5, 2][min(3, int(u * 4))]
        elif name in ('death', 'defeat'):
            f = frequency * (1 - .65 * u)
        else:
            f = frequency * (1 - .25 * u)
        phase += 2 * math.pi * f / rate
        envelope = min(1, i / (rate * .004)) * (1 - u) ** 2
        value = math.sin(phase)
        if name in ('explosion', 'crate', 'step'):
            value = .45 * value + .55 * rng.uniform(-1, 1)
        samples.append(int(value * envelope * .32 * 32767))
    with wave.open(str(root / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
        wav.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print('Generated 10 original mono PCM effects.')
