"""Musik prototipe Laskar Kendang: ditulis sebagai MIDI, dirender pakai soundfont,
terus dicek otomatis biar ketukannya pas sama jam game.

Hasil (di folder ini):
  MUSIK.wav           loop stage, 32 ketukan @120 BPM = 16 detik
  MUSIK_SEMANGAT.wav  loop yang sama + suling, taiko, kocokan (dipake pas SEMANGAT)
  MENANG.wav          musik pendek pas benteng ancur (sekali main, nggak di-loop)
  *.mid               not-nya, bisa dibuka di BandLab/LMMS buat ganti alat musik

Kebutuhan (Linux):
  apt-get install fluidsynth fluid-soundfont-gm
  python3 -m pip install numpy mido
Jalanin: python3 laskar/assets/musik/bikin_musik.py

Soundfont: FluidR3_GM (Frank Wen, lisensi MIT) -> hasil render bebas dipake.

Tangga nada: pentatonis D minor (D F G A C), perkiraan nuansa gamelan, bukan laras
slendro/pelog asli (alat musik General MIDI nggak punya gamelan).

Cara loop-nya mulus: lagu ditulis 3x berturut-turut, dirender, terus yang
diambil putaran ke-2. Ekor bunyi (gaung, gong) dari ujung putaran 1 jadi
otomatis ada di awal putaran 2, dan awal pukulan putaran 3 ada di ujungnya,
persis kayak pas loop muter ulang.

Tes otomatis (diulang sampai lolos, maksimal 6x):
  - panjang loop pas 32 ketukan (705600 sampel)
  - tiap ketukan: titik serangan bunyi pukulan dicari di +-40 ms dari ketukan.
    Median selisihnya dipake buat geser titik potong, diulang sampai |median| < 0.5 ms
  - selisih maksimal per ketukan < 10 ms, tempo (regresi) = 0.5 detik/ketukan
  - ketukan harus lebih nonjol dari sela ketukan (rasio)
  - sambungan loop nggak "klik"
  - nggak clipping
"""

import os
import subprocess
import sys
import tempfile
import wave

import mido
import numpy as np

BPM = 120
TPB = 480
KETUKAN = 60 / BPM
RATE = 44100
LOOP = 32  # ketukan per loop (samain sama LaskarConfig.MUSIK_KETUKAN)
SF2 = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
FOLDER = os.path.dirname(os.path.abspath(__file__))
SEMENTARA = os.path.join(tempfile.gettempdir(), "laskar_render.wav")

# Program General MIDI (mulai dari 0).
MARIMBA, TUBULAR, KALIMBA, BASS, PANFLUTE, TAIKO, TIMPANI = 12, 14, 108, 32, 75, 116, 47
DRUM = 9  # channel perkusi

# Nada (MIDI). Pentatonis D minor.
D2, F2, G2, A2 = 38, 41, 43, 45
D4, F4, G4, A4, C5, D5, F5, G5, A5, C6, D6 = 62, 65, 67, 69, 72, 74, 77, 79, 81, 84, 86

# Perkusi General MIDI.
BASS_DRUM, LOW_CONGA, MUTE_HI_CONGA, OPEN_HI_CONGA = 35, 64, 62, 63
HI_BONGO, LOW_BONGO, CABASA, MARACAS, TAMBOURINE, WOODBLOCK = 60, 61, 69, 70, 54, 76


class Lagu:
    def __init__(self):
        self.ev = []  # (tick, urutan, pesan)

    def alat(self, ch, program):
        self.ev.append((0, 0, mido.Message("program_change", channel=ch, program=program)))

    def nada(self, ch, note, ketukan, durasi, vel):
        on = int(round(ketukan * TPB))
        off = int(round((ketukan + durasi) * TPB))
        self.ev.append((on, 2, mido.Message("note_on", channel=ch, note=note, velocity=vel)))
        self.ev.append((off, 1, mido.Message("note_off", channel=ch, note=note, velocity=0)))

    def simpan(self, path, total_ketukan):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        trk = mido.MidiTrack()
        mid.tracks.append(trk)
        trk.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
        sekarang = 0
        for tick, _, msg in sorted(self.ev, key=lambda e: (e[0], e[1])):
            trk.append(msg.copy(time=tick - sekarang))
            sekarang = tick
        akhir = int(total_ketukan * TPB)
        trk.append(mido.MetaMessage("end_of_track", time=max(0, akhir - sekarang)))
        mid.save(path)


