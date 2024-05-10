local class = require("class")
local stbl = require("stbl")
local crc32 = require("crc32")
local json = require("json")
local util = require("util")
local config = require("config")

---@class repo.RepoBuilder
---@operator call: repo.RepoBuilder
local RepoBuilder = class()

---@param git_repo repo.GitRepo
function RepoBuilder:new(git_repo)
	self.git_repo = git_repo
end

local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

function RepoBuilder:writeConfigs(gamedir)
	util.write(gamedir .. "/version.lua", serialize({
		date = self.git_repo:log_date(),
		commit = self.git_repo:log_commit(),
	}))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	local urls = dofile(urls_path)
	urls.host = config.game.api
	urls.update = config.game.repo .. "/files.json"
	urls.osu = config.osu
	urls.multiplayer = config.game.multiplayer
	util.write(urls_path, serialize(urls))
end

local extract_list = {
	"bin",
	"resources",
	"userdata",
	"game-appimage",
	"game-linux",
	"game-install-ubuntu64",
	"game-macos",
	"game-win64.bat",
}

function RepoBuilder:build()
	util.md("repo")

	local gamerepo = "repo/soundsphere"
	local gamedir = gamerepo .. "/gamedir.love"

	util.rm(gamerepo)
	util.md(gamerepo)

	util.cp(self.git_repo:getDirName(), gamedir)

	for _, dir in ipairs(extract_list) do
		util.mv(gamedir .. "/" .. dir, gamerepo)
	end
	util.mv(gamedir .. "/3rd-deps/lib", gamerepo .. "/bin/")

	util.findall(gamedir, '-regextype posix-egrep -not -regex ".*\\.(lua|c|sql)$" -type f -delete')
	util.findall(gamerepo, '-name ".*" -delete')
	util.findall(gamerepo, "-empty -type d -delete")

	self:writeConfigs(gamedir)

	os.execute(("7z a -tzip %s/game.love ./%s/*"):format(gamerepo, gamedir))  -- "./" is important
	util.rm(gamedir)

	util.cp("conf.lua", gamerepo)

	local files = {}
	for line in util.find(gamerepo, "-not -type d") do
		table.insert(files, {
			path = line:gsub(("^%s/"):format(gamerepo), ""),
			url = config.game.repo .. line:gsub("^repo", ""),
			hash = crc32.hash(util.read(line)),
		})
	end

	util.write(gamerepo .. "/userdata/files.lua", serialize(files))
	util.write("repo/files.json", json.encode(files))
end

return RepoBuilder
