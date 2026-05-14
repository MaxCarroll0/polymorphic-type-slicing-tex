-- Rewrite `\inference[label]{premises}{conclusion}` (semantic.sty) into a
-- form a text reader can parse:
--   * txt mode  → "premises → conclusion"   (ASCII arrow)
--   * md / org  → "\dfrac{premises}{conclusion}"  (MathJax-renderable)
-- The semantic.sty macro itself is not in MathJax's vocabulary, so we have
-- to choose a substitute that survives the target writer.
--
-- Walks Math and (since pandoc emits some \inference uses as RawInline /
-- RawBlock when surrounding context confuses the LaTeX reader) also the
-- raw nodes.

local MODE = os.getenv("SLICE_TEXT_MODE") or "txt"

function Meta(meta)
  if meta and meta['slice-text-mode'] then
    MODE = pandoc.utils.stringify(meta['slice-text-mode'])
  end
  return meta
end

local function read_arg(s, i)
  if s:sub(i, i) ~= '{' then return nil, i end
  local depth, j = 1, i + 1
  local start = j
  while j <= #s and depth > 0 do
    local c = s:sub(j, j)
    if c == '\\' then j = j + 2
    else
      if c == '{' then depth = depth + 1
      elseif c == '}' then depth = depth - 1
      end
      j = j + 1
    end
  end
  return s:sub(start, j - 2), j
end

local function ws_skip(s, k)
  while s:sub(k, k):match("%s") do k = k + 1 end
  return k
end

local function combine(prem, concl)
  -- `&` is alignment in the source, not math; flatten to comma so the
  -- result is valid in any math context.
  prem  = prem:gsub("%s*&%s*", ", ")
  concl = concl:gsub("%s*&%s*", ", ")
  if MODE == "md" or MODE == "org" then
    return "\\dfrac{" .. prem .. "}{" .. concl .. "}"
  end
  return prem .. " → " .. concl
end

local function rewrite(s)
  local out, i = {}, 1
  while i <= #s do
    local a, b = s:find("\\inference", i, true)
    if not a then out[#out+1] = s:sub(i); break end
    out[#out+1] = s:sub(i, a - 1)
    local k = ws_skip(s, b + 1)
    if s:sub(k, k) == '[' then
      local depth, j = 1, k + 1
      while j <= #s and depth > 0 do
        local c = s:sub(j, j)
        if c == '[' then depth = depth + 1
        elseif c == ']' then depth = depth - 1
        end
        j = j + 1
      end
      k = ws_skip(s, j)
    end
    local prem, k2 = read_arg(s, k)
    if not prem then out[#out+1] = s:sub(a, b); i = b + 1; goto continue end
    k2 = ws_skip(s, k2)
    local concl, k3 = read_arg(s, k2)
    if not concl then out[#out+1] = s:sub(a, b); i = b + 1; goto continue end
    out[#out+1] = combine(prem, concl)
    i = k3
    ::continue::
  end
  return table.concat(out)
end

function Math(el)
  el.text = rewrite(el.text)
  return el
end

function RawInline(el)
  if el.format == 'tex' or el.format == 'latex' then
    el.text = rewrite(el.text)
  end
  return el
end

function RawBlock(el)
  if el.format == 'tex' or el.format == 'latex' then
    el.text = rewrite(el.text)
  end
  return el
end
