" Vim syntax file
" Language:     Nelua (https://nelua.io)
" Filenames:    *.nelua, scripts with a "#!... nelua" first line
" Last Change:  2026-11-25
" Remark:       Rewritten for Vim and Neovim. See README.md for credits, sources and design notes.
"
" Design (why it looks like this):
"   * Regions are used ONLY for constructs that delimit themselves lexically:
"     comments, strings, long brackets, the four preprocessor forms and
"     one-line annotations. There are no if/then/end or function/end regions:
"     Nelua's preprocessor freely splits blocks ("## if x then" ... "## end"),
"     and block regions would leak across them. Statement-level context is
"     expressed with look-around patterns instead.
"   * Preprocessor spans embed Nelua itself (contains=TOP,...) with keepend,
"     like Nelua.sublime-syntax does with "embed: scope:source.nelua" + escape.
"   * Word lists use :syn keyword (hash lookup); look-behinds are byte-bounded.
"   * Every group links to a standard highlight group, so any colour scheme works.
"
" Options (set before the file is loaded):
"   g:nelua_no_builtin_highlight  1 = don't highlight builtin functions/modules
"   g:nelua_minlines              lines to look back when syncing (default 3000;
"                                 nelua-lang's lib/ has 2,060-line ##[[ ]] blocks)
"   g:nelua_sync_fromstart        1 = always sync from the start of the file

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match
syn spell notoplevel

" ---------------------------------------------------------------------------
" Operators (defined first: anything more specific defined later wins when it
" starts at the same column, e.g. comments over "-", varargs over "..").
syn match neluaOperator "[-+*/%^#&|~<>=$?@]"
syn match neluaOperator "\%(\.\.\|//\|<<\|>>\|[=~<>]=\)"
syn match neluaOperator "\%(///\|%%%\|>>>\)"
syn match neluaVarargs  "\.\.\."
syn keyword neluaOperatorWord and or not

" ---------------------------------------------------------------------------
" Keywords (reserved words of syntaxdefs.lua; "in" is handled below)
syn keyword neluaConditional if then elseif else switch case
syn keyword neluaRepeat      for while repeat until
syn keyword neluaKeyword     do end function
syn keyword neluaStatement   return break continue fallthrough defer
syn keyword neluaGoto        goto nextgroup=neluaGotoLabel skipwhite
syn keyword neluaStorageClass local global
syn keyword neluaConstant    nil nilptr
syn keyword neluaBoolean     true false
syn keyword neluaSelf        self
" "in" starts a statement at the beginning of a line (returns a value from a
" do-expression or a preprocessor macro), otherwise it belongs to "for ... in".
syn match neluaRepeat    "\<in\>"
syn match neluaStatement "\%(^\s*\)\@<=in\>"

" ---------------------------------------------------------------------------
" Types. Builtin type names (typedefs.lua primtypes + common stdlib generics).
syn keyword neluaType integer uinteger number byte isize usize
syn keyword neluaType int8 int16 int32 int64 int128 uint8 uint16 uint32 uint64 uint128
syn keyword neluaType float32 float64 float128 boolean string void auto any
syn keyword neluaType niltype type table pointer array span varargs varanys
syn keyword neluaType facultative overload decltype stringview
syn keyword neluaType cstring cchar cschar cshort cint clong clonglong cptrdiff
syn keyword neluaType cuchar cushort cuint culong culonglong csize clongdouble
syn keyword neluaType cfloat cdouble cvarargs cvalist cclock_t ctime_t cwchar_t
syn keyword neluaType vector hashmap stringbuilder

