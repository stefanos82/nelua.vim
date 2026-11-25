-- run_all.lua: run every nelua.vim check. Cross-platform (no shell needed).
--
-- Usage, from anywhere:
--   nvim -l path/to/nelua.vim/test/run_all.lua [DIR_WITH_NELUA_SOURCES ...]
--
-- Checks (each in a fresh `nvim --headless --clean` with only this plugin):
--   1. assertion corpora (test/corpus/*.nelua with --@ / ^^^ assertions)
--   2. leak check: syntax vs. an independent reference lexer (test/leakcheck.lua)
--      on test/corpus/docs_examples.nelua and every *.nelua under the given dirs
--   3. indentation: gg=G must not change test/corpus/indent_sample.nelua
--   4. filetype detection: *.nelua and a "#!/usr/bin/env nelua" script
-- Exit code 0 when everything passes.

local script = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(script, ":p:h")
local root = vim.fn.fnamemodify(test_dir, ":h")
local nvim = vim.v.progpath
local rtp_cmd = ("lua vim.opt.rtp:prepend(%q)"):format(root)

local failures, lines = 0, {}
local function log(s) lines[#lines + 1] = s; io.stdout:write(s, "\n") end

local function run(args, env)
  local cmd = { nvim, "--headless", "--clean", "--cmd", rtp_cmd }
  vim.list_extend(cmd, args)
  return vim.system(cmd, { env = env, text = true }):wait()
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local s = f:read("*a"); f:close(); return s
end

local function corpus(name) return vim.fs.joinpath(root, "test", "corpus", name) end
local function tool(name) return vim.fs.joinpath(test_dir, name) end

-- 1. assertion corpora
for _, name in ipairs({ "nelua_features.nelua", "sublime_syntax_test_nelua.nelua" }) do
  local out = vim.fn.tempname()
  local r = run({ "-c", "luafile " .. vim.fn.fnameescape(tool("run_assertions.lua")), corpus(name) }, { ASSERT_OUT = out })
  local text = read(out)
  local summary = text:match("SUMMARY[^\n]*") or ("no summary (exit " .. r.code .. ")")
  log(("[%s] assertions %s"):format(r.code == 0 and "PASS" or "FAIL", summary))
  if r.code ~= 0 then
    failures = failures + 1
    for l in text:gmatch("[^\n]+") do
      if l:match("^FAIL") or l:match("^XPASS") then log("    " .. l) end
    end
  end
end

-- 2. leak check
local leak_files = { corpus("docs_examples.nelua") }
for i = 1, #arg do
  for _, f in ipairs(vim.fs.find(function(n) return n:match("%.nelua$") end,
    { path = arg[i], type = "file", limit = math.huge })) do
    leak_files[#leak_files + 1] = f
  end
end
local leak_out = vim.fn.tempname()
for _, f in ipairs(leak_files) do
  run({ "-c", "luafile " .. vim.fn.fnameescape(tool("leakcheck.lua")), f }, { LEAK_OUT = leak_out })
end
local nfiles, nlines, nmis, bad = 0, 0, 0, {}
for l in read(leak_out):gmatch("[^\n]+") do
  local nl, m = l:match(" lines=(%d+) chars=%d+ mismatches=(%d+)")
  if nl then
    nfiles = nfiles + 1; nlines = nlines + tonumber(nl); nmis = nmis + tonumber(m)
    if tonumber(m) > 0 then bad[#bad + 1] = l end
  elseif l:match("^    ") and #bad > 0 then
    bad[#bad + 1] = l
  end
end
local leak_ok = nmis == 0 and nfiles == #leak_files
log(("[%s] leak check: files=%d/%d lines=%d mismatches=%d"):format(leak_ok and "PASS" or "FAIL", nfiles, #leak_files, nlines, nmis))
if not leak_ok then
  failures = failures + 1
  for _, l in ipairs(bad) do log("    " .. l) end
end

-- 3. indentation
do
  local out = vim.fn.tempname()
  run({ "-c", "luafile " .. vim.fn.fnameescape(tool("indent_check.lua")), corpus("indent_sample.nelua") }, { IND_OUT = out })
  local text = read(out)
  local changed = tonumber(text:match("changed=(%d+)") or "-1")
  log(("[%s] indent: indent_sample.nelua %s"):format(changed == 0 and "PASS" or "FAIL", (text:match("[^\n]+") or "no result")))
  if changed ~= 0 then
    failures = failures + 1
    for l in text:gmatch("[^\n]+") do if l:match("^    ") then log(l) end end
  end
end

-- 4. filetype detection
do
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local cases = {
    { vim.fs.joinpath(dir, "plain.nelua"), "print('hi')\n", "nelua" },
    { vim.fs.joinpath(dir, "script_without_extension"), "#!/usr/bin/env nelua\nprint('hi')\n", "nelua" },
    -- must not be claimed by the plugin (Neovim itself then says "lua")
    { vim.fs.joinpath(dir, "other_tool_script"), "#!/usr/bin/env nelua-lsp\n", "!nelua" },
    { vim.fs.joinpath(dir, "plain.lua"), "print('hi')\n", "lua" },
  }
  for _, c in ipairs(cases) do
    local f = assert(io.open(c[1], "w")); f:write(c[2]); f:close()
    local r = run({ "-c", "lua io.stdout:write(vim.bo.filetype)", "-c", "qa!", c[1] })
    local ft = vim.trim(r.stdout or "")
    local ok = (c[3] == "!nelua") and (ft ~= "nelua") or (ft == c[3])
    log(("[%s] filetype: %s -> %q (want %q)"):format(ok and "PASS" or "FAIL", vim.fs.basename(c[1]), ft, c[3]))
    if not ok then failures = failures + 1 end
  end
end

log(("%s (%s, plugin at %s)"):format(failures == 0 and "ALL CHECKS PASSED" or (failures .. " CHECK(S) FAILED"),
  tostring(vim.version()), root))
os.exit(failures == 0 and 0 or 1)