# ── KOMPOSISI ──────────────────────────────────────────────────────
# Balungan (1 nada per ketukan), 4 frase x 8 ketukan.
BALUNGAN = [
    [A4, G4, F4, D4, F4, G4, A4, G4],
    [C5, A4, G4, A4, G4, F4, D4, F4],
    [A4, C5, D5, C5, A4, G4, F4, G4],
    [F4, G4, A4, C5, A4, G4, F4, D4],
]
# Bass per birama (4 ketukan): 2 birama per frase.
BASS_NADA = [(D2, G2), (A2, F2), (A2, G2), (F2, D2)]
# Kendang per birama, posisi 1/16 (0-15). Birama ke-2 tiap frase ada isian.
KENDANG_A = [(3, MUTE_HI_CONGA, 60), (6, OPEN_HI_CONGA, 70), (10, MUTE_HI_CONGA, 55), (11, MUTE_HI_CONGA, 60), (14, OPEN_HI_CONGA, 70)]
KENDANG_B = [(3, MUTE_HI_CONGA, 60), (6, OPEN_HI_CONGA, 70), (10, MUTE_HI_CONGA, 55), (13, HI_BONGO, 70), (14, LOW_BONGO, 75), (15, HI_BONGO, 80)]
# Suling (mode SEMANGAT): per birama, (posisi 1/8, nada, durasi 1/8).
SULING = [
    [(0, D5, 2), (2, F5, 1), (3, G5, 1), (4, A5, 3), (7, G5, 1)],
    [(0, F5, 2), (2, D5, 2), (4, C5, 2), (6, D5, 2)],
    [(0, A5, 2), (2, C6, 2), (4, D6, 3), (7, C6, 1)],
    [(0, A5, 2), (2, G5, 1), (3, F5, 1), (4, G5, 4)],
    [(0, D6, 2), (2, C6, 1), (3, A5, 1), (4, G5, 2), (6, A5, 2)],
    [(0, C6, 2), (2, A5, 2), (4, G5, 2), (6, F5, 2)],
    [(0, F5, 1), (1, G5, 1), (2, A5, 2), (4, C6, 2), (6, A5, 1), (7, G5, 1)],
    [(0, F5, 2), (2, G5, 2), (4, D5, 4)],
]


def tulis_dasar(lagu, mulai):
    """Satu putaran loop (32 ketukan) mulai dari ketukan `mulai`."""
    for f, frase in enumerate(BALUNGAN):
        awal = mulai + f * 8
        # Gong di awal frase, kempul di tengah.
        lagu.nada(0, D4, awal, 4, 80)
        lagu.nada(5, D2, awal, 2, 70)
        lagu.nada(0, A4 - 12, awal + 4, 2, 50)
        for i, n in enumerate(frase):
            k = awal + i
            lagu.nada(1, n, k, 0.9, 92 if i % 4 == 0 else 76)  # marimba (balungan)
            berikut = frase[(i + 1) % 8]
            lagu.nada(2, berikut + 12, k + 0.5, 0.45, 48)  # kalimba: nada berikut, satu oktaf naik
        for b, akar in enumerate(BASS_NADA[f]):
            kb = awal + b * 4
            lagu.nada(3, akar, kb, 1.8, 72)
            lagu.nada(3, akar, kb + 2, 1.4, 62)
            lagu.nada(3, akar + 12, kb + 3.5, 0.45, 50)
        for b in range(2):
            kb = awal + b * 4
            for k in range(4):
                # Denyut ketukan: conga rendah + bass drum. Ini panduan ritme utama.
                lagu.nada(DRUM, LOW_CONGA, kb + k, 0.4, 112 if k == 0 else 98)
                lagu.nada(DRUM, BASS_DRUM, kb + k, 0.3, 78 if k == 0 else 66)
                lagu.nada(DRUM, CABASA, kb + k + 0.5, 0.2, 42)
                if k in (1, 3):
                    lagu.nada(DRUM, WOODBLOCK, kb + k, 0.2, 50)
            for pos, note, vel in (KENDANG_B if b == 1 else KENDANG_A):
                lagu.nada(DRUM, note, kb + pos / 4, 0.2, vel)


