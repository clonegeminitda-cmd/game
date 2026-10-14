#!/usr/bin/env python3
"""Generate original, deterministic PCM ambience. No third-party sound assets."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050


def write(name, seconds, synth):
    count = int(RATE * seconds)
    rng = random.Random(307)
    values = [max(-1.0, min(1.0, synth(i / RATE, rng))) for i in range(count)]
    with wave.open(str(ROOT / name), "wb") as out:
        out.setparams((1, 2, RATE, count, "NONE", "not compressed"))
        out.writeframes(struct.pack(f"<{count}h", *(int(v * 32767) for v in values)))


def rain(t, rng):
    # Broad-band rain plus a gentle, periodic window resonance.
    return rng.uniform(-0.28, 0.28) * (0.9 + 0.1 * math.sin(2 * math.pi * t / 4))


def electric(t, rng):
    return 0.12 * math.sin(2 * math.pi * 100 * t) + 0.02 * math.sin(2 * math.pi * 200 * t)


def footstep(t, rng):
    return (0.45 * math.sin(2 * math.pi * 85 * t) + rng.uniform(-0.12, 0.12)) * math.exp(-t * 22) * min(1, t * 600)


def knock(t, rng):
    for at in (0.0, 0.42, 0.88):
        dt = t - at
        if 0 <= dt < 0.30:
            return (0.55 * math.sin(2 * math.pi * 145 * dt) + 0.25 * math.sin(2 * math.pi * 277 * dt) + rng.uniform(-0.04, 0.04)) * math.exp(-dt * 23) * min(1, dt * 700)
    return 0.0


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    write("rain.wav", 4, rain)
    write("electric.wav", 1, electric)
    write("footstep.wav", 0.32, footstep)
    write("knock.wav", 1.3, knock)
    print("Generated four original sounds.")
