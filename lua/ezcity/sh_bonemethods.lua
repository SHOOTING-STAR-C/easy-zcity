--[[
	ezcity Bone Manipulation Layer System
	Source: lua/homigrad/sh_bonemethods.lua
	Multi-layer bone manipulation (lean, crouch, holding, headturn)
	Each layer independently adds its offset and layers are combined
]]

ezc.bone = ezc.bone or {}
ezc.bone.boneNames = ezc.boneNames

local vecZero, angZero, vecFull = Vector(0, 0, 0), Angle(0, 0, 0), Vector(1, 1, 1)
local CurTime, LerpVector, LerpAngle = CurTime, LerpVector, LerpAngle

-- ============================================
-- Reset all bone manipulations to zero
-- ============================================
local function reset(ply)
	ply.ezc_manipulated = nil
	ply.ezc_unmanipulated = {}
	ply.ezc_matrixes = {}

	for bone = 0, ply:GetBoneCount() do
		ply:ManipulateBonePosition(bone, vecZero, true)
		ply:ManipulateBoneAngles(bone, angZero, true)
		ply:ManipulateBoneScale(bone, vecFull, true)
	end
end

hook.Add("PlayerGetup", "ezc_bones_reset", function(ply)
	reset(ply)
end)

-- ============================================
-- Create a layer for a specific bone
-- ============================================
local function createLayer(ply, boneID, layer)
	ply.ezc_manipulated = ply.ezc_manipulated or {}
	ply.ezc_manipulated[boneID] = ply.ezc_manipulated[boneID] or {}
	ply.ezc_manipulated[boneID].Pos = ply.ezc_manipulated[boneID].Pos or Vector(0, 0, 0)
	ply.ezc_manipulated[boneID].Ang = ply.ezc_manipulated[boneID].Ang or Angle(0, 0, 0)
	ply.ezc_manipulated[boneID].layers = ply.ezc_manipulated[boneID].layers or {}
	ply.ezc_manipulated[boneID].layers[layer] = ply.ezc_manipulated[boneID].layers[layer] or {Pos = Vector(0, 0, 0), Ang = Angle(0, 0, 0)}
end

-- ============================================
-- Set a bone with layer system
-- Source: sh_bonemethods.lua:391-421
-- ply: player
-- lookup_name: bone name string or bone ID number
-- vec/ang: target position/angle offset
-- layer: layer name string
-- lerp: lerp speed (optional)
-- dtime: delta time for lerp (optional)
-- ============================================
function ezc.bone.Set(ply, lookup_name, vec, ang, layer, lerp, dtime)
	local boneName = ezc.boneNames[lookup_name]
	local boneID = isnumber(lookup_name) and lookup_name or ply:LookupBone(boneName or lookup_name)

	if not boneID then return end

	layer = layer or "unspecified"

	if layer and layer ~= "all" then
		createLayer(ply, boneID, layer)

		if lerp then
			vec = LerpVector(ezc.lerpFrameTime(lerp, dtime), ply.ezc_manipulated[boneID].layers[layer].Pos, vec)
			ang = LerpAngle(ezc.lerpFrameTime(lerp, dtime), ply.ezc_manipulated[boneID].layers[layer].Ang, ang)
		end

		local oldpos, oldang = ezc.bone.Get(ply, boneID)
		local setPos = oldpos and (oldpos - ply.ezc_manipulated[boneID].layers[layer].Pos + vec) or vec
		local setAng = oldang and (oldang - ply.ezc_manipulated[boneID].layers[layer].Ang + ang) or ang

		ezc.bone.SetRaw(ply, boneID, setPos, setAng)

		ply.ezc_manipulated[boneID].layers[layer].Pos = vec
		ply.ezc_manipulated[boneID].layers[layer].Ang = ang
		ply.ezc_manipulated[boneID].layers[layer].lastset = CurTime()
	end
end

-- ============================================
-- Direct bone manipulation (no layer)
-- Source: sh_bonemethods.lua:423-432
-- ============================================
function ezc.bone.SetRaw(ply, boneID, vec, ang)
	ply.ezc_manipulated = ply.ezc_manipulated or {}
	ply.ezc_manipulated[boneID] = ply.ezc_manipulated[boneID] or {}

	ply.ezc_manipulated[boneID].Pos = vec
	ply.ezc_manipulated[boneID].Ang = ang

	ply:ManipulateBonePosition(boneID, vec, false)
	ply:ManipulateBoneAngles(boneID, ang, false)
end

-- ============================================
-- Get current bone manipulation values
-- Source: sh_bonemethods.lua:434-441
-- ============================================
function ezc.bone.Get(ply, lookup_name)
	local boneName = ezc.boneNames[lookup_name]
	local boneID = isnumber(lookup_name) and lookup_name or ply:LookupBone(boneName or lookup_name)

	if not boneID or not ply.ezc_manipulated or not ply.ezc_manipulated[boneID] then return vecZero, angZero end

	return ply.ezc_manipulated[boneID].Pos, ply.ezc_manipulated[boneID].Ang
end

-- ============================================
-- Apply a matrix directly to a bone (for TPIK)
-- Source: cl_tpik.lua (bone_apply_matrix pattern)
-- ============================================
function ezc.bone_apply_matrix(ent, idx, matrix, childIdx)
	local old_matrix = ent.ezc_unmanipulated and ent.ezc_unmanipulated[idx] or ent:GetBoneMatrix(idx)
	if not old_matrix or not matrix then return end

	local lmat = old_matrix:GetInverse() * matrix
	local ang = lmat:GetAngles()
	local matp = childIdx and (ent.ezc_unmanipulated and ent.ezc_unmanipulated[childIdx] or ent:GetBoneMatrix(childIdx)) or old_matrix

	local vec, _ = WorldToLocal(matrix:GetTranslation(), angle_zero, old_matrix:GetTranslation(), matp:GetAngles())

	ent:ManipulateBonePosition(idx, vec, false)
	ent:ManipulateBoneAngles(idx, ang, false)
end

-- ============================================
-- Head bone scale manipulation (hide head in first person)
-- Source: fake/sh_render.lua
-- ============================================
function ezc.HideHead(ply, hide)
	local headIdx = ply:LookupBone("ValveBiped.Bip01_Head1")
	if not headIdx then return end

	if hide then
		ply:ManipulateBoneScale(headIdx, Vector(0.001, 0.001, 0.001))
	else
		ply:ManipulateBoneScale(headIdx, Vector(1, 1, 1))
	end
end

-- ============================================
-- Cleanup layer system for bones that haven't been updated
-- Source: sh_bonemethods.lua:159-220 (simplified)
-- ============================================
hook.Add("PlayerThink", "ezc_bones_think", function(ply, time, dtime)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

	local time = CurTime()

	if not ply.ezc_manipulated then return end

	for bone, tbl in pairs(ply.ezc_manipulated) do
		if tbl.layers then
			for layer, ltbl in pairs(tbl.layers) do
				if ltbl.lastset and ltbl.lastset ~= time then
					if ltbl.Pos:IsEqualTol(vecZero, 0.01) and ltbl.Ang:IsEqualTol(angZero, 0.01) then
						ply.ezc_manipulated[bone] = nil
						break
					end
				end
			end
		end
	end
end)
