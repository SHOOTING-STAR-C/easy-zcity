--[[
	ezcity Shared Utility Functions
	Source: lua/homigrad/sh_utility.lua in Z-City
	Core math utilities, trace functions, ConVars, and player defaults
]]

ezc = ezc or {}

-- ============================================
-- ConVars
-- ============================================

-- Camera
ezc.thirdperson = CreateConVar("hg_thirdperson", "0", FCVAR_REPLICATED, "Toggle third-person camera")
ezc.thirdperson_orbit = CreateConVar("hg_thirdperson_orbit", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable third-person orbit camera")
ezc.legacycam = CreateConVar("hg_legacycam", "0", FCVAR_REPLICATED, "First-person in third-person mode")
ezc.fov = CreateConVar("hg_fov", "70", FCVAR_REPLICATED, "Field of view", 75, 100)
ezc.coolcamera = CreateConVar("hg_coolcamera", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement", 0, 5)
ezc.oldsights = CreateConVar("hg_oldsights", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "No camera wobble when aiming")
ezc.realismcam = CreateClientConVar("hg_realismcam", "0", true, false, "Realism camera mode", 0, 1)

-- Toggle concommand for third person (bind this to a key)
concommand.Add("+hg_thirdperson", function()
	ezc.thirdperson:SetInt(1 - ezc.thirdperson:GetInt())
end)
ezc.gopro = CreateClientConVar("hg_gopro", "0", true, false, "GoPro camera mode", 0, 1)
ezc.leancam_mul = CreateClientConVar("hg_leancam_mul", "7", true, false, "Lean camera roll multiplier", -10, 10)

-- Movement
ezc.inertiaenabled = CreateConVar("hg_inertiaenabled", "0", {FCVAR_REPLICATED}, "Enable movement inertia")
ezc.inertiamul = CreateConVar("hg_inertiamul", "1", {FCVAR_REPLICATED}, "Inertia multiplier", 0.01, 5)
ezc.movement_speed_gain_mul = CreateConVar("hg_movement_speed_gain_mul", "1", {FCVAR_REPLICATED}, "Speed gain multiplier", 0.01, 5)
ezc.movement_speed_lose_mul = CreateConVar("hg_movement_speed_lose_mul", "1", {FCVAR_REPLICATED}, "Speed lose multiplier", 0.01, 5)

-- ============================================
-- Player Defaults
-- ============================================
DEFAULT_JUMP_POWER = 200

local HullMins = Vector(-16, -16, 0)
local HullMaxs = Vector(16, 16, 72)
local HullDuckMins = Vector(-16, -16, 0)
local HullDuckMaxs = Vector(16, 16, 36)
local ViewOffset = Vector(0, 0, 64)
local ViewOffsetDucked = Vector(0, 0, 38)

hook.Add("PlayerSpawn", "ezc_player_defaults", function(ply)
	timer.Simple(0, function()
		if not IsValid(ply) then return end

		ply:SetWalkSpeed(100)
		ply:SetRunSpeed(350)
		ply:SetJumpPower(DEFAULT_JUMP_POWER)

		ply:SetHull(HullMins, HullMaxs)
		ply:SetHullDuck(HullDuckMins, HullDuckMaxs)
		ply:SetViewOffset(ViewOffset)
		ply:SetViewOffsetDucked(ViewOffsetDucked)

		ply:SetSlowWalkSpeed(60)
		ply:SetLadderClimbSpeed(150)
		ply:SetCrouchedWalkSpeed(60)
		ply:SetDuckSpeed(0.4)
		ply:SetUnDuckSpeed(0.4)

		ply.ezc_stamina = ply.ezc_stamina or 100
	end)
end)

-- ============================================
-- Frame Time / Lerp Utilities
-- Source: sh_utility.lua:172-220
-- ============================================
FrameTimeClamped = 1 / 66
ftlerped = 1 / 66

hook.Add("Think", "ezc_ftlerp", function()
	local ft = FrameTime()
	ftlerped = Lerp(0.5, ftlerped, math.Clamp(ft, 0.001, 0.1))
end)

function ezc.FrameTimeClamped(ft)
	return math.Clamp(1 - math.exp(-0.5 * (ft or ftlerped) * game.GetTimeScale()), 0.000, 0.02)
end

local FrameTimeClamped_ = ezc.FrameTimeClamped

function ezc.lerpFrameTime(lerp, frameTime)
	return math.Clamp(1 - lerp ^ (frameTime or ftlerped), 0, 1)
end

function ezc.lerpFrameTime2(lerp, frameTime)
	if lerp == 1 then return 1 end
	return math.Clamp(lerp * FrameTimeClamped_(frameTime or ftlerped) * 150, 0, 1)
end

function LerpFT(lerp, source, set)
	return Lerp(ezc.lerpFrameTime2(lerp), source, set)
end

function LerpVectorFT(lerp, source, set)
	return LerpVector(ezc.lerpFrameTime2(lerp), source, set)
end

function LerpAngleFT(lerp, source, set)
	return LerpAngle(ezc.lerpFrameTime2(lerp), source, set)
end

-- ============================================
-- Vector/Angle Clamp
-- Source: sh_utility.lua:344-349
-- ============================================
function ezc.clamp(vecOrAng, val)
	vecOrAng[1] = math.Clamp(vecOrAng[1], -val, val)
	vecOrAng[2] = math.Clamp(vecOrAng[2], -val, val)
	vecOrAng[3] = math.Clamp(vecOrAng[3], -val, val)
	return vecOrAng
end

-- ============================================
-- Weapon Check
-- Source: sh_utility.lua:29-32
-- ============================================
function ezc.IsEZCWeapon(wep)
	if not IsValid(wep) then return false end
	return wep.IsEZCWeapon or false
end

-- ============================================
-- KeyDown Wrapper
-- Source: sh_utility.lua:98-110
-- Simplified: For local player, use ply:KeyDown directly
-- ============================================
function ezc.KeyDown(ply, key)
	if not IsValid(ply) then return false end
	return ply:KeyDown(key)
end

-- ============================================
-- Eye Trace System
-- Source: sh_utility.lua:767-850
-- Traces from neck bone position for realistic camera
-- ============================================
function ezc.eye(ply, dist, ent, aimvec, startpos)
	if not ply:IsPlayer() then return false end

	local ent = IsValid(ent) and ent or ply
	local bon = ent:LookupBone("ValveBiped.Bip01_Neck1")
	if not bon then return end
	if not IsValid(ply) then return end
	if not ply.GetAimVector then return end

	local aim_vector = isvector(aimvec) and aimvec or isangle(aimvec) and aimvec:Forward() or ply:GetAimVector()

	if not bon or not ent:GetBoneMatrix(bon) then
		return ply:EyePos(), aim_vector * (dist or 60)
	end

	local headm = ent:GetBoneMatrix(bon)
	local eyeAng = aim_vector:Angle()
	eyeAng.r = isangle(aimvec) and aimvec.r or ply:EyeAngles().r

	local eyeang2 = aim_vector:Angle()
	eyeang2.r = isangle(aimvec) and aimvec.r or ply:EyeAngles().r

	local pos = startpos or headm:GetTranslation() + (
		eyeAng:Up() * 2 + headm:GetAngles():Right() * 4 +
		headm:GetAngles():Up() * 0 + headm:GetAngles():Forward() * 4
	)

	return pos, aim_vector * (dist or 60)
end

function ezc.eyeTrace(ply, dist, ent, aim_vector, startpos, fFilter)
	local start, aim = ezc.eye(ply, dist, ent, aim_vector, startpos)
	if not start then return end
	if not isvector(start) then return end

	return util.TraceLine({
		start = start,
		endpos = start + aim,
		filter = fFilter or {ply, ply.FakeRagdoll, ply:GetVehicle()}
	})
end

-- ============================================
-- Hull Check (camera collision prevention)
-- Source: sh_utility.lua:735-747
-- ============================================
function ezc.hullCheck(startpos, endpos, ply)
	if ply:InVehicle() then return {HitPos = endpos} end

	local traceBuilder = {
		start = IsValid(ply.FakeRagdoll) and endpos or startpos,
		endpos = endpos,
		filter = {ply, ply.FakeRagdoll, ply:InVehicle() and ply:GetVehicle() or nil, ply.OldRagdoll or nil},
		mins = -Vector(5, 5, 5),
		maxs = Vector(5, 5, 5),
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_DEBRIS
	}

	return util.TraceHull(traceBuilder)
end

-- ============================================
-- Aim Detection
-- Source: cl_optics.lua:21-25
-- ============================================
function IsAimingNoScope(ply)
	local wep = ply:GetActiveWeapon()
	return IsValid(wep) and ezc.IsEZCWeapon(wep) and ply:KeyDown(IN_ATTACK2) and (wep.CanUse and wep:CanUse() or true)
end

-- ============================================
-- IsOnGround
-- Source: sh_utility.lua:352-359
-- ============================================
function ezc.IsOnGround(ent)
	local tr = {}
	tr.start = ent:GetPos()
	tr.endpos = ent:GetPos() - vector_up * 10
	tr.filter = ent
	tr.mask = MASK_PLAYERSOLID
	return util.TraceEntityHull(tr, ent).Hit
end

-- ============================================
-- IsValid Player (simplified - no organism check)
-- Source: sh_utility.lua:55-57
-- ============================================
function ezc.IsValidPlayer(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:Alive()
end

-- ============================================
-- Bone Matrix Name Table
-- Used by bonemethods, lean, TPIK
-- Source: sh_bonemethods.lua:3-13
-- ============================================
ezc.boneNames = {
	["head"] = "ValveBiped.Bip01_Head1",
	["spine"] = "ValveBiped.Bip01_Spine",
	["spine1"] = "ValveBiped.Bip01_Spine1",
	["spine2"] = "ValveBiped.Bip01_Spine2",
	["spine3"] = "ValveBiped.Bip01_Spine3",
	["spine4"] = "ValveBiped.Bip01_Spine4",
	["pelvis"] = "ValveBiped.Bip01_Pelvis",
	["r_upperarm"] = "ValveBiped.Bip01_R_UpperArm",
	["r_forearm"] = "ValveBiped.Bip01_R_Forearm",
	["l_upperarm"] = "ValveBiped.Bip01_L_UpperArm",
	["l_forearm"] = "ValveBiped.Bip01_L_Forearm",
	["r_hand"] = "ValveBiped.Bip01_R_Hand",
	["l_hand"] = "ValveBiped.Bip01_L_Hand",
	["r_clavicle"] = "ValveBiped.Bip01_R_Clavicle",
	["l_clavicle"] = "ValveBiped.Bip01_L_Clavicle",
	["neck"] = "ValveBiped.Bip01_Neck1",
	["r_wrist"] = "ValveBiped.Bip01_R_Wrist",
	["l_wrist"] = "ValveBiped.Bip01_L_Wrist",
	["r_ulna"] = "ValveBiped.Bip01_R_Ulna",
	["l_ulna"] = "ValveBiped.Bip01_L_Ulna",
}
