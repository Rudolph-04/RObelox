--[[
	Roda kendaraan. Root-nya part "Ban" (silinder sumbu X = as roda), sisanya
	(pelek, tutup as, baut) nanti di-weld ke Ban sama Rig, terus Ban dipasang
	ke kendaraan pake Motor6D "PutarRoda". Baut nggak di tengah, jadi
	keliatan muter.

	Tiap lapis nongol minimal 0.05 stud dari lapis di bawahnya: kalau dua
	permukaan cuma beda seujung rambut, di kejauhan gambarnya kedip-kedip
	(z-fighting).
]]

local Bantu = require(script.Parent.Parent.Bantu)

local M = Enum.Material
local W = Bantu.WARNA

return function(parent, name, cf, radius, width)
	local m = Bantu.model(parent, name)
	Bantu.cylinder(m, "Ban", width, radius * 2, cf, W.BAN, M.Rubber)
	Bantu.cylinder(m, "Pelek", width + 0.1, radius * 1.2, cf, W.KROM, M.Metal)
	Bantu.cylinder(m, "TutupAs", width + 0.32, 0.42, cf, W.RANGKA, M.Metal)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local offset = CFrame.new(0, math.cos(a) * radius * 0.38, math.sin(a) * radius * 0.38)
		Bantu.cylinder(m, "Baut", width + 0.22, 0.13, cf * offset, W.RANGKA, M.Metal)
	end
	return m
end
