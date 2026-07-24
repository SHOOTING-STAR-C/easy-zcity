--[[
	ezcity Posture System (Weapon Holding Stances)
	Source: weapons/homigrad_base/sh_options.lua (posture table + net)
	Source: weapons/homigrad_base/shared.lua:1472-1560 (posture functions)
	Source: weapons/homigrad_base/sh_anim.lua:119-178 (animation integration)
]]

ezc = ezc or {}

-- ============================================
-- Posture Definitions
-- Source: sh_options.lua:70-81
-- ============================================
ezc.postures = {
	[0] = "常规持枪",
	[1] = "腰射",
	[2] = "左肩射击",
	[3] = "高位戒备",
	[4] = "低位戒备",
	[5] = "指向射击",
	[6] = "掩体射击",
	[7] = {"黑帮持枪", isPistolOnly = true},
	[8] = {"单手射击", isPistolOnly = true},
	[9] = "索马里式射击",
}

-- ============================================
-- Posture Position Offsets
-- Source: shared.lua:1472-1560
-- Simplified: modifies AdditionalPos/AdditionalAng directly
-- ============================================
local angPosture3 = Angle(45, 45, -25)
local angPosture3pistol = Angle(5, 65, 0)
local angPosture4 = Angle(40, -30, -40)
local angPosture7 = Angle(5, -30, 0)
local angPosture8 = Angle(40, 10, -30)
local angPostureHighReady = Angle(-30, -25, 30)
local angRunning = Angle(20, 10, 0)

ezc.postureOffsets = {
	[1] = function(self, ply)
		-- Hipfire
		if self:IsZoom and self:IsZoom() then return end
		if self.IsPistolHoldType and self:IsPistolHoldType() then
			self.AdditionalPos[1] = self.AdditionalPos[1] - 4
			self.AdditionalPos[2] = self.AdditionalPos[2] - 3
			self.AdditionalAng[1] = self.AdditionalAng[1] + 2
			self.AdditionalAng[2] = self.AdditionalAng[2] + 5
			self.AdditionalAng[3] = self.AdditionalAng[3] - 20
			return
		end
		self.AdditionalPos[2] = self.AdditionalPos[2] - 9
		self.AdditionalPos[1] = self.AdditionalPos[1] - 2
		self.AdditionalPos[3] = self.AdditionalPos[3] + 1.5
		self.AdditionalAng[1] = self.AdditionalAng[1] + 3
		self.AdditionalAng[2] = self.AdditionalAng[2] + 5
		self.AdditionalAng[3] = self.AdditionalAng[3] - 4
	end,
	[2] = function(self, ply)
		-- Left shoulder
		self.AdditionalAng[3] = self.AdditionalAng[3] - 15
		self.AdditionalPos[3] = self.AdditionalPos[3] - 6
		if self.IsPistolHoldType and self:IsPistolHoldType() then return end
		self.AdditionalPos[1] = self.AdditionalPos[1] + 2
		self.AdditionalPos[2] = self.AdditionalPos[2] + 1
		self.AdditionalAng[1] = self.AdditionalAng[1] - 2
	end,
	[3] = function(self, ply)
		-- High ready
		if self:IsZoom and self:IsZoom() then return end
		if not ply:KeyDown(IN_SPEED) and ply:GetVelocity():LengthSqr() <= 150 * 150 then return end
		local pistolRun = (self.IsPistolHoldType and self:IsPistolHoldType()) or (self.CanEpicRun)
		if not pistolRun then
			self.AdditionalPos[1] = self.AdditionalPos[1] - 9
			self.AdditionalPos[2] = self.AdditionalPos[2] - 6
			self.AdditionalPos[3] = self.AdditionalPos[3] - 3
			self.AdditionalAng:Add(angPostureHighReady)
		end
		self.AdditionalAng:Add((pistolRun and angPosture3pistol or angPosture3))
	end,
	[4] = function(self, ply)
		-- Low ready
		if self:IsZoom and self:IsZoom() then return end
		if self.IsPistolHoldType and self:IsPistolHoldType() then
			self.AdditionalPos[2] = self.AdditionalPos[2] - 7
			self.AdditionalPos[1] = self.AdditionalPos[1] - 3
			self.AdditionalPos[3] = self.AdditionalPos[3] + 1
		else
			self.AdditionalPos[3] = self.AdditionalPos[3] + 1
			self.AdditionalPos[2] = self.AdditionalPos[2] - 8
			self.AdditionalPos[1] = self.AdditionalPos[1] - 2
		end
		local ducking = ply:IsFlagSet and ply:IsFlagSet(FL_ANIMDUCKING)
		self.AdditionalAng:Add((self.IsPistolHoldType and self:IsPistolHoldType() and angPosture7) or (ducking and angPosture8 or angPosture4))
	end,
	[5] = function(self, ply)
		-- Point shooting
		if self:IsZoom and self:IsZoom() then return end
		if self.IsPistolHoldType and self:IsPistolHoldType() then
			self.AdditionalAng[3] = self.AdditionalAng[3] + 15
			self.AdditionalPos[2] = self.AdditionalPos[2] - 3
		else
			self.AdditionalAng[3] = self.AdditionalAng[3] + 20
		end
	end,
	[7] = function(self, ply)
		-- Gangsta (pistol only)
		if self.IsPistolHoldType and not self:IsPistolHoldType() then ply.posture = 0 return end
		self.AdditionalAng[3] = self.AdditionalAng[3] + 20
		self.AdditionalPos[2] = self.AdditionalPos[2] - 2
	end,
	[8] = function(self, ply)
		-- One-handed (pistol only)
		if self.IsPistolHoldType and not self:IsPistolHoldType() then ply.posture = 0 return end
		self.AdditionalAng[3] = self.AdditionalAng[3] + 20
	end,
	[9] = function(self, ply)
		-- Somalian
		self.AdditionalAng[3] = self.AdditionalAng[3] - 40
	end,
}

