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
tap-untuk-jualan, konsep keliling jualan di mana aja naik mobil pickup,
susunan upgrade mereka, sama jingle "digoreng dadakan". Jingle sendiri nanti
dibikin.

Kendaraan dagangan (Viar dulu, nanti nambah lewat upgrade) emang bisa
dikendarai, tapi **cuma bisa goreng kalau diparkir di titik jualan** sebuah
lokasi (Pasar sekarang, nanti cabang-cabang lain). Jadi pembedanya tetep
konsep lokasi/cabang, bukan keliling.

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

**Step 1 selesai: lokasi Pasar + mekanik goreng + kendaraan dagangan (gerobak motor).**

- Map kota graybox (map mancing lama udah disapu bersih): jalan raya +
  trotoar + lampu jalan, deretan ruko, rumah, pohon, batas kota.
  - **Pasar** (bisa dimainin): gapura, **TITIK JUALAN** (6 petak parkir
    kendaraan), 6 lapak tetangga, spawn deket titik jualan.
- **Kendaraan dagangan**: tombol **KENDARAAN** di kiri layar → pilih →
  **Keluarin** (muncul di petak parkir kosong terdeket; keluarin lagi =
  diganti baru, sekalian buat yang nyangkut). Sekarang baru **Gerobak
  Motor**: motor roda tiga + box jualan "TAHU JURAGAN" di belakang (tanpa
  logo/merek asli; id internalnya masih `Viar`).
  - Motor depan: tangki bensin, jok, stang + 2 spion, lampu bulat, shock
    depan keliatan, pijakan kaki. Tangan avatar megang stang (IKControl).
  - Box (tempat stok + etalase): rangka aluminium, atap kabin melengkung di
    atas pengendara, papan nama "TAHU JURAGAN" di atas (satu-satunya),
    pintu belakang, sepatbor + karet lumpur, lampu + plat. Dalemnya counter,
    etalase kaca, tirisan, baskom tahu mentah, stok, lampu TL.
  - **Buka Lapak** (otomatis pas kendaraan diem di TITIK JUALAN tanpa supir):
    panel samping kiri keangkat jadi peneduh (TweenService, disangga 2
    piston), terus di sisi luar muncul **meja goreng** setinggi pinggang
    (kompor + wajan, api keliatan, tabung gas di tanah) + **bangku plastik**
    di tanah. Lapak luar ini anchored & nggak di-weld ke kendaraan;
    kendaraannya dikunci selama lapak buka. Depan meja & etalase dikosongin
    buat pembeli nanti.
  - **Tutup Lapak**: pencet **F** (naik) → meja + bangku ilang, panel nutup,
    baru duduk di jok. Nggak bisa selama lagi goreng.
  - Nyetir: W/S gas/mundur, A/D belok, Spasi turun (HP: stik + tombol
    lompat). Selalu tegak, nggak bisa kebalik.
  - Goreng (**E** di wajan) sambil **berdiri** di samping meja atau **duduk**
    di bangku (**G**). Prompt cuma muncul pas relevan: F (jarak 6) mati
    selama nyetir/goreng/duduk jualan; G (jarak 5, harus keliatan langsung)
    & E (jarak 5) cuma ada pas lapak buka.
  - Cuma pemiliknya yang bisa naik/duduk/goreng di kendaraannya.
  - **Depan Sekolah, Terminal, Alun-alun**: plot cabang yang masih
    terkunci (gerbang/palang ditutup + papan "Segera dibuka"), disiapin
    buat Step 4 (Buka Cabang).
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
  Remotes.lua              -> RemoteEvent goreng + SpawnKendaraan / InfoKendaraan
  FryConfig.lua            -> durasi goreng, batas zona, reward, warna tahu
  KendaraanConfig.lua      -> daftar kendaraan dagangan + angka nyetirnya
src/server/              -> masuk ke ServerScriptService
  Leaderstats.server.lua   -> "Uang" per player (BELUM ada DataStore)
  FryService.server.lua    -> logika goreng (server yang nentuin hasil)
  KendaraanService.server.lua -> spawn kendaraan, siapa boleh naik, boleh jualan di mana
src/client/               -> masuk ke StarterPlayer.StarterPlayerScripts
  FryController.client.lua -> UI bar kematangan, tombol angkat, feedback hasil
  KendaraanController.client.lua -> nyetir, animasi roda/setir/tangan/panel, petunjuk di layar
  KendaraanMenu.client.lua -> tombol KENDARAAN + menu keluarin kendaraan
tools/                    -> masuk ke ServerStorage.Tools; BUKAN script game,
                             builder buat Studio (jalan di mode Edit)
  Jalankan.luau            -> runner: require(game.ServerStorage.Tools.Jalankan)("Kendaraan/Viar")
  Bantu.luau               -> helper bareng (part, silinder, pipa, CSG, tulisan)
  CekTumpuk.luau           -> cari permukaan numpuk (z-fighting / kedip-kedip)
  BuildKota.luau           -> bangun map kota + Pasar + plot cabang (sekali jalan)
  Kendaraan/
    Viar/                  -> gerobak motor -> ServerStorage.Kendaraan.Viar
      init.luau              -> rakit semua bagian + collider
      Dasar.luau             -> ukuran bareng + helper
      Motor.luau, Bak.luau, Box.luau, Lapak.luau -> per bagian
      LapakLuar.luau         -> meja goreng + bangku -> ServerStorage.Kendaraan.ViarLapak
    Wajan.luau, Roda.luau  -> bagian yang dipake ulang semua kendaraan
    Rig.luau               -> jadiin model kendaraan bisa jalan (fisika, sambungan)
```

### Soal map & template (Workspace / ServerStorage)

Rojo cuma nge-sync script, bukan part/map. Map & template kendaraan dibangun
pake builder di `tools/`, dijalanin dari Command Bar Studio (mode Edit), terus
**Save place** (Ctrl+S):

- Map kota: `tools/BuildKota.luau` di place yang Workspace-nya kosong →
  `Workspace.Kota` + terrain. Catatan: permukaan smooth terrain jadinya ~2
  stud di atas batas isian, makanya terrain diisi sampe y = -2.
- Kendaraan: `require(game.ServerStorage.Tools.Jalankan)("Kendaraan/Viar")`
  → `ServerStorage.Kendaraan.Viar`. Kendaraan baru = builder baru di
  `tools/Kendaraan/` (pake Wajan/Roda/Rig) + entri di `KendaraanConfig`.
  Abis ngubah model, cek kedip-kedip:
  `print(require(game.ServerStorage.Tools.CekTumpuk)(game.ServerStorage.Kendaraan.Viar))`.

Gameplay nyari semuanya lewat tag CollectionService (`"Wajan"`,
`"TitikJualan"`, `"ParkirKendaraan"`), jadi dekorasi bebas digeser/diubah
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
