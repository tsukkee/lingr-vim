" Lingr-Vim: Lingr client for Vim
" Version:     0.5.2
" Last Change: 29 May 2010
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
        let {a:variable_name} = a:default
    endif
endfunction

call s:set_default('g:lingr_vim_sidebar_width', 25)
call s:set_default('g:lingr_vim_rooms_buffer_height', 10)
call s:set_default('g:lingr_vim_say_buffer_height', 3)
call s:set_default('g:lingr_vim_update_time', 500)
call s:set_default('g:lingr_vim_remain_height_to_auto_scroll', 5)
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
    elseif executable('exo-open')
        let g:lingr_vim_command_to_open_url = 'exo-open %s &'
    else
        let g:lingr_vim_command_to_open_url = ''
    endif
endif
" }}}

" Initialize {{{
let s:path = expand("<sfile>:p:h")
python <<EOM
# coding=utf-8
import sys
import re
import vim
if not vim.eval('s:path') in sys.path:
    # append the path to load lingr_vim.py and lingr.py
    sys.path.append(vim.eval('s:path'))
    lingr_vim = None
import lingrvim
EOM
" }}}

" Python Utilities {{{
python <<EOM
# coding=utf-8
def do_if_alive(func, show_error=False, *args, **keywords):
    if lingr_vim and lingr_vim.is_alive():
        func(*args, **keywords)
    elif show_error:
        lingrvim.echo_error("Lingr-Vim has not been initialized")
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
    call s:MessagesBuffer.initialize()
    call s:MembersBuffer.initialize()
    call s:RoomsBuffer.initialize()

    python <<EOM
# coding=utf-8
if lingr_vim:
    lingr_vim.destroy()

lingr_vim = lingrvim.LingrVim(
    vim.eval('user'),
    vim.eval('password'),
    int(vim.eval('s:MessagesBuffer.bufnr')),
    int(vim.eval('s:MembersBuffer.bufnr')),
    int(vim.eval('s:RoomsBuffer.bufnr')))

lingr_vim.setup()
EOM

    augroup plugin-lingr-vim
        autocmd!
        autocmd CursorHold * call s:BufferBase.rendering()
        autocmd VimLeavePre * silent call lingr#exit()
        autocmd User plugin-lingr-* : " do nothing
    augroup END

    command! LingrExit call lingr#exit()

    redraw
endfunction

function! lingr#exit()
    echo "Exiting Lingr-Vim..."
    sleep 1m
    redraw

    augroup plugin-lingr-vim
        autocmd! CursorHold,VimLeavePre
    augroup END

    python <<EOM
# coding=utf-8
if lingr_vim:
    lingr_vim.destroy()
    lingr_vim = None
EOM

    silent! delcommand LingrExit

    call s:MessagesBuffer.destroy()
    call s:MembersBuffer.destroy()
    call s:RoomsBuffer.destroy()
    call s:SayBuffer.destroy()

    doautocmd User plugin-lingr-leave
    augroup plugin-lingr-vim
        autocmd! User
    augroup END

    echo "Exiting Lingr-Vim... done!"
endfunction

function! lingr#say(text)
    python <<EOM
# coding=utf-8
def _lingr_temp():
    if lingr_vim.say(vim.eval('a:text')):
        pass
    else:
        lingrvim.echo_error("Failed to say: {0}".format(vim.eval('a:text')))
do_if_alive(_lingr_temp, show_error=True)
EOM
endfunction

" Reference:
" http://github.com/kana/config/blob/master/vim/dot.vim/autoload/wwwsearch.vim
" http://lingr.com/room/vim/archives/2010/01/15#message-157044
function! lingr#open_url(url)
    if match(a:url, s:URL_PATTERN) == 0 && g:lingr_vim_command_to_open_url != ""
        echo "open url:" a:url . "..."
        sleep 1m
        " Do we need Vim 7.2 or higher to use second argument of shellescape()?
        execute 'silent !' printf(g:lingr_vim_command_to_open_url, shellescape(a:url, 1))
        redraw!
        echo "open url:" a:url . "... done!"
    else
        echohl ErrorMsg
        echomsg "Failed to open given url: " . a:url
        echohl None
    endif
endfunction

function! lingr#unread_count()
    let result = -1
    python <<EOM