" Any name in a type position, found with nextgroup chains (no look-behind):
"   ": " + type     declarations, parameters, record fields, return types
"   ":" + type      without a space, unless it is a method call  obj:method(...)
"   "@" + type      type expressions
" with optional prefixes  *  ?  [N]  between, which keep their own colours.
syn match neluaTypeColonSp ":\@1<!:\%(:\)\@!\ze\s" nextgroup=neluaTypePrefix,neluaTypeArray,neluaTypeAny skipwhite
syn match neluaTypeColon   ":\@1<!:\%(:\)\@!\ze\S" nextgroup=neluaTypePrefix,neluaTypeArray,neluaTypeNoCall
syn match neluaTypeAt      "@" nextgroup=neluaTypePrefix,neluaTypeArray,neluaTypeAny skipwhite
syn match neluaTypePrefix  "[*?]" contained nextgroup=neluaTypePrefix,neluaTypeArray,neluaTypeAny skipwhite
syn match neluaTypeArray   "\[[^]]*\]" contained contains=neluaNumber,neluaPPExpr,neluaOperator nextgroup=neluaTypePrefix,neluaTypeArray,neluaTypeAny skipwhite
syn match neluaTypeAny     "\%(\%(record\|union\|enum\|variant\|function\)\>\)\@!\h\w*\%(\.\h\w*\)*" contained
syn match neluaTypeNoCall  "\%(\%(record\|union\|enum\|variant\|function\)\>\)\@!\h\w*\%(\.\h\w*\)*\>\%(\s*\%([(\"'{]\|\[=*\[\)\)\@!" contained

" ---------------------------------------------------------------------------
" Calls and definitions
syn match neluaFunctionCall "\<\h\w*\ze\s*\%((\|\"\|'\|{\|\[=*\[\)"
syn match neluaFunctionDef  "\<\h\w*\ze\s*=\s*function\>"
syn match neluaStructure    "\<\%(record\|union\|enum\|variant\)\>\ze\s*[{(]"
syn match neluaMacroCall    "\<\h\w*!\ze\s*\%((\|\"\|'\|{\|\[=*\[\)"

if !get(g:, "nelua_no_builtin_highlight", 0)
  " Global functions of lib/builtins.nelua and the stdlib, plus the Lua
  " builtins commonly used inside the preprocessor. Only when called.
  syn match neluaBuiltin "\<\%(require\|print\|panic\|error\|assert\|check\|likely\|unlikely\|pairs\|ipairs\|mpairs\|next\|mnext\|select\|pcall\|xpcall\|tostring\|tonumber\|setmetatable\|getmetatable\|rawget\|rawset\|rawequal\|rawlen\|load\|loadfile\|dofile\|collectgarbage\|unpack\|static_assert\|static_error\)\ze\s*\%((\|\"\|'\|{\|\[=*\[\)"
  syn match neluaModule  "\<\%(coroutine\|io\|math\|os\|utf8\|debug\|package\|memory\|bit32\)\ze\s*\."
  syn keyword neluaBuiltinConst _VERSION _G
endif

" ---------------------------------------------------------------------------
" Labels
syn match neluaLabel     "::\s*\h\w*\s*::"
syn match neluaGotoLabel "\h\w*" contained

" ---------------------------------------------------------------------------
" Numbers (NUMBER rule of syntaxdefs.lua). A literal may carry a type suffix
" such as 1234_u32, 1_f32 or 10u8. Later definitions win at the same column,
" so the decimal form comes first and hexadecimal last.
syn match neluaNumber "\<\d\+\%(\.\d*\)\=\%([eE][-+]\=\d\+\)\=" nextgroup=neluaNumberSuffix
syn match neluaNumber "\%(\.\|\w\)\@1<!\.\d\+\%([eE][-+]\=\d\+\)\=" nextgroup=neluaNumberSuffix
syn match neluaNumber "\<0[bB]\%([01]\+\%(\.[01]*\)\=\|\.[01]\+\)\%([pP][-+]\=\d\+\)\=" nextgroup=neluaNumberSuffix
syn match neluaNumber "\<0[xX]\%(\x\+\%(\.\x*\)\=\|\.\x\+\)\%([pP][-+]\=\d\+\)\=" nextgroup=neluaNumberSuffix
syn match neluaNumberSuffix "\h\w*" contained