def tulis_semangat(lagu, mulai):
    """Lapisan tambahan buat mode SEMANGAT (ditumpuk di atas dasar)."""
    for bar in range(8):
        kb = mulai + bar * 4
        for k in (0, 2):
            lagu.nada(4, D2, kb + k, 0.5, 105)  # taiko
        lagu.nada(4, D2, kb + 3.5, 0.4, 85)
        for s in range(16):
            if s % 2 == 1:
                lagu.nada(DRUM, MARACAS, kb + s / 4, 0.1, 34)
        for k in (1, 3):
            lagu.nada(DRUM, TAMBOURINE, kb + k, 0.2, 58)
        for pos, note, dur in SULING[bar]:
            lagu.nada(6, note, kb + pos / 2, dur / 2 * 0.95, 88)


def lagu_loop(semangat):
    lagu = Lagu()
    for ch, prog in ((0, TUBULAR), (1, MARIMBA), (2, KALIMBA), (3, BASS), (4, TAIKO), (5, TIMPANI), (6, PANFLUTE)):
        lagu.alat(ch, prog)
    for putaran in range(3):
        tulis_dasar(lagu, putaran * LOOP)
        if semangat:
            tulis_semangat(lagu, putaran * LOOP)
    return lagu


def lagu_menang():
    lagu = Lagu()
    for ch, prog in ((0, TUBULAR), (1, MARIMBA), (4, TAIKO), (5, TIMPANI), (6, PANFLUTE)):
        lagu.alat(ch, prog)
    naik = [D4, F4, G4, A4, C5, D5, F5, G5, A5, C6, D6]
    for i, n in enumerate(naik):
        lagu.nada(1, n, i * 0.25, 0.3, 70 + i * 3)
        lagu.nada(DRUM, LOW_CONGA if i % 2 == 0 else OPEN_HI_CONGA, i * 0.25, 0.2, 60 + i * 4)
    puncak = 3
    lagu.nada(6, D6, puncak, 4, 100)
    for n in (D5, A5):
        lagu.nada(1, n, puncak, 2, 100)
    lagu.nada(0, D4, puncak, 5, 95)
    lagu.nada(5, D2, puncak, 3, 90)
    for k in (puncak, puncak + 0.5, puncak + 1):
        lagu.nada(4, D2, k, 0.5, 110)
    lagu.nada(1, D5, puncak + 2, 1, 80)
    lagu.nada(1, A4, puncak + 2.5, 1, 75)
    lagu.nada(1, D4, puncak + 3, 2, 85)
    return lagu


# ── RENDER & BACA ──────────────────────────────────────────────────
def render(mid, wav):
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.5", "-r", str(RATE), "-F", wav, SF2, mid], check=True, stdout=subprocess.DEVNULL)


def baca(path):
    with wave.open(path, "rb") as w:
        assert w.getframerate() == RATE and w.getsampwidth() == 2
        n = w.getnchannels()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768
    return data.reshape(-1, n)


