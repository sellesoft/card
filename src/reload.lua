--
--
-- Module reloader.
--
--

local log = require("logger").register_module("reload")

local reload = {}

-- list of registered tables
-- that may be reloaded
reload.manifest = {}

-- set true when reloading
-- so we know that instead of registering a given obj
-- we just capture it instead to replace the original 
-- later.
reload.is_reloading = false

-- table we capture objects in when they are being reloaded
reload.captures = {}

reload.
register = function(name, file, obj)
	if reload.is_reloading then
		reload.captures[name] = obj
	else
		reload.manifest[name] = {file=file,obj=obj}
	end
end

local reload_internal = function(name)
	local entry = reload.manifest[name]
	if not entry then
		log:error("given entry '", name, "' was not found in reload's manifest.")
		return false
	end

	log:info("reloading table '", name, "' from file '", entry.file, "'")

	local chunk, errmsg = loadfile(entry.file)

	if not chunk then
		log:error("failed to load file '", entry.file, "': ", errmsg)
		return false
	end

	local result = table.pack(pcall(chunk))

	if not result[1] then
		log:error("reloaded file threw error: ", result[2])
		return false
	end

	-- check that the wanted object was captured

	local capture = reload.captures[name]

	if not capture then
		log:error("reloaded file did not register requested object '", name, "'!")
		return false
	end

	-- check types are the same 

	local obj = entry.obj

	local obj_type = type(obj)
	local cap_type = type(capture)

	if obj_type ~= cap_type then
		log:error("type of captured object '", cap_type, "' is not the same as the originally registerd object '", obj_type, "'!")
		return false
	end

	if obj_type == "table" then
		for k,v in pairs(capture) do
			-- check if already existed in registered obj
			if obj[k] then
				local objk_type = type(obj[k])
				if objk_type == "function" then
					-- we're going to replace the function in the obj with
					-- the one in capture, so we need to readjust the captures
					-- upvalues in use by the obj
					local f_obj = obj[k]
					local f_cap = capture[k]
					local idx = 1
					local obj_upvalues = {}
					local cap_upvalues = {}
					while true do
						local obj_uname, obj_uval = debug.getupvalue(f_obj, idx)
						local cap_uname, cap_uval = debug.getupvalue(f_cap, idx)

						if not obj_uname and not cap_uname then
							break
						end

						if obj_uname then
							obj_upvalues[obj_uname] = { idx, obj_uval }
						end

						if cap_uname then
							cap_upvalues[cap_uname] = { idx, cap_uval }
						end

						idx = idx + 1
					end

					local info = debug.getinfo(f_obj, "nSl")

					-- now we need to properly match upvalue indexes in the new function
					for k,v in pairs(obj_upvalues) do
						idx = idx + 1
						if cap_upvalues[k] then
							debug.setupvalue(f_cap, cap_upvalues[k][1], v[2])
						end
					end

					obj[k] = capture[k]
				else
					-- dont disturb the original object ?
				end
			else
				-- if we don't already have it just add it to the table
				obj[k] = v
			end
		end
	else
		-- TODO(sushi) move this to the register function
		log:error("only reloading tables is supported at the moment.")
		return false
	end

	log("finished reloading '", name, "'")

	return true
end

reload.
reload = function(name)
	reload.is_reloading = true
	local result = reload_internal(name)
	reload.is_reloading = false
	reload.captures = {}
	return result
end

setmetatable(reload, {__call = function(_,n) reload.reload(n) end})

return reload
