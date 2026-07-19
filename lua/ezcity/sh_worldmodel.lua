--[[
	ezcity World Model Rendering
	Source: lua/weapons/homigrad_base/sh_worldmodel.lua
	Weapons are rendered as world models on the right hand instead of viewmodels
]]

local SWEP = baseclass.Get("weapon_base")
if not SWEP then return end

-- Disable standard viewmodels only for ezcity weapons
-- Source: sh_worldmodel.lua:894-896

function SWEP:ShouldDrawViewModel()
	return not self.IsEZCWeapon
end

-- ============================================
-- Create world model
-- Source: sh_worldmodel.lua:476-558
-- ============================================
function SWEP:CreateWorldModel()
	if self.WorldModelFake then
		self.worldModel = ClientsideModel(self.WorldModelFake)
	else
		self.worldModel = ClientsideModel(self.WorldModel)
	end

	if not IsValid(self.worldModel) then return end

	self.worldModel:SetNoDraw(true)
	self.worldModel:SetModelScale(1, 0)
	self.worldModel:SetParent(self)
	self.worldModel:AddEffects(EF_BONEMERGE_FASTCULL)
	-- For fake view model in first person
	if self.WorldModelFake then
		self.worldModel:SetNoDraw(false)
	end

	return self.worldModel
end

function SWEP:GetWM()
	return self.worldModel
end

-- ============================================
-- Should use fake model in first person
-- Source: sh_worldmodel.lua:820-871
-- ============================================
function SWEP:ShouldUseFakeModel()
	if not self:IsLocal() then return false end
	local owner = self:GetOwner()
	if not IsValid(owner) then return false end

	local ent = GetViewEntity()
	if ent == owner then
		return true
	end

	return false
end

-- ============================================
-- World Model Transform - position weapon on right hand
-- Source: sh_worldmodel.lua:561-672
-- ============================================
function SWEP:WorldModel_Transform(boneOverwrite)
	if not IsValid(self) then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local WM = self:GetWM()
	if not IsValid(WM) then return end

	WM:SetNoDraw(false)

	-- Get right hand bone
	local bone = boneOverwrite or owner:LookupBone("ValveBiped.Bip01_R_Hand")
	if not bone then return end

	local bonemat = owner:GetBoneMatrix(bone)
	if not bonemat then return end

	local pos, ang = self:PosAngChanges(bonemat)

	if pos then
		-- Reset bone merge and position manually
		WM:RemoveEffects(EF_BONEMERGE)
		WM:SetPos(pos)
		WM:SetAngles(ang)

		-- Recalculate bone angles for attachments
		WM:SetupBones()
	end
end

-- ============================================
-- World Model Transform Holstered
-- Source: sh_worldmodel.lua
-- ============================================
function SWEP:WorldModel_Transform_Holstered()
	if not IsValid(self) then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local WM = self:GetWM()
	if not IsValid(WM) then return end

	-- Put weapon on back/spine when holstered
	local bone = owner:LookupBone("ValveBiped.Bip01_Spine4")
	if not bone then return end

	local bonemat = owner:GetBoneMatrix(bone)
	if not bonemat then return end

	local pos, ang = bonemat:GetTranslation(), bonemat:GetAngles()

	pos = pos + ang:Right() * -8 + ang:Up() * -5 + ang:Forward() * -5

	WM:SetPos(pos)
	WM:SetAngles(ang)
	WM:SetupBones()

	self:ClearAttModels()
end

-- ============================================
-- Position/Angle Changes - calculate final weapon position from hand
-- Source: sh_worldmodel.lua:153-283
-- ============================================
function SWEP:PosAngChanges(bonemat)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local pos, ang = bonemat:GetTranslation(), bonemat:GetAngles()

	-- Additional position/angle offsets
	local addPos = self.AdditionalPos or Vector(0, 0, 0)
	local addAng = self.AdditionalAng or Angle(0, 0, 0)
	local addPos2 = self.AdditionalPos2 or Vector(0, 0, 0)
	local addAng2 = self.AdditionalAng2 or Angle(0, 0, 0)

	-- Apply custom viewmodel-like offsets
	pos = pos + ang:Right() * (addPos.x + addPos2.x)
		+ ang:Forward() * (addPos.y + addPos2.y)
		+ ang:Up() * (addPos.z + addPos2.z)

	ang:RotateAroundAxis(ang:Right(), addAng.p + addAng2.p)
	ang:RotateAroundAxis(ang:Up(), addAng.y + addAng2.y)
	ang:RotateAroundAxis(ang:Forward(), addAng.r + addAng2.r)

	return pos, ang
