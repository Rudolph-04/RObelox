# Brainrot Fishing (Roblox)

Project fishing game, di-develop pake [Rojo](https://rojo.space) biar kode
Luau-nya ke-track di git dan bisa di-edit di editor biasa, bukan copy-paste
manual ke Command Bar tiap kali ada perubahan.

## Struktur

```
default.project.json   -> config Rojo, nentuin file mana masuk ke mana di Studio
rokit.toml              -> pin versi Rojo (rokit = toolchain manager resmi Rojo)
src/shared/              -> masuk ke ReplicatedStorage (dipake server & client)
  Remotes.lua             -> bikin/ambil RemoteEvent (CastRod, CatchResult)
  FishData.lua             -> daftar ikan + rarity + value
src/server/              -> masuk ke ServerScriptService
  TerrainBuilder.server.lua -> generate ocean + island (SEKALI doang, ada guard)
  Leaderstats.server.lua    -> setup "Coins" per player (BELUM ada DataStore)
  RodSetup.server.lua       -> bikin Tool "FishingRod" masuk StarterPack
  FishingService.server.lua -> logika cast -> roll ikan -> kasih coins
src/client/               -> masuk ke StarterPlayer.StarterPlayerScripts
  FishingController.client.lua -> deteksi klik joran, print hasil tangkapan
```

## Setup sekali di awal

1. **Install Rokit** (toolchain manager resmi buat Rojo) — ikutin instruksi
   di [github.com/rojo-rbx/rokit](https://github.com/rojo-rbx/rokit).
2. Di folder project ini, jalanin:
   ```
   rokit install
   ```
   Ini bakal install Rojo versi yang di-pin di `rokit.toml` (7.7.0).
3. Di Roblox Studio, install plugin **Rojo** dari Plugin Marketplace
   (cari "Rojo" — punya `rojo-rbx`).

## Tiap mau ngoding

1. Jalanin di terminal, di folder project ini:
   ```
   rojo serve
   ```
2. Buka Studio, buka place kosong (atau place lama lu), buka panel plugin
   Rojo, klik **Connect**.
3. Klik **Sync In** — semua file di `src/` bakal muncul jadi Script/ModuleScript
   di Explorer, sesuai mapping di `default.project.json`.
4. Tekan **Play**. Pas pertama kali, `TerrainBuilder` bakal jalan bikin
   ocean + island (agak lama, tunggu aja, cek Output buat progress log-nya).
5. Kalau udah puas sama hasil terrain-nya: **Stop** play test, terus
   **File > Save** place-nya. Terrain kesimpen di file `.rbxl` (Rojo nggak
   nge-sync data terrain, cuma script — jadi ini langkah manual, sekali aja).
6. Selanjutnya tiap lu edit file di `src/` (via editor/Claude), Studio yang
   lagi konek bakal auto-update. Nggak perlu copy-paste manual lagi.

## Yang udah jalan

- Ocean + island digenerate otomatis, ukuran udah dikecilin (1200 studs,
  dulunya 4000 — kegedean, bisa bikin Studio ngefreeze lama).
- Alur cast -> tunggu -> dapet ikan acak (weighted) -> coins masuk
  leaderstats, semua logic di server (aman dari exploit client-side).
- Tool "FishingRod" otomatis ada di Backpack tiap player spawn.

## Yang BELUM ada (next steps, jujur biar jelas)

- **DataStore** — coins reset tiap player leave/rejoin. Ini prioritas
  paling penting sebelum publish ke publik.
- **UI beneran** — catch result masih cuma `print()` ke Output, belum ada
  popup/animasi di layar.
- **Shop / upgrade** — marker lokasi udah ada di map, tapi belum ada NPC
  atau GUI buat beli upgrade rod.
- **Anti-exploit tambahan** — rate limit `CastRod` masih basic (cuma cek
  "lagi casting apa nggak"), belum ada validasi jarak ke air / debounce
  per-detik yang lebih ketat.

Kalau mau lanjut ke salah satu dari ini, tinggal bilang aja.
