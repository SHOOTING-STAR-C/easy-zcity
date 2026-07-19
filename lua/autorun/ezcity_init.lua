--[[
	ezcity Loader
	Loads all ezcity modules in the correct order
	Place this in lua/autorun/
]]

ezc = ezc or {}

-- ============================================
-- Shared modules (loaded on both client and server)
-- ============================================
include("ezcity/sh_quaternions.lua")
include("ezcity/sh_utility.lua")
include("ezcity/sh_movement.lua")
include("ezcity/sh_posture.lua")
include("ezcity/sh_wepshared.lua")

-- ============================================
-- Server-side only
-- ============================================
if SERVER then
	AddCSLuaFile("ezcity/sh_quaternions.lua")
	AddCSLuaFile("ezcity/sh_utility.lua")
	AddCSLuaFile("ezcity/sh_movement.lua")
	AddCSLuaFile("ezcity/sh_posture.lua")
	AddCSLuaFile("ezcity/sh_wepshared.lua")

	AddCSLuaFile("ezcity/sh_bonemethods.lua")
	AddCSLuaFile("ezcity/sh_worldmodel.lua")
	AddCSLuaFile("ezcity/cl_viewpunch.lua")
	AddCSLuaFile("ezcity/cl_view.lua")
	AddCSLuaFile("ezcity/cl_lean.lua")
	AddCSLuaFile("ezcity/cl_tpik.lua")
	AddCSLuaFile("ezcity/cl_wepcamera.lua")
	return
end

-- ============================================
-- Client-side modules (load order matters!)
-- ============================================
include("ezcity/sh_bonemethods.lua")
include("ezcity/sh_worldmodel.lua")
include("ezcity/cl_viewpunch.lua")
include("ezcity/cl_view.lua")    -- Depends on viewpunch
include("ezcity/cl_lean.lua")    -- Depends on bonemethods
include("ezcity/cl_tpik.lua")    -- Depends on quaternions
include("ezcity/cl_wepcamera.lua")

-- ============================================
-- Print status
-- ============================================
print("[ezcity] Loaded successfully!")
print("[ezcity] Features: First/Third person camera, Posture system, Q/E lean, movement inertia, TPIK")