" ---------------------------------------------------------------------------
" Strings (STRING rule). Escapes follow the ESCAPE rule exactly: anything else
" after a backslash is an error. A backslash at the end of the line (or \z)
" continues the string on the next line; otherwise an unclosed string stops at
" the end of its line instead of colouring the rest of the file.
syn match neluaEscapeError contained "\\."
syn match neluaEscape contained "\\[abfnrtv\\'\"]"
syn match neluaEscape contained "\\x\x\x"
syn match neluaEscape contained "\\\%([012]\d\d\|\d\d\=\d\@!\)"
syn match neluaEscape contained "\\u{\x\+}"
syn match neluaEscape contained "\\z\s*"
syn match neluaEscape contained "\\$"
" The line continues only if it ends in an odd number of backslashes
" (optionally followed by z and blanks): "a\\" at the end of a line is an
" escaped backslash, so that string is unclosed. (A skip pattern cannot do
" this: the contained \z escape would consume the text the skip needs.)
syn region neluaString matchgroup=neluaStringDelim start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\%(\%(^\|[^\\]\)\%(\\\\\)*\\\%(z\s*\)\=\)\@16<!$+ contains=neluaEscape,neluaEscapeError,@Spell nextgroup=neluaStringSuffix
syn region neluaString matchgroup=neluaStringDelim start=+'+ skip=+\\\\\|\\'+ end=+'+ end=+\%(\%(^\|[^\\]\)\%(\\\\\)*\\\%(z\s*\)\=\)\@16<!$+ contains=neluaEscape,neluaEscapeError,@Spell nextgroup=neluaStringSuffix
syn region neluaLongString matchgroup=neluaStringDelim start="\[\z(=*\)\[" end="\]\z1\]" contains=@Spell nextgroup=neluaStringSuffix
syn match neluaStringSuffix "\h\w*" contained

" ---------------------------------------------------------------------------
" Comments (after the operators, so "--" beats "-")
syn keyword neluaTodo contained TODO FIXME XXX NOTE HACK BUG
syn match  neluaComment "--.*$" contains=neluaTodo,@Spell
syn region neluaComment start="--\[\z(=*\)\[" end="\]\z1\]" contains=neluaTodo,@Spell
syn match  neluaShebang "\%^#!.*$"

" ---------------------------------------------------------------------------
" Annotations:  local x <comptime> = 1   function f() <inline, nodecl>
" Recognised when "<" is followed by a known annotation name (typedefs.lua)
" and the closing ">" is on the same line; otherwise "<" stays an operator.
let s:annots = 'comptime\|const\|close\|cimport\|cexport\|cinclude\|codename\|cqualifier\|cpostqualifier\|cattribute\|deprecated\|inline\|noreturn\|noinline\|volatile\|nodecl\|nodce\|nosideeffect\|nosideffect\|entrypoint\|polymorphic\|alwayspoly\|forwarddecl\|aligned\|static\|register\|restrict\|atomic\|threadlocal\|noinit\|nogcscan\|ctopinit\|nickname\|ctypedef\|cincomplete\|packed\|using\|nocopy\|builtin'
exe 'syn region neluaAnnotation matchgroup=neluaAnnotationDelim start="<\ze\s*\%(' . s:annots . '\)\>" end=">" oneline contains=neluaString,neluaLongString,neluaNumber,neluaBoolean,neluaConstant,neluaPPExpr,neluaComment'
unlet s:annots

" ---------------------------------------------------------------------------
" Preprocessor (PREPROCESS, PreprocessExpr, PreprocessName). The contents are
" highlighted as Nelua (Lua-compatible) code; plain names use the PreProc
" colour, so preprocessor code stands out from the code it generates.
syn cluster neluaPPRegions contains=neluaPPLine,neluaPPBlock,neluaPPExpr,neluaPPName,neluaShebang
syn region neluaPPLine  matchgroup=neluaPPDelim start="##\%(\[=*\[\)\@!" end="$" keepend contains=TOP,@neluaPPRegions
syn region neluaPPBlock matchgroup=neluaPPDelim start="##\[\z(=*\)\[" end="\]\z1\]" keepend contains=TOP,@neluaPPRegions
syn region neluaPPExpr  matchgroup=neluaPPDelim start="#\[" end="\]#" keepend contains=TOP,@neluaPPRegions
syn region neluaPPName  matchgroup=neluaPPDelim start="#|" end="|#" keepend contains=TOP,@neluaPPRegions

