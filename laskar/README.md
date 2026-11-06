# Laskar Kendang (prototipe)

Judul sementara. Game ritme + strategi ala Patapon 3, tapi tema dan tampilannya
sendiri: avatar Roblox lu jadi **panglima**, lu mukul **4 kendang** ngikutin
ketukan, dan susunan pukulan jadi perintah buat pasukan kecil lu.

Tujuan prototipe ini cuma satu: **ngetes mukul kendang di Roblox kerasa enak
atau nggak.** Belum ada level/stat tree/loot.

Status (2026-11-07): udah kepasang & dites di Studio. Stage kebangun, MAJU
berhenti pas di depan musuh, SERANG ngebunuh musuh, kombo naik 1-2-3-4.
Belum dites: rasa mukul pake tangan (butuh suara diupload dulu).

## Cara main

| Tombol | Fungsi |
|---|---|
| D F J K | kendang DUNG, TAK, PAK, TUNG (HP: pencet pad di bawah) |
| H | buka/tutup daftar perintah |
| C | ganti kamera samping / kamera bebas |
| [ ] | kalibrasi -10 / +10 ms (kalau pukulan selalu kerasa telat/kecepetan) |

| Perintah | Pola | Efek |
|---|---|---|
| MAJU | DUNG DUNG TAK TAK | pasukan jalan ke depan |
| SERANG | TAK DUNG TAK DUNG | deketin musuh terdekat & nyerang |
| TAHAN | PAK PAK DUNG DUNG | damage yang diterima x0.4 |
| MUNDUR | TUNG TUNG TAK TAK | mundur 12 stud, damage diterima x0.25 |

Alur ritme (120 BPM, 1 ketukan = 0.5 detik):
1. Pukul 4 kendang di 4 ketukan berturut-turut. Tiap pukulan dinilai
   PERFECT (selisih <= 70 ms) / BAGUS (<= 150 ms) / MELESET.
2. Pola cocok -> pasukan "jawab" 4 ketukan (slot berubah jadi teks perintah).
   **Jangan mukul di 4 ketukan ini** (KACAU, kombo putus).
3. Perintah berikutnya mulai pas di ketukan sesudahnya -> kombo nyambung.
   Kombo 5 = **SEMANGAT**: damage x1.3, langkah x1.25, nyerang 3x per perintah.

Stage: jalur lurus, 4 gelombang musuh, benteng di ujung. Benteng ancur = menang,
stage diulang 10 detik kemudian. Semua prajurit gugur = pasukan mulai lagi
dari awal. Bisa co-op: tiap player punya pasukan sendiri di jalurnya.

## Setup di Studio (buat local session)

Bikin place **baru**, jangan di place Juragan Tahu.

1. Studio: File > New > Baseplate. Di Explorer hapus `Baseplate` dan
   `SpawnLocation` bawaan. Save sebagai "Laskar Kendang".
2. Game Settings > Avatar > set **R15** (animasi tangan cuma jalan di R15).
   Kalau Game Settings minta publish dulu, publish private aja.
3. Bikin script sesuai tabel (isi = isi file di repo, nama persis sama):

| File di repo | Tempat di Studio | Jenis |
|---|---|---|
| `laskar/src/shared/LaskarConfig.lua` | ReplicatedStorage > `LaskarConfig` | ModuleScript |
| `laskar/src/shared/LaskarRemotes.lua` | ReplicatedStorage > `LaskarRemotes` | ModuleScript |
| `laskar/src/server/LaskarServer.server.lua` | ServerScriptService > `LaskarServer` | Script |
| `laskar/src/server/Bentuk.lua` | ServerScriptService > `Bentuk` | ModuleScript |
| `laskar/src/server/Arena.lua` | ServerScriptService > `Arena` | ModuleScript |
| `laskar/src/client/LaskarClient.client.lua` | StarterPlayer > StarterPlayerScripts > `LaskarClient` | LocalScript |
| `laskar/src/client/LaskarUI.lua` | StarterPlayer > StarterPlayerScripts > `LaskarUI` | ModuleScript |
| `laskar/src/client/LaskarEfek.lua` | StarterPlayer > StarterPlayerScripts > `LaskarEfek` | ModuleScript |
| `laskar/src/client/LaskarLatar.lua` | StarterPlayer > StarterPlayerScripts > `LaskarLatar` | ModuleScript |