# coding=utf-8
do_if_alive(lambda: vim.command("let result = '{0}'".format(lingr_vim.unread_count())))
EOM
    return result
endfunction

function! lingr#status()
    let result = ""
    python <<EOM
# coding=utf-8
def _lingr_temp():
    state = ""
    if lingr_vim.state == lingrvim.LingrVim.CONNECTED:
        state = "connected"
    elif lingr_vim.state == lingrvim.LingrVim.OFFLINE:
        state = "offline"
    elif lingr_vim.state == lingrvim.LingrVim.RETRYING:
        state = "waiting for reconnect..."
    vim.command('let result = "{0}"'.format(state))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#current_room()
    let result = ""
    python <<EOM
# coding=utf-8
def _lingr_temp():
    room_name = lingr_vim.rooms[lingr_vim.current_room_id].name.encode(vim.eval('&encoding'))
    vim.command('let result = "{0}"'.format(room_name))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#member_count()
    let result = ""
    python <<EOM
# coding=utf-8
def _lingr_temp():
    count = len(filter(lambda x: hasattr(x, 'presence'),
        lingr_vim.current_members))
    vim.command('let result = "{0}"'.format(count))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#online_member_count()
    let result = ""
    python <<EOM
# coding=utf-8
def _lingr_temp():
    count = len(filter(lambda x: hasattr(x, 'presence') and x.presence,
        lingr_vim.current_members))
    vim.command('let result = "{0}"'.format(count))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#offline_member_count()
    let result = ""
    python <<EOM
# coding=utf-8
def _lingr_temp():
    count = len(filter(lambda x: hasattr(x, 'presence') and not x.presence,
        lingr_vim.current_members))
    vim.command('let result = "{0}"'.format(count))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#get_last_message()
    let result = {}
    python <<EOM
def _lingr_temp():
    m = lingr_vim.last_message
    if m:
        def set(name, value):
            vim.command("let result.{0} = '{1}'".format(name, value))
        enc = vim.eval('&encoding')
        set('nickname', m.nickname.encode(enc))
        set('text', re.sub("'", "''", m.text.encode(enc)))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#get_last_member()
    let result = {}
    python <<EOM
def _lingr_temp():
    m = lingr_vim.last_member
    if m:
        def set(name, value):
            vim.command("let result.{0} = '{1}'".format(name, value))
        enc = vim.eval('&encoding')
        set('name', m.name.encode(enc))
        set('username', m.username.encode(enc))
        set('presence', int(m.presence))
do_if_alive(_lingr_temp)
EOM
    return result
endfunction

function! lingr#quote_operator(motion_wiseness)
    let lines = map(getline(line("'["), line("']")), '">" . v:val')

    call s:SayBuffer.initialize()
    call setline(1, lines)
    call feedkeys('Go', 'n')
endfunction
" }}}

" object BufferBase {{{
let s:BufferBase = {"bufnr": -1}

function! s:BufferBase.initialize()
    let self.bufnr = self.layout()
    call self.setup_base()
    call self.setup()
endfunction

function! s:BufferBase.destroy()
    silent! execute 'bwipeout' self.bufnr
    let self.bufnr = -1
endfunction

function! s:BufferBase.setup_base()
    " option
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldmethod=manual
    setlocal foldcolumn=0
    setlocal winfixwidth
    setlocal winfixheight

    " autocmd
    autocmd! * <buffer>
    autocmd BufEnter <buffer> silent call s:BufferBase.on_enter()
    autocmd BufLeave <buffer> silent call s:BufferBase.on_leave()
    autocmd CursorHold <buffer> silent call s:BufferBase.polling()
endfunction

function! s:BufferBase.layout()
    return bufnr('')
endfunction

function! s:BufferBase.setup()
endfunction

function! s:BufferBase.on_enter()
    python <<EOM
# coding=utf-8
do_if_alive(lambda: lingr_vim.set_focus(vim.eval("bufname('')")))
EOM
    let b:saved_updatetime = &updatetime
    let &updatetime = g:lingr_vim_update_time
endfunction

function! s:BufferBase.on_leave()
    python <<EOM
# coding=utf-8
do_if_alive(lambda: lingr_vim.set_focus(None))
EOM
    if exists('b:saved_updatetime')
        let &updatetime = b:saved_updatetime
    endif
