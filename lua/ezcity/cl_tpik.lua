--[[
	ezcity TPIK (Third Person Inverse Kinematics)
	Source: lua/homigrad/cl_tpik.lua
	Arm IK system for holding weapons as world models
]]

if SERVER then return end

-- ============================================
-- Bone Name Dictionaries
-- Source: cl_tpik.lua:1-185
-- ============================================
local TPIKBones = {
	"ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_L_Ulna",
	"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Finger4",
	"ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42",
	"ValveBiped.Bip01_L_Finger3", "ValveBiped.Bip01_L_Finger31",
	"ValveBiped.Bip01_L_Finger32", "ValveBiped.Bip01_L_Finger2",
	"ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22",
	"ValveBiped.Bip01_L_Finger1", "ValveBiped.Bip01_L_Finger11",
	"ValveBiped.Bip01_L_Finger12", "ValveBiped.Bip01_L_Finger0",
	"ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02",
	"ValveBiped.Bip01_R_Wrist", "ValveBiped.Bip01_R_Ulna",
	"ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Finger4",
	"ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42",
	"ValveBiped.Bip01_R_Finger3", "ValveBiped.Bip01_R_Finger31",
	"ValveBiped.Bip01_R_Finger32", "ValveBiped.Bip01_R_Finger2",
	"ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22",
	"ValveBiped.Bip01_R_Finger1", "ValveBiped.Bip01_R_Finger11",
	"ValveBiped.Bip01_R_Finger12", "ValveBiped.Bip01_R_Finger0",
	"ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02",
}

local vecUpX, vecUpY, vecUpZ = Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)

-- ============================================
-- FABRIK Solver (Forward And Backward Reaching Inverse Kinematics)
-- Source: cl_tpik.lua:820-867
-- ============================================
local function solve(segments, iter)
	local final = {}
	for i = 1, #segments do final[i] = segments[i] end

	for i = 1, iter do
		-- Backward pass
		local inverse = {}
		for i = #final, 1, -1 do
			if i == #final then
				inverse[i] = segments[i]
			else
				local nextpos = inverse[i + 1].Pos
				inverse[i] = {Pos = nextpos + ((final[i].Pos - nextpos):GetNormalized() * final[i].Len), Len = segments[i].Len}
			end
		end

		-- Forward pass
		for i = 1, #inverse do
			if i == 1 then
				final[i] = segments[i]
			else
				local prev = final[i - 1].Pos
				final[i] = {Pos = prev + ((inverse[i].Pos - prev):GetNormalized() * segments[i - 1].Len), Len = segments[i].Len}
			end
		end
	end

	return final
end

-- ============================================
-- 2-Bone IK Solver (for arms)
-- Source: cl_tpik.lua:1284-1351
-- ============================================
function ezc.Solve2PartIK(start_p, end_p, length0, length1, mat0, mat1, sign, torsomat, angs, ang)
	local length2 = (start_p - end_p):Length()
	local cosAngle0 = math.Clamp(((length2 ^ 2) + (length0 ^ 2) - (length1 ^ 2)) / (2 * length2 * length0), -1, 1)
	local angle0 = -math.deg(math.acos(cosAngle0))
	local cosAngle1 = math.Clamp(((length1 ^ 2) + (length0 ^ 2) - (length2 ^ 2)) / (2 * length1 * length0), -1, 1)
	local angle1 = -math.deg(math.acos(cosAngle1))

	local diff = end_p - start_p
	diff:Normalize()

	local angle2 = math.deg(math.atan2(-math.sqrt(diff.x ^ 2 + diff.y ^ 2), diff.z)) - 90
	local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
	angle3 = math.NormalizeAngle(angle3)

	local torsoright = -math.deg(math.atan2(torsomat:GetAngles():Up().x, torsomat:GetAngles():Up().y)) - 180 - 60 * sign

	local Joint0 = Angle(angle0 + angle2, angle3, 0)
	local diffa2 = 90 + (sign > 0 and -30 or 30)

	Joint0:RotateAroundAxis(Joint0:Forward(), diffa2 + 15)
	Joint0:RotateAroundAxis(diff, angle3 - torsoright)

	local q0 = Quaternion()
	q0:SetAngle(Joint0)
	local Joint0_F = start_p + q0:Angle():Forward() * length0

	local Joint1 = Angle(angle0 + angle2 + 180 + angle1, angle3, 0)
	Joint1:RotateAroundAxis(Joint1:Forward(), diffa2 + 30)
	Joint1:RotateAroundAxis(diff, angle3 - torsoright)

	local q1 = Quaternion()
	q1:SetAngle(Joint1)
	local Joint1_F = Joint0_F + q1:Angle():Forward() * length1

	return Joint0_F, Joint1_F, q0:Angle(), q1:Angle()
