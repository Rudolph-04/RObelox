-- RemoteEvent prototipe Laskar Kendang. ModuleScript di ReplicatedStorage.
-- Server bikin, client nunggu. Require dari dua sisi buat dapet reference yang sama.
--
--   Perintah  client -> server  (id, ketukan, kualitas)  perintah dari 4 pukulan,
--                                                        atau ("Putus") pas kombo putus
--   Umpan     server -> client  (info)                    kombo, menang, pesan
--   Efek      server -> semua   (jenis, ...)              angka damage, panah, mati, ayun
--   Peran     client -> server  (peran)                  pilih peran panglima (avatar)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMA_FOLDER = "LaskarEvents" -- beda dari nama ModuleScript ini biar WaitForChild nggak ketuker
local NAMA_EVENT = { "Perintah", "Umpan", "Efek", "Peran" }

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = NAMA_FOLDER
	for _, nama in ipairs(NAMA_EVENT) do
		local event = Instance.new("RemoteEvent")
		event.Name = nama
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(NAMA_FOLDER)
end

local Remotes = {}
for _, nama in ipairs(NAMA_EVENT) do
	Remotes[nama] = folder:WaitForChild(nama)
end

return Remotes
