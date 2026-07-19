--[[
	ezcity Camera System (CalcView)
	Source: lua/homigrad/cl_camera.lua
	First/third person camera, view effects, orbit mode
]]

-- ============================================
-- Cross-file global variables (for weapon camera access)
-- Source: cl_camera.lua:42-61
-- ============================================
angle_difference_localvec = Vector(0, 0, 0)
angle_difference_localvec2 = Vector(0, 0, 0)
angle_difference = Angle(0, 0, 0)
angle_difference2 = Angle(0, 0, 0)
position_difference = Vector(0, 0, 0)
position_difference2 = Vector(0, 0, 0)
position_difference23 = Vector(0, 0, 0)
position_difference3 = Vector(0, 0, 0)
offsetView = offsetView or Angle(0, 0, 0)
camera_position_addition = Vector(0, 0, 0)

-- ============================================
-- Local caches
-- ============================================
local vecZero, vecFull = Vector(0.001, 0.001, 0.001), Vector(1, 1, 1)
local limit = 4
local oldview = render.GetViewSetup()
local traceBuilder = {
	filter = {LocalPlayer()},
	mins = -Vector(5, 5, 5),
	maxs = Vector(5, 5, 5),
	mask = MASK_SOLID,
	collisiongroup = COLLISION_GROUP_DEBRIS
}

-- Third person orbit state
-- Source: cl_camera.lua:228-232
local tp_orbit_ang = Angle(0, 0, 0)
local tp_orbit_dist = 1
local prevRagdoll = false
local lerpasad = 0

-- Zoom state
-- Source: cl_camera.lua:240-253
zooming = false
lerpfovadd = 0
lerpfovadd2 = 0

concommand.Add("+ezc_zoom", function() zooming = true end)
concommand.Add("-ezc_zoom", function() zooming = false end)
concommand.Add("ezc_zoom", function() zooming = not zooming end)

-- Alt-look state
-- Source: cl_camera.lua:218-219
LookX, LookY = 0, 0
local altlook = false

concommand.Add("+altlook", function() altlook = true end)
concommand.Add("-altlook", function() altlook = false end)

-- ============================================
-- Camera hook - delegates to weapon
-- Source: cl_camera.lua:63-67
-- ============================================
hook.Add("Camera", "ezc_weapon_camera", function(ply, ...)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep.Camera then return wep:Camera(...) end
end)

-- ============================================
-- HGAddView - View effects (breathing, walk bob, inertia)
-- Source: cl_camera.lua:93-209
-- Simplified: organism values replaced with defaults
-- ============================================
local lerped_ang = Angle(0, 0, 0)
local velocityAddVel = Vector()
local velocityAdd = Vector()
local walkLerped = 0
local walkTime = 0

function ezc.AddView(ply, origin, angles, velLen)
	if not ply:Alive() then
		if ply.ezc_MovementInertiaAddView then
			ply.ezc_MovementInertiaAddView.r = 0
			ply.ezc_MovementInertiaAddView.p = 0
		end
		return origin, angles
	end

	-- Breathing (simplified - organism-free)
	-- Source: cl_camera.lua:107
	local breathing_amount = math.sin((CurTime() * 1.2) + 0.8) * 0.05

	-- Camera position from breathing
	-- Source: cl_camera.lua:114-123
	camera_position_addition[1] = 0
	camera_position_addition[2] = 0
	camera_position_addition[3] = (math.sin(breathing_amount + math.pi)) * 0.15

	local spineIdx = ply:LookupBone("ValveBiped.Bip01_Spine")
	if spineIdx then
		local spineMat = ply:GetBoneMatrix(spineIdx)
		if spineMat then
			local anga2 = spineMat:GetAngles()
			anga2:RotateAroundAxis(anga2:Right(), 90)
			camera_position_addition:Rotate(anga2)
		end
	end

	origin:Add(camera_position_addition)

	-- Walk bob
	-- Source: cl_camera.lua:147-170
	local vel = ply:GetVelocity()
	local vellen = vel:Length()
	local vellenlerp = velocityAdd and velocityAdd:Length() or vellen

	walkLerped = LerpFT(0.1, walkLerped, ply:InVehicle() and 0 or vellenlerp * 100)
	local walk = math.Clamp(walkLerped / 100, 0, 1)

	walkTime = walkTime + walk * FrameTime() * 2 * game.GetTimeScale() * (ply:OnGround() and 1 or 0)

	velocityAddVel = LerpFT(0.9, velocityAddVel * 0.9, -vel * 0.1)
	velocityAdd = LerpFT(0.1, velocityAdd, velocityAddVel)

	local huy = walkTime
	local y2 = math.sin(huy) * walk + math.cos(huy) * 0.25 * walk
	local x2 = math.cos(huy) * math.sin(huy) * walk + math.sin(huy + 0.25) * 0.25 * walk

	ezc.ViewPunch4(Angle(y2, x2, x2 * 10) * 0.0000015)

	-- Movement inertia view effect
	-- Source: cl_camera.lua:191-194
	if ply.ezc_MovementInertiaAddView then
		angles = angles + ply.ezc_MovementInertiaAddView
		ply.ezc_MovementInertiaAddView.r = Lerp(FrameTime() * 5, ply.ezc_MovementInertiaAddView.r, 0)
		ply.ezc_MovementInertiaAddView.p = Lerp(FrameTime() * 5, ply.ezc_MovementInertiaAddView.p, 0)
	end

	return origin, angles
