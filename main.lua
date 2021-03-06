local json = require("json")
local md5 = require("md5")

local branch = "master"
local branch_file = io.open("branch", "r")
if branch_file then
	branch = branch_file:read("*all")
else
	branch_file = io.open("branch", "w")
	branch_file:write(branch)
	branch_file:close()
end

local download = function(url, path)
	print(("Downloading %s"):format(url))
	local p = io.popen(("curl --location --silent --create-dirs --output %s %s"):format(path, url))
	return p:read("*all")
end

local update_launcher = function()
	local filelist_response = download("https://raw.githubusercontent.com/semyon422/soundsphere-updater/master/filelist.json", "-")
	local status, server_filelist = pcall(json.decode, filelist_response)

	if not status then
		return
	end

	local client_filelist
	do
		local f = io.open("filelist.json", "r")

		if not f then
			client_filelist = {}
		else
			local content = f:read("*all")
			f:close()
			client_filelist = json.decode(content)
		end
	end

	local filemap = {}
	for _, file in ipairs(server_filelist) do
		local path = file.path
		filemap[path] = filemap[path] or {}
		filemap[path].hash = file.hash
		filemap[path].path = path
		filemap[path].url = file.url
	end
	for _, file in ipairs(client_filelist) do
		local path = file.path
		filemap[path] = filemap[path] or {}
		filemap[path].hash_old = file.hash
		filemap[path].path = path
	end

	local filelist = {}
	for _, file in pairs(filemap) do
		filelist[#filelist + 1] = file
	end
	table.sort(filelist, function(a, b)
		return a.path < b.path
	end)

	local updated = #filelist
	for _, file in ipairs(filelist) do
		if file.hash_old and not file.hash then
			os.remove(file.path)
		elseif file.hash and not file.hash_old or file.hash ~= file.hash_old then
			download(file.url, file.path)
		else
			updated = updated - 1
		end
	end

	local f = io.open("filelist.json", "w")
	f:write(filelist_response)
	f:close()

	return updated > 0
end

local find_files = function()
	local p = io.popen((jit.os == "Windows" and "busybox " or "") .. "find . -not -type d")
	local pathlist = {}
	for line in p:lines() do
		line = line:gsub("\\", "/"):gsub("^%./", "")
		if
			not line:find("^%..*") and
			not line:find("^soundsphere.+") and
			not line:find("noautoupdate", 1) and
			not line:find("filelist.json", 1, true)
		then
			pathlist[#pathlist + 1] = line
		end
	end
	p:close()
	return pathlist
end

local generate_filelist = function()
	local pathlist = find_files()

	local filelist = {}
	for _, path in ipairs(pathlist) do
		local file = {}
		file.path = path
		file.url = "https://raw.githubusercontent.com/semyon422/soundsphere-updater/master/" .. path

		local f = io.open(path, "r")
		local content = f:read("*all")
		f:close()
		file.hash = md5.sumhexa(content)

		filelist[#filelist + 1] = file
	end

	local content = json.encode(filelist)
	local f = io.open("filelist.json", "w")
	f:write(content)
	f:close()
end

local start_game = function()
	if jit.os == "Windows" then
		os.execute(("cd soundsphere-%s && call start-win64.bat"):format(branch))
	else
		os.execute(("cd soundsphere-%s && ./start-linux64"):format(branch))
	end
end

local git_clone = function()
	os.execute(("git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch --branch %s https://github.com/semyon422/soundsphere soundsphere-%s"):format(branch, branch))
end

local git_pull = function()
	os.execute(("cd soundsphere-%s && git pull --recurse-submodules"):format(branch))
end

local git_reset = function()
	os.execute(("cd soundsphere-%s && git reset --hard --recurse-submodules"):format(branch))
end

local clear = function()
	os.execute(jit.os == "Windows" and "cls" or "clear")
end

local select_branch = function()
	local response = download("https://api.github.com/repos/semyon422/soundsphere/branches", "-")
	local status, branches = pcall(json.decode, response)

	if not status then
		return
	end

	for i = 1, #branches do
		print(i .. " - " .. branches[i].name)
	end

	local branch_index = tonumber(io.read())
	if branch_index then
		branch = branches[branch_index].name
		local file = io.open("branch", "w")
		file:write(branch)
		file:close()
	end
end

local get_repo_data = function()
	local response = download("https://api.github.com/repos/semyon422/soundsphere", "-")
	local status, data = pcall(json.decode, response)

	if not status then
		return {}
	end

	return data
end

local restart = function()
	clear()
	dofile("main.lua")
	os.exit()
end

local install_git = function()
	if jit.os == "Windows" then
		download("https://github.com/git-for-windows/git/releases/download/v2.30.1.windows.1/Git-2.30.1-64-bit.exe", "gitinstall.exe")
		print("Installing Git")
		os.execute("gitinstall.exe /LOADINF=\"gitinstall.inf\" /VERYSILENT")
		os.execute("del gitinstall.exe")
		restart()
	end
end

local is_git_installed = function()
	local p = io.popen("git version 2> " .. (jit.os == "Windows" and "nul" or "/dev/null"))
	local version = p:read("*all")
	p:close()
	return version:find("version")
end

local is_game_downloaded = function()
	local p = io.popen((jit.os == "Windows" and "busybox " or "") .. "ls")
	local files = p:read("*all")
	p:close()
	return files:find(("soundsphere-%s"):format(branch), 1, true)
end

local noautoupdate_file = io.open("noautoupdate", "r")
if not noautoupdate_file then
	local updated = update_launcher()
	if updated then
		restart()
	end
else
	noautoupdate_file:close()
end

local get_menu_items = function()
	return {
		{"play", start_game},
		{"download " .. (is_game_downloaded() and "[downloaded]" or "[not downloaded]"), git_clone},
		{"update", git_pull},
		{"reset", function()
			print("Are you sure? Type \"yes\"")
			local answer = io.read()
			if answer == "yes" then
				git_reset()
			end
		end},
		{"generate filelist", generate_filelist},
		{"select branch [" .. branch .. "]", select_branch},
		{"install git " .. (is_git_installed() and "[installed]" or "[not installed]"), install_git},
		{"exit", os.exit},
	}
end

local repo_data = get_repo_data()

while true do
	clear()

	print("soundsphere launcher")
	print("")

	if repo_data.name == "soundsphere" then
		print(repo_data.name)
		print(repo_data.description)
		print(repo_data.homepage)
	end
	print("")

	local menu_items = get_menu_items()
	for i, item in ipairs(menu_items) do
		print(i .. " - " .. item[1])
	end

	local entry = tonumber(io.read())
	clear()

	if menu_items[entry] then
		menu_items[entry][2]()
	end
end