" ---------------------------------------------------------------------------
" Syncing
if get(g:, "nelua_sync_fromstart", 0)
  syn sync fromstart
else
  exe "syn sync minlines=" . get(g:, "nelua_minlines", 3000)
endif

" ---------------------------------------------------------------------------
" Default links. Group -> Tree-sitter capture for a future queries/nelua/highlights.scm:
"   neluaComment           @comment
"   neluaShebang           @keyword.directive
"   neluaTodo              @comment.todo
"   neluaString            @string
"   neluaLongString        @string
"   neluaStringDelim       @string
"   neluaStringSuffix      @type
"   neluaEscape            @string.escape
"   neluaEscapeError       @error
"   neluaNumber            @number / @number.float
"   neluaNumberSuffix      @number
"   neluaConditional       @keyword.conditional
"   neluaRepeat            @keyword.repeat
"   neluaKeyword           @keyword / @keyword.function
"   neluaStatement         @keyword.return / @keyword
"   neluaGoto              @keyword
"   neluaStorageClass      @keyword.modifier
"   neluaOperator          @operator
"   neluaOperatorWord      @keyword.operator
"   neluaVarargs           @variable.builtin
"   neluaConstant          @constant.builtin
"   neluaBoolean           @boolean
"   neluaSelf              @variable.builtin
"   neluaType              @type.builtin
"   neluaTypeAny/NoCall    @type
"   neluaTypeAt/Prefix     @operator
"   neluaStructure         @keyword.type
"   neluaFunctionCall      @function.call
"   neluaFunctionDef       @function
"   neluaMacroCall         @function.macro
"   neluaBuiltin           @function.builtin
"   neluaBuiltinConst      @constant.builtin
"   neluaModule            @module.builtin
"   neluaLabel             @label
"   neluaGotoLabel         @label
"   neluaAnnotation        @attribute
"   neluaAnnotationDelim   @punctuation.bracket
"   neluaPreProc           @keyword.directive
hi def link neluaComment         Comment
hi def link neluaShebang         Comment
hi def link neluaTodo            Todo
hi def link neluaString          String
hi def link neluaLongString      String
hi def link neluaStringDelim     String
hi def link neluaStringSuffix    Type
hi def link neluaEscape          SpecialChar
hi def link neluaEscapeError     Error
hi def link neluaNumber          Number
hi def link neluaNumberSuffix    Number
hi def link neluaConditional     Conditional
hi def link neluaRepeat          Repeat
hi def link neluaKeyword         Keyword
hi def link neluaStatement       Statement
hi def link neluaGoto            Statement
hi def link neluaStorageClass    StorageClass
hi def link neluaOperator        Operator
hi def link neluaOperatorWord    Operator
hi def link neluaVarargs         Special
hi def link neluaConstant        Constant
hi def link neluaBoolean         Boolean
hi def link neluaSelf            Special
hi def link neluaType            Type
hi def link neluaTypeAny         Type
hi def link neluaTypeNoCall      Type
hi def link neluaTypeAt          Operator
hi def link neluaTypePrefix      Operator
hi def link neluaStructure       Structure
hi def link neluaFunctionCall    Function
hi def link neluaFunctionDef     Function
hi def link neluaMacroCall       Macro
hi def link neluaBuiltin         Special
hi def link neluaBuiltinConst    Special
hi def link neluaModule          Special
hi def link neluaLabel           Label
hi def link neluaGotoLabel       Label
hi def link neluaAnnotation      Macro
hi def link neluaAnnotationDelim Delimiter
hi def link neluaPreProc         PreProc
hi def link neluaPPDelim         neluaPreProc
hi def link neluaPPLine          neluaPreProc
hi def link neluaPPBlock         neluaPreProc
hi def link neluaPPExpr          neluaPreProc
hi def link neluaPPName          neluaPreProc

let b:current_syntax = "nelua"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: et ts=8 sw=2
