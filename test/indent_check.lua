-- indent_check.lua: re-indent the current buffer with gg=G and count the
-- non-blank lines whose indentation changes (compared with the file as-is).
-- Usage: nvim --headless --clean --cmd "set rtp^=." -c "luafile test/indent_check.lua" FILE.nelua
-- Env: IND_OUT=path appends one result line per file (default: stdout).
local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
vim.cmd("silent normal! gg=G")
local after = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local diff, total, ex = 0, 0, {}
for i, l in ipairs(before) do
  if l:match("%S") then
    total = total + 1
    if l ~= after[i] then
      diff = diff + 1
      if #ex < 3 then ex[#ex+1] = ("    L%d: %q -> %q"):format(i, l, after[i]) end
    end
  end
end
local path = os.getenv("IND_OUT")
local f = path and io.open(path, "a") or io.stdout
f:write(("%s nonblank=%d changed=%d\n%s"):format(vim.fn.expand("%:t"), total, diff, #ex > 0 and table.concat(ex, "\n") .. "\n" or ""))
if path then f:close() end
vim.cmd("qa!")
