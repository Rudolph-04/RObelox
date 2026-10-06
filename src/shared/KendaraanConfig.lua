-- Daftar kendaraan dagangan + angka nyetirnya. Dipake bareng:
--   server (KendaraanService) -> validasi id, template mana yang di-clone
--   client (KendaraanController) -> nyetir + animasi roda/setir
--   client (KendaraanMenu) -> isi menu "Kendaraan"
--
-- Nambah kendaraan baru (upgrade nanti): bikin builder-nya di
-- tools/Kendaraan/, terus tambahin entri di DAFTAR. Template-nya harus ikut
-- kontrak yang sama kayak gerobak motor (lihat tools/Kendaraan/Viar/init.luau
-- sama tools/Kendaraan/Rig.luau). id "Viar" cuma nama internal, nggak keliatan pemain.
-- Satuan kecepatan = stud/detik (karakter ~5 stud, kira-kira 1 stud = 0.35 m).

local KendaraanConfig = {}

KendaraanConfig.DAFTAR = {
	{
		id = "Viar",
		nama = "Gerobak Motor",
		deskripsi = "Motor roda tiga, box jualan di belakang (panelnya kebuka jadi lapak).",
		template = "Viar", -- ServerStorage.Kendaraan.<template>

		maxSpeed = 30, -- maju, ~38 km/jam
		maxReverse = 10,
		accel = 14, -- tambah kecepatan per detik pas gas penuh
		brake = 40, -- ngerem (tekan arah kebalikan)
		coastDrag = 8, -- ngelambat sendiri kalau gas dilepas
		turnRate = 1.5, -- rad/detik pas setir mentok
		turnFullSpeed = 10, -- di bawah ini beloknya makin pelan (nggak bisa muter di tempat)

		-- Cuma tampilan:
		maxSteerAngle = math.rad(28),
		wheelRadius = 1,
	},
}

-- Di bawah kecepatan ini kendaraan dianggap udah berhenti (boleh goreng).
KendaraanConfig.PARKED_SPEED = 0.6

-- Jeda minimal antar "Keluarin" per player.
KendaraanConfig.SPAWN_COOLDOWN = 3

function KendaraanConfig.get(id)
	for _, kendaraan in ipairs(KendaraanConfig.DAFTAR) do
		if kendaraan.id == id then
			return kendaraan
		end
	end
	return nil
end

return KendaraanConfig
