local json = require("luajit.json")

local branch
local file = io.open("branch", "r")
if file then
	branch = file:read("*all")
else
	local file = io.open("branch", "w")
	file:write("master")
	file:close()
end

branch = branch or "master"

local pipe = function(command)
	local p = io.popen(command, "r")
	while true do
		local line = p:read()
		if line then
			io.write(line)
		else
			break
		end
	end
	io.write("\n")
end

local getBranches = function()
	local p = io.popen("cd curl && curl https://api.github.com/repos/semyon422/soundsphere/branches -o - --silent", "r")
	local response = p:read("*all")
	local jsonObject = json.decode(response)
	local branches = {}
	for i = 1, #jsonObject do
		branches[#branches + 1] = jsonObject[i].name
	end
	return branches
end

local screen = "menu"

local gitClonePattern = "git clone -b %s --recursive https://github.com/semyon422/soundsphere soundsphere-%s"
local gitUpdatePattern = "cd soundsphere-%s && git pull --recurse-submodules"
local gitResetPattern = "cd soundsphere-%s && git reset --hard --recurse-submodules"
local startPattern = "@cd soundsphere-%s && call start-win%s.bat"

while true do
	os.execute("cls")
	print("soundsphere updater")
	print("selected branch: " .. branch)
	print("1 - play")
	print("2 - download")
	print("3 - update")
	print("4 - select branch")
	print("5 - reset")
	print("6 - exit")
	local entry = tonumber(io.read())
	if entry == 1 then
		os.execute(startPattern:format(branch, jit.arch == "x64" and 64 or 32))
	elseif entry == 2 then
		os.execute("cls")
		pipe(gitClonePattern:format(branch, branch))
		print("continue?")
		io.read()
	elseif entry == 3 then
		os.execute("cls")
		pipe(gitUpdatePattern:format(branch))
		print("continue?")
		io.read()
	elseif entry == 4 then
		os.execute("cls")
		local branches = getBranches()
		for i = 1, #branches do
			print(i .. " - " .. branches[i])
		end
		branch = branches[tonumber(io.read())] or "master"
		local file = io.open("branch", "w")
		file:write(branch)
		file:close()
	elseif entry == 5 then
		os.execute("cls")
		print("Are you sure? Type \"yes\"")
		local answer = io.read()
		if answer == "yes" then
			pipe(gitResetPattern:format(branch))
			print("continue?")
			io.read()
		end
	elseif entry == 6 then
		os.exit()
	end
end