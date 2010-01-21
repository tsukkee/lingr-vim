" Lingr-Vim: Lingr client for Vim
" Version:     0.0.1
" Last Change: 2010 Jan 21
" Author:      tsukkee <takayuki0510+lingr_vim at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
"
"     日本語参考訳
"     http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
" }}}

" Constants {{{
let s:MESSAGES_BUFNAME   = 'lingr-messages'
let s:MESSAGES_FILETYPE  = 'lingr-messages'
let s:ROOMS_BUFNAME      = 'lingr-rooms'
let s:ROOMS_FILETYPE     = 'lingr-rooms'
let s:MEMBERS_BUFNAME    = 'lingr-members'
let s:MEMBERS_FILETYPE   = 'lingr-members'
let s:SAY_BUFNAME        = 'lingr-say'
let s:SAY_FILETYPE       = 'lingr-say'
let s:URL_PATTERN        = '^https\?://[^ ]*'
let s:ARCHIVES_DELIMITER = '--------------------'
" }}}

" Settings {{{
function! s:set_default(variable_name, default)
    if !exists(a:variable_name)
        execute printf('let %s = "%s"', a:variable_name, a:default)
    endif
endfunction

call s:set_default('g:lingr_vim_sidebar_width', 25)
call s:set_default('g:lingr_vim_rooms_buffer_height', 10)
call s:set_default('g:lingr_vim_say_buffer_height', 3)
call s:set_default('g:lingr_vim_update_time', 500)
call s:set_default('g:lingr_vim_remain_height_to_auto_scroll', 20)
call s:set_default('g:lingr_vim_time_format', '%c') " see C language strftime() reference

