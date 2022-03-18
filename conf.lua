local mainLoop

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
	if love.timer then love.timer.step() end

	return function()
		return mainLoop()
	end
end

function love.load(...)
	local fileData = assert(love.filesystem.newFileData("game.love"))
	assert(love.filesystem.mount(fileData, ""))

	package.loaded.main = nil
	package.loaded.conf = nil

	local love_load = love.load

	love.conf = nil
	love.handlers = nil
	love.init()
	if love.load ~= love_load then
		love.load(...)
	end
	mainLoop = love.run()
end

function love.conf(t)
	t.audio = nil
	t.window = nil
	t.modules = {}
end
