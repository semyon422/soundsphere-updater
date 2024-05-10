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

function RepoBuilder:build()
	util.md("repo")

	util.rm("repo/soundsphere")
	util.md("repo/soundsphere")

	local gamedir = "repo/soundsphere/gamedir.love"
	util.cp(self.git_repo:getDirName(), gamedir)

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

	self:writeConfigs(gamedir)

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

return RepoBuilder
