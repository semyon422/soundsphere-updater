local json = require("json")
local crc32 = require("crc32")
local serpent = require("serpent")
local config = require("config")

local branch = "master"
local branch_file = io.open("branch", "rb")
if branch_file then
	branch = branch_file:read("*all")
else
	branch_file = io.open("branch", "wb")
	branch_file:write(branch)
	branch_file:close()
end

local dev_null = jit.os == "Windows" and "nul" or "/dev/null"

local function get_repo()
	return ("soundsphere-%s"):format(branch)
end

local function download(url, path)
	print(("Downloading %s"):format(url))
	local p = io.popen(("curl --location --silent --create-dirs --output %s %s"):format(path, url))
	return p:read("*all")
end

local function shell(command)
	return (jit.os == "Windows" and "busybox " or "") .. command
end

local function repo_shell(command)
	return ("cd %s && %s"):format(get_repo(), command)
end

local function popen_read(command)
	local p = io.popen(command .. " 2> " .. dev_null)
	local content = p:read("*all")
	p:close()
	return content
end

local function git_clone()
	os.execute(("git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch --branch %s %s %s"):format(
		branch, config.github.repo, get_repo()
	))
end

local function git_pull()
	os.execute(repo_shell("git pull --recurse-submodules"))
end

local function git_reset()
	os.execute(repo_shell("git reset --hard --recurse-submodules"))
end

local function git_log_date()
	return popen_read(repo_shell("git log -1 --format=%cd")):match("^%s*(.+)%s*\n.*$")
end

local function git_log_commit()
	return popen_read(repo_shell("git log -1 --format=%H")):match("^%s*(.+)%s*\n.*$")
end

local function clear()
	print(("-"):rep(80))
	-- os.execute(jit.os == "Windows" and "cls" or "clear")
end

local function select_branch()
	local response = download(config.github.repo .. "/branches", "-")
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
		local file = io.open("branch", "wb")
		file:write(branch)
		file:close()
	end
end

local function get_repo_data()
	local response = download(config.github.repo, "-")
	local status, data = pcall(json.decode, response)

	if not status then
		return {}
	end

	return data
end

local function install_git()
	if jit.os ~= "Windows" then
		return
	end
	download("https://github.com/git-for-windows/git/releases/download/v2.30.1.windows.1/Git-2.30.1-64-bit.exe", "gitinstall.exe")
	print("Installing Git")
	os.execute("gitinstall.exe /LOADINF=\"gitinstall.inf\" /VERYSILENT")
	os.execute("del gitinstall.exe")
end

local function is_git_installed()
	return popen_read("git version"):find("version")
end

local function is_game_downloaded()
	return popen_read(shell("ls")):find(get_repo(), 1, true)
end

local function rm(path)
	os.execute(shell(("rm -rf %s"):format(path)))
end

local function md(path)
	os.execute(shell(("mkdir %s"):format(path)))
end

local function mv(src, dst)
	os.execute(shell(("mv %s %s"):format(src, dst)))
end

local function cp(src, dst)
	os.execute(shell(("cp -r %s %s"):format(src, dst)))
end

local function read(path)
	local f = io.open(path, "rb")
	local content = f:read("*all")
	f:close()
	return content
end

local function write(path, content)
	local f = io.open(path, "wb")
	f:write(content)
	f:close()
end

local function serpent_block(t)
	return ("return %s\n"):format(serpent.block(t, {
		indent = "\t",
		comment = false,
		sortkeys = true,
	}))
end

local function write_configs()
	write("soundsphere/gamedir.love/version.lua", serpent_block({
		date = git_log_date(),
		commit = git_log_commit(),
	}))

	local online_path = "soundsphere/gamedir.love/sphere/models/ConfigModel/online.lua"
	local online = loadfile(online_path)()
	online.host = config.game.api
	online.update = config.game.repo .. "/files.json"
	write(online_path, serpent_block(online))
end

local function build_repo()
	rm("soundsphere")
	md("soundsphere")
	cp(get_repo(), "soundsphere/gamedir.love")
	mv("soundsphere/gamedir.love/bin", "soundsphere/bin")
	mv("soundsphere/gamedir.love/resources", "soundsphere/resources")
	mv("soundsphere/gamedir.love/userdata", "soundsphere/userdata")

	write_configs()

	os.execute(shell('find soundsphere -name ".git" -exec rm -rf {} +'))
	os.execute("7z a -tzip soundsphere/game.love ./soundsphere/gamedir.love/*")

	cp("conf.lua", "soundsphere/")
	cp("soundsphere/gamedir.love/game*", "soundsphere/")
	rm("soundsphere/gamedir.love")

	local p = io.popen(shell("find soundsphere -not -type d"))
	local files = {}
	for line in p:lines() do
		line = line:gsub("\\", "/"):gsub("^%./", "")
		if not line:find("^%..*") then
			files[#files + 1] = {
				path = line:gsub("^soundsphere/", ""),
				url = config.game.repo .. line:gsub("^soundsphere", ""),
				hash = crc32.hash(read(line)),
			}
		end
	end
	p:close()

	write("soundsphere/userdata/files.lua", serpent_block(files))
	write("files.json", json.encode(files))
end

local build_zip = function()
	os.execute("rm soundsphere.zip")
	os.execute("7z a -tzip soundsphere.zip soundsphere/")
end

local function get_menu_items()
	return {
		{"download " .. (is_game_downloaded() and "[downloaded]" or "[not downloaded]"), git_clone},
		{"update", git_pull},
		{"reset", function()
			print("Are you sure? Type \"yes\"")
			local answer = io.read()
			if answer == "yes" then
				git_reset()
			end
		end},
		{"build repo", build_repo},
		{"build zip", build_zip},
		{"select branch [" .. branch .. "]", select_branch},
		{"install git " .. (is_git_installed() and "[installed]" or "[not installed]"), install_git},
		{"exit", os.exit},
	}
end

if arg[1] == "build_repo" then
	return build_repo()
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

	io.write("> ")
	local entry = tonumber(io.read())
	clear()

	if menu_items[entry] then
		menu_items[entry][2]()
	end
end
