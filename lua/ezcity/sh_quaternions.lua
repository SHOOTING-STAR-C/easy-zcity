--[[
	Quaternion Library for ezcity
	Source: sh_quaternions.lua in Z-City (from https://github.com/JWalkerMailly/glua-quaternion)
	3D rotation using quaternions (avoids gimbal lock from Euler angles)
]]

local QUATERNION = {
	__epsl = 0.0001,
	__lerp = 0.9995,
	__axis = Vector()
}

QUATERNION.__index = QUATERNION
debug.getregistry().Quaternion = QUATERNION

function IsQuaternion(obj)
	return getmetatable(obj) == QUATERNION
end

function Quaternion(w, x, y, z)
	return IsQuaternion(w)
		and setmetatable({ w = w.w, x = w.x, y = w.y, z = w.z }, QUATERNION)
		or  setmetatable({ w = w or 1.0, x = x or 0.0, y = y or 0.0, z = z or 0.0 }, QUATERNION)
end

function QUATERNION:__eq(q)
	return self.w == q.w and self.x == q.x and self.y == q.y and self.z == q.z
end

function QUATERNION:Set(w, x, y, z)
	if IsQuaternion(w) then
		self.w, self.x, self.y, self.z = w.w, w.x, w.y, w.z
	else
		self.w, self.x, self.y, self.z = w, x, y, z
	end
	return self
end

function QUATERNION:SetAngle(ang)
	local p    = math.rad(ang.p) * 0.5
	local y    = math.rad(ang.y) * 0.5
	local r    = math.rad(ang.r) * 0.5
	local sinp = math.sin(p)
	local cosp = math.cos(p)
	local siny = math.sin(y)
	local cosy = math.cos(y)
	local sinr = math.sin(r)
	local cosr = math.cos(r)

	return self:Set(
		cosr * cosp * cosy + sinr * sinp * siny,
		sinr * cosp * cosy - cosr * sinp * siny,
		cosr * sinp * cosy + sinr * cosp * siny,
		cosr * cosp * siny - sinr * sinp * cosy
	)
end

function QUATERNION:SetAngleAxis(theta, axis)
	local ang = math.rad(theta) * 0.5
	local sin = math.sin(ang)
	local vec = axis:GetNormalized()

	self.__axis = vec
	return self:Set(math.cos(ang), vec.x * sin, vec.y * sin, vec.z * sin)
end

function QUATERNION:SetMatrix(m)
	local m11, m12, m13, _, m21, m22, m23, _, m31, m32, m33, _ = m:Unpack()

	local scale = 1.0
	local trace = m11 + m22 + m33 + scale

	if trace > self.__epsl then
		scale = math.sqrt(trace) * 2.0
		self:Set(0.25 * scale, (m32 - m23) / scale, (m13 - m31) / scale, (m21 - m12) / scale)
	elseif m11 > m22 and m11 > m33 then
		scale = math.sqrt(1.0 + m11 - m22 - m33) * 2.0
		self:Set((m32 - m23) / scale, 0.25 * scale, (m21 + m12) / scale, (m13 + m31) / scale)
	elseif m22 > m33 then
		scale = math.sqrt(1.0 + m22 - m11 - m33) * 2.0
		self:Set((m13 - m31) / scale, (m21 + m12) / scale, 0.25 * scale, (m32 + m23) / scale)
	else
		scale = math.sqrt(1.0 + m33 - m11 - m22) * 2.0
		self:Set((m21 - m12) / scale, (m13 + m31) / scale, (m23 + m32) / scale, 0.25 * scale)
	end

	return self:Normalize()
end

function QUATERNION:SetDirection(forward, up)
	up = up and up:GetNormalized() or Vector(0, 0, 1)
	forward = forward:GetNormalized()

	local m = Matrix()
	local right = up:Cross(forward)
	m:SetUnpacked(
		forward.x, right.x, up.x, 0.0,
		forward.y, right.y, up.y, 0.0,
		forward.z, right.z, up.z, 0.0,
		0.0, 0.0, 0.0, 1.0
	)

	return self:SetAngle(m:GetAngles())
end

function QUATERNION:LengthSqr()
	return self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z
end

function QUATERNION:Length()
	return math.sqrt(self:LengthSqr())
end

function QUATERNION:Normalize()
	local len = self:Length()
	return len > 0 and self:DivScalar(len) or self
end

function QUATERNION:Normalized()
	return Quaternion(self):Normalize()
end

function QUATERNION:Conjugate()
	return self:Set(self.w, -self.x, -self.y, -self.z)
end

function QUATERNION:Conjugated()
	return Quaternion(self):Conjugate()
end

function QUATERNION:Invert()
	return self:Conjugate():Normalize()
end

function QUATERNION:Inverted()
	return Quaternion(self):Invert()
end

function QUATERNION:Negate()
	return self:MulScalar(-1.0)
end

function QUATERNION:Negated()
	return Quaternion(self):Negate()
end

function QUATERNION:__unm()
	return self:Negated()
end

function QUATERNION:Dot(q)
	return self.w * q.w + self.x * q.x + self.y * q.y + self.z * q.z
end

function QUATERNION:AngleDifference(q)
	return math.deg(math.acos(math.min(math.abs(self:Dot(q)), 1.0)) * 2.0)
end

function QUATERNION:AddScalar(scalar)
	self.w = self.w + scalar
	return self
end

function QUATERNION:Add(q)
	return self:Set(self.w + q.w, self.x + q.x, self.y + q.y, self.z + q.z)
end

function QUATERNION:__add(q)
	return IsQuaternion(q) and Quaternion(self):Add(q) or Quaternion(self):AddScalar(q)
end

function QUATERNION:SubScalar(scalar)
	return self:AddScalar(-scalar)
end

function QUATERNION:Sub(q)
	return self:Add(-q)
end

function QUATERNION:__sub(q)
	return IsQuaternion(q) and Quaternion(self):Sub(q) or Quaternion(self):SubScalar(q)
end

function QUATERNION:MulScalar(scalar)
	return self:Set(self.w * scalar, self.x * scalar, self.y * scalar, self.z * scalar)
end

function QUATERNION:Mul(q)
	local qw, qx, qy, qz = self:Unpack()
	local q2w, q2x, q2y, q2z = q:Unpack()

	return self:Set(
		qw * q2w - qx * q2x - qy * q2y - qz * q2z,
		qx * q2w + qw * q2x + qy * q2z - qz * q2y,
		qy * q2w + qw * q2y + qz * q2x - qx * q2z,
		qz * q2w + qw * q2z + qx * q2y - qy * q2x
	)
end

function QUATERNION:__mul(q)
	return IsQuaternion(q) and Quaternion(self):Mul(q) or Quaternion(self):MulScalar(q)
end

function QUATERNION:__concat(q)
	return Quaternion(q):Mul(self)
end

function QUATERNION:DivScalar(scalar)
	return self:MulScalar(1.0 / scalar)
end

function QUATERNION:Div(q)
	return self:Mul(q:Inverted())
end

function QUATERNION:__div(q)
	return IsQuaternion(q) and Quaternion(self):Div(q) or Quaternion(self):DivScalar(q)
end

function QUATERNION:LerpDomain(q, alphaStart, alphaEnd)
	return self:MulScalar(alphaStart):Add(Quaternion(q):MulScalar(alphaEnd)):Normalize()
end

function QUATERNION:Lerp(q, alpha)
	return self:LerpDomain(q, 1.0 - alpha, alpha)
end

function QUATERNION:SLerp(q, alpha)
	local ref = q
	local dot = self:Dot(ref)

	local alphaStart = 1.0 - alpha
	local alphaEnd   = alpha

	if dot < 0.0 then
		ref = -q
		dot = -dot
	end

	if dot < self.__lerp then
		local theta    = math.acos(dot)
		local thetaInv = math.abs(theta) < self.__epsl and 1.0 or (1.0 / math.sin(theta))

		alphaStart = math.sin((1.0 - alpha) * theta) * thetaInv
		alphaEnd   = math.sin(alpha * theta) * thetaInv
	end

	return self:LerpDomain(ref, alphaStart, alphaEnd)
end

function QUATERNION:RotateVector(vec)
	local qw, qx, qy, qz = self:Unpack()
	local vx, vy, vz = vec:Unpack()

	vec:SetUnpacked(
		qw * qw * vx + 2.0 * qy * qw * vz - 2.0 * qz * qw * vy + qx * qx * vx + 2.0 * qy * qx * vy + 2.0 * qz * qx * vz - qz * qz * vx - qy * qy * vx,
		2.0 * qx * qy * vx + qy * qy * vy + 2.0 * qz * qy * vz + 2.0 * qw * qz * vx - qz * qz * vy + qw * qw * vy - 2.0 * qx * qw * vz - qx * qx * vy,
		2.0 * qx * qz * vx + 2.0 * qy * qz * vy + qz * qz * vz - 2.0 * qw * qy * vx - qy * qy * vz + 2.0 * qw * qx * vy - qx * qx * vz + qw * qw * vz
	)

	return vec
end

function QUATERNION:RotatedVector(vec)
	return self:RotateVector(Vector(vec))
end

function QUATERNION:Angle()
	local qw, qx, qy, qz = self:Unpack()

	return Angle(
		math.deg(math.asin(2.0 * (qw * qy - qz * qx))),
		math.deg(math.atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz))),
		math.deg(math.atan2(2.0 * (qw * qx + qy * qz), 1.0 - 2.0 * (qx * qx + qy * qy)))
	)
end

function QUATERNION:AngleAxis()
	local qw  = self.w
	local den = math.sqrt(1.0 - qw * qw)

	return math.deg(2.0 * math.acos(qw)), den > self.__epsl and (Vector(self.x, self.y, self.z) / den) or self.__axis
end

function QUATERNION:Matrix(m)
	local qw, qx, qy, qz = self:Unpack()

	m = m or Matrix()
	m:SetUnpacked(
		1.0 - 2.0 * (qy * qy + qz * qz), 2.0 * (qx * qy - qw * qz),       2.0 * (qx * qz + qw * qy),       0.0,
		2.0 * (qx * qy + qw * qz),       1.0 - 2.0 * (qx * qx + qz * qz), 2.0 * (qy * qz - qw * qx),       0.0,
		2.0 * (qx * qz - qw * qy),       2.0 * (qy * qz + qw * qx),       1.0 - 2.0 * (qx * qx + qy * qy), 0.0,
		0.0,                             0.0,                             0.0,                             1.0
	)

	return m
end

function QUATERNION:Unpack()
	return self.w, self.x, self.y, self.z
end

function QUATERNION:__tostring()
	return string.format("%f %f %f %f", self:Unpack())
end