end

-- ============================================
-- Draw World Model
-- Source: sh_worldmodel.lua:299-462
-- ============================================
local function DrawWorldModel(self, force)
	if not IsValid(self) or not self.WorldModel_Transform then return end
	local owner = self:GetOwner()

	if not IsValid(self.worldModel) then
		self.worldModel = self:CreateWorldModel()
	end

	if not IsValid(self.worldModel) then return end

	local localdraw = self:IsLocal2() and owner:GetActiveWeapon() == self and not owner:InVehicle() and not force
	local willdraw = false

	if not localdraw then
		if IsValid(owner) and owner:IsPlayer() then
			if owner:GetActiveWeapon() ~= self or owner:IsRagdoll() then
				if not self.shouldntDrawHolstered then
					self:WorldModel_Transform_Holstered()
					willdraw = true
				else
					self.worldModel:SetNoDraw(true)
					self:ClearAttModels()
					return
				end
			elseif owner:GetActiveWeapon() == self then
				self:WorldModel_Transform()
				willdraw = true
			end
		elseif not IsValid(owner) then
			self:WorldModel_Transform()
			willdraw = true
		end
	else
		willdraw = true
	end

	if IsValid(self.worldModel) and willdraw then
		-- In first person, use FakeViewModel for proper positioning
		if self:ShouldUseFakeModel() then
			-- Calculate view bob from weapon bone
			local WorldModel = self.worldModel
			local camBone = WorldModel:LookupBone("Weapon")
			or WorldModel:LookupBone("ValveBiped.Bip01_R_Hand")

			if camBone then
				local matrix = WorldModel:GetBoneMatrix(camBone)
				if matrix then
					local gAngles = matrix:GetAngles()
					local _, gAngles = WorldToLocal(vector_origin, gAngles,
						WorldModel:GetPos(),
						(WorldModel:GetBoneMatrix(WorldModel:LookupBone("ValveBiped.Bip01_R_Hand") or 0) or WorldModel:GetBoneMatrix(0)):GetAngles()
					)
					self.OldAngPunch = self.OldAngPunch or gAngles
					local punch = (self.OldAngPunch - gAngles) / (self.ViewPunchDiv or 50)
					ViewPunch2(-punch)
					ViewPunch(punch)
					self.OldAngPunch = gAngles
				end
			end

			self:FakeViewModel()
		end

		self.worldModel:DrawModel()

		-- Draw attachment models
		if self.DrawPost then self:DrawPost() end
	end
end

-- Override DrawWorldModel (ezcity weapons only)
function SWEP:DrawWorldModel(flags)
	if not self.IsEZCWeapon then return end
	DrawWorldModel(self, flags)
end

-- ============================================
-- Fake View Model (first-person rendering)
-- Source: sh_worldmodel.lua:535-558
-- ============================================
function SWEP:FakeViewModel()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local WM = self:GetWM()
	if not IsValid(WM) then return end

	-- Head bone is hidden in first person
	-- This is handled by ezcity_init.lua's RenderScene or CalcView

	-- Apply animation
	if self.seq and WM.SetSequence then
		WM:SetSequence(self.seq)
	end

	if not self.cycling then
		local timing = self.animtime and (1 - math.Clamp((self.animtime - CurTime()) / (self.animspeed or 1), 0, 1)) or 0
		WM:SetCycle(timing)

		if self.callback and timing >= 1 then
			self.callback(self)
			self.callback = nil
		end
	end
end

-- ============================================
-- Clear attachment models
-- Source: sh_worldmodel.lua
-- ============================================
function SWEP:ClearAttModels()
	if self.attmodels then
		for _, mdl in pairs(self.attmodels) do
			if IsValid(mdl) then
				mdl:SetNoDraw(true)
			end
		end
	end

	if self.holomodels then
		for mdl in pairs(self.holomodels) do
			if IsValid(mdl) then
				mdl:SetNoDraw(true)
			end
		end
	end
end

-- ============================================
-- Draw Post (attachment models)
-- Source: sh_worldmodel.lua
-- ============================================
function SWEP:DrawPost()
	if self.attmodels then
		for _, mdl in pairs(self.attmodels) do
			if IsValid(mdl) then
				mdl:DrawModel()
			end
		end
	end
end

-- ============================================
-- Set Hand Position (for TPIK)
-- Source: shared.lua in weapons/homigrad_base
-- ============================================
function SWEP:SetHandPos()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	-- Right hand follows the weapon
	self.rhandik = true

	-- Left hand position (two-handed weapons)
	if self.lhandik ~= nil then
		self.lhandik = true
	end
end
