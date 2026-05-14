-- Clean up Math text content and crack open RawBlock display math that
-- pandoc could not parse (typically because of \begin{aligned}…\end{aligned}
-- with `&` separators). After cracking, each row becomes an ordinary Math
-- element pandoc can write through the standard math path — for plain text
-- that means Unicode; for gfm/org that means the row is wrapped in the
-- format's native math delimiters.
--
-- Mode flag:
--   slice-text-mode = txt | md | org   (default txt, via SLICE_TEXT_MODE env)

local MODE = os.getenv("SLICE_TEXT_MODE") or "txt"

function Meta(meta)
  if meta and meta['slice-text-mode'] then
    MODE = pandoc.utils.stringify(meta['slice-text-mode'])
  end
  return meta
end

-- ──── substitution tables ────────────────────────────────────────────────

local glyphs = {
  -- stmaryrd brackets (used by \type, \contextualsub, \hole, \mark*)
  { "\\llbracket",     "⟦" },
  { "\\rrbracket",     "⟧" },
  { "\\llparenthesis", "⦇" },
  { "\\rrparenthesis", "⦈" },
  -- AMS symbols pandoc sometimes leaves raw inside complex math
  { "\\boxdot",        "⊡" },
  { "\\nRightarrow",   "⇏" },
  { "\\nLeftarrow",    "⇍" },
  { "\\bigcirc",       "○" },
  -- Pandoc's plain writer maps \setminus to a literal backslash. That looks
  -- like a residual LaTeX command in the audit and visually fights with
  -- escape syntax. Force the Unicode SET MINUS instead.
  { "\\setminus",      "∖" },
  -- The \chk accent (and \check) pandoc plain doesn't unicode-fy.
  { "\\nleftarrow",    "↚" },
  { "\\nrightarrow",   "↛" },
  -- Big operators pandoc's plain writer leaves raw when combined with
  -- sub/superscripts (it can't typeset \bigsqcup_{j=1}^m as plain text).
  { "\\bigsqcup",      "⨆" },
  { "\\bigsqcap",      "⨅" },
  { "\\bigotimes",     "⨂" },
  { "\\bigoplus",      "⨁" },
  { "\\biguplus",      "⨄" },
  { "\\bigodot",       "⨀" },
  -- Brace decorators have no plain-text rendering. Drop them; their
  -- argument stays in place.
  -- ---------- standard math letters / operators ----------
  -- Pre-substituted to Unicode so that when pandoc's math writer falls
  -- back to dumping raw (e.g. on a math node containing \bigsqcup_{…}),
  -- the dump still reads as plain text rather than a soup of \tau, …
  { "\\alpha", "α" }, { "\\beta", "β" }, { "\\gamma", "γ" }, { "\\delta", "δ" },
  { "\\epsilon", "ε" }, { "\\zeta", "ζ" }, { "\\eta", "η" }, { "\\theta", "θ" },
  { "\\iota", "ι" }, { "\\kappa", "κ" }, { "\\lambda", "λ" }, { "\\mu", "μ" },
  { "\\nu", "ν" }, { "\\xi", "ξ" }, { "\\pi", "π" }, { "\\rho", "ρ" },
  { "\\sigma", "σ" }, { "\\tau", "τ" }, { "\\upsilon", "υ" }, { "\\phi", "φ" },
  { "\\chi", "χ" }, { "\\psi", "ψ" }, { "\\omega", "ω" },
  { "\\varepsilon", "ε" }, { "\\varphi", "φ" }, { "\\varsigma", "ς" }, { "\\vartheta", "ϑ" },
  { "\\Gamma", "Γ" }, { "\\Delta", "Δ" }, { "\\Theta", "Θ" }, { "\\Lambda", "Λ" },
  { "\\Xi", "Ξ" }, { "\\Pi", "Π" }, { "\\Sigma", "Σ" }, { "\\Upsilon", "Υ" },
  { "\\Phi", "Φ" }, { "\\Psi", "Ψ" }, { "\\Omega", "Ω" },
  -- Relations
  { "\\sim", "∼" }, { "\\simeq", "≃" }, { "\\approx", "≈" }, { "\\equiv", "≡" },
  { "\\neq", "≠" }, { "\\le", "≤" }, { "\\leq", "≤" }, { "\\ge", "≥" }, { "\\geq", "≥" },
  { "\\mid", "∣" }, { "\\parallel", "∥" }, { "\\perp", "⊥" }, { "\\vdash", "⊢" },
  { "\\dashv", "⊣" }, { "\\models", "⊨" }, { "\\in", "∈" }, { "\\notin", "∉" },
  { "\\ni", "∋" }, { "\\subset", "⊂" }, { "\\supset", "⊃" }, { "\\subseteq", "⊆" },
  { "\\supseteq", "⊇" }, { "\\sqsubseteq", "⊑" }, { "\\sqsupseteq", "⊒" },
  { "\\sqsubset", "⊏" }, { "\\sqsupset", "⊐" }, { "\\triangleq", "≜" },
  { "\\triangleright", "▷" }, { "\\triangleleft", "◁" },
  { "\\blacktriangleright", "▶" }, { "\\blacktriangleleft", "◀" },
  -- Operators
  { "\\cap", "∩" }, { "\\cup", "∪" }, { "\\sqcap", "⊓" }, { "\\sqcup", "⊔" },
  { "\\oplus", "⊕" }, { "\\otimes", "⊗" }, { "\\odot", "⊙" }, { "\\ominus", "⊖" },
  { "\\times", "×" }, { "\\div", "÷" }, { "\\cdot", "·" }, { "\\circ", "∘" },
  { "\\bullet", "•" }, { "\\ast", "∗" }, { "\\star", "⋆" }, { "\\amalg", "⨿" },
  { "\\wedge", "∧" }, { "\\vee", "∨" }, { "\\neg", "¬" },
  { "\\top", "⊤" }, { "\\bot", "⊥" }, { "\\forall", "∀" }, { "\\exists", "∃" },
  { "\\emptyset", "∅" },
  -- Arrows
  { "\\to", "→" }, { "\\gets", "←" }, { "\\mapsto", "↦" },
  { "\\leftarrow", "←" }, { "\\rightarrow", "→" },
  { "\\Leftarrow", "⇐" }, { "\\Rightarrow", "⇒" },
  { "\\leftrightarrow", "↔" }, { "\\Leftrightarrow", "⇔" },
  { "\\hookrightarrow", "↪" }, { "\\hookleftarrow", "↩" },
  { "\\longrightarrow", "⟶" }, { "\\longleftarrow", "⟵" },
  { "\\Longrightarrow", "⟹" }, { "\\Longleftarrow", "⟸" },
  { "\\leadsto", "⤳" }, { "\\rightsquigarrow", "⇝" },
  { "\\looparrowright", "↬" }, { "\\looparrowleft", "↫" },
  { "\\uparrow", "↑" }, { "\\downarrow", "↓" },
  { "\\Uparrow", "⇑" }, { "\\Downarrow", "⇓" },
  -- Fences / delimiters
  { "\\langle", "⟨" }, { "\\rangle", "⟩" },
  { "\\lfloor", "⌊" }, { "\\rfloor", "⌋" },
  { "\\lceil", "⌈" }, { "\\rceil", "⌉" },
  -- Decorations
  { "\\Box", "□" }, { "\\square", "□" }, { "\\Diamond", "◇" },
  { "\\ldots", "…" }, { "\\cdots", "⋯" }, { "\\dots", "…" }, { "\\vdots", "⋮" }, { "\\ddots", "⋱" },
  { "\\infty", "∞" }, { "\\prime", "′" }, { "\\partial", "∂" }, { "\\nabla", "∇" },
  -- Sums
  { "\\sum", "∑" }, { "\\prod", "∏" }, { "\\coprod", "∐" },
  { "\\int", "∫" }, { "\\oint", "∮" },
  { "\\bigcup", "⋃" }, { "\\bigcap", "⋂" },
  { "\\bigvee", "⋁" }, { "\\bigwedge", "⋀" },
  -- Stragglers from composite-glyph overlays.
  { "\\hidewidth",     ""  },
  { "\\cr",            ""  },
}

local composites = {
  -- \ooalign{$\bigcirc$\cr\hidewidth$\times$\hidewidth} → ⊗ (CIRCLED TIMES)
  -- Match before $-strip so the inner $ borders are still present.
  { "\\ooalign%s*{%s*%$\\bigcirc%$%s*\\cr%s*\\hidewidth%s*%$\\times%$%s*\\hidewidth%s*}", "⊗" },
  { "\\ooalign%s*{%s*\\bigcirc%s*\\cr%s*\\hidewidth%s*\\times%s*\\hidewidth%s*}",         "⊗" },
}

local drop_envs = { "tikzpicture", "tikzcd", "scope", "pgfpicture" }

-- Commands that take exactly one braced argument we throw away.
local drop_one_arg = {
  "color","textcolor","colorbox","fcolorbox",
  "phantom","vphantom","hphantom",
}

-- Commands that take one braced argument we keep the inner of (display
-- shifts that have no semantic content beyond formatting).
local unwrap_one_arg = {
  "mathbin","mathrel","mathop","mathit","mathbf","mathcal","mathfrak",
  "mathrm","mathsf","mathtt","mathsfit","boldsymbol",
  "texttt","textit","textsc","textbf","textnormal","textrm",
  "ensuremath","operatorname","mbox","hbox","text",
  -- Brace decorators: keep the inner expression and drop the brace overlay.
  "underbrace","overbrace","underline","overline","widetilde","widehat",
}

-- No-argument commands that should just disappear (TeX font-size /
-- declaration switches that have no meaning outside typesetting).
local drop_zero_arg = {
  "scriptsize","tiny","footnotesize","small","normalsize",
  "large","Large","LARGE","huge","Huge",
  "itshape","slshape","upshape","scshape","bfseries","mdseries",
  "rmfamily","sffamily","ttfamily","em",
  "noindent","centering","raggedright","raggedleft",
  "allowbreak","newline","linebreak","nobreak",
  "relax","protect",
}

local spacing = {
  { "\\[,;:!]",       " " },
  { "\\ ",            " " },
  { "\\quad",         "  " },
  { "\\qquad",        "    " },
  { "\\strut",        ""  },
  { "\\displaystyle", "" },
  { "\\negthinspace", "" },
  { "\\negmedspace",  "" },
  { "\\negthickspace",""},
}

-- ──── primitives ─────────────────────────────────────────────────────────

local function read_brace(s, i)
  if s:sub(i, i) ~= '{' then return nil, i end
  local depth, j = 1, i + 1
  local start = j
  while j <= #s and depth > 0 do
    local c = s:sub(j, j)
    if c == '\\' then j = j + 2
    elseif c == '{' then depth = depth + 1; j = j + 1
    elseif c == '}' then depth = depth - 1; j = j + 1
    else j = j + 1 end
  end
  return s:sub(start, j - 2), j
end

local function strip_cmd(s, name, keep)
  keep = keep or function(inner) return inner end
  local out = {}
  local i = 1
  local pat = "\\" .. name .. "%s*{"
  while i <= #s do
    local a, b = s:find(pat, i)
    if not a then out[#out+1] = s:sub(i); break end
    out[#out+1] = s:sub(i, a - 1)
    local inner, after = read_brace(s, b)
    if inner == nil then
      out[#out+1] = s:sub(a)
      break
    end
    out[#out+1] = keep(inner)
    i = after
  end
  return table.concat(out)
end

local function drop_env(s, env)
  local pat_b = "\\begin%s*{" .. env .. "}"
  local pat_e = "\\end%s*{"   .. env .. "}"
  local out = {}
  local i = 1
  while i <= #s do
    local a, b = s:find(pat_b, i)
    if not a then out[#out+1] = s:sub(i); break end
    out[#out+1] = s:sub(i, a - 1)
    local c, d = s:find(pat_e, b + 1)
    if not c then break end
    i = d + 1
  end
  return table.concat(out)
end

local function strip_env_keep(s, env)
  local pat_b = "\\begin%s*{" .. env .. "}"
  local pat_e = "\\end%s*{"   .. env .. "}"
  local out = {}
  local i = 1
  while i <= #s do
    local a, b = s:find(pat_b, i)
    if not a then out[#out+1] = s:sub(i); break end
    out[#out+1] = s:sub(i, a - 1)
    local c, d = s:find(pat_e, b + 1)
    if not c then out[#out+1] = s:sub(b + 1); break end
    out[#out+1] = s:sub(b + 1, c - 1)
    i = d + 1
  end
  return table.concat(out)
end

local function escape_pat(s)
  return (s:gsub("([%-%.%+%*%?%^%$%(%)%[%]%%])", "%%%1"))
end

-- ──── residual user-macro expansion ─────────────────────────────────────
--
-- Pandoc's +latex_macros reader extension (on by default for the LaTeX
-- reader) expands \newcommand/\def/\let from the preamble in-place
-- before our filter sees a Math node, so we don't need to redefine the
-- bulk of the dissertation's macros here. Only the cases where pandoc's
-- *writer* fails — or where pandoc's math reader bails out on a macro
-- it would otherwise expand — remain.
--
-- Rule = { name, arity, default_first_or_nil, template } with #1, #2 …
-- placeholders. A non-nil default makes the first argument optional.
local user_macros = {
  -- pandoc plain renders simple \check{x} → x̌, but bails on subscripts
  -- inside the argument (e.g. \check{e_\star}); \chk is just an alias.
  { "chk",       1, nil, "#1̌" },
  { "check",     1, nil, "#1̌" },
  -- Pandoc passes \resizebox/\scalebox through to the math reader,
  -- which fails. Drop the size args, keep the content.
  { "resizebox", 3, nil, "#3" },
  { "scalebox",  2, nil, "#2" },
  { "adjustbox", 1, nil, "#2" },
}

local function expand_one(s, rule)
  local name, arity, default, template = rule[1], rule[2], rule[3], rule[4]
  local pat = "\\" .. name
  local out = {}
  local i = 1
  while i <= #s do
    local a, b = s:find(pat, i, true)
    if not a then out[#out+1] = s:sub(i); break end
    -- Ensure the match isn't a prefix of a longer command.
    local nextc = s:sub(b + 1, b + 1)
    if nextc:match("[A-Za-z]") then
      out[#out+1] = s:sub(i, b); i = b + 1
    else
      out[#out+1] = s:sub(i, a - 1)
      local k = b + 1
      while s:sub(k, k):match("%s") do k = k + 1 end
      local args = {}
      -- Optional first arg
      if default ~= nil then
        if s:sub(k, k) == '[' then
          local close = s:find(']', k + 1, true)
          if close then
            args[1] = s:sub(k + 1, close - 1)
            k = close + 1
          else
            args[1] = default
          end
        else
          args[1] = default
        end
      end
      -- Required args. Accept either `{…}` (balanced braces) or a single
      -- non-brace token — TeX's "one-token argument" rule, used in the
      -- preamble for invocations like `\chk e` or `\Forall \alpha \tau`.
      local ok = true
      for _ = 1, arity do
        while s:sub(k, k):match("%s") do k = k + 1 end
        if s:sub(k, k) == '{' then
          local inner, after = read_brace(s, k)
          if not inner then ok = false; break end
          args[#args + 1] = inner
          k = after
        elseif s:sub(k, k) == '\\' then
          -- Single control sequence: \name, possibly followed by more args
          -- we don't try to parse — just take \name as the token.
          local name_end = k + 1
          while s:sub(name_end, name_end):match("[A-Za-z@]") do
            name_end = name_end + 1
          end
          if name_end == k + 1 then name_end = k + 2 end  -- single-char escape
          args[#args + 1] = s:sub(k, name_end - 1)
          k = name_end
        elseif s:sub(k, k) ~= '' then
          args[#args + 1] = s:sub(k, k)
          k = k + 1
        else
          ok = false; break
        end
      end
      if not ok then
        out[#out+1] = s:sub(a, b); i = b + 1
      else
        local repl = template
        for n, v in ipairs(args) do
          repl = repl:gsub("#" .. n, function() return v end)
        end
        -- If the text immediately before this command ends in a
        -- letter/digit and the replacement begins with one, insert a
        -- separating space so adjacent tokens don't fuse (e.g.
        -- "\looparrowright\check{e}" → "\looparrowright" + "ě" must not
        -- become "\looparrowrightě").
        local prev = out[#out] or ""
        local prev_tail = prev:sub(-1)
        local repl_head = repl:sub(1, 1)
        if prev_tail:match("[A-Za-z]") and repl_head:match("[%w%\\]") then
          repl = " " .. repl
        end
        out[#out+1] = repl
        i = k
      end
    end
  end
  return table.concat(out)
end

local function apply_user_macros(s)
  local prev
  -- Re-run until fixed point (some templates emit other macros, e.g.
  -- \mctxclass uses \looparrowright; user macros may reference other
  -- user macros).
  for _ = 1, 8 do
    prev = s
    for _, rule in ipairs(user_macros) do
      s = expand_one(s, rule)
    end
    if s == prev then break end
  end
  return s
end

-- Replace each \tikz[…]{…} with the inner `\strut$X$` payload (typical for
-- the project's box-style macros: \sli, \markbox, \slist, …). When no
-- such payload is found the whole \tikz call is dropped — TikZ pictures
-- proper carry no plain-text rendering.
local function strip_tikz(s)
  local out, i = {}, 1
  while i <= #s do
    local a, b = s:find("\\tikz", i, true)
    if not a then out[#out + 1] = s:sub(i); break end
    out[#out + 1] = s:sub(i, a - 1)
    local k = b + 1
    while s:sub(k, k):match("%s") do k = k + 1 end
    if s:sub(k, k) == '[' then
      local depth, j = 1, k + 1
      while j <= #s and depth > 0 do
        local c = s:sub(j, j)
        if c == '[' then depth = depth + 1
        elseif c == ']' then depth = depth - 1
        end
        j = j + 1
      end
      k = j
    end
    while s:sub(k, k):match("%s") do k = k + 1 end
    if s:sub(k, k) == '(' then
      local close = s:find(')', k + 1, true)
      if close then k = close + 1 end
    end
    while s:sub(k, k):match("%s") do k = k + 1 end
    local body, after = read_brace(s, k)
    if not body then i = b + 1
    else
      -- Nested \tikz inside body throws off the \strut$X$ pattern (the
      -- inner $...$ shadows the outer). Recurse into the body so the
      -- innermost \tikz is collapsed first.
      if body:find("\\tikz", 1, true) then
        body = strip_tikz(body)
      end
      local payload = body:match("\\strut%s*%$(.-)%$") or ""
      -- The dissertation's highlight macros (\sli, \slist, \markbox, \slr)
      -- all expand to \tikz[…]{\node[draw=COLOUR!N, dashed|…] (N){\strut$X$}}.
      -- Wrap the payload with vertical bars so plain-text readers can still
      -- see the slice/highlight boundary. Detect a box by looking for the
      -- `draw=` attribute (always present in the highlight macros, absent
      -- from incidental tikz figures whose bodies survive this far).
      if payload ~= "" and body:find("draw=", 1, true) then
        payload = "|" .. payload .. "|"
      end
      out[#out + 1] = payload
      i = after
    end
  end
  return table.concat(out)
end

-- ──── core: apply substitutions to a string of math text ─────────────────

local function apply_macros(s)
  -- Strip TeX line-comments first. They survive into Math text whenever
  -- pandoc expands a macro whose body uses `%` for line continuation
  -- (\sli, \markbox, \slist, …) and then can't parse the result.
  s = s:gsub("%%[^\n]*", "")

  -- pandoc's `+latex_macros` reader extension (on by default) expands
  -- most \newcommand definitions from the preamble before our filter
  -- ever sees the Math node. We only have to handle the macros pandoc
  -- can't (or won't) expand: \check/\resizebox/\not\sim/composites/etc.
  s = apply_user_macros(s)
  s = strip_tikz(s)
  for _, rule in ipairs(composites) do
    s = s:gsub(rule[1], rule[2])
  end
  for _, env in ipairs(drop_envs) do
    s = drop_env(s, env)
  end
  for _, name in ipairs(drop_one_arg) do
    s = strip_cmd(s, name, function() return "" end)
  end
  -- Unwrap font/style commands. Wrap the inner content in spaces so that
  -- adjacent control sequences don't fuse (e.g. \lfloor\mathit{Int} must
  -- not become \lfloorInt after unwrapping \mathit).
  for _, name in ipairs(unwrap_one_arg) do
    s = strip_cmd(s, name, function(inner) return " " .. inner .. " " end)
  end
  for _, name in ipairs(drop_zero_arg) do
    -- Drop \name when followed by a non-letter character so we don't eat
    -- prefixes of longer commands (e.g. \small vs \smallskip).
    s = s:gsub("\\" .. name .. "(%A)", "%1")
    s = s:gsub("\\" .. name .. "$",    "")
  end
  for _, rule in ipairs(spacing) do
    s = s:gsub(rule[1], rule[2])
  end
  -- Pre-substitute composite negations BEFORE the per-symbol substitution
  -- below: pandoc plain natively renders \not\sim → ≁, but only if both
  -- tokens survive together. If we have already replaced \sim with ∼ the
  -- writer can no longer match the digraph and leaves \not literal.
  s = s:gsub("\\not%s*\\sim",      "≁")
  s = s:gsub("\\not%s*\\equiv",    "≢")
  s = s:gsub("\\not%s*\\in",       "∉")
  s = s:gsub("\\not%s*\\subset",   "⊄")
  s = s:gsub("\\not%s*\\subseteq", "⊈")
  s = s:gsub("\\not%s*=",          "≠")
  s = s:gsub("\\not%s*\\le",       "≰")
  s = s:gsub("\\not%s*\\ge",       "≱")

  -- In md / org mode we want most LaTeX commands preserved so MathJax
  -- can render them downstream. The glyph table holds two kinds of rules
  -- intermixed: ones that *must* always run (composites like ⊗, brackets
  -- like ⟦, things pandoc plain mis-renders), and ones we should only
  -- run in txt (greek letters, standard operators, arrows). To keep the
  -- table single-source, we treat the latter — entries whose
  -- replacement is exactly one Unicode codepoint and whose command is
  -- a well-known math command — as txt-only by checking MODE here.
  local txt_only_set = {
    ["\\alpha"]=1,["\\beta"]=1,["\\gamma"]=1,["\\delta"]=1,["\\epsilon"]=1,
    ["\\zeta"]=1,["\\eta"]=1,["\\theta"]=1,["\\iota"]=1,["\\kappa"]=1,
    ["\\lambda"]=1,["\\mu"]=1,["\\nu"]=1,["\\xi"]=1,["\\pi"]=1,["\\rho"]=1,
    ["\\sigma"]=1,["\\tau"]=1,["\\upsilon"]=1,["\\phi"]=1,["\\chi"]=1,
    ["\\psi"]=1,["\\omega"]=1,["\\varepsilon"]=1,["\\varphi"]=1,
    ["\\varsigma"]=1,["\\vartheta"]=1,
    ["\\Gamma"]=1,["\\Delta"]=1,["\\Theta"]=1,["\\Lambda"]=1,["\\Xi"]=1,
    ["\\Pi"]=1,["\\Sigma"]=1,["\\Upsilon"]=1,["\\Phi"]=1,["\\Psi"]=1,["\\Omega"]=1,
    ["\\sim"]=1,["\\simeq"]=1,["\\approx"]=1,["\\equiv"]=1,["\\neq"]=1,
    ["\\le"]=1,["\\leq"]=1,["\\ge"]=1,["\\geq"]=1,["\\mid"]=1,
    ["\\parallel"]=1,["\\perp"]=1,["\\vdash"]=1,["\\dashv"]=1,["\\models"]=1,
    ["\\in"]=1,["\\notin"]=1,["\\ni"]=1,["\\subset"]=1,["\\supset"]=1,
    ["\\subseteq"]=1,["\\supseteq"]=1,["\\sqsubseteq"]=1,["\\sqsupseteq"]=1,
    ["\\sqsubset"]=1,["\\sqsupset"]=1,["\\triangleq"]=1,
    ["\\triangleright"]=1,["\\triangleleft"]=1,
    ["\\blacktriangleright"]=1,["\\blacktriangleleft"]=1,
    ["\\cap"]=1,["\\cup"]=1,["\\sqcap"]=1,["\\sqcup"]=1,
    ["\\oplus"]=1,["\\otimes"]=1,["\\odot"]=1,["\\ominus"]=1,
    ["\\times"]=1,["\\div"]=1,["\\cdot"]=1,["\\circ"]=1,
    ["\\bullet"]=1,["\\ast"]=1,["\\star"]=1,["\\amalg"]=1,
    ["\\wedge"]=1,["\\vee"]=1,["\\neg"]=1,["\\top"]=1,["\\bot"]=1,
    ["\\forall"]=1,["\\exists"]=1,["\\emptyset"]=1,
    ["\\to"]=1,["\\gets"]=1,["\\mapsto"]=1,["\\leftarrow"]=1,["\\rightarrow"]=1,
    ["\\Leftarrow"]=1,["\\Rightarrow"]=1,["\\leftrightarrow"]=1,["\\Leftrightarrow"]=1,
    ["\\hookrightarrow"]=1,["\\hookleftarrow"]=1,
    ["\\longrightarrow"]=1,["\\longleftarrow"]=1,
    ["\\Longrightarrow"]=1,["\\Longleftarrow"]=1,
    ["\\leadsto"]=1,["\\rightsquigarrow"]=1,
    ["\\looparrowright"]=1,["\\looparrowleft"]=1,
    ["\\uparrow"]=1,["\\downarrow"]=1,["\\Uparrow"]=1,["\\Downarrow"]=1,
    ["\\langle"]=1,["\\rangle"]=1,
    ["\\lfloor"]=1,["\\rfloor"]=1,["\\lceil"]=1,["\\rceil"]=1,
    ["\\Box"]=1,["\\square"]=1,["\\Diamond"]=1,
    ["\\ldots"]=1,["\\cdots"]=1,["\\dots"]=1,["\\vdots"]=1,["\\ddots"]=1,
    ["\\infty"]=1,["\\prime"]=1,["\\partial"]=1,["\\nabla"]=1,
    ["\\sum"]=1,["\\prod"]=1,["\\coprod"]=1,["\\int"]=1,["\\oint"]=1,
    ["\\bigcup"]=1,["\\bigcap"]=1,["\\bigvee"]=1,["\\bigwedge"]=1,
  }
  for _, rule in ipairs(glyphs) do
    if MODE == "txt" or not txt_only_set[rule[1]] then
      -- Match \name not followed by a letter (so \to doesn't eat \top).
      local pat = escape_pat(rule[1])
      s = s:gsub(pat .. "(%A)", rule[2] .. "%1")
      s = s:gsub(pat .. "$",    rule[2])
    end
  end
  -- Drop spurious $ markers inside math content. They come from nested
  -- text-in-math invocations like \textnormal{{\color{…}$\Uparrow$}…} the
  -- preamble macros use to switch fonts. After the outer text command is
  -- unwrapped, the dollars become bare math-mode toggles that confuse
  -- pandoc's writer.
  s = s:gsub("%$", "")
  -- Strip redundant braces left over from preamble groupings like
  -- `\mathbin{{\color{…}\OLDsqcup}}` → `{⊔}` after the colour and the
  -- \mathbin wrapper are gone. Only strip when the inner content has no
  -- letters/digits (so subscripts like x_{12} are preserved).
  if MODE == "txt" then
    for _ = 1, 4 do
      local changed = false
      s = s:gsub("{([^{}\\]-)}", function(inner)
        if inner:match("[%w_]") then return nil end
        if inner:match("^%s*$") then return nil end
        changed = true
        return inner
      end)
      if not changed then break end
    end
  end
  return s
end

-- ──── cracking display math the LaTeX reader could not parse ─────────────

local ALIGN_ENVS = {
  ["aligned"] = true, ["align"] = true, ["align*"] = true,
  ["alignat"] = true, ["alignat*"] = true, ["alignedat"] = true,
  ["gathered"] = true, ["gather"] = true, ["gather*"] = true,
  ["cases"] = true, ["dcases"] = true,
  ["array"] = true, ["matrix"] = true,
  ["bmatrix"] = true, ["pmatrix"] = true,
  ["vmatrix"] = true, ["Bmatrix"] = true, ["Vmatrix"] = true,
  ["smallmatrix"] = true,
  ["multline"] = true, ["multline*"] = true,
  ["split"] = true,
  ["eqnarray"] = true, ["eqnarray*"] = true,
}

local function find_top_align_env(s)
  for env in s:gmatch("\\begin%s*{([^}]+)}") do
    if ALIGN_ENVS[env] then return env end
  end
  return nil
end

local function split_rows(s)
  local rows = {}
  local depth = 0
  local env_depth = 0  -- counts \begin{…}…\end{…} nesting
  local start = 1
  local i = 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == '{' then depth = depth + 1; i = i + 1
    elseif c == '}' then depth = depth - 1; i = i + 1
    elseif c == '\\' then
      if s:sub(i, i + 5) == '\\begin' then
        env_depth = env_depth + 1
        i = i + 1
      elseif s:sub(i, i + 3) == '\\end' then
        env_depth = env_depth - 1
        i = i + 1
      elseif depth == 0 and env_depth == 0 and s:sub(i + 1, i + 1) == '\\' then
        rows[#rows + 1] = s:sub(start, i - 1)
        i = i + 2
        if s:sub(i, i) == '[' then
          local close = s:find(']', i + 1, true)
          if close then i = close + 1 end
        end
        start = i
      else
        i = i + 2
      end
    else i = i + 1 end
  end
  rows[#rows + 1] = s:sub(start)
  return rows
end

local function flatten_row(row)
  row = row:gsub("&", " ")
  -- Drop embedded $…$ markers: after \text{…} unwrapping the source's
  -- nested-math wrappers (`\text{... $x$ ...}`) leave dollar pairs in
  -- the row content; pandoc treats those as math boundaries and fails.
  row = row:gsub("%$", "")
  row = row:gsub("%s+", " ")
  return row:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Quick check for `\\` row separators outside of nested envs/braces.
local function has_row_separators(s)
  local depth, env_depth = 0, 0
  local i = 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == '{' then depth = depth + 1; i = i + 1
    elseif c == '}' then depth = depth - 1; i = i + 1
    elseif c == '\\' then
      if s:sub(i, i + 5) == '\\begin' then env_depth = env_depth + 1; i = i + 1
      elseif s:sub(i, i + 3) == '\\end' then env_depth = env_depth - 1; i = i + 1
      elseif depth == 0 and env_depth == 0 and s:sub(i + 1, i + 1) == '\\' then
        return true
      else i = i + 2 end
    else i = i + 1 end
  end
  return false
end

local function crack_display(body)
  local env = find_top_align_env(body)
  local inner = env and strip_env_keep(body, env) or body
  if not env and not has_row_separators(inner) then return nil end
  local rows = split_rows(inner)
  local out = {}
  for _, r in ipairs(rows) do
    local sub_rows = crack_display(r)
    if sub_rows then
      for _, sr in ipairs(sub_rows) do out[#out + 1] = sr end
    else
      local clean = flatten_row(apply_macros(r))
      if clean ~= "" then out[#out + 1] = clean end
    end
  end
  return out
end

-- ──── public AST hooks ───────────────────────────────────────────────────

function Math(el)
  el.text = apply_macros(el.text)
  if MODE == "txt" and not el.text:find("\\", 1, true) then
    -- All commands have been substituted to Unicode. Convert to Str so
    -- pandoc's plain writer doesn't wrap the now-Unicode content in
    -- `$…$` (it does so unconditionally when the math reader can't
    -- typeset complex notation like \bigsqcup_{…}^… subscripts).
    return pandoc.Str(el.text)
  end
  -- If this DisplayMath contains an alignment env, we leave it as-is here:
  -- the Pandoc walker visits Math inlines but cannot split them into
  -- multiple block-level paragraphs. The Para/Plain handler below picks
  -- up these elements and rewrites the parent block.
  return el
end

-- Block-level handler: if a Para/Plain contains a DisplayMath element
-- whose content uses an alignment-family environment, slice the para
-- around it and emit one paragraph per cracked row. The plain writer
-- then renders each row through the standard math path; the $$..$$
-- wrapper for the unparseable aligned block disappears.

local function trim_edges(list)
  while #list > 0 and (list[#list].t == 'Space' or list[#list].t == 'SoftBreak') do
    list[#list] = nil
  end
  while #list > 0 and (list[1].t == 'Space' or list[1].t == 'SoftBreak') do
    table.remove(list, 1)
  end
  return list
end

local function split_para(blk)
  if blk.t ~= 'Para' and blk.t ~= 'Plain' then return nil end
  local segments, current = {}, {}
  local saw_split = false
  for _, c in ipairs(blk.content) do
    if c.t == 'Math' and c.mathtype == 'DisplayMath'
       and (find_top_align_env(c.text) or has_row_separators(c.text)) then
      local rows = crack_display(c.text)
      if rows and #rows > 0 then
        segments[#segments + 1] = { kind = 'text', inlines = current }
        current = {}
        for _, r in ipairs(rows) do
          segments[#segments + 1] = { kind = 'math', text = r }
        end
        saw_split = true
      else
        current[#current + 1] = c
      end
    else
      current[#current + 1] = c
    end
  end
  segments[#segments + 1] = { kind = 'text', inlines = current }
  if not saw_split then return nil end

  local out = {}
  for _, seg in ipairs(segments) do
    if seg.kind == 'math' then
      out[#out + 1] = pandoc.Para { pandoc.Math('DisplayMath', seg.text) }
    else
      trim_edges(seg.inlines)
      if #seg.inlines > 0 then
        out[#out + 1] = (blk.t == 'Plain') and pandoc.Plain(seg.inlines)
                                           or pandoc.Para(seg.inlines)
      end
    end
  end
  return out
end

-- Recursively walk all block lists in the document tree, applying
-- split_para. Handles every container type the pandoc AST exposes.
local function walk_blocks(blocks)
  local out = {}
  for _, blk in ipairs(blocks) do
    local rep = split_para(blk)
    if rep then
      for _, b in ipairs(rep) do out[#out + 1] = b end
    else
      if blk.t == 'BlockQuote' or blk.t == 'Div' or blk.t == 'Note'
         or blk.t == 'Figure'   or blk.t == 'LineBlock' then
        blk.content = walk_blocks(blk.content)
      elseif blk.t == 'OrderedList' or blk.t == 'BulletList' then
        for i, item in ipairs(blk.content) do
          blk.content[i] = walk_blocks(item)
        end
      elseif blk.t == 'DefinitionList' then
        for _, item in ipairs(blk.content) do
          local defs = item[2]
          for j, d in ipairs(defs) do defs[j] = walk_blocks(d) end
        end
      elseif blk.t == 'Table' then
        -- Table cells contain [Block]. The pandoc Lua object exposes
        -- bodies/head/foot; iterate any field with a .content list.
        local function fix_cells(tbody)
          if not tbody or not tbody.body then return end
          for _, row in ipairs(tbody.body) do
            for _, cell in ipairs(row.cells) do
              cell.contents = walk_blocks(cell.contents)
            end
          end
        end
        if blk.head and blk.head.rows then
          for _, row in ipairs(blk.head.rows) do
            for _, cell in ipairs(row.cells) do
              cell.contents = walk_blocks(cell.contents)
            end
          end
        end
        if blk.bodies then
          for _, body in ipairs(blk.bodies) do fix_cells(body) end
        end
      end
      out[#out + 1] = blk
    end
  end
  return out
end

function Pandoc(doc)
  doc.blocks = walk_blocks(doc.blocks)
  return doc
end

local function rawblock_to_rows(body)
  local rows = crack_display(body)
  if not rows then
    return { pandoc.Para { pandoc.Math('DisplayMath', apply_macros(body)) } }
  end
  local blocks = {}
  for _, r in ipairs(rows) do
    blocks[#blocks + 1] = pandoc.Para { pandoc.Math('DisplayMath', r) }
  end
  return blocks
end

local function rawinline_to_inlines(body)
  return { pandoc.Math('InlineMath', apply_macros(body)) }
end

function RawBlock(el)
  if el.format ~= 'tex' and el.format ~= 'latex' then return el end
  local body = el.text:match("^%s*%$%$(.*)%$%$%s*$")
  if body then return rawblock_to_rows(body) end
  body = el.text:match("^%s*\\%[(.*)\\%]%s*$")
  if body then return rawblock_to_rows(body) end
  if find_top_align_env(el.text) then
    return rawblock_to_rows(el.text)
  end
  local cleaned = apply_macros(el.text)
  if cleaned:match("^%s*$") then return {} end
  return el
end

function RawInline(el)
  if el.format ~= 'tex' and el.format ~= 'latex' then return el end
  local body = el.text:match("^%s*%$(.*)%$%s*$")
  if body then return rawinline_to_inlines(body) end
  body = el.text:match("^%s*\\%((.*)\\%)%s*$")
  if body then return rawinline_to_inlines(body) end
  local cleaned = apply_macros(el.text)
  if cleaned:match("^%s*$") then return {} end
  return el
end
