local util = {}

function util.download(url, path)
	print(("Downloading %s"):format(url))
	local p = assert(io.popen(("curl --location --silent --create-dirs --output %s %s"):format(path, url)))
	return p:read("*all")
end

function util.popen_read(command)
	local p = assert(io.popen(command .. " 2> /dev/null"))
	local content = p:read("*all")
	p:close()
	return content
end

function util.rm(path)
	os.execute(("rm -rf %s"):format(path))
end

function util.rm_find(root, path)
	os.execute(("find %q -name %q -exec rm -rf {} +"):format(root, path))
end

function util.md(path)
	os.execute(("mkdir %s"):format(path))
end

function util.mv(src, dst)
	os.execute(("mv %s %s"):format(src, dst))
end

function util.cp(src, dst)
	os.execute(("cp -r %s %s"):format(src, dst))
end

function util.read(path)
	local f = assert(io.open(path, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

function util.write(path, content)
	local f = assert(io.open(path, "wb"))
	f:write(content)
	f:close()
end

return util
