local pkg = require("aqua.pkg")
pkg.import_lua()
pkg.add("aqua")
pkg.export_lua()

local config = require("config")
local util = require("util")
local GitRepo = require("GitRepo")
local RepoBuilder = require("RepoBuilder")

local repo_client = GitRepo(config.github.repo, "client")
repo_client:setBranch(config.github.client_branch)

local repo_server = GitRepo(config.github.repo, "server")
repo_server:setBranch(config.github.server_branch)

local repoBuilder = RepoBuilder(repo_client)

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

local function is_client_downloaded()
	return util.popen_read("ls"):find(repo_client:getDirName(), 1, true)
end

local function get_menu_items()
	return {
		{"build repo", function()
			repoBuilder:build()
		end},
		{"build zip", function()
			repoBuilder:build_zip()
			repoBuilder:buildMacos()
		end},
		{"openresty reload", function()
			os.execute(("./%s/openresty reload"):format(repo_server:getDirName()))
		end},
		-- {"update zip (game.love only)", function()
		-- 	repoBuilder:update_zip()
		-- end},
		{"git pull", function()
			repo_client:pull()
			repo_server:pull()
		end},
		-- {"status", function()
		-- 	repo_client:status()
		-- 	repo_server:status()
		-- end},
		{"git clone", function()
			repo_client:clone()
			repo_server:clone()
		end},
		-- {"reset", function()
		-- 	print("Are you sure? Type \"yes\"")
		-- 	local answer = io.read()
		-- 	if answer == "yes" then
		-- 		repo_client:reset()
		-- 	end
		-- end},
		{"download love-macos", function()
			util.download(love_macos, "love-macos.zip")
		end},
		{"exit", os.exit},
	}
end

if arg[1] == "build_repo" then
	repoBuilder:build()
end

while true do
	clear()

	print("soundsphere updater")

	print("")
	print("git: " .. (is_git_installed() and "+" or "-"))
	print("7z: " .. (is_7z_installed() and "+" or "-"))
	print("curl: " .. (is_curl_installed() and "+" or "-"))
	print("love-macos: " .. (is_love_macos_downloaded() and "+" or "-"))
	print("")
	print("client branch: " .. config.github.client_branch)
	print("server branch: " .. config.github.server_branch)

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