end

-- ============================================
-- cam_things - View angle offsets (velocity sway, lean roll)
-- Source: cl_camera.lua:612-668
-- ============================================
local eyeAnglesOld
local torsoOld

function ezc.cam_things(ply, view, angles)
	local wep = ply:GetActiveWeapon()
	local eyeAngs = ply:EyeAngles()
	eyeAngs[3] = 0
	local oldviewa = oldview or view

	local ent = ply
	if not ent:LookupBone("ValveBiped.Bip01_Spine") then return end
	if not ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Spine")) then return end

	local torso = ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Spine")):GetAngles()
	oldviewa = not ply:Alive() and view or oldviewa

	-- Angle difference calculation
	-- Source: cl_camera.lua:624-637
	local different, _ = WorldToLocal(eyeAngs:Forward(), angle_zero, (eyeAnglesOld or eyeAngs):Forward(), angle_zero)
	local different2, _ = WorldToLocal(torso:Forward(), angle_zero, (torsoOld or torso):Forward(), angle_zero)
	local _, localAng = WorldToLocal(vector_origin, eyeAngs, vector_origin, eyeAnglesOld or eyeAngs)

	torsoOld = torso

	local fthuy = math.max(ftlerped * 150 * game.GetTimeScale(), 0.0001)

	angle_difference_localvec = LerpVectorFT(0.08, angle_difference_localvec, -different / fthuy)
	angle_difference_localvec2 = LerpVectorFT(0.08, angle_difference_localvec2, -different2 / fthuy)
	angle_difference = LerpAngleFT(0.08, angle_difference, localAng * 2 / fthuy)
	angle_difference2 = LerpAngleFT(0.1, angle_difference2, localAng * 2 / fthuy)

	local vela = -(ply:GetVelocity() / 50)
	position_difference = LerpVectorFT(0.15, position_difference, vela)
	position_difference2 = LerpVectorFT(0.05, position_difference2, vela)
	position_difference23 = ply:EyeAngles():Right() * math.Clamp(position_difference2:Dot(ply:EyeAngles():Right()), -4, 4)
		+ ply:EyeAngles():Up() * math.Clamp(position_difference2:Dot(ply:EyeAngles():Up()), -4, 4)

	table.CopyFromTo(view, oldview)

	position_difference3[1] = 0
	position_difference3[3] = 0
	position_difference3[2] = position_difference:Dot(eyeAngs:Right())

	-- Clamp values
	ezc.clamp(position_difference, 2)
	ezc.clamp(position_difference3, 5)
	ezc.clamp(angle_difference_localvec, 10)
	ezc.clamp(angle_difference, 10)
	ezc.clamp(angle_difference2, 10)

	-- Offset view
	if not ply:KeyDown(IN_SPEED) then
		offsetView[1] = math.Clamp(offsetView[1] - angle_difference2[1] / 18, -2, 2)
		offsetView[2] = math.Clamp(offsetView[2] - angle_difference2[2] / 18, -4, 4)
	end

	offsetView = LerpFT(0.001, offsetView, angle_zero)
	eyeAnglesOld = eyeAngs

	-- Camera roll from mouse velocity and lean
	-- Source: cl_camera.lua:665-667
	angles[3] = angles[3] - angle_difference[2] * 0.05
	angles[3] = angles[3] - (ezc.lean_lerp or 0) * ezc.leancam_mul:GetInt()
