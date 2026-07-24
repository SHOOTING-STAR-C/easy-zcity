--[[
	ezcity View Punch System (4-channel spring physics)
	Source: lua/homigrad/sh_viewpunch.lua
	Spring-damper system for realistic camera recoil/shake
]]

local PUNCH_DAMPING = 5
local PUNCH_SPRING_CONSTANT = 15

-- Channel 0 (primary)
vp_punch_angle = vp_punch_angle or Angle()
local vp_punch_angle_velocity = Angle()
vp_punch_angle_last = vp_punch_angle_last or vp_punch_angle

-- Channel 1
vp_punch_angle2 = vp_punch_angle2 or Angle()
local vp_punch_angle_velocity2 = Angle()
vp_punch_angle_last2 = vp_punch_angle_last2 or vp_punch_angle2

-- Channel 2
vp_punch_angle3 = vp_punch_angle3 or Angle()
local vp_punch_angle_velocity3 = Angle()
vp_punch_angle_last3 = vp_punch_angle_last3 or vp_punch_angle3

-- Channel 3
vp_punch_angle4 = vp_punch_angle4 or Angle()
local vp_punch_angle_velocity4 = Angle()
vp_punch_angle_last4 = vp_punch_angle_last4 or vp_punch_angle4

-- ============================================
-- Spring physics update function
-- Source: sh_viewpunch.lua:63-140 (simplified)
-- ============================================
local function updateChannel(angle, velocity, lastAngle)
	if not angle:IsZero() or not velocity:IsZero() then
		angle:Add(velocity * ftlerped)
		local damping = 1 - (PUNCH_DAMPING * ftlerped)
		if damping < 0 then damping = 0 end
		velocity:Mul(damping)
		local springForce = PUNCH_SPRING_CONSTANT * ftlerped * 5
		velocity:Sub(angle * springForce)
		angle.p = math.Clamp(angle.p, -89, 89)
		angle.y = math.Clamp(angle.y, -179, 179)
		angle.r = math.Clamp(angle.r, -89, 89)
	else
		angle:Zero()
		velocity:Zero()
	end

	local add = angle - lastAngle
	if not add:IsZero() then
		local ply = LocalPlayer()
		if IsValid(ply) and ply:Alive() and not ply.lockcamera then
			local angs = ply:EyeAngles()
			ply:SetEyeAngles(angs + add)
		end
	end
	return angle
end

-- ============================================
-- Think hook - update all channels
-- Source: sh_viewpunch.lua:56-140
-- ============================================
hook.Add("Think", "ezc_viewpunch_think", function()
	if IsValid(lply) and IsValid(lply.FakeRagdoll) then return end

	vp_punch_angle = updateChannel(vp_punch_angle, vp_punch_angle_velocity, vp_punch_angle_last)
	vp_punch_angle_last = Angle(vp_punch_angle.p, vp_punch_angle.y, vp_punch_angle.r)

	vp_punch_angle2 = updateChannel(vp_punch_angle2, vp_punch_angle_velocity2, vp_punch_angle_last2)
	vp_punch_angle_last2 = Angle(vp_punch_angle2.p, vp_punch_angle2.y, vp_punch_angle2.r)

	vp_punch_angle3 = updateChannel(vp_punch_angle3, vp_punch_angle_velocity3, vp_punch_angle_last3)
	vp_punch_angle_last3 = Angle(vp_punch_angle3.p, vp_punch_angle3.y, vp_punch_angle3.r)

	vp_punch_angle4 = updateChannel(vp_punch_angle4, vp_punch_angle_velocity4, vp_punch_angle_last4)
	vp_punch_angle_last4 = Angle(vp_punch_angle4.p, vp_punch_angle4.y, vp_punch_angle4.r)
end)

-- ============================================
-- View Punch Functions
-- Source: sh_viewpunch.lua (various ViewPunch functions)
-- ============================================

function ezc.ViewPunch(ang)
	vp_punch_angle_velocity:Add(ang * 20)
end

function ezc.ViewPunch2(ang)
	vp_punch_angle_velocity2:Add(ang * 20)
end

function ezc.ViewPunch3(ang)
	vp_punch_angle_velocity3:Add(ang * 20)
end

function ezc.ViewPunch4(ang)
	vp_punch_angle_velocity4:Add(ang * 20)
end

function ezc.GetViewPunchAngles()
	return vp_punch_angle
end

function ezc.GetViewPunchAngles2()
	return vp_punch_angle2
end

function ezc.GetViewPunchAngles3()
	return vp_punch_angle3
end

function ezc.GetViewPunchAngles4()
	return vp_punch_angle4
end

function ezc.GetAllViewPunchAngles()
	return vp_punch_angle + vp_punch_angle2 + vp_punch_angle3 + vp_punch_angle4
end

-- ============================================
-- Reset on spawn
-- Source: sh_utility.lua:416-421
-- ============================================
hook.Add("PlayerSpawn", "ezc_viewpunch_reset", function(ply)
	if CLIENT and ply == LocalPlayer() then
		vp_punch_angle:Zero()
		vp_punch_angle_velocity:Zero()
		vp_punch_angle_last:Zero()
		vp_punch_angle2:Zero()
		vp_punch_angle_velocity2:Zero()
		vp_punch_angle_last2:Zero()
		vp_punch_angle3:Zero()
		vp_punch_angle_velocity3:Zero()
		vp_punch_angle_last3:Zero()
		vp_punch_angle4:Zero()
		vp_punch_angle_velocity4:Zero()
		vp_punch_angle_last4:Zero()
	end
end)

-- Global wrappers for backward compatibility (for other addons)
Viewpunch = ezc.ViewPunch  -- lowercase variant for viewbob addon compat
ViewPunch = ezc.ViewPunch
ViewPunch2 = ezc.ViewPunch2
ViewPunch3 = ezc.ViewPunch3
ViewPunch4 = ezc.ViewPunch4
GetViewPunchAngles = ezc.GetViewPunchAngles
GetViewPunchAngles2 = ezc.GetViewPunchAngles2
GetViewPunchAngles3 = ezc.GetViewPunchAngles3
GetViewPunchAngles4 = ezc.GetViewPunchAngles4
GetAllViewPunchAngles = ezc.GetAllViewPunchAngles
