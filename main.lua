local json = require("json")
local crc32 = require("crc32")
local serpent = require("serpent")
local config = require("config")

local branch = "master"
local branch_file = io.open("branch", "rb")
if branch_file then
	branch = branch_file:read("*all")
else
	branch_file = assert(io.open("branch", "wb"))
	branch_file:write(branch)
	branch_file:close()
end

local function get_repo()
	return ("soundsphere-%s"):format(branch)
end

local function download(url, path)
	print(("Downloading %s"):format(url))
	local p = assert(io.popen(("curl --location --silent --create-dirs --output %s %s"):format(path, url)))
	return p:read("*all")
end

local function repo_shell(command)
	return ("cd %s && %s"):format(get_repo(), command)
end

local function popen_read(command)
	local p = assert(io.popen(command .. " 2> /dev/null"))
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

local function git_status()
	os.execute(repo_shell("git status"))
end

local function clear()
	print(("-"):rep(80))
end

local function select_branch()
	local response = download(config.github.repo .. "/branches", "-")
	local status, branches = pcall(json.decode, response)

	if not status then
		return
	end
	assert(type(branches) == "table")

	for i = 1, #branches do
		print(i .. " - " .. branches[i].name)
	end

	local branch_index = tonumber(io.read())
	if branch_index then
		branch = branches[branch_index].name
		local file = assert(io.open("branch", "wb"))
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
	assert(type(data) == "table")

	return data
end

local function is_git_installed()
	return popen_read("git version"):find("version")
end

local function is_7z_installed()
	return popen_read("7z"):find("p7zip")
end

local function is_curl_installed()
	return popen_read("curl --version"):find("curl")
end

local function is_game_downloaded()
	return popen_read("ls"):find(get_repo(), 1, true)
end

local function rm(path)
	os.execute(("rm -rf %s"):format(path))
end

local function rm_find(root, path)
	os.execute(("find %q -name %q -exec rm -rf {} +"):format(root, path))
end

local function md(path)
	os.execute(("mkdir %s"):format(path))
end

local function mv(src, dst)
	os.execute(("mv %s %s"):format(src, dst))
end

local function cp(src, dst)
	os.execute(("cp -r %s %s"):format(src, dst))
end

local function read(path)
	local f = assert(io.open(path, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

local function write(path, content)
	local f = assert(io.open(path, "wb"))
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

local function write_configs(gamedir)
	write(gamedir .. "/version.lua", serpent_block({
		date = git_log_date(),
		commit = git_log_commit(),
	}))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	local urls = dofile(urls_path)
	urls.host = config.game.api
	urls.update = config.game.repo .. "/files.json"
	urls.osu = config.osu
	urls.multiplayer = config.game.multiplayer
	write(urls_path, serpent_block(urls))
end

local extract_list = {"bin", "resources", "userdata"}
local delete_list = {
	"cimgui-love/cimgui",
	"cimgui-love/cparser",
	"inspect/rockspecs",
	"inspect/spec",
	"json/bench",
	"json/test",
	"lua-toml/rockspecs",
	"lua-toml/spec",
	"md5/rockspecs",
	"md5/spec",
	"serpent/t",
	"tinyyaml/rockspec",
	"tinyyaml/spec",
	"tween/rockspecs",
	"tween/spec",
	"s3dc/screenshot.png",
	"lua-MessagePack/src5.3",
	"lua-MessagePack/test",
	"lua-MessagePack/docs",
	"lua-MessagePack/dist.ini",
}

local delete_recursive_list = {
	".*",
	"*.rockspec",
	"*_spec.lua",
	"rockspec.*",
	"rockspec",
	"Makefile",
	"CHANGES",
	"COPYRIGHT",
	"LICENSE",
	"LICENSE.txt",
	"MIT-LICENSE.txt",
	"README.md",
	"CHANGELOG.md",
	"*.md",
	"*.yml",
	"*.xcf",
}
local function build_repo()
	md("repo")

	rm("repo/soundsphere")
	md("repo/soundsphere")

	local gamedir = "repo/soundsphere/gamedir.love"
	cp(get_repo(), gamedir)
	for _, dir in ipairs(extract_list) do
		mv(gamedir .. "/" .. dir, "repo/soundsphere/")
	end
	for _, dir in ipairs(delete_list) do
		rm(gamedir .. "/" .. dir)
	end
	for _, dir in ipairs(delete_recursive_list) do
		rm_find("repo/soundsphere", dir)
	end
	mv(gamedir .. "/3rd-deps/lib", "repo/soundsphere/bin/")

	write_configs(gamedir)

	mv(gamedir .. "/game*", "repo/soundsphere/")
	os.execute("7z a -tzip repo/soundsphere/game.love ./repo/soundsphere/gamedir.love/*")
	rm(gamedir)

	cp("conf.lua", "repo/soundsphere/")

	local p = assert(io.popen("find repo/soundsphere -not -type d"))
	local files = {}
	for line in p:lines() do
		line = line:gsub("\\", "/"):gsub("^%./", "")
		if not line:find("^%..*") then
			files[#files + 1] = {
				path = line:gsub("^repo/soundsphere/", ""),
				url = config.game.repo .. line:gsub("^repo", ""),
				hash = crc32.hash(read(line)),
			}
		end
	end
	p:close()

	write("repo/soundsphere/userdata/files.lua", serpent_block(files))
	write("repo/files.json", json.encode(files))
end

local build_zip = function()
	os.execute("7z a -tzip repo/soundsphere_temp.zip ./repo/soundsphere")
	rm("repo/soundsphere.zip")
	mv("repo/soundsphere_temp.zip", "repo/soundsphere.zip")
end

local update_zip = function()
	md("repo/tmp")
	md("repo/tmp/soundsphere")
	cp("repo/soundsphere/game.love", "repo/tmp/soundsphere/game.love")
	os.execute("7z u -tzip repo/soundsphere.zip ./repo/tmp/soundsphere")
	rm("repo/tmp")
end

local function get_menu_items()
	return {
		{"download " .. (is_game_downloaded() and "[downloaded]" or "[not downloaded]"), git_clone},
		{"update", git_pull},
		{"status", git_status},
		{"reset", function()
			print("Are you sure? Type \"yes\"")
			local answer = io.read()
			if answer == "yes" then
				git_reset()
			end
		end},
		{"build repo", build_repo},
		{"build zip", build_zip},
		{"update zip (game.love only)", update_zip},
		{"select branch [" .. branch .. "]", select_branch},
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
	print("git: " .. (is_git_installed() and "+" or "-"))
	print("7z: " .. (is_7z_installed() and "+" or "-"))
	print("curl: " .. (is_curl_installed() and "+" or "-"))
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