def tulis(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# ── TES RITME ──────────────────────────────────────────────────────
def amplop_serangan(x):
    """Kekuatan 'serangan' bunyi pita rendah (30-400 Hz: conga rendah, bass drum)
    per hop 16 sampel (0.36 ms). Pake energi linear: versi log bikin gaung
    pelan kebaca kayak pukulan."""
    mono = x.mean(axis=1)
    spek = np.fft.rfft(mono)
    f = np.fft.rfftfreq(len(mono), 1 / RATE)
    spek[(f < 30) | (f > 400)] = 0
    rendah = np.fft.irfft(spek, n=len(mono))
    hop, jendela = 16, 128
    energi = np.convolve(rendah**2, np.ones(jendela) / jendela, mode="same")[::hop]
    serangan = np.maximum(0, np.diff(energi, prepend=energi[0]))
    return serangan, hop


def ukur(x, jumlah_ketukan):
    serangan, hop = amplop_serangan(x)
    t = np.arange(len(serangan)) * hop / RATE
    selisih, kuat = [], []
    for k in range(jumlah_ketukan):
        pusat = k * KETUKAN
        m = (t >= pusat - 0.04) & (t <= pusat + 0.04)
        if not m.any():
            continue
        idx = np.where(m)[0]
        w = serangan[idx]
        i = idx[np.argmax(w >= 0.3 * w.max())]  # tepi depan: pertama kali lewat 30% puncak
        selisih.append(t[i] - pusat)
        kuat.append(w.max())
    selisih = np.array(selisih)
    # Pembanding: titik di tengah antara ketukan (1/8 sela) +- 40 ms.
    sela = []
    for k in range(jumlah_ketukan):
        pusat = k * KETUKAN + KETUKAN / 2
        m = (t >= pusat - 0.04) & (t <= pusat + 0.04)
        if m.any():
            sela.append(serangan[m].max())
    ketukan_idx = np.arange(len(selisih))
    kemiringan = np.polyfit(ketukan_idx, ketukan_idx * KETUKAN + selisih, 1)[0]
    return {
        "median_ms": float(np.median(selisih) * 1000),
        "maks_ms": float(np.max(np.abs(selisih - np.median(selisih))) * 1000),
        "tempo_detik": float(kemiringan),
        "rasio": float(np.mean(kuat) / (np.mean(sela) + 1e-9)),
    }


def klik_sambungan(loop):
    mono = loop.mean(axis=1)
    dua = np.concatenate([mono, mono])
    d = np.abs(np.diff(dua))
    n0 = len(mono)
    return float(d[n0 - 3 : n0 + 2].max()), float(np.percentile(d, 99.9))


def potong_loop(render_wav, nama, geser_tetap=None):
    x = baca(render_wav)
    panjang = LOOP * int(KETUKAN * RATE)
    if geser_tetap is not None:
        mulai = LOOP * int(KETUKAN * RATE) + geser_tetap
        loop = x[mulai : mulai + panjang]
        h = ukur(np.concatenate([loop, loop]), 2 * LOOP)
        print(f"  [{nama}] geser {geser_tetap:+d} sampel (sama kayak MUSIK), median {h['median_ms']:+.2f} ms, "
              f"maks {h['maks_ms']:.2f} ms, tempo {h['tempo_detik']:.5f} s/ketukan, rasio ketukan/sela {h['rasio']:.2f}")
        return loop, h, geser_tetap
    geser = 0
    for coba in range(1, 7):
        mulai = LOOP * int(KETUKAN * RATE) + geser
        loop = x[mulai : mulai + panjang]
        assert len(loop) == panjang, "render kependekan"
        h = ukur(np.concatenate([loop, loop]), 2 * LOOP)  # 2x biar ketukan di sambungan ikut dicek
        print(f"  [{nama}] percobaan {coba}: geser {geser:+d} sampel, median {h['median_ms']:+.2f} ms, "
              f"maks {h['maks_ms']:.2f} ms, tempo {h['tempo_detik']:.5f} s/ketukan, rasio ketukan/sela {h['rasio']:.2f}")
        if abs(h["median_ms"]) < 0.5:
            return loop, h, geser
        geser += int(round(h["median_ms"] / 1000 * RATE))
    raise SystemExit(f"[{nama}] median nggak mau < 0.5 ms setelah 6x")


def main():
    if not os.path.exists(SF2):
        sys.exit(f"Soundfont nggak ada di {SF2}. Install: apt-get install fluidsynth fluid-soundfont-gm")
    hasil = {}
    for nama, semangat in (("MUSIK", False), ("MUSIK_SEMANGAT", True)):
        mid = os.path.join(FOLDER, nama + ".mid")
        lagu_loop(semangat).simpan(mid, 3 * LOOP + 4)
        render(mid, SEMENTARA)
        geser_tetap = hasil["MUSIK"][2] if semangat else None
        loop, h, geser = potong_loop(SEMENTARA, nama, geser_tetap)
        hasil[nama] = (loop, h, geser)

    a = hasil["MUSIK"][0].mean(axis=1)
    b = hasil["MUSIK_SEMANGAT"][0].mean(axis=1)
    lags = range(-200, 201)
    korelasi = [float(np.dot(a[200:-200], np.roll(b, lag)[200:-200])) for lag in lags]
    lag_terbaik = list(lags)[int(np.argmax(korelasi))]
    print(f"  [MUSIK vs SEMANGAT] geser antar file: {lag_terbaik} sampel")

    # Volume disamain (gain sama) biar pas ganti ke SEMANGAT nggak loncat.
    puncak = max(np.abs(v[0]).max() for v in hasil.values())
    gain = 0.89 / puncak  # -1 dBFS
    gagal = []
    if lag_terbaik != 0:
        gagal.append(f"MUSIK vs SEMANGAT nggak sejajar ({lag_terbaik} sampel)")
    for nama, (loop, h, geser) in hasil.items():
        loop = loop * gain
        lompat, normal = klik_sambungan(loop)
        rms = 20 * np.log10(np.sqrt(np.mean(loop**2)) + 1e-12)
        print(f"  [{nama}] sambungan: lompatan {lompat:.4f} vs 99.9% sampel biasa {normal:.4f}, puncak {np.abs(loop).max():.3f}, RMS {rms:.1f} dBFS")
        if len(loop) != LOOP * int(KETUKAN * RATE):
            gagal.append(f"{nama}: panjang salah")
        if h["maks_ms"] > 10:
            gagal.append(f"{nama}: ada ketukan meleset {h['maks_ms']:.1f} ms")
        if abs(h["tempo_detik"] - KETUKAN) > 0.0005:
            gagal.append(f"{nama}: tempo {h['tempo_detik']:.5f}")
        if nama == "MUSIK_SEMANGAT" and abs(h["median_ms"]) > 6:
            gagal.append(f"{nama}: rata-rata ketukan geser {h['median_ms']:.1f} ms dari MUSIK")
        if h["rasio"] < 3:
            gagal.append(f"{nama}: ketukan kurang nonjol (rasio {h['rasio']:.2f})")
        if lompat > normal:
            gagal.append(f"{nama}: sambungan loop klik")
        if np.abs(loop).max() > 0.95:
            gagal.append(f"{nama}: clipping")
        tulis(os.path.join(FOLDER, nama + ".wav"), loop)

    # Musik menang: sekali main. Mulai pas di pukulan pertama, ekor di-fade.
    mid = os.path.join(FOLDER, "MENANG.mid")
    lagu_menang().simpan(mid, 12)
    render(mid, SEMENTARA)
    x = baca(SEMENTARA)
    mono = np.abs(x).max(axis=1)
    awal = max(0, int(np.argmax(mono > mono.max() * 0.02)) - int(0.005 * RATE))  # nada pertama (pelan) jangan kepotong
    x = x[awal : awal + int(6.5 * RATE)]
    fade = int(1.0 * RATE)
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    x *= 0.89 / np.abs(x).max()
    tulis(os.path.join(FOLDER, "MENANG.wav"), x)
    print(f"  [MENANG] {len(x) / RATE:.2f} detik, mulai dipotong {awal / RATE * 1000:.1f} ms")
    os.remove(SEMENTARA)

    if gagal:
        print("GAGAL:\n  " + "\n  ".join(gagal))
        sys.exit(1)
    print("SEMUA TES LOLOS")


if __name__ == "__main__":
    main()
