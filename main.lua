local pkg = require("aqua.package")
pkg.add("aqua")

local config = require("config")
local util = require("util")
local GitRepo = require("GitRepo")
local RepoBuilder = require("RepoBuilder")

local branch_file = assert(io.open("branch", "rb"))
local branch = branch_file:read("*a"):match("^%s*(.-)%s*$")

local git_repo = GitRepo(config.github.repo, "soundsphere")
git_repo:setBranch(branch)

local repoBuilder = RepoBuilder(git_repo)

local love_macos = "https://github.com/love2d/love/releases/download/11.5/love-11.5-macos.zip"

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

local function is_love_macos_downloaded()
	return util.popen_read("ls"):find("love-macos.zip", 1, true)
end

local function is_game_downloaded()
	return util.popen_read("ls"):find(git_repo:getDirName(), 1, true)
end

local function get_menu_items()
	return {
		{"build repo", function()
			repoBuilder:build()
		end},
		{"update zip (game.love only)", function()
			repoBuilder:update_zip()
		end},
		{"build zip", function()
			repoBuilder:build_zip()
		end},
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
		{"download love-macos", function()
			util.download(love_macos, "love-macos.zip")
		end},
		{"build macos", function()
			repoBuilder:buildMacos()
		end},
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
	print("love-macos: " .. (is_love_macos_downloaded() and "+" or "-"))
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
