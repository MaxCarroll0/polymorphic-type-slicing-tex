local tpl_path, body_path, mode, out_path = arg[1], arg[2], arg[3], arg[4]

local function read_file(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a"); f:close()
  return s
end

local tpl  = read_file(tpl_path)
local body = read_file(body_path)

local i = tpl:find("__MODE__", 1, true)
if i then
  tpl = tpl:sub(1, i - 1) .. mode .. tpl:sub(i + #"__MODE__")
end

local marker = "%% __BEGIN_GENERATED__\n%% __END_GENERATED__"
i = tpl:find(marker, 1, true)
if i then
  tpl = tpl:sub(1, i - 1)
     .. "%% __BEGIN_GENERATED__\n" .. body .. "%% __END_GENERATED__"
     .. tpl:sub(i + #marker)
end

local of = assert(io.open(out_path, "w"))
of:write(tpl); of:close()