end

-- ============================================
-- CalcView - Main camera function
-- Source: cl_camera.lua:306-607
-- ============================================
function ezc.CalcView(ply, origin, angles, fov, znear, zfar)
	if GetViewEntity() ~= (ply or LocalPlayer()) then return end

	local view = {
		origin = origin,
		angles = angles,
		fov = fov,
		znear = znear,
		zfar = zfar,
		drawviewer = false,
	}

	-- FOV adjustments
	-- Source: cl_camera.lua:322-323
	lerpfovadd = LerpFT(0.01, lerpfovadd, ply:IsSprinting() and ply:GetVelocity():LengthSqr() > 1500 and 10 or 0)
	lerpfovadd2 = LerpFT(0.1, lerpfovadd2, zooming and -25 or 0)

	if not IsValid(ply) then return end

	-- Lean reset
	-- Source: cl_camera.lua:332-335
	if ply.ezc_lean and math.abs(ply.ezc_lean) < 0.01 then
		ezc.lean_lerp = 0
	end

	-- View punch angles
	-- Source: cl_camera.lua:339
	local vpang = ezc.GetViewPunchAngles2() + ezc.GetViewPunchAngles3()
	vpang[3] = 0

	-- Handle death/spectating
	-- Source: cl_camera.lua:354-367
	if not ply:Alive() then
		return
	end

	-- Bone check
	-- Source: cl_camera.lua:369
	if not ply.LookupBone or not ply:LookupBone("ValveBiped.Bip01_Head1") then return end
	if not ply.GetAimVector then return end

	local firstPerson = GetViewEntity() == LocalPlayer()
	if not firstPerson then return end

	-- Eye attachment for camera position
	-- Source: cl_camera.lua:380-381
	local att = ply:GetAttachment(ply:LookupAttachment("eyes"))
	if not att or not istable(att) then return end

	-- Eye trace from neck bone (Z-City style, not ply:EyePos())
	-- Source: cl_camera.lua:388
	local eyeTrace = ezc.eyeTrace(ply, 10, ply, att.Ang)

	-- Camera origin from eye trace
	local eyePos = eyeTrace and eyeTrace.StartPos or att.Pos

	-- View FOV
	-- Source: cl_camera.lua:535
	view.fov = math.Clamp(ezc.fov:GetFloat(), 75, 100) + lerpfovadd + lerpfovadd2

	-- Velocity calculation
	-- Source: cl_camera.lua:403
	local vel = ply:GetMoveType() ~= MOVETYPE_NOCLIP and (-ply:GetVelocity() / 200) or vector_origin
	local velLen = vel:Length() or 0

	-- Random positional jitter from velocity
	-- Source: cl_camera.lua:443
	if velLen > 2 then
		eyePos:Add(VectorRand() * (velLen + 0) / 10)
	end
	ezc.clamp(vel, 4)

	-- cam_things (called BEFORE third person branch in original)
	-- Source: cl_camera.lua:449
	ezc.cam_things(ply, view, angles)

	-- ==========================================
	-- Third Person Camera
	-- Source: cl_camera.lua:468-531
	-- ==========================================
	if ezc.thirdperson:GetBool() then
		lerpasad = Lerp(0.1, lerpasad, (IsAimingNoScope(ply) or ezc.legacycam:GetBool()) and 0.001 or 1)

		-- Camera position from neck bone (Z-City style)
		-- Source: cl_camera.lua:476
		local tpEyePos = ezc.eye(ply, 10) or ply:EyePos()
		local tpAng = ply:EyeAngles()

		if ezc.thirdperson_orbit:GetBool() and ply:Alive() then
			-- Orbit mode: trigonometric positioning (no gimbal lock)
			-- Source: cl_camera.lua:479-530
			if prevRagdoll then
				tp_orbit_ang.yaw = 0
				tp_orbit_ang.pitch = 0
				prevRagdoll = false
			end

			local camDist = 60 * lerpasad * tp_orbit_dist
			local yawRad = math.rad(tp_orbit_ang.yaw)
			local pitchRad = math.rad(tp_orbit_ang.pitch)

			local rightDist = math.sin(yawRad) * camDist
			local backDist = -math.cos(yawRad) * math.cos(pitchRad) * camDist
			local upDist = math.sin(pitchRad) * camDist

			local offset = tpAng:Right() * rightDist + tpAng:Forward() * backDist + tpAng:Up() * upDist

			local tr = {
				start = tpEyePos,
				endpos = tpEyePos + offset,
				filter = {ply},
				mask = MASK_SOLID,
			}

			view.origin = util.TraceLine(tr).HitPos + ((tr.endpos - tr.start):GetNormalized() * -5)

			if lerpasad > 0.1 then
				view.angles = (tpEyePos - view.origin):Angle()
			else
				local forward = angles:Forward() * math.cos(yawRad) * math.cos(pitchRad)
					+ angles:Right() * math.sin(yawRad)
					+ angles:Up() * math.sin(pitchRad)
				view.angles = forward:Angle()
			end
		else
			-- Simple third person
			-- Source: cl_camera.lua:517-526
			local leanmul1 = ((ply.ezc_lean or 0) < 0 and (ply.ezc_lean or 0) * 2.2 or 0) + 1

			local tr = {
				start = tpEyePos,
				endpos = tpEyePos - tpAng:Forward() * 60 * lerpasad + tpAng:Right() * 15 * lerpasad,
				filter = {ply},
				mask = MASK_SOLID,
			}

			view.origin = util.TraceLine(tr).HitPos + ((tr.endpos - tr.start):GetNormalized() * -5)
			view.angles = angles
		end

		view.drawviewer = true
		view.fov = 95 + lerpfovadd + lerpfovadd2
		return view
	end

	-- ==========================================
	-- First Person Camera
	-- Source: cl_camera.lua:533-606
	-- ==========================================
	view.znear = 1
	view.fov = math.Clamp(ezc.fov:GetFloat(), 75, 100) + lerpfovadd + lerpfovadd2
	view.drawviewer = true
	view.origin = eyePos  -- Use neck bone, not ply:EyePos()
	view.angles = angles

	-- Camera hook (weapon iron sights)
	-- Source: cl_camera.lua:547-548
	local wep = ply:GetActiveWeapon()
	local camResult
	if IsValid(wep) and wep.IsEZCWeapon and wep.Camera then
		local result = wep:Camera(eyePos, angles, view, ply:GetVelocity():Length() * 200)
		if result then
			view = result
			camResult = result
		end
	end

	-- Apply view effects (breathing, walk bob, inertia)
	-- Source: cl_camera.lua:552
	view.origin, view.angles = ezc.AddView(ply, view.origin, view.angles, ply:GetVelocity():Length())

	-- Cool camera mode
	-- Source: cl_camera.lua:557-563
	realangle = realangle or ply:EyeAngles()
	if ezc.coolcamera:GetBool() then
		view.angles = realangle + ezc.GetViewPunchAngles() * 0.4 + vpang
		view.angles[3] = view.angles[3] - ezc.GetViewPunchAngles4()[3]
		angles = view.angles
	end

	-- Alt-look (freelook)
	-- Source: cl_camera.lua:563-564
	view.angles:RotateAroundAxis(view.angles:Up(), -LookX)
	view.angles:RotateAroundAxis(view.angles:Right(), -LookY)

	-- GoPro mode
	-- Source: cl_camera.lua:571-579
	if ezc.gopro:GetBool() then
		view.origin = att.Pos + att.Ang:Up() * 6 + att.Ang:Forward() * -3 + att.Ang:Right() * 6.5
		view.angles = att.Ang + Angle(5, 2, 0)
		view.fov = 110
		view.drawviewer = true
		view.znear = 0.7
		return view
	end

	-- Camera hook result handling
	-- Source: cl_camera.lua:581-607
	if camResult == view then
		-- Camera hook modified the view, do hull check
		-- Source: cl_camera.lua:582-590
		local trace = ezc.hullCheck(ply:EyePos() - vector_up * 10, view.origin, ply)
		view.origin = trace.HitPos

		view.angles:Add(-vpang)
		view.angles[3] = view.angles[3] + ezc.GetViewPunchAngles4()[3]
		return view
	end

	-- Standard first person (no weapon camera override)
	-- Source: cl_camera.lua:593-606
	view.origin = eyePos
	view.angles = angles

	view.angles:Add(-vpang)
	view.angles[3] = view.angles[3] + ezc.GetViewPunchAngles4()[3]

	return view
