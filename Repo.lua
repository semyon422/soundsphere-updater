local class = require("class")
local util = require("util")

---@class repo.Repo
---@operator call: repo.Repo
local Repo = class()

---@param url string
---@param name string
function Repo:new(url, name)
	self.url = url
	self.name = name
end

---@param branch string
function Repo:setBranch(branch)
	self.branch = branch
end

function Repo:getDirName()
	return ("%s-%s"):format(self.name, self.branch)
end

function Repo:formatCommand(command)
	return("git -C %s %s"):format(self:getDirName(), command)
end

function Repo:execute(command)
	os.execute(self:formatCommand(command))
end

function Repo:pread(command)
	return util.popen_read(self:formatCommand(command))
end

function Repo:clone()
	os.execute(("git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch --branch %s %s %s"):format(
		self.branch, self.url, self:getDirName()
	))
end

function Repo:status()
	self:execute("status")
end

function Repo:pull()
	self:execute("pull --recurse-submodules")
end

function Repo:reset()
	self:execute("reset --hard --recurse-submodules")
end

function Repo:log_date()
	return self:pread("log -1 --format=%cd"):match("^%s*(.+)%s*\n.*$")
end

function Repo:log_commit()
	return self:pread("log -1 --format=%H"):match("^%s*(.+)%s*\n.*$")
end

return Repo
