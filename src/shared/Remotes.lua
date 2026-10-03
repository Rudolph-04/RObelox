-- Bikin (di server) atau nunggu (di client) folder RemoteEvent yang dipakai bareng.
-- Require module ini dari server maupun client buat dapet reference yang sama.
--
--   FryStarted  server -> client  (startTime, duration)  mulai goreng, tampilin bar
--   LiftTahu    client -> server  (clientServerTime)     player minta angkat
--   FryResult   server -> client  (result)               hasil + reward dari server

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RemoteEvents"
local EVENT_NAMES = { "FryStarted", "LiftTahu", "FryResult" }

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage

	for _, eventName in ipairs(EVENT_NAMES) do
		local event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {}
for _, eventName in ipairs(EVENT_NAMES) do
	Remotes[eventName] = folder:WaitForChild(eventName)
end

return Remotes