end

-- ============================================
-- Input Mouse Apply (alt-look + orbit)
-- Source: cl_camera.lua:680-749
-- Z-City uses a custom HG.InputMouseApply hook with a table wrapper.
-- We use standard InputMouseApply(cmd, x, y, angle) directly.
-- ============================================
local MaxLookX, MinLookX = 55, -55
local MaxLookY, MinLookY = 45, -45

hook.Add("InputMouseApply", "ezc_input", function(cmd, x, y, angle)
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end

	-- === Alt-Look ===
	if not altlook then
		LookY = LerpFT(0.1, LookY, 0)
		LookY = math.abs(LookY) > 0.01 and LookY or 0
		LookX = LerpFT(0.1, LookX, 0)
		LookX = math.abs(LookX) > 0.01 and LookX or 0
	end

	if altlook then
		LookX = math.Clamp(LookX + x * 0.015, MinLookX, MaxLookX)
		LookY = math.Clamp(LookY + y * 0.015, MinLookY, MaxLookY)
		-- Prevent player rotation in alt-look
		return true
	end

	-- === Third Person Orbit ===
	if not ezc.thirdperson:GetBool() or not ezc.thirdperson_orbit:GetBool() then
		ezc.ThirdPersonOrbitActive = false
		return
	end

	local moving = ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK) or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT)
	local aiming = IsAimingNoScope(ply)

	if moving or aiming then
		-- Auto-return behind player when moving
		tp_orbit_ang.yaw = LerpFT(0.1, tp_orbit_ang.yaw, 0)
		tp_orbit_ang.pitch = LerpFT(0.1, tp_orbit_ang.pitch, 0)
		if math.abs(tp_orbit_ang.yaw) < 0.5 and math.abs(tp_orbit_ang.pitch) < 0.5 then
			tp_orbit_ang.yaw = 0
			tp_orbit_ang.pitch = 0
		end
		ezc.ThirdPersonOrbitActive = false
		return
	end

	-- Orbit mode when standing still
	ezc.ThirdPersonOrbitActive = true

	local sens = GetConVar("sensitivity"):GetFloat() * 0.03
	tp_orbit_ang.yaw = tp_orbit_ang.yaw - x * sens
	tp_orbit_ang.pitch = tp_orbit_ang.pitch + y * sens
	tp_orbit_ang.pitch = math.NormalizeAngle(tp_orbit_ang.pitch)
	tp_orbit_ang.yaw = math.NormalizeAngle(tp_orbit_ang.yaw)

	-- Prevent player rotation (orbit angles are separate)
	return true