endfunction

function! s:BufferBase.polling()
    silent call feedkeys("g\<Esc>", "n")
endfunction

function! s:BufferBase.rendering()
    python <<EOM
# coding=utf-8
do_if_alive(lambda: lingr_vim.process_queue())
EOM
endfunction
" }}}

" object MessagesBuffer {{{
let s:MessagesBuffer = copy(s:BufferBase)

function! s:MessagesBuffer.layout()
    execute 'edit' s:MESSAGES_BUFNAME

    return bufnr('')
endfunction

function! s:MessagesBuffer.setup()
    " option
    let &filetype = s:MESSAGES_FILETYPE
    setlocal statusline=%f\ (%{lingr#current_room()})\ [%{lingr#status()}]%=%l/%L(%P)

    " autocmd
    autocmd WinEnter <buffer> call s:MessagesBuffer.scroll_to_end()

    " mapping
    nnoremap <silent> <buffer> <Plug>(lingr-messages-messages-buffer-action)
                \ :<C-u>call <SID>MessagesBuffer_action()<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-forward)
                \ :<C-u>call <SID>MessagesBuffer_search_delimiter('')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-backward)
                \ :<C-u>call <SID>MessagesBuffer_search_delimiter('b')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-next-room)
                \ :<C-u>call <SID>MessagesBuffer_select_room(v:count1)<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-prev-room)
                \ :<C-u>call <SID>MessagesBuffer_select_room(- v:count1)<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-show-say-buffer)
                \ :<C-u>call <SID>MessagesBuffer_show_say_buffer()<CR>

    nnoremap <script> <silent> <Plug>(lingr-messages-quote)
                \ :<C-u>let &operatorfunc='lingr#quote_operator'<CR>g@
    vnoremap <script> <silent> <Plug>(lingr-messages-quote)
                \ :<C-u>let &operatorfunc='lingr#quote_operator'<CR>gvg@
    onoremap <script> <silent> <Plug>(lingr-messages-quote) g@

    nmap <silent> <buffer> <CR> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> <LeftRelease> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> } <Plug>(lingr-messages-search-delimiter-forward)
    nmap <silent> <buffer> { <Plug>(lingr-messages-search-delimiter-backward)
    nmap <silent> <buffer> <C-n> <Plug>(lingr-messages-select-next-room)
    nmap <silent> <buffer> <C-p> <Plug>(lingr-messages-select-prev-room)
    nmap <silent> <buffer> s <Plug>(lingr-messages-show-say-buffer)
    map <silent> <buffer> Q <Plug>(lingr-messages-quote)
endfunction

function! s:MessagesBuffer.scroll_to_end()
    0
    redraw
    $
endfunction

function! s:MessagesBuffer_action()
    let initialized = 0
    python <<EOM
# coding=utf-8
do_if_alive(lambda: vim.command('let initialized = 1'), show_error=True)
EOM

    if !initialized
        return
    elseif line('.') == 1
        call s:MessagesBuffer_get_archives()
    elseif match(expand('<cWORD>'), s:URL_PATTERN) == 0
        call lingr#open_url(expand('<cWORD>'))
    endif
endfunction

function! s:MessagesBuffer_get_archives()
    let oldLines = line('$')
    echo "Getting archives..."
    sleep 1m
    redraw
    python <<EOM
# coding=utf-8
import socket, httplib
try:
    lingr_vim.get_archives()
except (socket.error, httplib.HTTPException) as e:
    lingrvim.echo_error("Failed to get archives due to network error")
EOM
    execute line('$') - oldLines + 1
    echo "Getting archives... done!"
endfunction

function! s:MessagesBuffer_search_delimiter(flags)
    call search('^' . s:ARCHIVES_DELIMITER, a:flags)
endfunction

function! s:MessagesBuffer_select_room(offset)
    python <<EOM
# coding=utf-8
do_if_alive(lambda: lingr_vim.select_room_by_offset(int(vim.eval("a:offset"))))
EOM
    call s:MessagesBuffer.scroll_to_end()
endfunction

function! s:MessagesBuffer_show_say_buffer()
    call s:SayBuffer.initialize()
    call feedkeys('GA', 'n')
    python <<EOM
# coding=utf-8
lingr_vim.set_focus(vim.eval("bufname('')"))
EOM
endfunction
" }}}

" object MembersBuffer {{{
let s:MembersBuffer = copy(s:BufferBase)

function! s:MembersBuffer.layout()
    execute 'topleft vsplit' s:MEMBERS_BUFNAME
    execute g:lingr_vim_sidebar_width 'wincmd |'

    return bufnr('')
endfunction

function! s:MembersBuffer.setup()
    " option
    let &filetype = s:MEMBERS_FILETYPE
    setlocal statusline=%f\ (%{lingr#online_member_count()}/%{lingr#member_count()})

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-members-open-member)
                \ :<C-u>call <SID>MembersBuffer_open()<CR>

    nmap <buffer> <silent> o <Plug>(lingr-members-open-member)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-members-open-member)
endfunction

function! s:MembersBuffer_open()
    python <<EOM
# coding=utf-8
def _lingr_temp():
    lnum = vim.eval('line(".")')
    member_id = lingr_vim.get_member_id_by_lnum(int(lnum))
    vim.command('call lingr#open_url("http://lingr.com/{0}")'.format(member_id))
do_if_alive(_lingr_temp)
EOM
endfunction

" }}}

" object RoomsBuffer {{{
let s:RoomsBuffer = copy(s:BufferBase)

function! s:RoomsBuffer.layout()
    execute 'leftabove split' s:ROOMS_BUFNAME
    execute g:lingr_vim_rooms_buffer_height 'wincmd _'

    return bufnr('')
endfunction

function! s:RoomsBuffer.setup()
    " option
    let &filetype = s:ROOMS_FILETYPE
    setlocal statusline=%f

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-select-room)
                \ :<C-u>call <SID>RoomsBuffer_select()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-open-room)
                \ :<C-u>call <SID>RoomsBuffer_open()<CR>

    nmap <buffer> <silent> <CR> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> <LeftRelease> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> o <Plug>(lingr-rooms-open-room)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-rooms-open-room)
