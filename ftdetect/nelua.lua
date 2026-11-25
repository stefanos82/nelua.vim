-- Nelua filetype detection for Neovim.
--
-- The extension rule is needed because Neovim has no "nelua" filetype.
-- The pattern rule fixes a misdetection: Neovim's hashbang table uses the
-- unanchored Lua pattern "lua" (lua/vim/filetype/detect.lua,
-- match_from_hashbang), so "#!/usr/bin/env nelua" otherwise becomes "lua".
vim.filetype.add({
  extension = {
    nelua = "nelua",
  },
  pattern = {
    [".*"] = {
      function(_, bufnr)
        if not bufnr then
          return -- vim.filetype.match() called without a buffer
        end
        local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        -- "nelua" as a whole word: not "nelua-lsp" or "neluac"
        if first and (first:match("^#!.*[/ ]nelua%s") or first:match("^#!.*[/ ]nelua$")) then
          return "nelua"
        end
      end,
      { priority = math.huge },
    },
  },
})
