local class = require("class")
local util = require("util")

---@class repo.GitRepo
---@operator call: repo.GitRepo
local GitRepo = class()

---@param url string
---@param name string
function GitRepo:new(url, name)
	self.url = url
	self.name = name
end

---@param branch string
function GitRepo:setBranch(branch)
	self.branch = branch
end

function GitRepo:getDirName()
	return ("%s-%s"):format(self.name, self.branch)
end

function GitRepo:formatCommand(command)
	return("git -C %s %s"):format(self:getDirName(), command)
end

function GitRepo:execute(command)
	os.execute(self:formatCommand(command))
end

function GitRepo:pread(command)
	return util.popen_read(self:formatCommand(command))
end

function GitRepo:clone()
	os.execute(("git clone --depth 1 --recurse-submodules --shallow-submodules --single-branch --branch %s %s %s"):format(
		self.branch, self.url, self:getDirName()
	))
end

function GitRepo:status()
	self:execute("status")
end

function GitRepo:pull()
	self:execute("pull --recurse-submodules")
end

function GitRepo:reset()
	self:execute("reset --hard --recurse-submodules")
end

function GitRepo:log_date()
	return self:pread("log -1 --format=%cd"):match("^%s*(.+)%s*\n.*$")
end

function GitRepo:log_commit()
	return self:pread("log -1 --format=%H"):match("^%s*(.+)%s*\n.*$")
end

return GitRepo
