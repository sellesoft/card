--
--
--  Central logger.
--
--

local logger = {}

logger.indentation = 0;
logger.color = true;
logger.src_loc = false;

logger.
color = function(col, str)
	if not logger.color then return str end

	local colormap = {
		["default"]       = 39,
		["black"]         = 30,
		["red"]           = 31,
		["green"]         = 32,
		["yellow"]        = 33,
		["blue"]          = 34,
		["magenta"]       = 35,
		["cyan"]          = 36,
		["light grey"]    = 37,
		["dark grey"]     = 90,
		["light red"]     = 91,
		["light green"]   = 91,
		["light yellow"]  = 93,
		["light blue"]    = 94,
		["light magenta"] = 95,
		["light cyan"]    = 96,
		["white"]         = 97,
	}

	local wrapcol = function(col, s)
		return "\027["..colormap[col].."m"..s.."\027[0m"
	end

	if not colormap[col] then
		error(wrapcol("red", "error: ").."unrecognized color given to colorize: '"..col.."'")
	end

	return wrapcol(col, str)
end

local write_indentation = function()
	for i=1,logger.indentation do
		io.write " "
	end
end

logger.
verbosity_levels = {
	trace   = 6,
	debug   = 5,
	info    = 4,
	warning = 3,
	error   = 2,
	fatal   = 1,
}

logger.verbosity = logger.verbosity_levels.debug

local write_name = function(self)
	if logger.name then
		io.write(self.name, ": ")
	end
end

local write_verbosity = function(v, c)
	io.write(logger.color(c, v), ": ")
end

local Logger = {
	name = "** unnamed logger **";

	verbosity = logger.verbosity_levels;

	set_verbosity = function(v)
		logger.verbosity = v
	end;

	get_verbosity = function(v)
		return logger.verbosity
	end;

	trace = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.trace then return end
		write_name(self)
		write_verbosity("trace", "blue")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	debug = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.debug then return end
		write_name(self)
		write_verbosity("debug", "green")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	info = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.info then return end
		write_name(self)
		write_verbosity(" info", "cyan")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	warn = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.warning then return end
		write_name(self)
		write_verbosity(" warn", "yellow")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	error = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.error then return end
		write_name(self)
		write_verbosity("error", "red")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	fatal = function(self, ...)
		if logger.verbosity < logger.verbosity_levels.fatal then return end
		write_name(self)
		write_verbosity("fatal", "red")
		write_indentation()
		io.write(...)
		io.write("\n")
	end;

	push_indent = function(_,n)
		n = n or 1
		logger.indentation = logger.indentation + n
	end;

	pop_indent = function(_,n)
		n = n or 1
		logger.indentation = math.max(0, logger.indentation - n)
	end;
}

Logger.__index = Logger
Logger.__call = function(self, ...) self:info(...) end

logger.
register_module = function(name)
	local o = {}
	o.name = name
	setmetatable(o, Logger)
	return o
end

return logger