end

-- ============================================
-- Main TPIK Function
-- Source: cl_tpik.lua:629-725
-- ============================================
local function ShouldTPIK(ply)
	return IsValid(ply) and ply:Alive() and not IsValid(ply.FakeRagdoll)
end

local lply = LocalPlayer

function ezc.MainTPIKFunction(ent, ply, wpn)
	if not IsValid(ply) then return end
	if not ply:IsPlayer() then return end
	if not ShouldTPIK(ply) then return end

	if IsValid(wpn) and wpn.SetHandPos then
		wpn:SetHandPos()
	end

	ezc.DoTPIK(ply, ent)
end

-- ============================================
-- Full IK Hand Positioning
-- Source: cl_tpik.lua:869-1280
-- ============================================
function ezc.DoTPIK(ply, ent)
	local ply_spine_index = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not ply_spine_index then return end
	local ply_spine_matrix = ent:GetBoneMatrix(ply_spine_index)

	local ply_pelvis_index = ent:LookupBone("ValveBiped.Bip01_Pelvis")
	if not ply_pelvis_index then return end
	local ply_pelvis_matrix = ent:GetBoneMatrix(ply_pelvis_index)

	local ply_head_index = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not ply_head_index then return end
	local ply_head_matrix = ent:GetBoneMatrix(ply_head_index)

	local ply_l_upperarm_index = ent:LookupBone("ValveBiped.Bip01_L_UpperArm")
	local ply_r_upperarm_index = ent:LookupBone("ValveBiped.Bip01_R_UpperArm")
	local ply_l_forearm_index = ent:LookupBone("ValveBiped.Bip01_L_Forearm")
	local ply_r_forearm_index = ent:LookupBone("ValveBiped.Bip01_R_Forearm")
	local ply_l_hand_index = ent:LookupBone("ValveBiped.Bip01_L_Hand")
	local ply_r_hand_index = ent:LookupBone("ValveBiped.Bip01_R_Hand")

	if not ply_l_upperarm_index or not ply_r_upperarm_index or not ply_l_forearm_index or not ply_r_forearm_index or not ply_l_hand_index or not ply_r_hand_index then return end

	local eyeang = ply:GetAimVector():Angle()
	local eyepos = ply:EyePos()
	local headpos = ply_head_matrix:GetTranslation()

	local ply_r_upperarm_matrix = ent:GetBoneMatrix(ply_r_upperarm_index)
	local ply_r_forearm_matrix = ent:GetBoneMatrix(ply_r_forearm_index)
	local ply_r_hand_matrix = ent:GetBoneMatrix(ply_r_hand_index)
	local ply_r_clavicle_matrix = ent:LookupBone("ValveBiped.Bip01_R_Clavicle") and ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_R_Clavicle"))

	local ply_l_upperarm_matrix = ent:GetBoneMatrix(ply_l_upperarm_index)
	local ply_l_forearm_matrix = ent:GetBoneMatrix(ply_l_forearm_index)
	local ply_l_hand_matrix = ent:GetBoneMatrix(ply_l_hand_index)
	local ply_l_clavicle_matrix = ent:LookupBone("ValveBiped.Bip01_L_Clavicle") and ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_L_Clavicle"))

	if not ply_r_hand_matrix or not ply_l_hand_matrix then return end

	local self = ply:GetActiveWeapon()

	local lhik2 = IsValid(self) and self.lhandik or false
	local rhik2 = IsValid(self) and self.rhandik or false

	ply.lerp_lh = math.Approach(ply.lerp_lh or 0, lhik2 and 1 or 0, FrameTime() * 2.0 * game.GetTimeScale())
	ply.lerp_rh = math.Approach(ply.lerp_rh or 0, rhik2 and 1 or 0, FrameTime() * 2.0 * game.GetTimeScale())

	local lerp_lh = math.ease.InOutSine(ply.lerp_lh)
	local lerp_rh = math.ease.InOutSine(ply.lerp_rh)

	local limblength = ply:BoneLength(ply_l_forearm_index) or 12
	if limblength == 0 then limblength = 12 end

	local spinepos = ply_spine_matrix:GetTranslation()
	local spineang = ply_spine_matrix:GetAngles()

	-- Right arm IK
	-- Source: cl_tpik.lua:1005-1141
	if lerp_rh ~= 0 then
		local segments = ply.segmentsr or {}
		segments[1] = segments[1] or {Pos = Vector(), Len = 0}
		segments[2] = segments[2] or {Pos = Vector(), Len = 0}
		segments[3] = segments[3] or {Pos = Vector(), Len = 12}

		segments[1].Pos = ply_r_upperarm_matrix:GetTranslation()
		segments[1].Len = limblength
		segments[2].Pos = spinepos + eyeang:Right() * 25 - eyeang:Up() * 20 - eyeang:Forward() * 20
		segments[2].Len = limblength

		local hand = ply_r_hand_matrix:GetTranslation()
		segments[3].Pos = Lerp(1 - lerp_rh, ply.last_rh and ply.last_rh:GetTranslation() or hand, hand)
		segments[3].Len = 12

		segments = solve(segments, 4)
		ply.segmentsr = segments

		ply_r_upperarm_matrix:SetTranslation(segments[1].Pos)
		ply_r_forearm_matrix:SetTranslation(segments[2].Pos)
		ply_r_hand_matrix:SetTranslation(segments[3].Pos)

		-- Calculate angles for upper arm
		local diff_r = (segments[2].Pos - segments[1].Pos):GetNormalized()
		local q_upper = Quaternion()
		q_upper = q_upper * Quaternion():SetAngleAxis(diff_r:Angle().y, vecUpZ)
		q_upper = q_upper * Quaternion():SetAngleAxis(diff_r:Angle().p, vecUpY)
		q_upper = q_upper * Quaternion():SetAngleAxis(-120 + diff_r:Angle().y - eyeang.y + eyeang.r, vecUpX)
		ply_r_upperarm_matrix:SetAngles(q_upper:Angle())

		-- Calculate angles for forearm
		local diff_r2 = (segments[3].Pos - segments[2].Pos):GetNormalized()
		local q_fore = Quaternion()
		q_fore = q_fore * Quaternion():SetAngleAxis(diff_r2:Angle().y, vecUpZ)
		q_fore = q_fore * Quaternion():SetAngleAxis(diff_r2:Angle().p, vecUpY)
		q_fore = q_fore * Quaternion():SetAngleAxis(-120 - diff_r2:Angle().r + eyeang.r - math.NormalizeAngle((eyeang.y - diff_r2:Angle().y)) * (math.NormalizeAngle(diff_r2:Angle().p)) / 90, vecUpX)
		ply_r_forearm_matrix:SetAngles(q_fore:Angle())

		-- Apply matrices
		ezc.bone_apply_matrix(ent, ply_r_upperarm_index, ply_r_upperarm_matrix, ply_r_forearm_index)
		ezc.bone_apply_matrix(ent, ply_r_forearm_index, ply_r_forearm_matrix, ply_r_hand_index)
		ezc.bone_apply_matrix(ent, ply_r_hand_index, ply_r_hand_matrix)
		ply.last_rh = ply_r_hand_matrix
	end

	-- Left arm IK
	-- Source: cl_tpik.lua:1143-1277
	if lerp_lh ~= 0 then
		local segments = ply.segmentsl or {}
		segments[1] = segments[1] or {Pos = Vector(), Len = 0}
		segments[2] = segments[2] or {Pos = Vector(), Len = 0}
		segments[3] = segments[3] or {Pos = Vector(), Len = 12}

		segments[1].Pos = ply_l_upperarm_matrix:GetTranslation()
		segments[1].Len = limblength
		segments[2].Pos = spinepos + eyeang:Right() * -25 - eyeang:Up() * 20
		segments[2].Len = limblength

		local hand = ply_l_hand_matrix:GetTranslation()
		segments[3].Pos = Lerp(1 - lerp_lh, ply.last_lh and ply.last_lh:GetTranslation() or hand, hand)
		segments[3].Len = 12

		segments = solve(segments, 4)
		ply.segmentsl = segments

		ply_l_upperarm_matrix:SetTranslation(segments[1].Pos)
		ply_l_forearm_matrix:SetTranslation(segments[2].Pos)
		ply_l_hand_matrix:SetTranslation(segments[3].Pos)

		-- Calculate angles for upper arm
		local diff_l = (segments[2].Pos - segments[1].Pos):GetNormalized()
		local q_upper = Quaternion()
		q_upper = q_upper * Quaternion():SetAngleAxis(diff_l:Angle().y, vecUpZ)
		q_upper = q_upper * Quaternion():SetAngleAxis(diff_l:Angle().p, vecUpY)
		q_upper = q_upper * Quaternion():SetAngleAxis(-30 + diff_l:Angle().y - eyeang.y + eyeang.r, vecUpX)
		ply_l_upperarm_matrix:SetAngles(q_upper:Angle())

		-- Calculate angles for forearm
		local diff_l2 = (segments[3].Pos - segments[2].Pos):GetNormalized()
		local q_fore = Quaternion()
		q_fore = q_fore * Quaternion():SetAngleAxis(diff_l2:Angle().y, vecUpZ)
		q_fore = q_fore * Quaternion():SetAngleAxis(diff_l2:Angle().p, vecUpY)
		q_fore = q_fore * Quaternion():SetAngleAxis(-60 - diff_l2:Angle().r + eyeang.r - math.NormalizeAngle((eyeang.y - diff_l2:Angle().y)) * (math.NormalizeAngle(diff_l2:Angle().p)) / 90, vecUpX)
		ply_l_forearm_matrix:SetAngles(q_fore:Angle())

		-- Apply matrices
		ezc.bone_apply_matrix(ent, ply_l_upperarm_index, ply_l_upperarm_matrix, ply_l_forearm_index)
		ezc.bone_apply_matrix(ent, ply_l_forearm_index, ply_l_forearm_matrix, ply_l_hand_index)
		ezc.bone_apply_matrix(ent, ply_l_hand_index, ply_l_hand_matrix)
		ply.last_lh = ply_l_hand_matrix
	end

	-- Reset hand ik flags
	if IsValid(self) then
		self.lhandik = false
		self.rhandik = false
	end
