--!strict
-- src/ServerScriptService/Services/Data/SaveCoordinator.luau
-- Lote R1-04: Coordinador de guardado, control de revisiones y coalescencia.

export type SaveCoordinatorInterface = {
	GetCurrentRevision: (self: any) -> number,
	GetDurableRevision: (self: any) -> number,
	GetTargetRevision: (self: any) -> number,
	AdvanceCurrent: (self: any, delta: number?) -> number,
	ConfirmDurable: (self: any, revision: number) -> (),
	RequestTarget: (self: any, revision: number) -> (),
	IsFlushNeeded: (self: any) -> boolean,
	ShouldFlush: (self: any, target: number?) -> boolean,
}

local SaveCoordinator = {}

function SaveCoordinator.new(initialRevision: number?): SaveCoordinatorInterface
	local currentRevision = initialRevision or 1
	local durableRevision = initialRevision or 1
	local targetRevision = initialRevision or 1

	local self = {}

	function self:GetCurrentRevision(): number
		return currentRevision
	end

	function self:GetDurableRevision(): number
		return durableRevision
	end

	function self:GetTargetRevision(): number
		return targetRevision
	end

	function self:AdvanceCurrent(delta: number?): number
		local d = delta or 1
		currentRevision = currentRevision + d
		return currentRevision
	end

	function self:ConfirmDurable(revision: number)
		durableRevision = math.max(durableRevision, revision)
	end

	function self:RequestTarget(revision: number)
		targetRevision = math.max(targetRevision, revision)
	end

	function self:IsFlushNeeded(): boolean
		return currentRevision > durableRevision
	end

	function self:ShouldFlush(target: number?): boolean
		local t = target or currentRevision
		return t > durableRevision
	end

	return self
end

return SaveCoordinator
