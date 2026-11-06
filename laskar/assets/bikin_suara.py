"""Bikin file suara prototipe Laskar Kendang (sintesis, tanpa sampel orang lain).

Jalanin:  python3 laskar/assets/bikin_suara.py
Hasil di laskar/assets/suara/: DUNG/TAK/PAK/TUNG (kendang), TIK (metronom),
MUSIK (loop 16 ketukan @120 BPM = 8 detik, pas sama LaskarConfig.MUSIK_KETUKAN).
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


def kosong(detik):
    return [0.0] * int(detik * RATE)


def tambah(buf, sampel, mulai_detik=0.0, gain=1.0, lipat=False):
    """lipat=True: bagian yang lewat ujung buffer diterusin dari depan (buat loop)."""
    awal = int(mulai_detik * RATE)
    for i, v in enumerate(sampel):
        j = awal + i
        if j >= len(buf):
            if not lipat:
                break
            j %= len(buf)
        buf[j] += v * gain


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


def gong():
    """Gong rendah: dua sinus deket biar ada efek ngombak."""
    out = []
    for i in range(int(3.0 * RATE)):
        t = i / RATE
        v = math.sin(2 * math.pi * 82 * t) + 0.6 * math.sin(2 * math.pi * 84.5 * t) + 0.25 * math.sin(2 * math.pi * 164 * t)
        serang = min(1.0, t / 0.02)
        out.append(v * serang * math.exp(-t / 1.1))
    return out


def petik(f, tau=0.35, detik=0.6):
    """Bilah logam ala bonang (sinus + harmonik tinggi)."""
    out = []
    for i in range(int(detik * RATE)):
        t = i / RATE
        v = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t / 0.08)
        out.append(v * math.exp(-t / tau))
    return out


def musik():
    """Loop 16 ketukan: gong tiap 8 ketukan, kendang rendah tiap ketukan,
    desis di sela ketukan, petikan pentatonis pelan."""
    panjang = 16 * KETUKAN
    buf = kosong(panjang)
    # Pentatonis ala slendro (perkiraan, bukan laras asli).
    nada = [293.7, 336.0, 386.0, 443.0, 509.0]
    pola = [0, 2, 1, 3, 2, 4, 3, 1, 0, 2, 4, 3, 2, 1, 0, 2]
    # lipat=True: ekor yang lewat ujung loop diterusin dari depan biar sambungannya mulus.
    for n in range(16):
        t = n * KETUKAN
        if n % 8 == 0:
            tambah(buf, gong(), t, 0.5, lipat=True)
        tambah(buf, nada_turun(110, 55, 0.18, 0.4), t, 0.55 if n % 2 == 0 else 0.4, lipat=True)
        tambah(buf, desis(0.02, 0.1, 1), t + KETUKAN / 2, 0.12, lipat=True)
        tambah(buf, petik(nada[pola[n]]), t, 0.12, lipat=True)
    return buf


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
    tulis("MUSIK", musik(), 0.8)
