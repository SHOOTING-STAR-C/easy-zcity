--[[
	ezcity Weapon Camera (Iron Sights / Aiming)
	Source: lua/weapons/homigrad_base/cl_camera.lua
	SWEP:Camera positions the camera at the weapon's sight when aiming
]]

local SWEP = baseclass.Get("weapon_base")
if not SWEP then return end

-- ============================================
-- GetZoomPos - Calculate camera position at weapon sight
-- Source: cl_camera.lua:53-110
-- ============================================
function SWEP:GetZoomPos(recoilZoomPos, view, eyePos)
	recoilZoomPos = recoilZoomPos or vecZero
	local gun = self:GetWeaponEntity()
	if not IsValid(gun) then return eyePos or vector_origin, (view and view.angles or angle_zero) end

	local pos, ang = gun:GetPos(), gun:GetAngles()

	if self.WorldModelFake then
		local mat = Matrix()
		mat:SetTranslation(self.FakePos or Vector())
		mat:SetAngles(self.FakeAng or Angle())
		mat = mat:GetInverse()
		pos, ang = LocalToWorld(mat:GetTranslation(), mat:GetAngles(), gun:GetPos(), gun:GetAngles())
	end

	local zoomPos = self.ZoomPos or Vector()
	local _, ang2 = self:GetTrace(true, nil, nil, true)

	local posZoom = LocalToWorld(zoomPos, angle_zero, pos, ang2)

	-- Sight alignment
	if eyePos then
		if self.HasAttachment and self:HasAttachment("sight", "optic") then
			posZoom = posZoom - recoilZoomPos * 0.25 - ang2:Forward() * ((self.AdditionalPos2 and self.AdditionalPos2[1]) or 0) * 0.5 + ang2:Forward() * 1
		else
			local _, hitpos, dist = util.DistanceToLine(posZoom, posZoom + (self:GetOwner():GetAimVector()), eyePos)
			dist = dist - 1
			posZoom = posZoom + ang2:Forward() * dist - recoilZoomPos * 0.5
		end
	end

	return posZoom, ang2
end

-- ============================================
-- Camera - Main weapon camera function
-- Source: cl_camera.lua:162-374
-- Called by the Camera hook in cl_view.lua
-- ============================================
local vecZero = Vector(0, 0, 0)
local fov_mode_lerp = 0
local recoilZoomPos = Vector(0, 0, 0)

function SWEP:Camera(eyePos, eyeAng, view, vellen, ply)
	if not IsValid(self) then return end

	local ply = ply or self:GetOwner()
	if not IsValid(ply) then return end

	-- Draw world model (replaces viewmodel)
	if ezc.IsEZCWeapon(self) then
		self:DrawWorldModel()
	end

	if not ply.GetAimVector then return end

	local aimvec = ply:GetAimVector():Angle()
	local up, right, forward = aimvec:Up(), aimvec:Right(), aimvec:Forward()

	-- Calculate zoom position
	local posZoom, angPos = self:GetZoomPos(recoilZoomPos or vecZero, view, eyePos)

	-- Aim state
	local zooming = self:IsZoom()
	local k = self.k or 0
	self.k = Lerp(FrameTime() * 5, k, zooming and 1 or 0)
	k = math.min(1, k)

	if self.deploy or self.holster then self.k = 0 end

	-- Output position and angle
	local outputPos = LerpVector(k, eyePos, posZoom)
	local outputAng = eyeAng  -- Keep eye angles, position changes only

	-- Camera sway from view angle differences
	-- Source: cl_camera.lua:315
	outputPos:Add(-(angle_difference_localvec or vecZero) * 30 * (-k + 2) * 2 / (self.Ergonomics or 1)
		+ (position_difference23 or vecZero) * 0.25 * (-k + 1.25))

	-- FOV adjustment
	-- Source: cl_camera.lua:353-358
	fov_mode_lerp = LerpFT(0.12, fov_mode_lerp, -15 - (ezc.fov:GetInt() - 75))
	view.fov = view.fov + fov_mode_lerp * k

	view.origin = outputPos
	view.angles = outputAng

	return view
end

-- ============================================
-- GetTrace - Weapon barrel trace
-- Source: cl_camera.lua (from various weapon methods)
-- ============================================
function SWEP:GetTrace(ignoreMuzzle, ...)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local gun = self:GetWeaponEntity()
	if not IsValid(gun) then return end

	local att = gun:GetAttachment(gun:LookupAttachment("muzzle"))
	if not att then
		return owner:EyePos(), owner:GetAimVector():Angle()
	end

	return att.Pos, att.Ang
end