end)

-- Orbit scroll zoom
-- Source: cl_camera.lua:752-762
hook.Add("PlayerBindPress", "ezc_orbit_scroll", function(ply, bind, pressed)
	if not ezc.ThirdPersonOrbitActive then return end
	if bind == "invprev" or bind == "invnext" then
		if bind == "invprev" then
			tp_orbit_dist = math.Clamp(tp_orbit_dist - 0.1, 0.3, 2)
		else
			tp_orbit_dist = math.Clamp(tp_orbit_dist + 0.1, 0.3, 2)
		end
		return true
	end
end, "HIGHEST")

-- ============================================
-- Head bone scaling (hide head in first person, show in third person)
-- Source: cl_camera.lua:463, fake/sh_render.lua
-- ============================================
hook.Add("PrePlayerDraw", "ezc_hide_head", function(ply)
	if CLIENT and ply == LocalPlayer() and GetViewEntity() == ply then
		local hide = not ezc.thirdperson:GetBool()
		ezc.HideHead(ply, hide)
	end
end)

-- ============================================
-- Register CalcView
-- Source: cl_camera.lua:765-769
-- ============================================
hook.Add("CalcView", "ezc_view", function(ply, origin, angles, fov, znear, zfar)
	return ezc.CalcView(ply, origin, angles, fov, znear, zfar)
end)