-- ============================================
-- Apply posture offset to weapon (called from Think)
-- ============================================
function ezc.ApplyPosture(ply, wep)
	if not IsValid(ply) or not IsValid(wep) then return end
	local pos = ply.posture or 0
	if pos == 0 then return end
	local func = ezc.postureOffsets[pos]
	if func then
		-- Reset offsets before applying
		wep.AdditionalPos = wep.AdditionalPos or Vector(0, 0, 0)
		wep.AdditionalAng = wep.AdditionalAng or Angle(0, 0, 0)
		func(wep, ply)
	end
end

-- ============================================
-- Network & Commands
-- Source: sh_options.lua:83-151
-- ============================================

-- Server receive
if SERVER then
	util.AddNetworkString("change_posture")

	net.Receive("change_posture", function(len, ply)
		local pos = net.ReadInt(8)
		if (ply.change_posture_cooldown or 0) > CurTime() then return end
		ply.change_posture_cooldown = CurTime() + 0.1

		if pos == -2 then
			-- Reset to auto mode
			ply.customPosture = false
			ply.posture = 0
		elseif pos == -1 then
			-- Cycle
			ply.customPosture = true
			ply.posture = ply.posture or 0
			ply.posture = (ply.posture + 1) > 9 and 0 or ply.posture + 1
		else
			ply.customPosture = true
			if pos == ply.posture then
				ply.posture = 0
			else
				ply.posture = pos
			end
		end

		net.Start("change_posture")
		net.WriteEntity(ply)
		net.WriteInt(ply.posture or 0, 9)
		net.Broadcast()
	end)

	return
end

-- Client
local printed
concommand.Add("hg_change_posture", function(ply, cmd, args)
	if not args[1] and not isnumber(args[1]) and not printed then
		print([[Change your gun posture:
	0 - regular hold
	1 - hipfire
	2 - left shoulder
	3 - high ready
	4 - low ready
	5 - point shooting
	6 - shooting from cover
	7 - gangsta shooting
	8 - one-handed shooting
	9 - somalian shooting
	-1 - cycle through postures
	-2 - reset to auto mode
	]])
	printed = true end
	local pos = math.Round(args[1] or -1)
	net.Start("change_posture")
	net.WriteInt(pos, 8)
	net.SendToServer()
end)

net.Receive("change_posture", function()
	local ply = net.ReadEntity()
	local pos = net.ReadInt(8)
	ply.posture = pos
end)

-- Apply posture offset each frame
hook.Add("Think", "ezc_posture_think", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end

	-- Auto-reset pistol-only postures for non-pistol weapons
	if ply.posture and (ply.posture == 7 or ply.posture == 8) then
		if not (wep.IsPistolHoldType and wep:IsPistolHoldType()) then
			ply.posture = 0
		end
	end

	if ezc.IsEZCWeapon(wep) then
		-- Reset then apply
		wep.AdditionalPos = Vector(0, 0, 0)
		wep.AdditionalAng = Angle(0, 0, 0)
		ezc.ApplyPosture(ply, wep)
	end
end)
