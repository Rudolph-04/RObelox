-- Angka-angka NPC warga & pembeli (dipake PembeliService + Antrean di server).
-- Koordinat = dunia, ngikutin layout tools/BuildKota.luau (Pasar di z -60,
-- pintu masuk/gapura di z -21, trotoar selatan z -18..-12).

local PembeliConfig = {}

PembeliConfig.MAX_WARGA = 8 -- jumlah NPC jalan-jalan di pasar
PembeliConfig.MAX_ANTRE = 4 -- slot antrean per lapak
PembeliConfig.STOK_MAX = 6 -- tahu yang bisa disimpen di etalase kalau belum ada pembeli

-- Peluang warga yang lagi jalan-jalan mutusin beli (dicek tiap abis jalan 1 putaran).
PembeliConfig.PELUANG_BELI = 0.35
PembeliConfig.JARAK_TERTARIK = 70 -- cuma lapak sedeket ini yang bikin pengen beli

-- Area jalan-jalan (persegi di lantai pasar, antara titik jualan & gapura).
PembeliConfig.AREA_JALAN = { minX = -34, maxX = 34, minZ = -36, maxZ = -25, y = 0.4 }
-- Lewat gapura buat masuk/keluar pasar, terus ke trotoar.
PembeliConfig.GAPURA = { minX = -8, maxX = 8, z = -24 }
PembeliConfig.TROTOAR = { minX = -55, maxX = 55, z = -15, y = 0.6 }
PembeliConfig.PUTARAN_SEBELUM_PULANG = { 4, 9 } -- abis segini kali jalan-jalan, pulang

-- Slot antrean, relatif ke pivot lapak (tanah di tengah kendaraan; -X = sisi
-- lapak luar/pembeli, +Z = arah belakang kendaraan). Slot 1 ngadep meja.
PembeliConfig.SLOT_X = -8.0
PembeliConfig.SLOT_Z1 = 3.8
PembeliConfig.SLOT_JARAK = 2.2
PembeliConfig.MASUK_ANTRE_Z = 11 -- titik ngumpul di belakang kendaraan sebelum masuk antrean

-- Kulit (dipilih acak).
PembeliConfig.KULIT = {
	Color3.fromRGB(234, 192, 145),
	Color3.fromRGB(205, 155, 110),
	Color3.fromRGB(170, 120, 80),
	Color3.fromRGB(135, 92, 62),
}

-- Tipe pembeli. sabar = detik nunggu di antrean. porsi = {min, max}.
-- harga = pengali bayaran dari FryConfig.RESULTS. Tanpa logo/merek.
PembeliConfig.TIPE = {
	{
		id = "AnakSekolah",
		bobot = 3,
		kecepatan = 13,
		sabar = 30,
		porsi = { 1, 1 },
		harga = 0.8, -- minta murah
		baju = { Color3.fromRGB(245, 245, 240) }, -- kemeja putih
		celana = { Color3.fromRGB(170, 35, 40), Color3.fromRGB(40, 60, 120), Color3.fromRGB(110, 115, 120) },
		tas = true,
	},
	{
		id = "IbuIbu",
		bobot = 3,
		kecepatan = 9,
		sabar = 60,
		porsi = { 2, 3 },
		harga = 1,
		baju = { Color3.fromRGB(150, 60, 120), Color3.fromRGB(60, 120, 110), Color3.fromRGB(190, 120, 60) }, -- daster
		celana = { Color3.fromRGB(80, 60, 90), Color3.fromRGB(60, 70, 60) },
	},
	{
		id = "Ojol",
		bobot = 2,
		kecepatan = 14,
		sabar = 20,
		porsi = { 1, 2 },
		harga = 1,
		baju = { Color3.fromRGB(55, 80, 60), Color3.fromRGB(45, 45, 50) }, -- jaket polos
		celana = { Color3.fromRGB(35, 35, 40) },
		helm = { Color3.fromRGB(30, 30, 35), Color3.fromRGB(200, 200, 200) },
	},
	{
		id = "Bapak",
		bobot = 2,
		kecepatan = 11,
		sabar = 40,
		porsi = { 1, 2 },
		harga = 1,
		baju = { Color3.fromRGB(120, 140, 170), Color3.fromRGB(150, 110, 80), Color3.fromRGB(90, 90, 95) },
		celana = { Color3.fromRGB(60, 55, 50), Color3.fromRGB(40, 45, 60) },
	},
}

-- Kalimat pendek di atas kepala (muncul sebentar doang).
PembeliConfig.KATA = {
	pesan = { "Tahu %d ya!", "Beli %d, Bang!", "%d bungkus!" },
	puas = { "Makasih!", "Mantap!", "Enak nih!" },
	gosong = { "Kok gosong...", "Pait, Bang..." },
	kesel = { "Lama banget!", "Ah, nggak jadi!" },
}

-- Bonus kecil acak pas Perfect ("kembaliannya ambil aja").
PembeliConfig.BONUS_PELUANG = 0.25
PembeliConfig.BONUS = 500

-- Fallback ID animasi R15 bawaan kalau nggak kebaca dari script Animate
-- (normalnya ID diambil langsung dari Animate yang ikut kebikin).
PembeliConfig.ANIM_JALAN = "rbxassetid://507777826"
PembeliConfig.ANIM_DIEM = "rbxassetid://507766388"

return PembeliConfig
