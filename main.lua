local json = require("luajit.json")
local md5 = require("luajit.md5")

local branch
local branchFile = io.open("branch", "r")
if branchFile then
	branch = branchFile:read("*all")
else
	branchFile = io.open("branch", "w")
	branchFile:write("master")
	branchFile:close()
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

local curlCommand = "curl\\curl"

local download = function(url, path)
	print(url)
	local p = io.popen(
		curlCommand .. " --silent --create-dirs --output " .. path .. " " .. url
	)
	return p:read("*all")
end

local getBranches = function()
	local response = download("https://api.github.com/repos/semyon422/soundsphere/branches", "-")
	local jsonObject = json.decode(response)
	local branches = {}
	for i = 1, #jsonObject do
		branches[#branches + 1] = jsonObject[i].name
	end
	return branches
end

local gitClonePattern = "git clone -b %s --recursive https://github.com/semyon422/soundsphere soundsphere-%s"
local gitUpdatePattern = "cd soundsphere-%s && git pull --recurse-submodules"
local gitResetPattern = "cd soundsphere-%s && git reset --hard --recurse-submodules"
local startPattern = "@cd soundsphere-%s && call start-win%s.bat"

local getServerFileList = function(self)
	local response = download("https://soundsphere.xyz/static/soundsphere-updater/filelist.json", "-")
	return json.decode(response)
end

local getClientFiles = function()
	local f = io.open("filelist.json", "r")

	if not f then
		return {}
	end

	local content = f:read("*all")
	f:close()
	return json.decode(content)
end

local addFiles = function(fileListToAdd)
	local f = io.open("filelist.json", "r")

	local fileList
	if f then
		local content = f:read("*all")
		f:close()
		fileList = json.decode(content)

		local fileMap = {}
		for i, subfile in ipairs(fileList) do
			fileMap[subfile.path] = i
		end
		for j, subfile in ipairs(fileListToAdd) do
			fileList[fileMap[subfile.path] or #fileList + 1] = subfile
		end
	else
		fileList = fileListToAdd
	end

	local content = json.encode(fileList)
	f = io.open("filelist.json", "w")
	f:write(content)
	f:close()
end

local curlUpdate = function()
	local serverFiles = getServerFileList()
	local clientFiles = getClientFiles()

	local fileMap = {}
	for _, file in ipairs(serverFiles) do
		local path = file.path
		fileMap[path] = fileMap[path] or {}
		fileMap[path].hash = file.hash
		fileMap[path].path = path
		fileMap[path].url = file.url
	end
	for _, file in ipairs(clientFiles) do
		local path = file.path
		fileMap[path] = fileMap[path] or {}
		fileMap[path].oldHash = file.hash
		fileMap[path].path = path
	end

	local fileList = {}
	for _, file in pairs(fileMap) do
		fileList[#fileList + 1] = file
	end
	table.sort(fileList, function(a, b)
		return a.path < b.path
	end)

	local fileListToAdd = {}
	for _, file in ipairs(fileList) do
		if file.oldHash and not file.hash then
			os.remove(file.path)
		elseif file.hash and not file.oldHash then
			download(file.url, file.path)
			fileListToAdd[#fileListToAdd + 1] = file
		elseif file.hash ~= file.oldHash then
			os.rename(file.path, file.path .. ".old")
			download(file.url, file.path)
			os.remove(file.path .. ".old")
			fileListToAdd[#fileListToAdd + 1] = file
		end
	end
	addFiles(fileListToAdd)
end

local generateFileList = function()
	local p = io.popen(
		"where /R . *"
	)
	local pathList = {}
	for line in p:lines() do
		line = line:gsub("\\", "/")
		if not line:find(".+/%..+") then
			print(line:match("soundsphere%-updater/(.+)$"))
			pathList[#pathList + 1] = line:match("soundsphere%-updater/(.+)$")
		end
	end

	local fileList = {}
	for _, path in ipairs(pathList) do
		local file = {}
		file.path = path
		file.url = "https://soundsphere.xyz/static/soundsphere-updater/" .. path

		local f = io.open(path, "r")
		local content = f:read("*all")
		f:close()
		file.hash = md5.sumhexa(content)

		fileList[#fileList + 1] = file
	end

	local content = json.encode(fileList)
	local f = io.open("filelist.json", "w")
	f:write(content)
	f:close()
end

while true do
	os.execute("cls")

	print("soundsphere updater")
	print("1 - play")
	print("2 - update using curl")
	print("3 - git clone")
	print("4 - git pull")
	print("5 - git reset")
	print("6 - select branch [" .. branch .. "]")
	print("7 - generate filelist.json")
	print("8 - exit")

	local entry = tonumber(io.read())
	os.execute("cls")

	if entry == 1 then
		os.execute(startPattern:format(branch, jit.arch == "x64" and 64 or 32))
	elseif entry == 2 then
		curlUpdate()
	elseif entry == 3 then
		pipe(gitClonePattern:format(branch, branch))
	elseif entry == 4 then
		pipe(gitUpdatePattern:format(branch))
	elseif entry == 5 then
		print("Are you sure? Type \"yes\"")
		local answer = io.read()
		if answer == "yes" then
			pipe(gitResetPattern:format(branch))
		end
	elseif entry == 6 then
		local branches = getBranches()
		for i = 1, #branches do
			print(i .. " - " .. branches[i])
		end
		branch = branches[tonumber(io.read())] or "master"
		local file = io.open("branch", "w")
		file:write(branch)
		file:close()
	elseif entry == 7 then
		generateFileList()
	elseif entry == 8 then
		os.exit()
	end
end
