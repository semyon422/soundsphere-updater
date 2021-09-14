local mainLoop

local function run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
	if love.timer then love.timer.step() end

	return function()
		return mainLoop()
	end
end

local function load(...)
	local fileData = assert(love.filesystem.newFileData("game.love"))
	assert(love.filesystem.mount(fileData, ""))

	package.loaded.main = nil
	package.loaded.conf = nil

	love.conf = nil
	love.handlers = nil
	love.init()
	if love.load ~= load then
		love.load(...)
	end
	mainLoop = love.run()
end

love.load = load
love.run = run
