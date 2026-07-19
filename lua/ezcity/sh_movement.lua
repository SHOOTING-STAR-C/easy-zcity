--[[
	ezcity Movement System
	Source: lua/homigrad/movement/sh_inertia.lua
	SetupMove with inertia, speed states (walk/run/crouch/aim), view effects
]]

local PLAYER = FindMetaTable("Player")

-- ============================================
-- Vector math helpers
-- Source: sh_inertia.lua:14-43
-- ============================================
local function calc_vector2d_angle(vector)
	return math.deg(math.atan2(vector.y, vector.x))
end

local function calc_forward_side_moves(inertia, ply_angles)
	local ply_angle = ply_angles.y
	local inertia_angle = calc_vector2d_angle(inertia)
	local angdiff = math.AngleDifference(inertia_angle, ply_angle)

	return math.cos(math.rad(angdiff)), -math.sin(math.rad(angdiff))
end

local function calc_forward_side_moves_to_vector2d(fm, sm, ply_angles)
	local ply_angle = ply_angles.y

	local vec = Vector(
		fm * math.cos(math.rad(ply_angle)) - sm * math.cos(math.rad(ply_angle + 90)),
		fm * math.sin(math.rad(ply_angle)) - sm * math.sin(math.rad(ply_angle + 90)),
		0
	)

	return vec:GetNormalized()
end

local function approach_vector(vecFrom, vecTo, change)
	return Vector(
		math.Approach(vecFrom.x, vecTo.x, change),
		math.Approach(vecFrom.y, vecTo.y, change),
		math.Approach(vecFrom.z, vecTo.z, change)
	)
end

