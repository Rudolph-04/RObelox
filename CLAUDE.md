# Aturan kerja (Juragan Tahu)

## Git
- **Sebelum mulai kerja: `git pull` dulu.** Ada AI lain yang kadang push ke repo ini.
- **Abis selesai 1 tugas: langsung commit + push**, jangan ditumpuk jadi satu commit gede.

## Studio
- File di repo (`src/`, `tools/`) = sumber utama. Tiap ubah script, update juga di
  Roblox Studio lewat Roblox Studio MCP biar dua-duanya sama, terus commit + push.
- Rojo nggak dipake dulu (nggak usah dibenerin).
- Template kendaraan disimpen di file place, bukan di git: abis rebuild template,
  ingetin buat save place di Studio (Ctrl+S).

## Hemat kuota & aturan konten
- Ubahan visual: jangan playtest, cukup screenshot viewport mode Edit sekali di
  akhir. Ubahan logic: playtest 1x di akhir aja.
- Kalau 2x gagal, berhenti & jelasin ke user, jangan coba-coba terus.
- Jangan pake logo/merek asli (Viar, Gojek, Grab, dll).
- Jangan nyalain HttpService/LoadStringEnabled tanpa izin.

## Project kedua: `laskar/` (prototipe Laskar Kendang)
- Place Studio-nya **terpisah** dari Juragan Tahu. Jangan sync file `laskar/`
  ke place Juragan Tahu, dan sebaliknya.
- Mapping file ke Studio + cara setup ada di `laskar/README.md`.
- Jangan pake nama/istilah Patapon (Pata, Pon, Chaka, Don, nama kelas, desain
  makhluk bermata satu): itu hak cipta Sony.
