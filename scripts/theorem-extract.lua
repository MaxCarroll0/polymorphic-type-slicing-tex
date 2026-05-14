local mode     = os.getenv("THM_MODE") or "all"
local src_dir  = os.getenv("SRC_DIR") or "."
local in_path  = assert(os.getenv("REF_INPUTS"), "REF_INPUTS not set")
local out_path = assert(arg[1], "missing output path")

local MATH_ENVS = { theorem=true, lemma=true, proposition=true,
                    corollary=true, conjecture=true, counterexample=true }
local BOX_ENVS  = { majortheorembox=true, counterexamplebox=true, thmcase=true }

local groups = {}
do
  local f = assert(io.open(in_path, "r"))
  for line in f:lines() do
    if line ~= "" then
      local sid, file, sname = line:match("([^|]*)|([^|]*)|(.*)")
      if sid and file and sname then
        groups[#groups+1] = { sid = sid, file = file, sname = sname }
      end
    end
  end
  f:close()
end

local function find_mechbox(s, start)
  start = start or 1
  local a, b = s:find("\\mechbox{", start, true)
  if not a then return nil, -1 end
  local i, depth, buf = b + 1, 1, {}
  while i <= #s do
    local c = s:sub(i, i)
    if c == '{' then
      depth = depth + 1; buf[#buf+1] = c
    elseif c == '}' then
      depth = depth - 1
      if depth == 0 then return table.concat(buf), i + 1 end
      buf[#buf+1] = c
    else
      buf[#buf+1] = c
    end
    i = i + 1
  end
  return nil, -1
end

local function all_mechboxes(s)
  local out, start = {}, 1
  while true do
    local content, e = find_mechbox(s, start)
    if not content then return out end
    out[#out+1] = content
    start = e
  end
end

local function strip_mechbox(s)
  local out, i = {}, 1
  while i <= #s do
    local a = s:find("\\mechbox{", i, true)
    if not a then out[#out+1] = s:sub(i); break end
    out[#out+1] = s:sub(i, a - 1)
    local _, e = find_mechbox(s, a)
    i = (e ~= -1) and e or (#s + 1)
  end
  return table.concat(out)
end

local function grab_bracket(s, pos)
  if pos > #s or s:sub(pos, pos) ~= '[' then return nil, pos end
  local depth, i, start = 0, pos, nil
  while i <= #s do
    local c = s:sub(i, i)
    if c == '{' then depth = depth + 1
    elseif c == '}' then depth = math.max(0, depth - 1)
    elseif c == '[' and depth == 0 then start = i + 1
    elseif c == ']' and depth == 0 then return s:sub(start, i - 1), i + 1
    end
    i = i + 1
  end
  return nil, pos
end

local function strip_labels(s) return (s:gsub("\\label{[^}]*}", "")) end
local function find_label(s)   return s:match("\\label{([^}]*)}") end

local function find_begins(line)
  local out, s = {}, 1
  while true do
    local a, b, env = line:find("\\begin{([A-Za-z%*]+)}", s)
    if not a then break end
    out[#out+1] = { start = a, after = b + 1, env = env }
    s = b + 1
  end
  return out
end

local function find_ends(line)
  local out, s = {}, 1
  while true do
    local a, b, env = line:find("\\end{([A-Za-z%*]+)}", s)
    if not a then break end
    out[#out+1] = { start = a, after = b + 1, env = env }
    s = b + 1
  end
  return out
end

local function find_all_mechfile(line)
  local out = {}
  for content in line:gmatch("\\mechfile{([^}]*)}") do
    out[#out+1] = content
  end
  return out
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function nonblank(s) return s:match("%S") ~= nil end

local entries = {}
local providecmds, seen_pc = {}, {}

for _, g in ipairs(groups) do
  local path = src_dir .. "/" .. g.file
  local f = io.open(path, "r")
  if f then
    local lines = {}
    for line in f:lines() do lines[#lines+1] = line end
    f:close()

    for _, ln in ipairs(lines) do
      if ln:match("^%s*\\providecommand") then
        local opens, closes = 0, 0
        for _ in ln:gmatch("{") do opens = opens + 1 end
        for _ in ln:gmatch("}") do closes = closes + 1 end
        if opens == closes then
          local key = trim(ln)
          if not seen_pc[key] then
            seen_pc[key] = true
            providecmds[#providecmds+1] = (ln:gsub("%s+$", ""))
          end
        end
      end
    end

    local box_stack = {}
    local current_mechfile, pending_mechbox = "", ""
    local i = 1
    while i <= #lines do
      local line = lines[i]

      local mf = find_all_mechfile(line)
      if #mf > 0 then current_mechfile = mf[#mf] end

      local mb = all_mechboxes(line)
      if #mb > 0 then pending_mechbox = mb[#mb] end

      for _, b in ipairs(find_begins(line)) do
        if BOX_ENVS[b.env] then box_stack[#box_stack+1] = b.env end
      end
      for _, e in ipairs(find_ends(line)) do
        if BOX_ENVS[e.env] and #box_stack > 0 and box_stack[#box_stack] == e.env then
          box_stack[#box_stack] = nil
        end
      end

      for _, b in ipairs(find_begins(line)) do
        if MATH_ENVS[b.env] then
          local env = b.env
          local after = line:sub(b.after)
          local title, after_pos = grab_bracket(after, 1)
          title = title or ""
          local inline_mb = find_mechbox(after:sub(after_pos))
          local local_mb = inline_mb or pending_mechbox
          local label = find_label(after:sub(after_pos)) or ""

          local body_lines = {}
          local rest = strip_labels(strip_mechbox(after:sub(after_pos)))
          rest = trim(rest)
          if rest ~= "" and rest:sub(1, 4) ~= "\\end" then
            body_lines[#body_lines+1] = rest
          end

          local depth, j = 1, i + 1
          while j <= #lines do
            local ln = lines[j]
            for _, bm in ipairs(find_begins(ln)) do
              if bm.env == env then depth = depth + 1 end
            end
            local closed_here = false
            for _, em in ipairs(find_ends(ln)) do
              if em.env == env then
                depth = depth - 1
                if depth == 0 then
                  local pre = (ln:sub(1, em.start - 1):gsub("%s+$", ""))
                  if nonblank(pre) then body_lines[#body_lines+1] = pre end
                  closed_here = true
                  break
                end
              end
            end
            if closed_here then break end
            if label == "" then
              local lbl = find_label(ln)
              if lbl then label = lbl end
            end
            body_lines[#body_lines+1] = ln
            j = j + 1
          end

          local body = table.concat(body_lines, "\n")
          body = strip_labels(body)
          body = strip_mechbox(body)

          entries[#entries+1] = {
            sid = g.sid, sname = g.sname, env = env,
            title = title, label = label,
            boxed = #box_stack > 0,
            mechbox = local_mb, mechfile = current_mechfile,
            body = body,
          }
          pending_mechbox = ""
          i = j
          break
        end
      end
      i = i + 1
    end
  end
end

local kept = {}
for _, e in ipairs(entries) do
  local ok
  if     mode == "counterexamples" then ok = (e.env == "counterexample")
  elseif mode == "important"       then ok = e.boxed
  else                                  ok = true end
  if ok then kept[#kept+1] = e end
end
entries = kept

local order, seen_sid = {}, {}
for _, g in ipairs(groups) do
  if not seen_sid[g.sid] then
    order[#order+1] = { sid = g.sid, sname = g.sname }
    seen_sid[g.sid] = true
  end
end

local by_sec = {}
for _, e in ipairs(entries) do
  by_sec[e.sid] = by_sec[e.sid] or {}
  by_sec[e.sid][#by_sec[e.sid]+1] = e
end

local out = {}
if #providecmds > 0 then
  out[#out+1] = "%% File-local notation collected from scanned sections:\n"
  for _, pc in ipairs(providecmds) do out[#out+1] = pc .. "\n" end
  out[#out+1] = "\n"
end

local function clean_id(s)
  return (s:gsub("\\\\", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

for _, ord in ipairs(order) do
  local es = by_sec[ord.sid] or {}
  if #es > 0 then
    out[#out+1] = "\\section{From " .. ord.sname .. "}\n"
    for _, e in ipairs(es) do
      local title = trim(e.title)
      out[#out+1] = "\\begin{" .. e.env .. "}"
      if title ~= "" then out[#out+1] = "[" .. title .. "]" end
      out[#out+1] = "\n" .. (e.body:gsub("%s+$", "")) .. "\n"
      out[#out+1] = "\\end{" .. e.env .. "}\n"
      local tail = {}
      if e.mechbox  ~= "" then
        tail[#tail+1] = "\\textit{Lemma name:}\\ \\texttt{" .. clean_id(e.mechbox)  .. "}"
      end
      if e.mechfile ~= "" then
        tail[#tail+1] = "\\textit{File:}\\ \\texttt{"      .. clean_id(e.mechfile) .. "}"
      end
      if #tail > 0 then
        out[#out+1] = "\\par\\noindent\\small " .. table.concat(tail, " --- ") .. "\\par\n"
      end
      out[#out+1] = "\\medskip\n\n"
    end
  end
end

local of = assert(io.open(out_path, "w"))
of:write(table.concat(out)); of:close()
