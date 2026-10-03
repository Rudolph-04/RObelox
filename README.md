# Juragan Tahu (Roblox)

Game jualan tahu goreng. Mulai dari 1 gerobak kecil di pasar, bangun usaha
sampe punya banyak cabang. Di-develop pake [Rojo](https://rojo.space) biar
kode Luau-nya ke-track di git, bisa diedit di editor biasa (bukan copy-paste
manual ke Command Bar tiap ada perubahan).

> Sebelumnya project ini "Brainrot Fishing" (ocean + island fishing game).
> Kode lama itu masih ada di git history branch ini kalau suatu saat mau
> diliat lagi, tapi udah nggak aktif — project ini sekarang full ganti arah.

## Kenapa beda dari game "tahu bulat" yang udah ada

Sengaja dijauhin dari ciri khas genre yang udah terkenal: mekanik
tap-untuk-jualan, konsep keliling naik mobil pickup, susunan upgrade mereka,
sama jingle "digoreng dadakan". Jingle sendiri nanti dibikin.

## Konsep inti

1. **Goreng betulan, bukan tap.** Tahu dimasukin ke wajan, ada indikator
   kematangan (mentah → pas → gosong). Angkat tepat di zona "pas" → pembeli
   kasih tip. Unsur skill, bukan spam klik.
2. **Pembeli punya karakter.** Anak sekolah (cepat, murah), ibu-ibu (beli
   banyak, sabar), ojol (buru-buru). Masing-masing punya batas sabar — harus
   diatur antreannya.
3. **Satu shift = satu hari jualan** (~5-8 menit), ditutup rangkuman
   pendapatan. Titik berhenti alami buat sesi main, dan ini juga pas sama
   cara kerja algoritma discovery Roblox sekarang: Roblox ranking lebih
   ngutamain "return behavior" (balik lagi sesi berikutnya) dibanding durasi
   main sekali duduk, dan recommendation benefit dibatesin ke 60 menit
   pertama per hari per game. Jadi shift pendek + ajakan "balik besok" itu
   emang strategi yang align sama algoritma, bukan sekadar gaya-gayaan.
4. **Rebirth = "Buka Cabang".** Uang & upgrade reset, tapi pindah lokasi baru
   yang beda suasana: Pasar → Depan Sekolah → Terminal → Alun-alun malam.
   Tiap lokasi punya tipe pembeli & tantangan sendiri (misal: terminal ada
   jam sibuk bikin antrean membeludak). Yang tetap dibawa: **Reputasi**,
   yang buka resep baru (pedas, keju, isi) — jadi rebirth berasa progress,
   bukan cuma angka dikali.
5. **Co-op** (satu goreng, satu layani) — fitur belakangan, bukan prioritas
   awal.

## Status sekarang

**Step 1 selesai: lokasi Pasar + mekanik goreng.**

- Area "Pasar" graybox: gerobak tahu (meja, kompor, wajan, etalase, atap
  belang), 2 lapak tetangga, spawn di sisi tukang goreng.
- Goreng: deketin wajan, tekan **E** (ProximityPrompt) → bar kematangan
  jalan 8 detik: Mentah → Oke → **Perfect** → Oke → Gosong. Tekan **E** /
  klik **ANGKAT!** buat ngangkat. Kalau dibiarin, otomatis keangkat gosong.
- Hasil selalu laku (nggak ada gagal total), reward sementara ke
  `leaderstats.Uang`: Mentah Rp 1.000, Oke Rp 2.000, Perfect Rp 2.000 + tip
  Rp 1.000, Gosong Rp 500.
- Server-authoritative: waktu mulai dicatat server, kualitas dihitung
  server. Client cuma ngirim "angkat" + jam klik, yang cuma diterima kalau
  mundurnya ≤ 0.3 detik (kompensasi lag, bukan celah curang).
- Belum ada: pembeli/antrean, shift, rebirth, lokasi lain, DataStore.

## Rencana urutan build (biar nggak kewalahan)

Scope lengkap di atas itu GEDE — minigame goreng, AI pembeli+antrean, sistem
shift+timer+summary, 4 lokasi beda, sistem reputasi+resep, baru co-op. Kalau
digarap sekaligus gampang keteteran. Urutan yang disaranin:

1. **Lokasi pertama (Pasar) + mekanik goreng doang.** Satu wajan, satu
   indikator kematangan, satu jenis pembeli dulu (belum perlu 3 karakter).
   Target: bisa goreng-angkat-dapet tip, itu aja dulu.
2. Nambah karakter pembeli + antrean (baru 2-3 tipe + sabar).
3. Sistem shift (timer + summary akhir hari).
4. Rebirth/buka cabang + lokasi ke-2 dst.
5. Reputasi + resep baru.
6. Co-op (paling akhir).

## Struktur project

```
default.project.json   -> config Rojo, nentuin file mana masuk ke mana di Studio
rokit.toml              -> pin versi Rojo (rokit = toolchain manager resmi Rojo)
src/shared/              -> masuk ke ReplicatedStorage (dipake server & client)
  Remotes.lua              -> RemoteEvent FryStarted / LiftTahu / FryResult
  FryConfig.lua            -> durasi goreng, batas zona, reward, warna tahu
src/server/              -> masuk ke ServerScriptService
  Leaderstats.server.lua   -> "Uang" per player (BELUM ada DataStore)
  FryService.server.lua    -> logika goreng (server yang nentuin hasil)
src/client/               -> masuk ke StarterPlayer.StarterPlayerScripts
  FryController.client.lua -> UI bar kematangan, tombol angkat, feedback hasil
tools/                    -> BUKAN bagian game, script bantu buat Studio
  BuildPasar.luau          -> bangun area Pasar + gerobak + wajan (sekali jalan)
```

### Soal map (Workspace)

Rojo cuma nge-sync script, bukan part/map. Map Pasar dibangun pake
`tools/BuildPasar.luau`: jalanin sekali di Command Bar Studio (mode Edit),
terus **Save place** (Ctrl+S). Gameplay nyari wajan lewat tag
CollectionService `"Wajan"`, jadi gerobak/dekorasi bebas digeser/diubah
manual di Studio tanpa ngerusak script.

## Setup sekali di awal

1. **Install Rokit** (toolchain manager resmi buat Rojo) — ikutin instruksi
   di [github.com/rojo-rbx/rokit](https://github.com/rojo-rbx/rokit).
2. Di folder project ini, jalanin:
   ```
   rokit install
   ```
3. Di Roblox Studio, install plugin **Rojo** dari Plugin Marketplace.

## Tiap mau ngoding

1. `rojo serve` di folder project.
2. Buka Studio, buka plugin Rojo, **Connect**, lalu **Sync In**.
3. Edit file di `src/` lewat editor/Claude — Studio yang lagi konek
   auto-update, nggak perlu copy-paste manual.

Atau, kalau pake **Roblox Studio MCP + Claude Code lokal** (udah pernah
disetup), bisa langsung minta Claude Code lokal baca/edit/eksekusi di
Studio secara real-time tanpa Rojo sama sekali.
