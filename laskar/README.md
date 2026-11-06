# Laskar Kendang (prototipe)

Judul sementara. Game ritme + strategi ala Patapon 3, tapi tema dan tampilannya
sendiri: avatar Roblox lu jadi **panglima**, lu mukul **4 kendang** ngikutin
ketukan, dan susunan pukulan jadi perintah buat pasukan kecil lu.

Tujuan prototipe ini cuma satu: **ngetes mukul kendang di Roblox kerasa enak
atau nggak.** Belum ada level/stat tree/loot.

Status: kode udah lolos compile Luau, **belum pernah dites di Studio**.

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

4. Stage dibangun sendiri pas Play (nggak ada builder yang perlu dijalanin).
5. Playtest **sekali**: Play, coba MAJU sama SERANG sampai ketemu musuh
   pertama. Screenshot + laporin semua error/warning di Output.

## Suara

File ada di `laskar/assets/suara/` (dibikin `laskar/assets/bikin_suara.py`,
sintesis sendiri, bebas hak cipta). Tanpa suara game tetep jalan, ketukan cuma
keliatan dari kedipan kotak slot, dan itu bikin susah ngerasain ritmenya.

1. Studio: View > Asset Manager > Import (atau Creator Dashboard > Audio),
   upload `DUNG.wav`, `TAK.wav`, `PAK.wav`, `TUNG.wav`, `TIK.wav`, `MUSIK.wav`.
   Upload audio butuh akun lu sendiri (ada batas jumlah upload per bulan).
2. Copy ID tiap file ke `LaskarConfig.SUARA`, formatnya `"rbxassetid://123456"`.
3. `MUSIK.wav` = loop 16 ketukan (8 detik). Kalau MUSIK diisi, metronom TIK
   nggak dipake.

## Belum ada (rencana v0.2)

- Level & pohon kelas (kelas turunan kebuka dari level kelas lain)
- Stat lengkap + rumus damage dari tabel (rancang dulu di Excel/Sheets)
- Peti per stage + tingkat kelangkaan perlengkapan
- Musuh yang jalan/ngejar, bos
- Animasi pukul kendang buat player lain (sekarang cuma keliatan di layar sendiri)

## Risiko yang udah ketauan

- Belum dites. Asumsi yang belum kebukti: prajurit digerakin lewat
  `Akar.CFrame` (part lain ikut lewat WeldConstraint), dan `Motor6D.Transform`
  yang diset di `RunService.Stepped` beneran nimpa animasi bawaan.
- Timing dinilai di client. Buat PvE aman, buat PvP nanti harus dipikir ulang.
- Avatar R6 nggak dapet animasi tangan.
