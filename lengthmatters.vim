" =============================================================================
" Author:         scps950707
" Email:          scps950707@gmail.com
" Created:        2016-07-01 04:05
" Last Modified:  2016-07-02 01:41
" Filename:       lengthmatters.vim
" =============================================================================
if exists('g:loaded_lengthmatters') || v:version < 700
    finish
endif
let g:loaded_lengthmatters=1

let g:lengthmatters_magit_mode = get ( g:, 'lengthmatters_magit_mode', 0)
" Another helper function that creates a default highlighting command based on
" the current colorscheme (it's always updated to the *current* colorscheme).
" By default, it creates a command that highlights the overlength match with the
" same bg as Comment's fg and the same fg as Normal's bg. It should look good on
" every colorscheme.
function! s:DefaultHighlighting()
    let cmd = 'highlight ' . g:lengthmatters_match_name

    for md in ['cterm', 'term', 'gui']
        if ( g:lengthmatters_magit_mode )
            let fg = synIDattr(hlID('Special'), 'fg', md)
            let bg = synIDattr(hlID('Normal'), 'bg', md)
        else
            let bg = synIDattr(hlID('Comment'), 'fg', md)
            let fg = synIDattr(hlID('Normal'), 'bg', md)
        endif

        " Break out if we're in GUI vim and the mode isn't 'gui' since GUI tries to
        " parse cterm values too, and it can screw up in some cases.
        if has('gui_running') && md !=# 'gui'
            continue
        endif

        if !empty(bg) | let cmd .= ' ' . md . 'bg=' . bg | endif
        if !empty(fg) | let cmd .= ' ' . md . 'fg=' . fg | endif
    endfor

    return cmd
endfunction


" Set some defaults.
let g:lengthmatters_on_by_default = get ( g:,'lengthmatters_on_by_default', 1)
let g:lengthmatters_use_textwidth = get ( g:,'lengthmatters_use_textwidth', 1)
let g:lengthmatters_start_at_column = get ( g:,'lengthmatters_start_at_column', 81)
let g:lengthmatters_match_name = get ( g:,'lengthmatters_match_name', 'OverLength')
let g:lengthmatters_highlight_command = get ( g:,'lengthmatters_highlight_command', s:DefaultHighlighting())
let g:lengthmatters_excluded = get ( g:,'lengthmatters_excluded', [
            \   'unite', 'tagbar', 'startify', 'gundo', 'vimshell', 'w3m',
            \   'nerdtree', 'help', 'qf', 'dirvish'
            \ ])
let g:lengthmatters_exclude_readonly = get ( g:,'exclude_readonly', 1)
let g:lengthmatters_magit_line_regex = get ( g:,'lengthmatters_magit_line_regex', '\%>14l\%<16l' )


function! s:ShouldBeDisabled()
    " buftype is 'terminal' in :terminal buffers in NeoVim
    return (index(g:lengthmatters_excluded, &ft) >= 0) || &buftype == 'terminal'
endfunction


" Enable the highlighting (if the filetype is not an excluded ft). Reuse the
" match of the current buffer if available, unless the textwidth has changed. If
" it has, force a reload by disabling the highlighting and re-enabling it.
function! s:Enable()
    " Do nothing if this is an excluded filetype.
    if s:ShouldBeDisabled() | return | endif

    " Do nothing if the file is read-only and we want to exclude it.
    if &readonly && g:lengthmatters_exclude_readonly | return | endif

    " Force a reload if the textwidth is in use and it's changed since the last
    " time.
    if s:ShouldUseTw() && s:TwChanged()
        call s:Disable()
        let w:lengthmatters_tw = &tw
    endif

    let w:lengthmatters_active = 1
    call s:Highlight()

    " Create a new match if it doesn't exist already (in order to avoid creating
    " multiple matches for the same buffer).
    if !exists('w:lengthmatters_match')
        let l:column = s:ShouldUseTw() ? &tw + 1 : g:lengthmatters_start_at_column
        if ( g:lengthmatters_magit_mode )
            let l:regex = g:lengthmatters_magit_line_regex . '\%>0v\%<51v'
        else
            let l:regex = '\%' . l:column . 'v.\+'
        endif
        let w:lengthmatters_match = matchadd(g:lengthmatters_match_name, l:regex)
    endif
endfunction


" Force the disabling of the highlighting and delete the match of the current
" buffer, if available.
function! s:Disable()
    let w:lengthmatters_active = 0

    if exists('w:lengthmatters_match')
        call matchdelete(w:lengthmatters_match)
        unlet w:lengthmatters_match
    endif
endfunction


" Toggle between active and inactive states.
function! s:Toggle()
    if !exists('w:lengthmatters_active') || !w:lengthmatters_active
        call s:Enable()
    else
        call s:Disable()
    endif
endfunction


" Return true if the textwidth should be used for creating the hl match.
function! s:ShouldUseTw()
    return g:lengthmatters_use_textwidth && &tw > 0
endfunction


" Execute the highlight command.
function! s:Highlight()
    " Clear every previous highlight.
    exec 'hi clear ' . g:lengthmatters_match_name
    exec 'hi link ' . g:lengthmatters_match_name . ' NONE'

    " The user forced something, so use that something. See the functions defined
    " in autoload/lengthmatters.vim.
    let l:name = g:lengthmatters_match_name
    if exists('g:lengthmatters_linked_to')
        exe 'hi link ' . l:name . ' ' . g:lengthmatters_linked_to
    elseif exists('g:lengthmatters_highlight_colors')
        exe 'hi ' . l:name . ' ' . g:lengthmatters_highlight_colors
    else
        exec s:DefaultHighlighting()
    endif
endfunction


" Return true if the textwidth has changed since the last time this plugin saw
" it. We're assuming that no recorder tw means it changed.
function! s:TwChanged()
    return !exists('w:lengthmatters_tw') || &tw != w:lengthmatters_tw
endfunction


" This function gets called on every autocmd trigger (defined later in this
" script). It disables the highlighting on the excluded filetypes and enables it
" if it wasn't enabled/disabled before or if there's a new textwidth.
function! s:AutocmdTrigger()
    if index(g:lengthmatters_excluded, &ft) >= 0
        call s:Disable()
    elseif !exists('w:lengthmatters_active') && g:lengthmatters_on_by_default
                \ || (s:ShouldUseTw() && s:TwChanged())
        call s:Enable()
    endif
endfunction



augroup lengthmatters
    autocmd!
    " Enable (if it's the case) on a bunch of events (the filetype event is there
    " so that we can avoid highlighting excluded filetypes.
    autocmd WinEnter,BufEnter,BufRead,FileType * call s:AutocmdTrigger()
    " Re-highlight the match on every colorscheme change (includes bg changes).
    autocmd ColorScheme * call s:Highlight()
augroup END



" Define the a bunch of commands (which map one to one with the functions
" defined before).
command! LengthmattersEnable call s:Enable()
command! LengthmattersDisable call s:Disable()
command! LengthmattersToggle call s:Toggle()
command! LengthmattersReload call s:Disable() | call s:Enable()
command! LengthmattersEnableAll windo call s:Enable()
command! LengthmattersDisableAll windo call s:Disable()
