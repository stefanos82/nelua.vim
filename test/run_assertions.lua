-- run_assertions.lua: check syntax highlighting against assertion comments.
--
-- Usage (from the plugin root, any OS):
--   nvim --headless --clean --cmd "set rtp^=." -c "luafile test/run_assertions.lua" FILE.nelua
-- Env:
--   ASSERT_OUT   write the report to this file instead of stdout
--   ASSERT_VERBOSE=1  also list passing assertions
--
-- Assertion format (the same as Sublime Text syntax tests, so the
-- nelua-sublime test file can be used unchanged):
--
--   local x = 10
--   --        ^^ constant.numeric          <- Sublime scope, mapped to Vim groups
--   --    ^ =Identifier                    <- exact final Vim group ("=" prefix)
--   --  ^ =Keyword - =Error                <- after a lone "-": must NOT be these
--   -- <- comment                          <- "<-" points at column 1
--
-- An assertion line refers to the closest line above it that is not itself an
-- assertion line. The checked value is the first standard group (:help
-- group-name) reached by following `hi link` chains from the syntax item,
-- i.e. the group colour schemes style. Plain text with no syntax item has the
-- group "" (written as =NONE).
--
-- Sublime scopes are mapped with SCOPE_MAP below (longest prefix wins). A scope
-- with no mapping (meta.*, punctuation.* ...) says nothing about colour in Vim
-- and is skipped. When a positive list has several scopes, the right-most one
-- that maps decides (Sublime lists scopes outer -> inner).

local POS = {
  ["comment"] = { "Comment" },
  ["punctuation.definition.comment"] = { "Comment" },
  -- Sublime stacks scopes, so an escape inside a string still has "string";
  -- in Vim each character has one group, so escapes count as string too.
  ["string"] = { "String", "SpecialChar", "Error" },
  ["meta.string"] = { "String", "SpecialChar", "Error" },
  ["punctuation.definition.string"] = { "String" },
  ["string.unquoted.key"] = { "NONE", "Identifier" },
  ["constant.character.escape"] = { "SpecialChar" },
  ["invalid.illegal.invalid-escape"] = { "Error" },
  ["invalid.illegal.unclosed-string"] = { "Error" },
  ["constant.numeric"] = { "Number" },
  ["meta.number"] = { "Number" },
  ["punctuation.separator.decimal"] = { "Number" },
  ["constant.language.boolean"] = { "Boolean" },
  ["constant.language.null"] = { "Constant" },
  ["constant.language"] = { "Constant", "Special" },
  ["variable.language.this"] = { "Special" },
  ["keyword.control.conditional"] = { "Conditional" },
  ["keyword.control.loop"] = { "Repeat" },
  ["keyword.control.return"] = { "Statement", "Keyword" },
  ["keyword.control.break"] = { "Statement", "Keyword" },
  ["keyword.control.goto"] = { "Statement", "Keyword" },
  ["keyword.control.continue"] = { "Statement", "Keyword" },
  ["keyword.control.fallthrough"] = { "Statement", "Keyword" },
  ["keyword.control"] = { "Keyword", "Conditional", "Repeat", "Statement" },
  ["keyword.operator.logical"] = { "Operator", "Keyword" },
  ["keyword.operator"] = { "Operator" },
  ["keyword.declaration.function"] = { "Keyword" },
  ["storage.type.function"] = { "Keyword" },
  ["storage.modifier"] = { "StorageClass", "Keyword", "Statement" },
  ["storage.type"] = { "Type" },
  ["entity.name.function"] = { "Function" },
  ["variable.function"] = { "Function" },
  ["support.function.builtin"] = { "Function", "Special" },
  ["support.constant.builtin"] = { "Special", "Constant" },
  ["entity.name.label"] = { "Label" },
  ["variable.label"] = { "Label" },
  ["punctuation.definition.label"] = { "Label" },
  ["variable.annotation"] = { "Macro" },
  ["entity.other.attribute-name"] = { "Macro" },
  ["punctuation.definition.annotation"] = { "Macro", "Delimiter", "Special" },
  ["variable.other"] = { "NONE", "Identifier" },
  ["variable.parameter"] = { "NONE", "Identifier" },
  ["markup.inserted"] = { "PreProc" },
}

local NEG = {
  ["comment"] = { "Comment" },
  ["constant"] = { "Constant", "Boolean", "Number", "Float", "Character", "SpecialChar" },
  ["invalid"] = { "Error" },
  ["illegal"] = { "Error" },
  ["entity"] = { "Function" },
  ["storage.modifier"] = { "StorageClass" },
  ["meta.annotation"] = { "Macro" },
}