endfunction

function! s:RoomsBuffer_select()
    python <<EOM
# coding=utf-8
def _lingr_temp():
    cursor = vim.current.window.cursor
    lingr_vim.select_room_by_lnum(cursor[0])
    vim.current.window.cursor = cursor
do_if_alive(_lingr_temp)
EOM
endfunction

function! s:RoomsBuffer_open()
    python <<EOM
# coding=utf-8
def _lingr_temp():
    lnum = vim.eval('line(".")')
    room_id = lingr_vim.get_room_id_by_lnum(int(lnum))
    vim.command('call lingr#open_url("http://lingr.com/room/{0}")'.format(room_id))
do_if_alive(_lingr_temp)
EOM
endfunction
" }}}

" object SayBuffer {{{
let s:SayBuffer = copy(s:BufferBase)

function! s:SayBuffer.layout()
    execute 'rightbelow split' s:SAY_BUFNAME
    execute g:lingr_vim_say_buffer_height 'wincmd _'

    return bufnr('')
endfunction

function! s:SayBuffer.setup()
    " option
    let &filetype = s:SAY_FILETYPE
    setlocal statusline=%f
    setlocal nobuflisted

    " autocmd
    autocmd InsertLeave <buffer> call s:SayBuffer.rendering()

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-say-say)
                \ :<C-u>call <SID>SayBuffer_say() \| call <SID>SayBuffer_close()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-say-close)
                \ :<C-u>call <SID>SayBuffer_close()<CR>
    nmap <buffer> <silent> <CR> <Plug>(lingr-say-say)
    nmap <buffer> <silent> <Esc> <Plug>(lingr-say-close)

    " for custormizing
    " ex) autocmd FileType lingr-say imap <buffer> <CR> <Plug>(lingr-say-insert-mode-say)
    inoremap <buffer> <silent> <Plug>(lingr-say-insert-mode-say)
                \ <Esc>:<C-u>call <SID>SayBuffer_say()<CR>i
endfunction

function! s:SayBuffer_close()
    close
endfunction

function! s:SayBuffer_say()
    let text = join(getline(0, line('$')), "\n")
    if len(text) > 0
        call lingr#say(text)
    endif
    normal! ggdG
endfunction
" }}}

" }}}