if !exists('g:lingr_vim_command_to_open_url')
    " Mac
    if has('mac') || has('macunix') || system('uname') =~? '^darwin'
        let g:lingr_vim_command_to_open_url = 'open %s'
    " Windows
    elseif has('win32') || ('win64')
        let g:lingr_vim_command_to_open_url = 'start rundll32 url.dll,FileProtocolHandler %s'
    " KDE
    elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
        let g:lingr_vim_command_to_open_url = 'kfmclient exec %s &'
    " GNOME
    elseif exists('$GNOME_DESKTOP_SESSION_ID')
        let g:lingr_vim_command_to_open_url = 'gnome-open %s &'
    " Xfce
    elseif executable(vimshell#getfilename('exo-open'))
        let g:lingr_vim_command_to_open_url = 'exo-open %s &'
    else
        " TODO: other OS support?
        let g:lingr_vim_command_to_open_url = ""
    endif
endif
" }}}

" Initialize {{{
" append python path
let s:path = expand('<sfile>:p:h')

python <<EOM
# coding=utf-8
import sys
import vim
sys.path.append(vim.eval('s:path'))

lingr_vim = None
EOM
" }}}

" Interface {{{
function! lingr#launch(use_setting)
    " get username and password
    let user = a:use_setting && exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let password = a:use_setting && exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    echo "Launching Lingr-Vim..."
    sleep 1m
    redraw

    wincmd o
    let s:messages_bufnr = s:setup_messages_buffer()
    let s:members_bufnr = s:setup_members_buffer()
    let s:rooms_bufnr = s:setup_rooms_buffer()

    " import lingrvim
    python <<EOM
# coding=utf-8
import lingr
import lingrvim

if lingr_vim:
    lingr_vim.destroy()

lingr_vim = lingrvim.LingrVim(\
    vim.eval('user'),\
    vim.eval('password'),\
    int(vim.eval('s:messages_bufnr')),\
    int(vim.eval('s:members_bufnr')),\
    int(vim.eval('s:rooms_bufnr')))

lingr_vim.setup()
EOM

    augroup plugin-lingr-vim
        autocmd!
        autocmd CursorHold * silent call s:rendering()
    augroup END

    command! LingrExit call lingr#exit()
endfunction

function! lingr#exit()
    echo "Exiting Lingr-Vim..."
    sleep 1m
    redraw

    augroup plugin-lingr-vim
        autocmd!
    augroup END

    python <<EOM
# coding=utf-8
if lingr_vim:
    lingr_vim.destroy()
EOM

    silent! delcommand LingrExit

    silent! execute 'bwipeout' s:messages_bufnr
    silent! execute 'bwipeout' s:members_bufnr
    silent! execute 'bwipeout' s:rooms_bufnr

    echo "Exiting Lingr-Vim... done!"
endfunction

function! lingr#say(text)
    python <<EOM
# coding=utf-8
lingr_vim.say(vim.eval('a:text'))
EOM
endfunction

" Reference:
" http://github.com/kana/config/blob/master/vim/dot.vim/autoload/wwwsearch.vim
" http://lingr.com/room/vim/archives/2010/01/15#message-157044
function! lingr#open_url(url)
    if match(a:url, s:URL_PATTERN) == 0 && g:lingr_vim_command_to_open_url != ""
        echo "open url:" a:url . "..."
        sleep 1m
        redraw
        " Do we need Vim 7.2 or higher to use second argument of shellescape()?
        execute 'silent !' printf(g:lingr_vim_command_to_open_url, shellescape(a:url, 'shell'))
        echo "open url:" a:url . "... done!"
    endif
endfunction
" }}}

" Private functions {{{
" setup buffer {{{
function! s:setup_buffer_base()
    " option
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldcolumn=0

    " autocmd
    autocmd! * <buffer>
    autocmd BufEnter <buffer> silent call s:on_buffer_enter()
    autocmd BufLeave <buffer> silent call s:on_buffer_leave()
    autocmd CursorHold <buffer> silent call s:polling()
endfunction

function! s:setup_messages_buffer()
    " split
    execute 'edit' s:MESSAGES_BUFNAME
    let &filetype = s:MESSAGES_FILETYPE

    call s:setup_buffer_base()

    " option
    setlocal statusline=lingr-messages

    " autocmd
    autocmd WinEnter <buffer> silent! 0 | $

    " mapping
    nnoremap <silent> <buffer> <Plug>(lingr-messages-messages-buffer-action)
                \ :<C-u>call <SID>messages_buffer_action()<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-forward)
                \ :<C-u>call <SID>search_delimiter('')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-backward)
                \ :<C-u>call <SID>search_delimiter('b')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-next-room)
                \ :<C-u>call <SID>select_room_by_offset(v:count1)<CR>
                \ :doautocmd WinEnter<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-prev-room)
                \ :<C-u>call <SID>select_room_by_offset(- v:count1)<CR>
                \ :doautocmd WinEnter<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-show-say-buffer)
                \ :<C-u>call <SID>show_say_buffer()<CR>

    nmap <silent> <buffer> <CR> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> <LeftRelease> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> } <Plug>(lingr-messages-search-delimiter-forward)
    nmap <silent> <buffer> { <Plug>(lingr-messages-search-delimiter-backward)
    nmap <silent> <buffer> <C-n> <Plug>(lingr-messages-select-next-room)
    nmap <silent> <buffer> <C-p> <Plug>(lingr-messages-select-prev-room)
    nmap <silent> <buffer> s <Plug>(lingr-messages-show-say-buffer)

    " window size
    " nothing to do

    return bufnr('')
endfunction

function! s:setup_members_buffer()
    " split
    execute 'topleft vsplit' s:MEMBERS_BUFNAME
    let &filetype = s:MEMBERS_FILETYPE

    call s:setup_buffer_base()

    " option
    setlocal statusline=lingr-members

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-members-open-member)
                \ :<C-u>call <SID>open_member()<CR>

    nmap <buffer> <silent> o <Plug>(lingr-members-open-member)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-members-open-member)

    " window size
    execute g:lingr_vim_sidebar_width 'wincmd |'

    return bufnr('')
endfunction

function! s:setup_rooms_buffer()
    " split
    execute 'leftabove split' s:ROOMS_BUFNAME
    let &filetype = s:ROOMS_FILETYPE

    call s:setup_buffer_base()

    " option
    setlocal statusline=lingr-rooms

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-select-room)
                \ :<C-u>call <SID>select_room()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-open-room)
                \ :<C-u>call <SID>open_room()<CR>

    nmap <buffer> <silent> <CR> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> <LeftRelease> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> o <Plug>(lingr-rooms-open-room)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-rooms-open-room)

    " window size
    execute g:lingr_vim_rooms_buffer_height 'wincmd _'

    return bufnr('')
endfunction

