-- probe.lua: dump legacy-syntax highlight groups per token of the current buffer.
--
-- Usage (any OS, from the plugin root):
--   nvim --headless --clean --cmd "set rtp^=." -c "luafile test/probe.lua" FILE.nelua
-- Env:
--   PROBE_OUT   write to this file instead of stdout
--   PROBE_LINES "a-b" restrict to a line range
--
-- Each line is printed, followed by one entry per run of characters that share
-- the same syntax item:  'text' Item -> StdGroup
-- StdGroup is the first standard group (:help group-name) on the `hi link`
-- chain, i.e. the group colour schemes style.

local out = {}
local STANDARD = {}
for g in ("Comment Constant String Character Number Boolean Float Identifier Function Statement Conditional Repeat Label Operator Keyword Exception PreProc Include Define Macro PreCondit Type StorageClass Structure Typedef Special SpecialChar Tag Delimiter SpecialComment Debug Underlined Ignore Error Todo Added Changed Removed"):gmatch("%S+") do STANDARD[g] = true end
local function standard_group(name)
  local seen = {}
  while name and name ~= "" and not STANDARD[name] and not seen[name] do
    seen[name] = true
    name = vim.api.nvim_get_hl(0, { name = name, link = true }).link
  end
  return name or ""
end
local function emit(s) out[#out + 1] = s end

local buf = vim.api.nvim_get_current_buf()
local n = vim.api.nvim_buf_line_count(buf)
local first, last = 1, n
local range = os.getenv("PROBE_LINES")
if range then
  local a, b = range:match("^(%d+)%-(%d+)$")
  first, last = tonumber(a), math.min(tonumber(b), n)
end

emit(("filetype=%s syntax=%s current_syntax=%s ts_highlight=%s"):format(
  vim.bo.filetype, vim.bo.syntax, tostring(vim.b.current_syntax), tostring(vim.b.ts_highlight)))

for lnum = first, last do
  local line = vim.fn.getline(lnum)
  emit(("%4d| %s"):format(lnum, line))
  local runs = {}
  local prev_item, start = nil, 1
  local len = #line
  for col = 1, len + 1 do
    local item, final
    if col <= len then
      local id = vim.fn.synID(lnum, col, 1)
      item = vim.fn.synIDattr(id, "name")
      final = standard_group(item)
      item = item .. "\0" .. final
    end
    if col > len or item ~= prev_item then
      if prev_item and prev_item ~= "\0" then
        local text = line:sub(start, col - 1)
        if text:match("%S") then
          local it, fg = prev_item:match("^(.-)%z(.*)$")
          runs[#runs + 1] = ("'%s' %s -> %s"):format(text, it, fg)
        end
      end
      prev_item, start = item, col
    end
  end
  if #runs > 0 then emit("    " .. table.concat(runs, " | ")) end
end

local path = os.getenv("PROBE_OUT")
if path then
  local f = assert(io.open(path, "w"))
  f:write(table.concat(out, "\n"), "\n")
  f:close()
else
  io.stdout:write(table.concat(out, "\n"), "\n")
end
vim.cmd("qa!")
