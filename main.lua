local json = require("luajit.json")
local md5 = require("luajit.md5")

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
	local p = io.popen(("curl --header 'Cache-Control: no-cache' --silent --create-dirs --output %s %s"):format(path, url))
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

local generate_filelist = function()
	local p = io.popen("where /R . *")

	local pathlist = {}
	for line in p:lines() do
		line = line:gsub("\\", "/")
		if
			not line:find(".+/%..+") and
			not line:find(".+/soundsphere%-updater/soundsphere.+") and
			not line:find("noautoupdate") and
			not line:find("filelist%.json")
		then
			pathlist[#pathlist + 1] = line:match("soundsphere%-updater/(.+)$")
		end
	end

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
	os.execute(("@cd soundsphere-%s && call start-win64.bat"):format(branch))
end

local git_clone = function()
	os.execute(("@git clone -b %s --recursive https://github.com/semyon422/soundsphere soundsphere-%s"):format(branch, branch))
end

local git_pull = function()
	os.execute(("@cd soundsphere-%s && git pull --recurse-submodules"):format(branch))
end

local git_reset = function()
	os.execute(("@cd soundsphere-%s && git reset --hard --recurse-submodules"):format(branch))
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

local noautoupdate_file = io.open("noautoupdate", "r")
if not noautoupdate_file then
	local updated = update_launcher()
	if updated then
		os.execute("cls")
		dofile("main.lua")
		os.exit()
	end
else
	noautoupdate_file:close()
end

while true do
	os.execute("cls")

	print("soundsphere launcher")
	print("1 - play")
	print("2 - download")
	print("3 - update")
	print("4 - reset")
	print("5 - select branch [" .. branch .. "]")
	print("6 - generate filelist")
	print("7 - exit")

	local entry = tonumber(io.read())
	os.execute("cls")

	if entry == 1 then
		start_game()
	elseif entry == 2 then
		git_clone()
	elseif entry == 3 then
		git_pull()
	elseif entry == 4 then
		print("Are you sure? Type \"yes\"")
		local answer = io.read()
		if answer == "yes" then
			git_reset()
		end
	elseif entry == 5 then
		select_branch()
	elseif entry == 6 then
		generate_filelist()
	elseif entry == 7 then
		os.exit()
	end
end
