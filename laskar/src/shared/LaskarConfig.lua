-- Angka-angka prototipe "Laskar Kendang" (judul sementara). Dipake server & client.
-- ModuleScript di ReplicatedStorage.
--
-- Konsep: avatar Roblox lu = panglima. Lu mukul 4 kendang ngikutin ketukan,
-- 4 pukulan berturut-turut = 1 perintah buat pasukan. Abis perintah, pasukan
-- "jawab" 4 ketukan (jangan mukul di situ), terus lu boleh kasih perintah
-- berikutnya. Perintah nyambung terus = kombo, kombo tinggi = Semangat.
--
-- Semua isi game (kelas, musuh, stage) ada di tabel ini. Nambah kelas/musuh
-- baru = nambah baris, kodenya nggak usah diubah.

local C = {}

-- ── RITME ──────────────────────────────────────────────────────────
C.BPM = 120
C.KETUKAN = 60 / C.BPM -- detik per ketukan (0.5)
C.JENDELA_PERFECT = 0.07 -- selisih maksimal dari ketukan (detik) buat PERFECT
C.JENDELA_BAGUS = 0.15 -- lewat dari ini = MELESET
C.KOMBO_SEMANGAT = 5 -- perintah nyambung berturut-turut buat masuk Semangat

-- 4 kendang. tombol = keyboard, pad = gamepad. Warna dipake UI.
C.DRUM = {
	{ id = "DUNG", tombol = Enum.KeyCode.D, pad = Enum.KeyCode.ButtonA, warna = Color3.fromRGB(214, 96, 64) },
	{ id = "TAK", tombol = Enum.KeyCode.F, pad = Enum.KeyCode.ButtonX, warna = Color3.fromRGB(226, 178, 66) },
	{ id = "PAK", tombol = Enum.KeyCode.J, pad = Enum.KeyCode.ButtonY, warna = Color3.fromRGB(96, 168, 112) },
	{ id = "TUNG", tombol = Enum.KeyCode.K, pad = Enum.KeyCode.ButtonB, warna = Color3.fromRGB(88, 140, 214) },
}

-- Perintah = pola 4 pukulan. pengaliTerima = pengali damage yang diterima
-- pasukan selama 4 ketukan jawaban.
C.PERINTAH = {
	{ id = "Maju", pola = { "DUNG", "DUNG", "TAK", "TAK" }, teks = "MAJU!" },
	{ id = "Serang", pola = { "TAK", "DUNG", "TAK", "DUNG" }, teks = "SERANG!" },
	{ id = "Tahan", pola = { "PAK", "PAK", "DUNG", "DUNG" }, teks = "TAHAN!", pengaliTerima = 0.4 },
	{ id = "Mundur", pola = { "TUNG", "TUNG", "TAK", "TAK" }, teks = "MUNDUR!", pengaliTerima = 0.25, jarakMundur = 12 },
}

-- Ketukan ke berapa (1-4) dari jawaban pasukan yang dipake buat nyerang.
C.KETUKAN_SERANG = { 2, 4 }
C.KETUKAN_SERANG_SEMANGAT = { 1, 2, 4 }

C.SEMANGAT = {
	damage = 1.3, -- pengali damage
	langkah = 1.25, -- pengali jarak jalan
}
C.CRIT_KALI = 1.5

-- ── PASUKAN ────────────────────────────────────────────────────────
-- hp, atk, def, crit (peluang 0-1), jangkau (stud), kecepatan (stud/detik).
C.KELAS = {
	Panglima = { hp = 260, atk = 20, def = 4, crit = 0.15, jangkau = 7, kecepatan = 10 }, -- avatar player
	Perisai = { hp = 190, atk = 9, def = 7, crit = 0.05, jangkau = 5, kecepatan = 8 },
	Tombak = { hp = 110, atk = 16, def = 2, crit = 0.10, jangkau = 7, kecepatan = 9 },
	Panah = { hp = 75, atk = 12, def = 0, crit = 0.10, jangkau = 26, kecepatan = 9, panah = true },
}