-- ============================================
-- Main SetupMove Hook
-- Source: sh_inertia.lua:55-539
-- ============================================
hook.Add("SetupMove", "ezc_movement", function(ply, mv, cmd)
	-- Delta Time
	ply.ezc_LastStartCommand = ply.ezc_LastStartCommand or SysTime()
	local delta_time = SysTime() - ply.ezc_LastStartCommand
	ply.ezc_LastStartCommand = SysTime()

	if not IsValid(ply) or not ply:Alive() then return end

	-- Ragdoll / disabled movement
	if IsValid(ply.FakeRagdoll) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		mv:SetForwardSpeed(0)
		mv:SetSideSpeed(0)
		cmd:RemoveKey(IN_JUMP)
		mv:RemoveKey(IN_JUMP)
		cmd:AddKey(IN_DUCK)
		mv:AddKey(IN_DUCK)
		if ply.ezc_MovementInertia then ply.ezc_MovementInertia:Zero() end
	end

	if ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	if ply:InVehicle() then return end

	local running = ply:KeyDown(IN_SPEED) and not ply:Crouching() and ply:KeyDown(IN_FORWARD)

	-- Can't sprint backward
	if ply:KeyDown(IN_SPEED) and not ply:Crouching() and ply:KeyDown(IN_BACK) then
		cmd:RemoveKey(IN_SPEED)
	end

	local wep = ply:GetActiveWeapon()
	local vel = ply:GetVelocity()
	local velLen = vel:Length()
	local fm = cmd:GetForwardMove() / math.max(math.abs(cmd:GetForwardMove()), 1)
	local sm = cmd:GetSideMove() / math.max(math.abs(cmd:GetSideMove()), 1)

	local slow_walking = ply:KeyDown(IN_WALK)
	local aiming = ply:KeyDown(IN_ATTACK2) and IsValid(wep) and ezc.IsEZCWeapon(wep)
	local walk_speed = ply:GetWalkSpeed()
	local slow_walk_speed = ply:GetSlowWalkSpeed()
	local crouch_walk_speed = ply:GetCrouchedWalkSpeed()

	-- Speed state management
	-- Source: sh_inertia.lua:185-276
	ply.ezc_CurrentSpeed = ply.ezc_CurrentSpeed or walk_speed
	ply.ezc_FrictionMul = ply.ezc_FrictionMul or 1

	ply.ezc_SpeedGainMul = 240 * (ezc.movement_speed_gain_mul:GetFloat())
	ply.ezc_SpeedLoseMul = 10000 * (ezc.movement_speed_lose_mul:GetFloat())
	ply.ezc_SpeedSharpLoseMul = 0.007
	ply.ezc_InertiaBlend = 2000

	-- Speed approach based on state
	-- Source: sh_inertia.lua:235-247
	if running and velLen >= 10 then
		ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, ply:GetRunSpeed(), delta_time * ply.ezc_SpeedGainMul)
	elseif ply:Crouching() then
		ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, crouch_walk_speed, delta_time * ply.ezc_SpeedLoseMul)
	elseif slow_walking then
		ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, slow_walk_speed, delta_time * ply.ezc_SpeedLoseMul)
	elseif aiming then
		ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, slow_walk_speed, delta_time * ply.ezc_SpeedLoseMul)
	else
		ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, walk_speed, delta_time * ply.ezc_SpeedLoseMul)
	end

	-- Speed change from direction change (sharp turns)
	-- Source: sh_inertia.lua:250-276
	ply.ezc_LastVelocity = ply.ezc_LastVelocity or vel
	ply.ezc_LastVelocityLen = ply.ezc_LastVelocityLen or velLen

	local vel1 = math.max(velLen, 1)
	local vel2 = math.max(ply.ezc_LastVelocityLen, 1)

	local change = math.abs(math.AngleDifference(
		calc_vector2d_angle(ply.ezc_LastVelocity),
		calc_vector2d_angle(vel)
	))

	if ply.ezc_LastVelocity == vel and ply.ezc_LastChangeVelocity then
		change = ply.ezc_LastChangeVelocity
	end

	ply.ezc_LastChangeVelocity = change
	ply.ezc_CurrentSpeed = math.Approach(ply.ezc_CurrentSpeed, slow_walk_speed, delta_time * change * math.abs(ply.ezc_CurrentSpeed - slow_walk_speed) * ply.ezc_SpeedSharpLoseMul * 0.25 * 200)
	ply.ezc_LastVelocity = vel
	ply.ezc_LastVelocityLen = velLen

	local speed = ply.ezc_CurrentSpeed

	-- Inertia system
	-- Source: sh_inertia.lua:278-374
	local ply_angles = cmd:GetViewAngles()
	ply.ezc_MovementInertia = ply.ezc_MovementInertia or vel

	-- Side/back movement speed penalties
	-- Source: sh_inertia.lua:285-299
	local movement_penalty = math.abs(sm * 1.2)
	if movement_penalty == 0 then movement_penalty = 1 end
	if fm < 0 then movement_penalty = math.max(movement_penalty, 1.3) end
	speed = speed / movement_penalty

	-- Air movement penalty
	-- Source: sh_inertia.lua:305-327
	if not ply:OnGround() and ply:WaterLevel() < 1 then
		if fm ~= 0 or sm ~= 0 then
			local tr = util.TraceLine({
				start = ply:GetPos(),
				endpos = ply:GetPos() + (calc_forward_side_moves_to_vector2d(fm, sm, ply_angles) / speed * 50),
				filter = ply
			})
			if not tr.Hit then
				speed = speed / 5
			end
		end
	end

	-- Inertia calculation
	-- Source: sh_inertia.lua:346-374
	ply.ezc_FrictionMul = 0.5 / ezc.inertiamul:GetFloat()
	ply.ezc_InertiaBlend = ply.ezc_InertiaBlend * ply.ezc_FrictionMul

	if not ply:OnGround() then
		ply.ezc_MovementInertia = ply.ezc_LastVelocity
	end

	local inertia_to = calc_forward_side_moves_to_vector2d(fm, sm, ply_angles) * speed
	local new_inertia = approach_vector(ply.ezc_MovementInertia, inertia_to, delta_time * ply.ezc_InertiaBlend)
	ply.ezc_MovementInertia = new_inertia

	local inertia_len = math.sqrt(ply.ezc_MovementInertia.x ^ 2 + ply.ezc_MovementInertia.y ^ 2)
	local forward_move, side_move = calc_forward_side_moves(ply.ezc_MovementInertia, ply_angles)

	-- Inertia view effect (client only)
	-- Source: sh_inertia.lua:370-374
	if CLIENT then
		ply.ezc_MovementInertiaAddView = ply.ezc_MovementInertiaAddView or Angle(0, 0, 0)
		ply.ezc_MovementInertiaAddView.r = ply.ezc_MovementInertiaAddView.r + side_move * delta_time * inertia_len * 0.0003
		ply.ezc_MovementInertiaAddView.p = ply.ezc_MovementInertiaAddView.p + math.abs(side_move) * delta_time * inertia_len * 0.0001
	end

	-- Minimum speed floor
	-- Source: sh_inertia.lua:410
	local minSpeed = 0.4
	speed = math.max(speed, minSpeed * 200)
	ply.ezc_move = speed

	-- Apply speed
	-- Source: sh_inertia.lua:520-538
	mv:SetMaxSpeed(inertia_len)
	mv:SetMaxClientSpeed(inertia_len)
	ply:SetMaxSpeed(math.max(100, inertia_len))
	ply:SetJumpPower(DEFAULT_JUMP_POWER * math.min(speed / 350, 1.1))

	if CLIENT then
		local fwangs = math.rad((ezc.GetViewPunchAngles2() or angle_zero).y + (ezc.GetViewPunchAngles3() or angle_zero).y)

		forward_move = forward_move * math.cos(fwangs) + side_move * math.sin(fwangs)
		side_move = side_move * math.cos(fwangs) + forward_move * math.sin(fwangs)

		cmd:SetForwardMove(forward_move * inertia_len)
		cmd:SetSideMove(side_move * inertia_len)
	end

	if ezc.inertiaenabled:GetBool() then
		mv:SetForwardSpeed(forward_move * inertia_len)
		mv:SetSideSpeed(side_move * inertia_len)
	end
end)

-- ============================================
-- Anti-crouch-spam
-- Source: sh_inertia.lua:562-571
-- ============================================
hook.Add("StartCommand", "ezc_anti_crouch_spam", function(ply, cmd)
	ply.ezc_NowCrouched = cmd:KeyDown(IN_DUCK)
	ply.ezc_OldCrouched = ply.ezc_OldCrouched or cmd:KeyDown(IN_DUCK)

	if not ply:OnGround() and ply:WaterLevel() < 2 and ply:GetMoveType() == MOVETYPE_WALK and ply.ezc_OldCrouched != ply.ezc_NowCrouched then
		cmd:AddKey(IN_DUCK)
	end

	ply.ezc_OldCrouched = cmd:KeyDown(IN_DUCK)
end)