end

-- ============================================
-- Drag hands to specific positions
-- Source: cl_tpik.lua:1428-1687
-- ============================================
function ezc.DragHandsToPos(ply, self, pos, twohanded, twohanddist, norm, angrh, anglh)
	if not IsValid(ply) then return end

	local rh = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	local lh = ply:LookupBone("ValveBiped.Bip01_L_Hand")
	local rhmat = ply:GetBoneMatrix(rh)
	local lhmat = ply:GetBoneMatrix(lh)

	if not pos then return end

	self.lhandik = true

	if twohanded then
		self.rhandik = true

		local oldpos = rhmat:GetTranslation()
		pos.x = math.Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
		pos.y = math.Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
		pos.z = math.Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

		rhmat:SetTranslation(pos)

		if norm then
			local p, a = LocalToWorld(Vector(0, -(twohanddist or 5), 0), angrh or Angle(0, 0, 180), pos, norm:Angle())
			rhmat:SetTranslation(p)
			rhmat:SetAngles(a)
		end

		ezc.bone_apply_matrix(ply, rh, rhmat)
	end

	local oldpos = lhmat:GetTranslation()
	pos.x = math.Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
	pos.y = math.Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
	pos.z = math.Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

	if norm then
		local p, a = LocalToWorld(Vector(0, twohanded and twohanddist or 5, 0), anglh or angle_zero, pos, norm:Angle())
		lhmat:SetTranslation(p)
		lhmat:SetAngles(a)
	end

	ezc.bone_apply_matrix(ply, lh, lhmat)
end
