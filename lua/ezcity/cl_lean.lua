--[[
	ezcity Lean System (Q/E head tilt)
	Source: lua/weapons/homigrad_base/sh_anim.lua:248-440 (bone animation)
	Source: lua/homigrad/sh_utility.lua:670-686 (lean lerp)
	Source: lua/homigrad/cl_camera.lua:667 (camera roll)
]]

if SERVER then return end

-- ============================================
-- Lean angle constants
-- Source: sh_anim.lua:316-346
-- ============================================
local ang1 = Angle(0, 0, -10)
local ang2 = Angle(0, 0, 20)
local ang3 = Angle(0, 20, 0)
local ang4 = Angle(0, 0, -30)
local ang5 = Angle(0, 0, 10)
local ang6 = Angle(0, 0, -20)
local ang7 = Angle(0, 0, 0)
local ang8 = Angle(0, 0, 20)
local ang9 = Angle(0, -20, 0)
local ang10 = Angle(35, 0, 0)
local ang11 = Angle(20, 0, 0)

-- ============================================
-- Lean lerp (global for cl_view to access)
-- Source: sh_utility.lua:670-686
-- ============================================
ezc.lean_lerp = 0

local lastLeanTime = SysTime()

hook.Add("HUDPaint", "ezc_lean_lerp", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local dtime = SysTime() - lastLeanTime
	lastLeanTime = SysTime()

	local lean = ply.ezc_lean or 0
	ezc.lean_lerp = LerpFT(1, ezc.lean_lerp, lean)
end)

-- ============================================
-- Console command flags for lean (for binds/console use)
-- Source: custom addition
-- ============================================
local cmdLeanLeft = false
local cmdLeanRight = false

concommand.Add("+ezc_lean_left", function() cmdLeanLeft = true end)
concommand.Add("-ezc_lean_left", function() cmdLeanRight = false cmdLeanLeft = false end)
concommand.Add("+ezc_lean_right", function() cmdLeanRight = true end)
concommand.Add("-ezc_lean_right", function() cmdLeanRight = false cmdLeanLeft = false end)

-- ============================================
-- Bone manipulation for lean
-- Source: sh_anim.lua:348-440
-- IN_ALT1 (default E) = right lean → ply.ezc_lean = -1.3
-- IN_ALT2 (default Q) = left lean  → ply.ezc_lean = 1.3
-- Console: +ezc_lean_left, +ezc_lean_right
-- ============================================
hook.Add("Bones", "ezc_lean_bone", function(ply, dtime)
	if not IsValid(ply) or not ply:Alive() then return end

	-- Only apply lean bone manipulation for ezcity weapons (others handle their own bones)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and not wep.IsEZCWeapon then return end

	-- Read lean input (keyboard OR console commands)
	-- Z-City source: IN_ALT2 = left, IN_ALT1 = right
	local left = (ply:KeyDown(IN_ALT2) or cmdLeanLeft) and not (ply:KeyDown(IN_ALT1) or cmdLeanRight)
	local right = (ply:KeyDown(IN_ALT1) or cmdLeanRight) and not (ply:KeyDown(IN_ALT2) or cmdLeanLeft)

	-- Calculate lean value
	-- Source: sh_anim.lua:357-361
	local targetLean = (left and 1.3) or (right and -1.3) or 0

	ply.ezc_lean = Lerp(
		ezc.lerpFrameTime((left or right) and 0.045 or 0.075, dtime * game.GetTimeScale()),
		ply.ezc_lean or 0,
		targetLean
	)

	local amt = 0.7
	local div = 0.33
	local leanspeed = 0.0001

	-- Right lean (ply.ezc_lean < 0)
	-- Source: sh_anim.lua:386-401
	if ply.ezc_lean < -0.01 then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and ezc.IsEZCWeapon(wep) and not (wep.IsPistolHoldType and wep:IsPistolHoldType()) then
			-- Long arm right lean
			ezc.bone.Set(ply, "r_upperarm", vecZero, ang1 * -ply.ezc_lean * amt, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine", vecZero, ang2 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine1", vecZero, ang2 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine2", vecZero, ang2 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "head", vecZero, ang3 * -ply.ezc_lean * amt, "lean", leanspeed, dtime)
		else
			-- Pistol right lean
			ezc.bone.Set(ply, "spine", vecZero, ang4 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine1", vecZero, ang4 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine2", vecZero, ang4 * -ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "pelvis", vecZero, ang4 * -ply.ezc_lean * amt * -div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "l_upperarm", vecZero, ang8 * -ply.ezc_lean * amt, "lean", leanspeed, dtime)
		end
	end

	-- Left lean (ply.ezc_lean > 0)
	-- Source: sh_anim.lua:425-439
	if ply.ezc_lean > 0.01 then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and ezc.IsEZCWeapon(wep) and not (wep.IsPistolHoldType and wep:IsPistolHoldType()) then
			-- Long arm left lean
			ezc.bone.Set(ply, "r_upperarm", vecZero, ang5 * ply.ezc_lean * amt, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine", vecZero, ang6 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine1", vecZero, ang6 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine2", vecZero, ang6 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "head", vecZero, ang9 * ply.ezc_lean * amt, "lean", leanspeed, dtime)
		else
			-- Pistol left lean
			ezc.bone.Set(ply, "spine", vecZero, ang10 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine1", vecZero, ang10 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "spine2", vecZero, ang10 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "pelvis", vecZero, ang4 * ply.ezc_lean * amt * div, "lean", leanspeed, dtime)
			ezc.bone.Set(ply, "r_upperarm", vecZero, ang11 * ply.ezc_lean * amt, "lean", leanspeed, dtime)
		end
	end

	-- Reset bones when not leaning
	-- If lean is near zero, the layer cleanup in bonemethods will handle it
	-- But we need to ensure all lean bones are reset if there's no active layer
	if math.abs(ply.ezc_lean or 0) < 0.01 and not left and not right then
		local leanBones = {"r_upperarm", "l_upperarm", "spine", "spine1", "spine2", "head", "pelvis"}
		for _, bone in ipairs(leanBones) do
			local boneID = ply:LookupBone(ezc.boneNames[bone])
			if boneID then
				ezc.bone.Set(ply, boneID, vecZero, angle_zero, "lean", 0.075, dtime)
			end
		end
	end
end)
