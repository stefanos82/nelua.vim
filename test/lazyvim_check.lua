-- lazyvim_check.lua: verify the plugin inside a real LazyVim config.
--
-- Usage (uses your normal config, no --clean):
--   nvim --headless -c "luafile <plugin>/test/lazyvim_check.lua" FILE.nelua
-- Env: CHECK_OUT=path (default stdout), CHECK_LUA=path of a .lua file to compare.

local out = {}
local function say(fmt, ...) out[#out + 1] = fmt:format(...) end

-- let lazy.nvim / LazyVim finish their lazy loading (LazyFile, VeryLazy)
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
vim.wait(1500, function() return false end)

local STANDARD = {}
for g in ("Comment Constant String Character Number Boolean Float Identifier Function Statement Conditional Repeat Label Operator Keyword Exception PreProc Include Define Macro PreCondit Type StorageClass Structure Typedef Special SpecialChar Tag Delimiter SpecialComment Debug Underlined Ignore Error Todo"):gmatch("%S+") do STANDARD[g] = true end
local function std(name)
  local seen = {}
  while name and name ~= "" and not STANDARD[name] and not seen[name] do
    seen[name] = true
    name = vim.api.nvim_get_hl(0, { name = name, link = true }).link
  end
  return name or "NONE"
end

local function report(buf)
  vim.api.nvim_set_current_buf(buf)
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local have = "LazyVim not loaded"
  if _G.LazyVim and LazyVim.treesitter and LazyVim.treesitter.have then
    have = LazyVim.treesitter.have(ft)
  end
  say("file=%s", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"))
  say("  filetype=%s  lang=%s  &syntax=%s  b:current_syntax=%s", ft, lang, vim.bo[buf].syntax, tostring(vim.b[buf].current_syntax))
  say("  b:ts_highlight=%s  highlighter.active=%s  LazyVim.treesitter.have(%q)=%s",
    tostring(vim.b[buf].ts_highlight), tostring(vim.treesitter.highlighter.active[buf] ~= nil), ft, tostring(have))
  say("  indentexpr=%s  commentstring=%s  shiftwidth=%d  expandtab=%s  foldexpr=%s",
    vim.bo[buf].indentexpr, vim.bo[buf].commentstring, vim.bo[buf].shiftwidth, tostring(vim.bo[buf].expandtab), vim.wo.foldexpr)
end

local nelua_buf = vim.api.nvim_get_current_buf()
-- re-open so the FileType autocmds registered by lazily loaded plugins run too
vim.cmd("edit!")
report(nelua_buf)

-- sample tokens: first occurrence of each text on any line
local samples = { "local", "##", "<comptime>", "print", "integer", "@record", "--", "'hello'", "0x1.921FB54442D18p+1", "switch", "goto" }
local lines = vim.api.nvim_buf_get_lines(nelua_buf, 0, -1, false)
for _, s in ipairs(samples) do
  for lnum, line in ipairs(lines) do
    local c = line:find(s, 1, true)
    if c and not line:match("^%s*%-%-@") then
      local item = vim.fn.synIDattr(vim.fn.synID(lnum, c, 1), "name")
      say("  token %-24q L%-4d item=%-22s group=%s", s, lnum, item, std(item))
      break
    end
  end
end

local lua_file = os.getenv("CHECK_LUA")
if lua_file then
  vim.cmd("edit " .. vim.fn.fnameescape(lua_file))
  vim.wait(500, function() return false end)
  report(vim.api.nvim_get_current_buf())
end

-- report the Nelua buffer again, now that every lazy plugin has loaded
report(nelua_buf)

say("  nvim-treesitter.highlight module loadable: %s", tostring((pcall(require, "nvim-treesitter.highlight"))))
say("  v:errmsg=%q", vim.v.errmsg)
say("  nvim=%s", tostring(vim.version()))

local text = table.concat(out, "\n") .. "\n"
local path = os.getenv("CHECK_OUT")
if path then
  local f = assert(io.open(path, "w")); f:write(text); f:close()
else
  io.stdout:write(text)
end
vim.cmd("qa!")
