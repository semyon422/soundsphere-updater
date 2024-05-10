local pkg = require("aqua.package")
pkg.add("aqua")

local json = require("json")
local crc32 = require("crc32")
local stbl = require("stbl")
local config = require("config")
local util = require("util")
local Repo = require("Repo")

local branch_file = assert(io.open("branch", "rb"))
local branch = branch_file:read("*a"):match("^%s*(.-)%s*$")

local repo = Repo(config.github.repo, "soundsphere")
repo:setBranch(branch)

local function clear()
	print(("-"):rep(80))
end

local function is_git_installed()
	return util.popen_read("git version"):find("version")
end

local function is_7z_installed()
	return util.popen_read("7z"):find("p7zip")
end

local function is_curl_installed()
	return util.popen_read("curl --version"):find("curl")
end

local function is_game_downloaded()
	return util.popen_read("ls"):find(repo:getDirName(), 1, true)
end

local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

local function write_configs(gamedir)
	util.write(gamedir .. "/version.lua", serialize({
		date = repo:log_date(),
		commit = repo:log_commit(),
	}))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	local urls = dofile(urls_path)
	urls.host = config.game.api
	urls.update = config.game.repo .. "/files.json"
	urls.osu = config.osu
	urls.multiplayer = config.game.multiplayer
	util.write(urls_path, serialize(urls))
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
	util.md("repo")

	util.rm("repo/soundsphere")
	util.md("repo/soundsphere")

	local gamedir = "repo/soundsphere/gamedir.love"
	util.cp(repo:getDirName(), gamedir)
	for _, dir in ipairs(extract_list) do
		util.mv(gamedir .. "/" .. dir, "repo/soundsphere/")
	end
	for _, dir in ipairs(delete_list) do
		util.rm(gamedir .. "/" .. dir)
	end
	for _, dir in ipairs(delete_recursive_list) do
		util.rm_find("repo/soundsphere", dir)
	end
	util.mv(gamedir .. "/3rd-deps/lib", "repo/soundsphere/bin/")

	write_configs(gamedir)

	util.mv(gamedir .. "/game*", "repo/soundsphere/")
	os.execute("7z a -tzip repo/soundsphere/game.love ./repo/soundsphere/gamedir.love/*")
	util.rm(gamedir)

	util.cp("conf.lua", "repo/soundsphere/")

	local p = assert(io.popen("find repo/soundsphere -not -type d"))
	local files = {}
	for line in p:lines() do
		line = line:gsub("\\", "/"):gsub("^%./", "")
		if not line:find("^%..*") then
			files[#files + 1] = {
				path = line:gsub("^repo/soundsphere/", ""),
				url = config.game.repo .. line:gsub("^repo", ""),
				hash = crc32.hash(util.read(line)),
			}
		end
	end
	p:close()

	util.write("repo/soundsphere/userdata/files.lua", serialize(files))
	util.write("repo/files.json", json.encode(files))
end

local function build_zip()
	os.execute("7z a -tzip repo/soundsphere_temp.zip ./repo/soundsphere")
	util.rm("repo/soundsphere.zip")
	util.mv("repo/soundsphere_temp.zip", "repo/soundsphere.zip")
end

local function update_zip()
	util.md("repo/tmp")
	util.md("repo/tmp/soundsphere")
	util.cp("repo/soundsphere/game.love", "repo/tmp/soundsphere/game.love")
	os.execute("7z u -tzip repo/soundsphere.zip ./repo/tmp/soundsphere")
	util.rm("repo/tmp")
end

local function get_menu_items()
	return {
		{"download " .. (is_game_downloaded() and "[downloaded]" or "[not downloaded]"), function()
			repo:clone()
		end},
		{"update", function()
			repo:pull()
		end},
		{"status", function()
			repo:status()
		end},
		{"reset", function()
			print("Are you sure? Type \"yes\"")
			local answer = io.read()
			if answer == "yes" then
				repo:reset()
			end
		end},
		{"build repo", build_repo},
		{"build zip", build_zip},
		{"update zip (game.love only)", update_zip},
		{"exit", os.exit},
	}
end

if arg[1] == "build_repo" then
	return build_repo()
end

while true do
	clear()

	print("soundsphere launcher")
	print("")

	print("")
	print("git: " .. (is_git_installed() and "+" or "-"))
	print("7z: " .. (is_7z_installed() and "+" or "-"))
	print("curl: " .. (is_curl_installed() and "+" or "-"))
	print("")
	print("branch: " .. branch)

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
