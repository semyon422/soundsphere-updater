local pkg = require("aqua.package")
pkg.add("aqua")

local json = require("json")
local crc32 = require("crc32")
local stbl = require("stbl")
local config = require("config")
local util = require("util")
local GitRepo = require("GitRepo")
local RepoBuilder = require("RepoBuilder")

local branch_file = assert(io.open("branch", "rb"))
local branch = branch_file:read("*a"):match("^%s*(.-)%s*$")

local git_repo = GitRepo(config.github.repo, "soundsphere")
git_repo:setBranch(branch)

local repoBuilder = RepoBuilder(git_repo)

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
	return util.popen_read("ls"):find(git_repo:getDirName(), 1, true)
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
			git_repo:clone()
		end},
		{"update", function()
			git_repo:pull()
		end},
		{"status", function()
			git_repo:status()
		end},
		{"reset", function()
			print("Are you sure? Type \"yes\"")
			local answer = io.read()
			if answer == "yes" then
				git_repo:reset()
			end
		end},
		{"build repo", function()
			repoBuilder:build()
		end},
		{"build zip", build_zip},
		{"update zip (game.love only)", update_zip},
		{"exit", os.exit},
	}
end

if arg[1] == "build_repo" then
	repoBuilder:build()
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
