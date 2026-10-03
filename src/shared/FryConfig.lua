-- Angka-angka mekanik goreng. Dipake bareng:
--   server -> nentuin kualitas + reward (yang sah cuma hitungan server)
--   client -> gambar bar kematangan + warna tahu (cuma tampilan)
-- progress 0 = tahu baru masuk wajan, 1 = gosong total (otomatis diangkat).

local FryConfig = {}

FryConfig.DURATION = 8 -- detik dari mentah sampe gosong total

-- Zona berurutan dari kiri ke kanan bar. `to` = batas akhir zona (0..1).
-- "Oke" + "Perfect" + "Oke" = zona "pas"; Perfect itu titik tengahnya.
FryConfig.ZONES = {
	{ quality = "Mentah", to = 0.48 },
	{ quality = "Oke", to = 0.58 },
	{ quality = "Perfect", to = 0.70 },
	{ quality = "Oke", to = 0.80 },
	{ quality = "Gosong", to = 1 },
}

-- Reward sementara buat Step 1 (nanti diganti sistem pembeli).
-- Sengaja nggak ada yang 0: salah angkat tetep laku, cuma lebih murah.
FryConfig.RESULTS = {
	Mentah = { label = "Kurang Mateng", pay = 1000, tip = 0 },
	Oke = { label = "Oke!", pay = 2000, tip = 0 },
	Perfect = { label = "PERFECT!", pay = 2000, tip = 1000 },
	Gosong = { label = "Gosong...", pay = 500, tip = 0 },
}

-- Toleransi lag: client ngirim waktu dia klik (jam server versi client).
-- Server cuma nerima waktu itu kalau mundurnya nggak lebih dari ini;
-- selebihnya dianggap lag parah/curang, dipotong ke batas ini.
FryConfig.LIFT_GRACE_SECONDS = 0.3

-- Jeda sebelum wajan bisa dipake goreng lagi.
FryConfig.COOLDOWN_SECONDS = 0.6

-- Warna tahu: pucat -> kuning keemasan (pas di tengah Perfect) -> item.
FryConfig.TAHU_RAW = Color3.fromRGB(240, 230, 195)
FryConfig.TAHU_GOLDEN = Color3.fromRGB(215, 150, 50)
FryConfig.TAHU_BURNT = Color3.fromRGB(55, 35, 20)
FryConfig.GOLDEN_AT = 0.64

function FryConfig.qualityAt(progress)
	for _, zone in ipairs(FryConfig.ZONES) do
		if progress <= zone.to then
			return zone.quality
		end
	end
	return "Gosong"
end

function FryConfig.tahuColorAt(progress)
	if progress <= FryConfig.GOLDEN_AT then
		return FryConfig.TAHU_RAW:Lerp(FryConfig.TAHU_GOLDEN, progress / FryConfig.GOLDEN_AT)
	end
	local t = (progress - FryConfig.GOLDEN_AT) / (1 - FryConfig.GOLDEN_AT)
	return FryConfig.TAHU_GOLDEN:Lerp(FryConfig.TAHU_BURNT, math.clamp(t, 0, 1))
end

-- Mulai zona gosong (dipake server buat nyalain asap).
function FryConfig.gosongStart()
	local previous = 0
	for _, zone in ipairs(FryConfig.ZONES) do
		if zone.quality == "Gosong" then
			return previous
		end
		previous = zone.to
	end
	return 1
end

return FryConfig
