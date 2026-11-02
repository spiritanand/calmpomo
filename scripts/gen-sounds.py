#!/usr/bin/env python3
import array
import math
import os
import shutil
import subprocess
import sys
import wave

SR = 48000
WARM = [(1, 1.0, 1.0), (0.5, 0.16, 1.3), (2, 0.08, 0.5)]
G4, D5 = 392.00, 587.33


def note(freq, dur, tau, attack):
    n, a, r = int(SR * dur), int(SR * attack), int(SR * 0.08)
    out = [0.0] * n
    for ratio, amp, tmul in WARM:
        w, k = 2 * math.pi * freq * ratio / SR, 1 / (SR * tau * tmul)
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-i * k)
    for i in range(a):
        out[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    for i in range(r):
        out[n - r + i] *= 1 - i / r
    return out


def seq(notes, total):
    buf = [0.0] * int(SR * total)
    for freq, start, dur, tau, attack in notes:
        s = int(SR * start)
        for i, v in enumerate(note(freq, dur, tau, attack)[: len(buf) - s]):
            buf[s + i] += v
    return buf


def write(path, x):
    g = 10 ** (-14 / 20) / max(abs(v) for v in x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(array.array("h", [int(v * g * 32767) for v in x]).tobytes())


def loudnorm(src, dst, lufs):
    probe = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", src, "-af", "ebur128", "-f", "null", "-"],
        capture_output=True, text=True, check=True,
    ).stderr
    measured = float(probe.rsplit(" I:", 1)[1].split("LUFS")[0])
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", src, "-af", f"volume={lufs - measured:.2f}dB", dst],
        check=True,
    )
    os.remove(src)


SOUNDS = {
    "focus_start": (seq([(G4, 0, 1.3, 0.38, 0.02), (D5, 0.16, 1.24, 0.42, 0.02)], 1.4), -26),
    "break_start": (seq([(D5, 0, 1.6, 0.5, 0.025), (G4, 0.22, 1.58, 0.6, 0.025)], 1.8), -26),
    "break_over": (seq([(G4, 0, 1.2, 0.35, 0.03)], 1.3), -31),
}

if not shutil.which("ffmpeg"):
    sys.exit("gen-sounds: ffmpeg is required for loudness matching (brew install ffmpeg)")

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "sounds")
for name, (samples, lufs) in SOUNDS.items():
    raw = os.path.join(out, f".{name}.raw.wav")
    write(raw, samples)
    loudnorm(raw, os.path.join(out, f"{name}.wav"), lufs)

with wave.open(os.path.join(out, "break_start.wav")) as w:
    params, frames = w.getparams(), w.readframes(w.getnframes())
gap = b"\x00\x00" * int(SR * 0.35)
with wave.open(os.path.join(out, "long_break.wav"), "wb") as w:
    w.setparams(params)
    w.writeframes(frames + gap + frames)
