--!strict
-- Server-clock measurements for playtesting; these never change rewards.
local HuntMetrics = {}

export type Metrics = {
	startedAt: number?,
	deaths: number,
	lastDuration: number?,
	bestDuration: number?,
	lastDeaths: number?,
}

local function validTime(now: number): boolean
	return now == now and now >= 0 and now < math.huge
end

function HuntMetrics.new(): Metrics
	return { startedAt = nil, deaths = 0, lastDuration = nil, bestDuration = nil, lastDeaths = nil }
end

function HuntMetrics.start(metrics: Metrics, now: number): boolean
	if metrics.startedAt ~= nil or not validTime(now) then
		return false
	end
	metrics.startedAt = now
	metrics.deaths = 0
	return true
end

function HuntMetrics.death(metrics: Metrics)
	if metrics.startedAt ~= nil then
		metrics.deaths += 1
	end
end

function HuntMetrics.finish(metrics: Metrics, now: number): boolean
	local start = metrics.startedAt
	if start == nil or not validTime(now) or now < start then
		return false
	end
	local duration = now - start
	metrics.lastDuration = duration
	metrics.lastDeaths = metrics.deaths
	metrics.bestDuration = if metrics.bestDuration then math.min(metrics.bestDuration, duration) else duration
	metrics.startedAt = nil
	return true
end

function HuntMetrics.snapshot(metrics: Metrics, now: number)
	local startedAt = metrics.startedAt
	return {
		elapsed = if startedAt and validTime(now) and now >= startedAt then now - startedAt else nil,
		deaths = metrics.deaths,
		lastDuration = metrics.lastDuration,
		bestDuration = metrics.bestDuration,
		lastDeaths = metrics.lastDeaths,
	}
end

return table.freeze(HuntMetrics)