4. Stage dibangun sendiri pas Play (nggak ada builder yang perlu dijalanin).
5. Playtest **sekali**: Play, coba MAJU sama SERANG sampai ketemu musuh
   pertama. Screenshot + laporin semua error/warning di Output.

## Suara & musik

Semua dibikin sendiri, bebas hak cipta:

| File | Isi | Dibikin oleh |
|---|---|---|
| `assets/suara/DUNG/TAK/PAK/TUNG.wav` | bunyi 4 kendang pas lu mukul | `assets/bikin_suara.py` (sintesis) |
| `assets/suara/TIK.wav` | metronom (cuma dipake kalau MUSIK kosong) | `assets/bikin_suara.py` |
| `assets/musik/MUSIK.wav` | loop stage, 32 ketukan = 16 detik | `assets/musik/bikin_musik.py` |
| `assets/musik/MUSIK_SEMANGAT.wav` | loop yang sama + suling, taiko, kocokan | `assets/musik/bikin_musik.py` |
| `assets/musik/MENANG.wav` | 6.5 detik pas benteng ancur | `assets/musik/bikin_musik.py` |

Musik ditulis sebagai MIDI (`assets/musik/*.mid`, bisa dibuka di BandLab/LMMS
buat ganti alat musik) terus dirender pakai soundfont FluidR3_GM (Frank Wen,
lisensi MIT). Nuansanya pentatonis ala gamelan, tapi alatnya marimba, kalimba,
conga, taiko, suling pan (General MIDI nggak punya gamelan asli).

`bikin_musik.py` ngetes sendiri dan baru nyimpen kalau semua lolos:
ketukan rata-rata geser 0.09 ms dari jam game (maks 0.9 ms), tempo pas
0.5 detik/ketukan, sambungan loop nggak klik, MUSIK & MUSIK_SEMANGAT sejajar
0 sampel. Yang **nggak** bisa dites program: enak didenger atau nggak.

Di game: MUSIK & MUSIK_SEMANGAT jalan barengan dan disinkronin ke jam ketukan
tiap detik; pas SEMANGAT nyala/mati, volumenya gantian (fade 0.4 detik).
Pas menang, loop diredam & MENANG diputer.

Cara pasang:
1. Upload 8 file di atas (Studio: View > Asset Manager > Import, atau Creator
   Dashboard > Audio). Upload audio butuh akun lu sendiri, ada batas per bulan.
2. Copy ID-nya ke `LaskarConfig.SUARA`, formatnya `"rbxassetid://123456"`.
3. Tanpa suara game tetep jalan, tapi ritmenya susah dirasain. Minimal upload
   4 kendang + MUSIK.

## Belum ada (rencana v0.2)

- Level & pohon kelas (kelas turunan kebuka dari level kelas lain)
- Stat lengkap + rumus damage dari tabel (rancang dulu di Excel/Sheets)
- Peti per stage + tingkat kelangkaan perlengkapan
- Musuh yang jalan/ngejar, bos
- Animasi pukul kendang buat player lain (sekarang cuma keliatan di layar sendiri)

## Risiko yang udah ketauan

- Udah kebukti: prajurit gerak lewat `Akar.CFrame` (part lain ikut lewat
  WeldConstraint). Belum dicek mata: `Motor6D.Transform` di `RunService.Stepped`
  beneran nimpa animasi bawaan (gerak tangan pas mukul).
- Kontrol jalan dimatiin lewat `DevComputerMovementMode = Scriptable` di
  server. `PlayerModule` sekarang ada di `StarterPlayer`, bukan
  `PlayerScripts`, jadi `GetControls():Disable()` nggak bisa dipake lagi.
- Error `rbxassetid://203785492 ... Asset type does not match` di Output
  bukan dari game ini (nggak ada di place/repo), aman diabaikan.
- Timing dinilai di client. Buat PvE aman, buat PvP nanti harus dipikir ulang.
- Avatar R6 nggak dapet animasi tangan.