function! s:setup_say_buffer()
    " split
    execute 'rightbelow split' s:SAY_BUFNAME
    let &filetype = s:SAY_FILETYPE

    call s:setup_buffer_base()

    " option
    setlocal statusline=lingr-say
    setlocal nobuflisted

    " autocmd
    autocmd InsertLeave <buffer> silent call s:rendering()

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-say-say)
                \ :<C-u>call <SID>say_buffer_contents()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-say-close)
                \ :<C-u>call <SID>close_say_buffer()<CR>
    nmap <buffer> <silent> <CR> <Plug>(lingr-say-say)
    nmap <buffer> <silent> <Esc> <Plug>(lingr-say-close)

    " window size
    execute g:lingr_vim_say_buffer_height 'wincmd _'

    return bufnr('')
endfunction
" }}}

" for all buffer {{{
function! s:on_buffer_enter()
    python <<EOM
# coding=utf-8
# after lingr_vim has initialized
if lingr_vim and lingr_vim.current_room_id:
    lingr_vim.set_focus(vim.eval("bufname('')"))
EOM
    " set 'updatetime'
    let b:saved_updatetime = &updatetime
    let &updatetime = g:lingr_vim_update_time
endfunction

function! s:on_buffer_leave()
    python <<EOM
# coding=utf-8
# after lingr_vim has initialized
if lingr_vim and lingr_vim.current_room_id:
    lingr_vim.set_focus(None)
EOM
    " reset 'updatetime'
    if exists('b:saved_updatetime')
        let &updatetime = b:saved_updatetime
    endif
endfunction

function! s:polling()
    silent call feedkeys("g\<Esc>", "n")
endfunction

function! s:rendering()
    python <<EOM
# coding=utf-8
lingr_vim.process_queue()
EOM
endfunction
" }}}

" for messages buffer {{{
function! s:messages_buffer_action()
    let [bufnum, lnum, col, off] = getpos('.')
    if lnum == 1
        call s:get_archives()
    elseif match(expand('<cWORD>'), s:URL_PATTERN) == 0
        call lingr#open_url(expand('<cWORD>'))
    endif
endfunction

function! s:get_archives()
    let oldLines = line('$')
    echo "Getting archives..."
    sleep 1m
    redraw
    python <<EOM
# coding=utf-8
lingr_vim.get_archives()
EOM
    call setpos('.', [0, line('$') - oldLines + 1, 0, 0])
    echo "Getting archives... done!"
endfunction

function! s:search_delimiter(flags)
    call search('^' . s:ARCHIVES_DELIMITER, a:flags)
endfunction

function! s:select_room_by_offset(offset)
    python <<EOM
# coding=utf-8
import vim
lingr_vim.select_room_by_offset(int(vim.eval("a:offset")))
EOM
endfunction
" }}}

" for members buffer {{{
function! s:open_member()
    python <<EOM
# coding=utf-8
import vim
bufnum, lnum, col, off = vim.eval('getpos(".")')
member_id = lingr_vim.get_member_id_by_lnum(int(lnum))
vim.command('call lingr#open_url("http://lingr.com/{0}")'.format(member_id))
EOM
endfunction
" }}}

" for rooms buffer {{{
function! s:select_room()
    python <<EOM
# coding=utf-8
bufnum, lnum, col, off = vim.eval('getpos(".")')
lingr_vim.select_room_by_lnum(int(lnum))
vim.eval('setpos(".", [{0}, {1}, {2}, {3}])'.format(bufnum, lnum, col, off))
EOM
endfunction

function! s:open_room()
    python <<EOM
# coding=utf-8
import vim
bufnum, lnum, col, off = vim.eval('getpos(".")')
room_id = lingr_vim.get_room_id_by_lnum(int(lnum))
vim.command('call lingr#open_url("http://lingr.com/room/{0}")'.format(room_id))
EOM
endfunction
" }}}

" for say buffer {{{
function! s:show_say_buffer()
    call s:setup_say_buffer()
    call feedkeys('A', 'n')
endfunction

function! s:close_say_buffer()
    close
endfunction

function! s:say_buffer_contents()
    let text = join(getline(0, line('$')), "\n")
    call lingr#say(text)
    normal! ggdG
    call s:close_say_buffer()
endfunction
" }}}

" }}}