-- Jarak maju per ketukan (sama buat semua, biar formasi nggak kepencar).
-- kecepatan di atas = kecepatan maksimal jalan; harus >= LANGKAH / KETUKAN.
C.LANGKAH_PER_KETUKAN = 4

-- Formasi tiap player. x = posisi relatif panglima (+ = di depan).
C.FORMASI = {
	{ kelas = "Perisai", x = 1.5 },
	{ kelas = "Tombak", x = -2.5 },
	{ kelas = "Tombak", x = -4.5 },
	{ kelas = "Panah", x = -8 },
	{ kelas = "Panah", x = -10 },
}

-- Warna baju pasukan per player (urut slot).
C.WARNA_PLAYER = {
	Color3.fromRGB(52, 92, 168),
	Color3.fromRGB(46, 130, 92),
	Color3.fromRGB(170, 120, 40),
	Color3.fromRGB(120, 70, 150),
	Color3.fromRGB(40, 130, 140),
	Color3.fromRGB(150, 80, 70),
}

-- ── MUSUH ──────────────────────────────────────────────────────────
-- jeda = detik antar serangan. lebar = jarak minimal pasukan bisa mepet.
C.MUSUH = {
	LawanTombak = { hp = 90, atk = 12, def = 1, crit = 0.05, jangkau = 6, jeda = 2.0, senjata = "Tombak", lebar = 1.8 },
	LawanPanah = { hp = 55, atk = 9, def = 0, crit = 0.05, jangkau = 24, jeda = 2.6, senjata = "Panah", panah = true, lebar = 1.8 },
	Benteng = { hp = 700, atk = 0, def = 3, crit = 0, jangkau = 0, jeda = 99, lebar = 3, benteng = true },
}

-- ── STAGE ──────────────────────────────────────────────────────────
-- Jalur lurus sepanjang sumbu X (maju = +X). Kamera dari samping (+Z).
C.ARENA = {
	mulaiX = 0,
	akhirX = 240,
	tanahY = 0.6, -- permukaan jalan tempat pasukan berdiri
}
C.GELOMBANG = {
	{ x = 55, musuh = { "LawanTombak", "LawanTombak" } },
	{ x = 100, musuh = { "LawanTombak", "LawanTombak", "LawanPanah" } },
	{ x = 150, musuh = { "LawanTombak", "LawanTombak", "LawanPanah", "LawanPanah" } },
	{ x = 205, musuh = { "LawanTombak", "LawanTombak", "LawanPanah" } },
}
C.BENTENG_X = 226
C.JEDA_ULANG_STAGE = 10 -- detik abis menang sebelum stage diulang

-- ── KAMERA ─────────────────────────────────────────────────────────
C.KAMERA = { jarak = 34, tinggi = 8, lihatDepan = 7, fov = 50 }

-- ── SUARA ──────────────────────────────────────────────────────────
-- Isi "rbxassetid://<id>" setelah upload file di laskar/assets/suara/.
-- Kosong = nggak bunyi (game tetep jalan, ketukan cuma keliatan di layar).
C.SUARA = {
	DUNG = "",
	TAK = "",
	PAK = "",
	TUNG = "",
	TIK = "", -- metronom (dipake kalau MUSIK kosong)
	MUSIK = "", -- loop musik latar
}
C.MUSIK_KETUKAN = 16 -- panjang loop musik dalam ketukan (harus pas sama file)

-- ── HELPER ─────────────────────────────────────────────────────────
function C.drum(id)
	for _, d in ipairs(C.DRUM) do
		if d.id == id then
			return d
		end
	end
	return nil
end

function C.perintah(id)
	for _, p in ipairs(C.PERINTAH) do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Urutan 4 pukulan -> perintah yang cocok (atau nil).
function C.cocokkan(urutan)
	for _, p in ipairs(C.PERINTAH) do
		local cocok = #urutan == #p.pola
		for i = 1, #p.pola do
			if urutan[i] ~= p.pola[i] then
				cocok = false
				break
			end
		end
		if cocok then
			return p
		end
	end
	return nil
end

return C
