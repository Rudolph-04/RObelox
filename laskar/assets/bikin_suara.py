"""Bikin file suara prototipe Laskar Kendang (sintesis, tanpa sampel orang lain).

Jalanin:  python3 laskar/assets/bikin_suara.py
Hasil di laskar/assets/suara/: DUNG/TAK/PAK/TUNG (kendang), TIK (metronom).
Musik latar dibikin terpisah: laskar/assets/musik/bikin_musik.py.
Upload ke Roblox, terus isi ID-nya di LaskarConfig.SUARA.

Cuma pake library bawaan Python (wave, math, random), nggak perlu numpy.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
BPM = 120
KETUKAN = 60 / BPM
FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "suara")

acak = random.Random(42)  # seed tetap: hasil selalu sama






def nada_turun(f0, f1, tau, detik, harmonik=()):
    """Sinus yang frekuensinya turun f0 -> f1 (kayak kulit kendang dipukul)."""
    out = []
    fase = 0.0
    for i in range(int(detik * RATE)):
        t = i / RATE
        f = f1 + (f0 - f1) * math.exp(-t / 0.04)
        fase += 2 * math.pi * f / RATE
        v = math.sin(fase)
        for kali, g in harmonik:
            v += g * math.sin(fase * kali)
        out.append(v * math.exp(-t / tau))
    return out


def desis(tau, detik, halus=1):
    """Noise yang cepet ilang. halus > 1 = lebih "tebel" (dirata-rata)."""
    out = []
    riwayat = [0.0] * halus
    for i in range(int(detik * RATE)):
        t = i / RATE
        riwayat[i % halus] = acak.uniform(-1, 1)
        out.append(sum(riwayat) / halus * math.exp(-t / tau))
    return out


def campur(*bagian):
    panjang = max(len(b) for b, _ in bagian)
    out = [0.0] * panjang
    for b, g in bagian:
        for i, v in enumerate(b):
            out[i] += v * g
    return out


def dung():
    return campur((nada_turun(150, 72, 0.22, 0.6, harmonik=((2, 0.15),)), 1.0), (desis(0.008, 0.05, 3), 0.25))


def tak():
    return campur((desis(0.035, 0.25, 1), 0.55), (nada_turun(980, 820, 0.04, 0.25), 0.5))


def pak():
    return campur((desis(0.06, 0.3, 4), 0.7), (nada_turun(430, 360, 0.07, 0.3), 0.45))


def tung():
    return campur((nada_turun(360, 300, 0.28, 0.6, harmonik=((2, 0.3), (3, 0.08))), 0.8), (desis(0.006, 0.04, 2), 0.2))


def tik():
    return nada_turun(2100, 2000, 0.012, 0.06)








def tulis(nama, sampel, puncak=0.85):
    m = max(1e-9, max(abs(v) for v in sampel))
    skala = puncak / m
    os.makedirs(FOLDER, exist_ok=True)
    path = os.path.join(FOLDER, nama + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * skala)) * 32767)) for v in sampel))
    print(f"{path}  ({len(sampel) / RATE:.2f} detik)")


if __name__ == "__main__":
    tulis("DUNG", dung())
    tulis("TAK", tak())
    tulis("PAK", pak())
    tulis("TUNG", tung())
    tulis("TIK", tik(), 0.5)
