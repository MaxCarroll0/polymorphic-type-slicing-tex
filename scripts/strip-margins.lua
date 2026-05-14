-- Drop RawInline/RawBlock LaTeX whose first command/environment is one we
-- have no plain-text rendering for.
--
-- Two classes:
--   * figure_cmds / drop_envs  — TikZ pictures, \ooalign overlays.
--     Always stripped: a literal "\tikz[baseline=…]" string is never useful.
--   * margin_cmds — margin notes and mechanisation annotations.
--     Stripped iff the pandoc metadata `slice-strip-margins` is "true".
--     The flake's `stripMargins=true` build flag sets that metadata.
--
-- This is run unconditionally for the txt/md/org outputs.

local margin_cmds = {
  marginpar = true, marginnote = true,
  mechfile = true, mechbox = true,
  mech = true, mechyes = true, mechno = true, mechpartial = true,
}

local figure_cmds = {
  tikz = true, tikzpicture = true, tikzcd = true,
  node = true, draw = true, path = true,
  ooalign = true,
  pgfpicture = true, pgfsetlinewidth = true,
}

local drop_envs = {
  tikzpicture = true, tikzcd = true,
  pgfpicture = true, scope = true,
}

local strip_margins = true  -- updated from metadata in Meta()

function Meta(meta)
  if meta and meta['slice-strip-margins'] ~= nil then
    local v = pandoc.utils.stringify(meta['slice-strip-margins'])
    strip_margins = (v == "true" or v == "1" or v == "yes")
  end
  return meta
end

local function first_command(text)
  local env = text:match('^%s*\\begin%s*{([^}]+)}')
  if env then return env, true end
  return text:match('^%s*\\([a-zA-Z@]+)'), false
end

local function check(el)
  if el.format ~= 'tex' and el.format ~= 'latex' then return el end
  local cmd, is_env = first_command(el.text)
  if not cmd then return el end
  if is_env and drop_envs[cmd] then return {} end
  if figure_cmds[cmd] then return {} end
  if strip_margins and margin_cmds[cmd] then return {} end
  return el
end

function RawInline(el) return check(el) end
function RawBlock(el)  return check(el) end
