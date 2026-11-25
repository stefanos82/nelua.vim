# nelua.vim

## Fork 
This is a fork from stefanos82/nelua.vim. See: https://github.com/stefanos82/nelua.vim
It is a rewrite of stefanos82/nelua.vim.

## About

Syntax highlighting for [Nelua](https://nelua.io/) programming language.

<img width="684" height="426" alt="image" src="https://github.com/user-attachments/assets/8d87fefe-f4f9-48e2-88d1-0c75c70ea74f" />

This repo is intended for a PR request. It contains many fixes. See [[#Issues in the original repo]] and [[#Improvements]]

## How to use this for Neovim

Download this repo. You should get a folder named `nelua.vim` after extracting the `.zip` file. 
Put it somewhere inside your config directory for Neovim. 

**For LazyVim / lazy.nvim:** Keep the directory somewhere inside your config folder.
Example: `~/.config/nvim/lua/plugins/nelua.vim/` on Linux, or
`%LOCALAPPDATA%/nvim/lua/plugins/nelua.vim/` on Windows) and add the file
`lua/plugins/nelua.lua`:

```lua
return {
    {
        dir = vim.fn.stdpath("config") .. "lua/plugins/nelua.vim",
        name = "nelua.vim",
        lazy = false, -- tiny; ftdetect must be registered before files open
    },
}
```

**Any other setup:** Put the directory on `'runtimepath'` (e.g. `vim.opt.rtp:prepend(path)`)
before filetype detection runs.

**Why Neovim needs ftdetect/nelua.lua?** Neovim has no `nelua` filetype. Worse,
`lua/vim/filetype/detect.lua` (`match_from_hashbang`) uses the hashbang key `lua` as an unanchored Lua
pattern, so `"nelua":find("lua")` matches and a `#!/usr/bin/env nelua` script becomes filetype `lua`
(verified on 0.11.6 and 0.12.6). The plugin's extension rule and high-priority shebang rule fix both.

**LazyVim interplay:** No Tree-sitter parser for Nelua exists, so
`LazyVim.treesitter.have("nelua")` is `false`: LazyVim does not call `vim.treesitter.start()`,
`b:ts_highlight` stays unset, and this regex syntax is what you see. Lua files keep Tree-sitter.
If a `nelua` parser is installed later, Tree-sitter takes over these buffers and this syntax file is
switched off for them.

## Options

| Variable | Default | Effect |
|---|---|---|
| `g:nelua_recommended_style` | `1` | `expandtab shiftwidth=2 softtabstop=2` (nelua-lang's own style). Set `0` to keep your global settings |
| `g:nelua_no_builtin_highlight` | `0` | `1` = don't highlight builtin calls (`print`, `require`, …), `_VERSION`, module names |
| `g:nelua_minlines` | `3000` | lines to look back when syncing. nelua-lang's own `lib/detail/` has `##[[ ]]` blocks of 1,926 and 2,060 lines; 500 mis-coloured them when jumping into their middle. Lower it for faster jumps in huge files |
| `g:nelua_sync_fromstart` | `0` | `1` = always parse from the top (exact, slower on huge files) |

## Highlight groups

Every group links to a standard group (`:help group-name`), so any colour scheme works. The full
group → future Tree-sitter capture table is in `syntax/nelua.vim` ("Default links"). Main ones:

| What | Group | Links to |
|---|---|---|
| `if then elseif else switch case` | `neluaConditional` | Conditional |
| `for while repeat until`, `in` (loop) | `neluaRepeat` | Repeat |
| `return break continue goto fallthrough defer`, `in` (statement) | `neluaStatement` / `neluaGoto` | Statement |
| `local global` | `neluaStorageClass` | StorageClass |
| `do end function` | `neluaKeyword` | Keyword |
| builtin type names | `neluaType` | Type |
| names in type positions (`x: T`, `@T`, `@*T`, `[N]T`) | `neluaTypeAny` / `neluaTypeNoCall` | Type |
| `record union enum variant` before `{`/`(` | `neluaStructure` | Structure |
| annotations `<comptime, cimport 'x'>` | `neluaAnnotation` (+ `neluaAnnotationDelim`) | Macro (+ Delimiter) |
| `##`, `##[[ ]]`, `#[ ]#`, `#\| \|#` | `neluaPP*` | PreProc |
| macro calls `name!(…)` | `neluaMacroCall` | Macro |
| calls / `f = function` | `neluaFunctionCall` / `neluaFunctionDef` | Function |
| builtin calls, `self`, `...`, `_VERSION`, modules | `neluaBuiltin`, `neluaSelf`, … | Special |
| numbers (+ suffix `_u8`) | `neluaNumber` (+ `neluaNumberSuffix`) | Number |
| strings, escapes, bad escapes, suffix | `neluaString`, `neluaEscape`, `neluaEscapeError`, `neluaStringSuffix` | String, SpecialChar, Error, Type |
| operators incl. `/// %%% >>> $ & @ ?` | `neluaOperator` | Operator |


## Issues in the original repo

* Block regions that leak. It pairs `if ... then ... end`, `function ... end` , `while ... do`
  and so on with regions. Nelua's preprocessors splits blocks, so these regions stay open.
* Unclosed strings take over the over the whole file.
* `##` lines aren't recognized. Only the single character `#` gets PreProc; the rest of the line coloured as normal code.
* `##[[ ]]` blocks are broken. The region uses `contains=ALL`, which also pulls in the contained block regions.
  Its plain text gets a group with no color link, so it shows uncolored.
* No `keepend` on `#[ ]#` and `#| |#`. An inner region can run past the closing delimiter.
* Escapes don't follow the grammar. `\999` is accepted and there is `\u{...}` and no
  `\z`-plus-whitespace. Invalid escapes like `\q` aren't flagged.
And much more...

## Improvements

* No leaks.
* Regions only for constructs that close themselves.
* Unclosed strings stop at the end of their line.
* Escapes, numbers and suffixes follow Nelua's grammar.
* Reserved words come from the PEG.
* Specific highlighting for preprocessors, Macros, annotations, types, types in type in positions, keywords and builtins.
* Indents. Handles `switch`/`case` in nelua-lang's style, `defer`, preprocessor lines, multi-bracket lines and long brackets.
* ftplugin fixes.
* Works for Neovim and LazyVim. Lua filetype detection that fixes Neovim's shebang bug. Also: There is a clean `lazy.nvim` spec. 
  Tree-sitter stays off for Nelua and on for Lua. There is currently no implementation for TreeSitter when working with Nelua.
* Improved speed. Bounded or no look-behinds, word lists as keywords and chained type patterns. About 15000 lines per second for a full parse.

...and lastly, better maintainability. 

## Testing

Everything runs headless with `nvim --headless --clean` and only this plugin on the runtimepath.
It needs no shell, so it works on Linux and Windows:

```
nvim -l nelua.vim/test/run_all.lua [path/to/nelua-lang]
```

Check out the `test/` directory because there is a full test setup.

## Open issues

* No syntax folding
* ASCII-only identifiers.

There are many known limits. 

* No error highlighting for unbalanced `end`, by design (block regions would leak).
* Type positions are found heuristically. User-defined type names inside parenthesised return lists
  `: (integer, MyType)` and generic arguments `span(MyType)` are not coloured (builtin names are).
  `obj:field` without a call is coloured as a type.
* Annotations are recognised only when the first name is a known annotation and `>` is on the same line.
* An unclosed string ends at the end of its line but is not marked as an error (Vim cannot colour the
  newline).
* `string`, `type` and `table` are always coloured as types, also in `string.format` or in Lua's
  `type(x)` inside the preprocessor. The preprocessor body is highlighted as Nelua, which is close to
  Lua but not identical.
* No syntax folding (there are no block regions). LazyVim sets a fold expression only for Tree-sitter
  buffers; use `:setlocal foldmethod=indent` if wanted.
* Indentation: upstream is inconsistent about indenting under `## if` (75 times not indented, 62
  times indented in `lib/`). The script indents like normal code. Continuation lines of multi-line
  expressions are not specially indented.
* With the default sync, a single comment/string/`##[[` block longer than 3000 lines can be
  mis-highlighted when jumping into its middle. Raise `g:nelua_minlines` or set `g:nelua_sync_fromstart`.
* `#[ "]#" ]#`: a `]#` inside a string ends the preprocessor expression early (bounded to that line).
  An unclosed `#[`/`#|` (invalid Nelua) runs to the next `]#`/`|#`.
* Identifiers are ASCII (`\h\w*`). Nelua allows UTF-8 names, so `x: Ação` colours only `A`.
* Files loaded as Unix with some CRLF lines: `"a\` before `\r\n` shows an escape error.
  Pure CRLF files (`ff=dos`) are fine.
* `<aligned(a > 1 and 8 or 4)>` ends the annotation at the first `>`. `in` inside a one-line
  `(do … in x end)` is coloured as the loop `in`. `obj: method()` (space after `:`) colours `method` as a type.
* `vim.filetype.match({contents = …})` without a buffer (used by some pickers) still says `lua` for a
  `nelua` shebang: the plugin can only read buffers, and the contents are not passed to its rule.

## Not verified

* It wasn't fully tested for Vim.
* `nelua-lsp` was not evaluated.

## Oppertunities and future work

* **Tree-sitter (next step).** A grammar + `queries/nelua/highlights.scm` can reuse the group →
  capture table in `syntax/nelua.vim`. Register it through nvim-treesitter `main`'s `User TSUpdate` hook.
  Once installed, LazyVim will use it automatically and this syntax file stays as a fallback.
* **More constructs.** Add a case to `test/corpus/nelua_features.nelua` first (`--@ "text" =Group`),
  then change `syntax/nelua.vim` until `nvim -l test/run_all.lua` passes.
* **Interop / C.** Annotation arguments (`<cimport 'x', cinclude '<y.h>'>`) are already
  strings/numbers inside `neluaAnnotation`. Embedding C syntax for `cemit` strings would be a
  contained `syn include @C`.
* **LSP.** `nvim-lspconfig` knows `nelua_lsp` (filetype `nelua`, no default `cmd`). Add it to
  `opts.servers` in `lua/plugins/nelua.lua` once a working server binary is available.



## Credits

This project is based on `lua.vim` found in
`/usr/share/vim/vim<X.Y>/syntax/lua.vim` and
`/usr/share/vim/vim<X.Y>/ftplugin/lua.vim` under GNU / Linux Debian distro.

Special gratitude goes to its original author(s) and current maintainer(s).
