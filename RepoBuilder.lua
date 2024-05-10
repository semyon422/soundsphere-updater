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

function RepoBuilder:buildGenericRepo()
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
end

function RepoBuilder:build()
	self:buildGenericRepo()

	local gamerepo = "repo/soundsphere"
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

function RepoBuilder:build_zip()
	os.execute("7z a -tzip repo/soundsphere_temp.zip ./repo/soundsphere")
	util.rm("repo/soundsphere.zip")
	util.mv("repo/soundsphere_temp.zip", "repo/soundsphere.zip")
end

function RepoBuilder:update_zip()
	util.md("repo/tmp")
	util.md("repo/tmp/soundsphere")
	util.cp("repo/soundsphere/game.love", "repo/tmp/soundsphere/game.love")
	os.execute("7z u -tzip repo/soundsphere.zip ./repo/tmp/soundsphere")
	util.rm("repo/tmp")
end

function RepoBuilder:buildMacos()
	local game_app = "repo/macos/soundsphere.app"
	local Contents = game_app .. "/Contents"
	local Frameworks = Contents .. "/Frameworks"
	local Resources = Contents .. "/Resources"

	util.rm("repo/macos")
	util.md("repo/macos")
	os.execute("7z x -tzip love-macos.zip -orepo/macos")
	util.mv("repo/macos/love.app", game_app)
	util.findall(game_app, "-type l -delete")
	util.findall(Frameworks, '-type f -not -regex "^.*/A/[^/]*$" -delete')
	util.cp("Info.plist", game_app .. "/Contents")
	util.rm(Resources)
	util.cp("repo/soundsphere", Resources)
	for path in util.find(Resources .. "/bin/mac64", "-type f") do
		util.mv(path, Frameworks)
	end
	util.rm(Resources .. "/bin/win64")
	util.rm(Resources .. "/bin/linux64")

	util.findall(game_app, "-empty -type d -delete")

	os.execute("7z a -tzip repo/soundsphere_macos_temp.zip ./" .. game_app)
	util.rm("repo/soundsphere_macos.zip")
	util.mv("repo/soundsphere_macos_temp.zip", "repo/soundsphere_macos.zip")
end

return RepoBuilder
