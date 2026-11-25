-- leakcheck.lua: compare the syntax highlighting of the current buffer with an
-- independent lexer that follows the lexical rules of nelua-lang's
-- lualib/nelua/syntaxdefs.lua (COMMENT, STRING, LONG_*, PREPROCESS,
-- PreprocessExpr, PreprocessName, SHEBANG).
--
-- Usage (from the plugin root):
--   nvim --headless --clean --cmd "set rtp^=." -c "luafile test/leakcheck.lua" FILE.nelua
-- Env: LEAK_OUT=path appends one result line per file (default: stdout).
--
-- Every non-blank character is classified by the reference lexer as
--   comment | string | ppdelim | code
-- and checked against the first standard highlight group of the syntax item:
--   comment -> Comment or Todo
--   string  -> String, SpecialChar (escapes) or Error (invalid escapes)
--   ppdelim -> PreProc
--   code    -> anything except Comment / String
-- A region that leaks (an unclosed region swallowing code, or code where a
-- string/comment should be) shows up as mismatches.

local STANDARD = {}
for g in ("Comment Constant String Character Number Boolean Float Identifier Function Statement Conditional Repeat Label Operator Keyword Exception PreProc Include Define Macro PreCondit Type StorageClass Structure Typedef Special SpecialChar Tag Delimiter SpecialComment Debug Underlined Ignore Error Todo"):gmatch("%S+") do STANDARD[g] = true end
local function std(name)
  local seen = {}
  while name and name ~= "" and not STANDARD[name] and not seen[name] do
    seen[name] = true
    name = vim.api.nvim_get_hl(0, { name = name, link = true }).link
  end
  return name or ""
end

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local text = table.concat(lines, "\n") .. "\n"
local N = #text
local class = {} -- byte index -> category

local function mark(a, b, c) for i = a, b do class[i] = c end end

-- position of the closing long bracket for "=" level eq, starting at i
local function long_close(i, eq)
  local s, e = text:find("]" .. eq .. "]", i, true)
  return s, e
end

local lex -- forward

-- short string starting at quote position i; returns last index
local function short_string(i)
  local q = text:sub(i, i)
  local j = i + 1
  while j <= N do
    local c = text:sub(j, j)
    if c == "\\" then
      local n = text:sub(j + 1, j + 1)
      if n == "z" then
        j = j + 2
        while j <= N and text:sub(j, j):match("%s") do j = j + 1 end
      else
        j = j + 2 -- escape (including backslash-newline)
      end
    elseif c == q then
      return j
    elseif c == "\n" then
      return j - 1 -- unclosed string ends at the line end
    else
      j = j + 1
    end
  end
  return N
end

-- lex range [a, b]
lex = function(a, b)
  local i = a
  while i <= b do
    local c = text:sub(i, i)
    if i == 1 and text:sub(1, 2) == "#!" then
      local e = (text:find("\n", i, true) or N + 1) - 1
      mark(i, e, "comment"); i = e + 1
    elseif text:sub(i, i + 1) == "--" then
      local eq = text:match("^%[(=*)%[", i + 2)
      if eq then
        local _, e = long_close(i + 4 + #eq, eq)
        e = math.min(e or N, b)
        mark(i, e, "comment"); i = e + 1
      else
        local e = math.min((text:find("\n", i, true) or N + 1) - 1, b)
        mark(i, e, "comment"); i = e + 1
      end
    elseif text:sub(i, i + 1) == "##" then
      local eq = text:match("^%[(=*)%[", i + 2)
      if eq then
        local open_e = i + 3 + #eq
        local s, e = long_close(open_e + 1, eq)
        s, e = s or b + 1, math.min(e or b, b)
        mark(i, open_e, "ppdelim")
        lex(open_e + 1, s - 1)
        if s <= b then mark(s, e, "ppdelim") end
        i = e + 1
      else
        local e = math.min((text:find("\n", i, true) or N + 1) - 1, b)
        mark(i, i + 1, "ppdelim")
        lex(i + 2, e)
        i = e + 1
      end
    elseif text:sub(i, i + 1) == "#[" or text:sub(i, i + 1) == "#|" then
      local close = text:sub(i + 1, i + 1) == "[" and "]#" or "|#"
      local s, e = text:find(close, i + 2, true)
      s, e = s or b + 1, math.min(e or b, b)
      mark(i, i + 1, "ppdelim")
      lex(i + 2, s - 1)
      if s <= b then mark(s, e, "ppdelim") end
      i = e + 1
    elseif c == "[" and text:match("^%[=*%[", i) then
      local eq = text:match("^%[(=*)%[", i)
      local _, e = long_close(i + 2 + #eq, eq)
      e = math.min(e or N, b)
      mark(i, e, "string"); i = e + 1
    elseif c == '"' or c == "'" then
      local e = math.min(short_string(i), b)
      mark(i, e, "string"); i = e + 1
    else
      class[i] = "code"; i = i + 1
    end
  end
end

lex(1, N)

-- compare
local ok_for = {
  comment = { Comment = true, Todo = true },
  string = { String = true, SpecialChar = true, Error = true },
  ppdelim = { PreProc = true },
}
local mismatches, checked, examples = 0, 0, {}
local pos = 1
for lnum, line in ipairs(lines) do
  for col = 1, #line do
    local ch = line:sub(col, col)
    local cat = class[pos + col - 1]
    if not ch:match("%s") and cat then
      checked = checked + 1
      local g = std(vim.fn.synIDattr(vim.fn.synID(lnum, col, 1), "name"))
      local good
      if cat == "code" then
        good = g ~= "Comment" and g ~= "String" and g ~= "Todo"
      else
        good = ok_for[cat][g] or false
      end
      if not good then
        mismatches = mismatches + 1
        if #examples < 5 then
          examples[#examples + 1] = ("L%d:%d %s got %s | %s"):format(lnum, col, cat, g ~= "" and g or "NONE", line)
        end
      end
    end
  end
  pos = pos + #line + 1
end

local result = ("%s lines=%d chars=%d mismatches=%d%s"):format(
  vim.fn.expand("%:."), #lines, checked, mismatches,
  #examples > 0 and ("\n    " .. table.concat(examples, "\n    ")) or "")
local out = os.getenv("LEAK_OUT")
if out then
  local f = assert(io.open(out, "a")); f:write(result, "\n"); f:close()
else
  io.stdout:write(result, "\n")
end
vim.cmd("qa!")
