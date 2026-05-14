local src_file  = os.getenv("SRC_FILE")
local src_dir   = os.getenv("SRC_DIR")
local figdir    = os.getenv("FIGDIR")
local base      = os.getenv("BASE")
local fig_out   = os.getenv("FIG_OUT")
local stub_file = os.getenv("STUB_FILE") or ""

local function exists(p)
  local f = io.open(p, "rb"); if not f then return false end
  f:close(); return true
end

local function file_size(p)
  local f = io.open(p, "rb"); if not f then return 0 end
  local sz = f:seek("end"); f:close()
  return sz or 0
end

local function read_file(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a"); f:close()
  return s
end

local function write_file(p, s)
  local f = assert(io.open(p, "wb"))
  f:write(s); f:close()
end

local function shq(s)
  return "'" .. (s:gsub("'", [['\'']])) .. "'"
end

if not src_file or not exists(src_file) then os.exit(0) end
local text = read_file(src_file)

local function strip_fig_wrappers(s)
  s = s:gsub("\\begin{figure%*?}%[[^%]]*%]", "")
  s = s:gsub("\\begin{figure%*?}", "")
  s = s:gsub("\\end{figure%*?}", "")
  return s
end

local function strip_caption(s)
  local m_start, m_end = s:find("\\caption", 1, true)
  if not m_start then return s, nil end
  local nc = s:sub(m_end + 1, m_end + 1)
  if nc:match("[%w_]") then return s, nil end
  local i = m_end + 1
  while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
  if s:sub(i, i) == '[' then
    local d, j = 1, i + 1
    while j <= #s and d > 0 do
      local c = s:sub(j, j)
      if c == '[' then d = d + 1
      elseif c == ']' then d = d - 1 end
      j = j + 1
    end
    i = j
    while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
  end
  if s:sub(i, i) ~= '{' then return s, nil end
  local d, j = 1, i + 1
  local start_arg = j
  while j <= #s and d > 0 do
    local c = s:sub(j, j)
    if c == '{' then d = d + 1
    elseif c == '}' then d = d - 1 end
    j = j + 1
  end
  return s:sub(1, m_start - 1) .. s:sub(j), s:sub(start_arg, j - 2)
end

local i, n = 1, 0
local stub_parts, prev_end = {}, 1

while true do
  local b_start, b_end = text:find("\\begin{figure%*?}", i)
  if not b_start then break end
  local e_start, e_end = text:find("\\end{figure%*?}", b_end + 1)
  if not e_start then break end
  local block = text:sub(b_start, e_end)
  n = n + 1

  local _, caption_text = strip_caption(strip_fig_wrappers(block))

  local body = strip_fig_wrappers(block)
  body = (strip_caption(body))
  body = body:gsub("\\label{[^}]*}", "")
  -- Force subfigures full-width so they stack rather than going side-by-side.
  body = body:gsub("\\begin{subfigure}(%b[])%b{}", "\\begin{subfigure}%1{\\linewidth}")
  body = body:gsub("\\begin{subfigure}%b{}",       "\\begin{subfigure}{\\linewidth}")
  local cap_block = ""
  if caption_text and caption_text ~= "" then
    cap_block = "\n\\par\\medskip\\captionof{figure}{" .. caption_text .. "}"
  end
  local wrapper_name = "figwrap-" .. base .. "-" .. n
  local wrapper = figdir .. "/" .. wrapper_name .. ".tex"
  write_file(wrapper,
    "\\documentclass[12pt,border={8pt 8pt 8pt 30pt},varwidth=18cm]{standalone}\n" ..
    "\\input{preamble.tex}\n" ..
    "\\pagestyle{empty}\n" ..
    "\\captionsetup{justification=centering,singlelinecheck=false}\n" ..
    "\\begin{document}\n" ..
    "\\begin{minipage}{18cm}\n\\centering\n" ..
    body .. cap_block ..
    "\n\\end{minipage}\n\\end{document}\n")
  os.execute(
    "cd " .. shq(src_dir) ..
    " && latexmk -interaction=nonstopmode -pdf -lualatex -outdir=" ..
    shq(figdir) .. " " .. shq(wrapper) .. " >/dev/null 2>&1")

  local pdf = figdir .. "/" .. wrapper_name .. ".pdf"
  if exists(pdf) and file_size(pdf) > 0 then
    local svg_out = fig_out .. "/" .. base .. "-fig" .. n .. ".svg"
    local ok = os.execute(
      "pdftocairo -svg " .. shq(pdf) .. " " .. shq(svg_out) .. " 2>/dev/null")
    if not ok then
      io.write("  (svg failed for " .. base .. "-fig" .. n .. ")\n")
    end
  else
    local err = ""
    local lf = io.open(figdir .. "/" .. wrapper_name .. ".log", "r")
    if lf then
      for line in lf:lines() do
        if line:sub(1, 2) == "! " then err = line; break end
      end
      lf:close()
    end
    io.write("  (skip " .. base .. "-fig" .. n .. ": " ..
             (err ~= "" and err or "no pdf produced") .. ")\n")
  end

  if stub_file ~= "" then
    local cap = caption_text or ""
    local cap_part = cap ~= "" and ("\\caption{" .. cap .. "}\n") or ""
    local stub = "\\begin{figure}\n" ..
                 "\\includegraphics{Figures/" .. base .. "-fig" .. n .. ".svg}\n" ..
                 cap_part ..
                 "\\end{figure}"
    stub_parts[#stub_parts+1] = text:sub(prev_end, b_start - 1)
    stub_parts[#stub_parts+1] = stub
    prev_end = e_end + 1
  end

  i = e_end + 1
end

if stub_file ~= "" then
  stub_parts[#stub_parts+1] = text:sub(prev_end)
  write_file(stub_file, table.concat(stub_parts))
end

io.write(tostring(n))
