--[[
	ezcity Weapon Shared Methods
	Source: lua/weapons/homigrad_base/shared.lua
	Core SWEP methods for aiming, sprinting, and usability checks
]]

local SWEP = baseclass.Get("weapon_base")
if not SWEP then return end

-- Tag weapons that use ezcity system (default false, weapons opt-in)
SWEP.IsEZCWeapon = false

-- ============================================
-- Position/angle offsets (set by each weapon)
-- Source: shared.lua:1412-1418
-- ============================================
SWEP.AdditionalPos = Vector(0, 0, 0)
SWEP.AdditionalPos2 = Vector(0, 0, 0)
SWEP.AdditionalAng = Angle(0, 0, 0)
SWEP.AdditionalAng2 = Angle(0, 0, 0)
SWEP.ZoomPos = Vector()  -- Camera position when aiming

-- ============================================
-- IsZoom - Check if weapon is aiming down sights
-- Source: shared.lua:294-308
-- Only applies to ezcity weapons
-- ============================================
function SWEP:IsZoom()
	if not self.IsEZCWeapon then return false end
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return false end

	return self:CanUse() and
		(self:KeyDown(IN_ATTACK2) and not self:IsSprinting()) and
		(owner:IsOnGround() or owner:InVehicle()) and
		not owner.suiciding
end

-- ============================================
-- CanUse - Check if weapon is usable
-- Source: shared.lua:310-316
-- ============================================
function SWEP:CanUse()
	if not self.IsEZCWeapon then return true end
	local owner = self:GetOwner()
	if not IsValid(owner) then return true end
	if owner:IsNPC() then return true end
	return not (self.reload or self.deploy or self:IsSprinting())
end

-- ============================================
-- IsSprinting - Check if player is running
-- Source: shared.lua:318-325
-- ============================================
function SWEP:IsSprinting()
	local ply = self:GetOwner()
	if not IsValid(ply) or ply:IsNPC() then return false end
	return ply:KeyDown(IN_SPEED) and ply:GetVelocity():LengthSqr() > 150 * 150
end

-- ============================================
-- IsLocal / IsLocal2
-- Source: shared.lua:327-333
-- ============================================
function SWEP:IsLocal()
	return CLIENT and self:GetOwner() == LocalPlayer()
end

function SWEP:IsLocal2()
	return CLIENT and self:IsLocal() and LocalPlayer() == GetViewEntity()
end

-- ============================================
-- IsPistolHoldType - Check hold type
-- Only applies to ezcity weapons
-- ============================================
function SWEP:IsPistolHoldType()
	if not self.IsEZCWeapon then return false end
	return self.HoldType == "pistol" or self.HoldType == "revolver" or self.PistolKinda
end