local function lookup(map, scope)
  local best, bestlen
  for prefix, groups in pairs(map) do
    if scope == prefix or scope:sub(1, #prefix + 1) == prefix .. "." then
      if not bestlen or #prefix > bestlen then best, bestlen = groups, #prefix end
    end
  end
  return best
end

local function strip_lua_suffix(scope) return (scope:gsub("%.lua$", "")) end

local function resolve(token, map)
  if token:sub(1, 1) == "=" then
    local g = token:sub(2)
    return { g }
  end
  return lookup(map, strip_lua_suffix(token))
end

-- The standard highlight groups of `:help group-name`. Colour schemes style
-- these; a scheme may link e.g. Conditional -> Statement, so we stop at the
-- first standard group of the link chain instead of following it to the end.
local STANDARD = {}
for _, g in ipairs({
  "Comment", "Constant", "String", "Character", "Number", "Boolean", "Float",
  "Identifier", "Function", "Statement", "Conditional", "Repeat", "Label",
  "Operator", "Keyword", "Exception", "PreProc", "Include", "Define", "Macro",
  "PreCondit", "Type", "StorageClass", "Structure", "Typedef", "Special",
  "SpecialChar", "Tag", "Delimiter", "SpecialComment", "Debug", "Underlined",
  "Ignore", "Error", "Todo", "Added", "Changed", "Removed",
}) do STANDARD[g] = true end

local function standard_group(name)
  local seen = {}
  while name and name ~= "" and not STANDARD[name] and not seen[name] do
    seen[name] = true
    local hl = vim.api.nvim_get_hl(0, { name = name, link = true })
    name = hl.link
  end
  return name
end

local function final_group(lnum, col)
  local id = vim.fn.synID(lnum, col, 1)
  local item = vim.fn.synIDattr(id, "name")
  local name = standard_group(item)
  if not name or name == "" then return "NONE", item end
  return name, item
end

local function contains(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

local report, pass, fail, skip, xfail, xpass = {}, 0, 0, 0, 0, 0
-- Expected failures: "<corpus file>.xfail" next to the corpus, one entry per
-- line: "<assertion line number> <reason>". They are reported, not hidden.
local XFAIL = {}
do
  local f = io.open(vim.fn.expand("%:p") .. ".xfail", "r")
  if f then
    for l in f:lines() do
      local n, why = l:match("^%s*(%d+)%s+(.*)$")
      if n then XFAIL[tonumber(n)] = why end
    end
    f:close()
  end
end
local verbose = os.getenv("ASSERT_VERBOSE") == "1"
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local target = nil -- line number of the code line under test

for i, line in ipairs(lines) do
  local carets_pre, carets, spec = line:match("^(%s*%-%-%s*)(%^+)%s*(.*)$")
  local arrow_spec = line:match("^%s*%-%-%s*<%-%s*(.*)$")
  -- substring form:  --@ "text"#n spec
  local sub_text, sub_n, sub_spec = line:match('^%s*%-%-@%s*"(.-)"#?(%d*)%s+(.*)$')
  local is_header = line:match("^%-%- SYNTAX TEST")
  if (carets or arrow_spec or sub_text) and target and not is_header then
    local cols = {}
    if carets then
      for c = #carets_pre + 1, #carets_pre + #carets do cols[#cols + 1] = c end
    elseif sub_text then
      spec = sub_spec
      sub_text = sub_text:gsub('\\"', '"')
      local occurrence = tonumber(sub_n) or 1
      local from, s = 1, nil
      for _ = 1, occurrence do
        s = lines[target]:find(sub_text, from, true)
        if not s then break end
        from = s + 1
      end
      if not s then
        fail = fail + 1
        report[#report + 1] = ("FAIL L%d: text %q (#%d) not found in code L%d"):format(i, sub_text, occurrence, target)
        goto continue
      end
      for c = s, s + #sub_text - 1 do cols[#cols + 1] = c end
    else
      spec = arrow_spec
      cols = { 1 }
    end
    local positives, negatives, neg = {}, {}, false
    for tok in spec:gmatch("%S+") do
      if tok == "-" then
        neg = true
      elseif tok:sub(1, 1) == "-" and #tok > 1 and tok:sub(2, 2) ~= "-" then
        negatives[#negatives + 1] = tok:sub(2)
      elseif neg then
        negatives[#negatives + 1] = tok
      else
        positives[#positives + 1] = tok
      end
    end
    local want
    for k = #positives, 1, -1 do
      want = resolve(positives[k], POS)
      if want then break end
    end
    local unwanted = {}
    for _, tok in ipairs(negatives) do
      local g = resolve(tok, NEG)
      if g then for _, x in ipairs(g) do unwanted[#unwanted + 1] = x end end
    end
    if not want and #unwanted == 0 then
      skip = skip + 1
    else
      local bad = {}
      for _, c in ipairs(cols) do
        local g, item = final_group(target, c)
        if (want and not contains(want, g)) or contains(unwanted, g) then
          bad[#bad + 1] = ("col %d=%s(%s)"):format(c, g, item)
        end
      end
      local where = ("L%d (code L%d) [%s]"):format(i, target, spec)
      if #bad == 0 and XFAIL[i] then
        xpass = xpass + 1
        report[#report + 1] = "XPASS " .. where .. " (listed as expected failure: " .. XFAIL[i] .. ")"
      elseif #bad == 0 then
        pass = pass + 1
        if verbose then report[#report + 1] = "PASS " .. where end
      elseif XFAIL[i] then
        xfail = xfail + 1
        report[#report + 1] = ("XFAIL %s: %s"):format(where, XFAIL[i])
      else
        fail = fail + 1
        report[#report + 1] = ("FAIL %s\n     code: %s\n     want: %s%s\n     got:  %s"):format(
          where, lines[target],
          want and table.concat(want, "|") or "(any)",
          #unwanted > 0 and ("  not: " .. table.concat(unwanted, "|")) or "",
          table.concat(bad, ", "))
      end
    end
  elseif not carets and not arrow_spec and not sub_text then
    target = i
  end
  ::continue::
end

report[#report + 1] = ("SUMMARY file=%s pass=%d fail=%d xfail=%d xpass=%d skipped(no colour meaning)=%d"):format(
  vim.fn.expand("%:t"), pass, fail, xfail, xpass, skip)

local text = table.concat(report, "\n") .. "\n"
local path = os.getenv("ASSERT_OUT")
if path then
  local f = assert(io.open(path, "w")); f:write(text); f:close()
else
  io.stdout:write(text)
end
vim.cmd((fail > 0 or xpass > 0) and "cq!" or "qa!")
