" lingr.vim: Lingr client for Vim
" Version:     0.6.0
" Last Change: 05 Feb 2012
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
" }}}

" Constants {{{
function! s:define(name, value)
    if !exists('s:' . a:name)
        let s:{a:name} = a:value
        lockvar s:{a:name}
    endif
endfunction

call s:define('MESSAGES_BUFNAME',   'lingr-messages')
call s:define('MESSAGES_FILETYPE',  'lingr-messages')
call s:define('ROOMS_BUFNAME',      'lingr-rooms')
call s:define('ROOMS_FILETYPE',     'lingr-rooms')
call s:define('MEMBERS_BUFNAME',    'lingr-members')
call s:define('MEMBERS_FILETYPE',   'lingr-members')
call s:define('SAY_BUFNAME',        'lingr-say')
call s:define('SAY_FILETYPE',       'lingr-say')
call s:define('URL_PATTERN',        '^https\?://[^ ]*')
call s:define('ARCHIVES_DELIMITER', '--------------------')
" }}}

" Settings {{{
function! s:set_default(variable_name, default)
    if !exists(a:variable_name)
        let {a:variable_name} = a:default
    endif
endfunction

call s:set_default('g:lingr_vim_api_version',                   1)
call s:set_default('g:lingr_vim_sidebar_width',                 25)
call s:set_default('g:lingr_vim_rooms_buffer_height',           10)
call s:set_default('g:lingr_vim_say_buffer_height',             3)
call s:set_default('g:lingr_vim_update_time',                   500)
call s:set_default('g:lingr_vim_remain_height_to_auto_scroll',  5)
call s:set_default('g:lingr_vim_time_format',                   '%c') " see C language strftime() reference
call s:set_default('g:lingr_vim_additional_rooms',              [])
call s:set_default('g:lingr_vim_count_unread_at_current_room',  0)

if !exists('g:lingr_vim_command_to_open_url')
    " Windows
    if has('win32') || ('win64')
        let g:lingr_vim_command_to_open_url = 'start rundll32 url.dll,FileProtocolHandler %s'
    " Mac
    elseif has('mac') || has('macunix') || system('uname') =~? '^darwin'
        let g:lingr_vim_command_to_open_url = 'open %s'
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

" Utility {{{
python <<EOM
# coding=utf-8
def lingr_is_alive():
    return 'lingr_vim' in globals() and lingr_vim and lingr_vim.is_alive()
EOM

function! s:show_message(str)
    echo a:str
    sleep 1m
    redraw
endfunction

function! s:show_error(str)
    echohl ErrorMsg
    echomsg str
    echohl None
endfunction

function! s:check_python()
    let [major, minor, micro, releaselevel, serial] = pyutil#version()
    return major == 2 && minor >= 6
endfunction
" }}}

" Initialize {{{
if !s:check_python()
    echoerr 'This plugin needs +python (Python 2.6 or 2.7)'
    finish
else
    call pyutil#use()
endif

python <<EOM
import vim
import vimutil
import lingrvim
EOM
" }}}

" Interface {{{

" Reference:
" http://github.com/kana/config/blob/master/vim/dot.vim/autoload/wwwsearch.vim
" http://lingr.com/room/vim/archives/2010/01/15#message-157044
function! lingr#open_url(url)
    if match(a:url, s:URL_PATTERN) == 0 && g:lingr_vim_command_to_open_url != ""
        call s:show_message('open url: ' . a:url . ' ...')

        " Do we need Vim 7.2 or higher to use second argument of shellescape()?
        execute 'silent !' printf(g:lingr_vim_command_to_open_url, shellescape(a:url, 1))
        redraw!

        call s:show_message('open url: ' .  a:url . ' ... done!')
    else
        call s:show_error('Failed to open given url: ' . a:url)
    endif
endfunction

function! lingr#launch(use_setting)
    " get username and password
    let user = a:use_setting && exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let password = a:use_setting && exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    call s:show_message("Launching lingr.vim...")

    " create buffer
    silent! wincmd o
    call s:MessagesBuffer.initialize()
    call s:MembersBuffer.initialize()
    call s:RoomsBuffer.initialize()

    " initialize lingr_vim
    python <<EOM
# coding=utf-8

if lingr_is_alive():
    lingr_vim.destroy()

lingr_vim = lingrvim.LingrVim(
    vim.eval('user'),
    vim.eval('password'),
    vimutil.integer('g:lingr_vim_api_version'),
    vimutil.integer('s:MessagesBuffer.bufnr'),
    vimutil.integer('s:MembersBuffer.bufnr'),
    vimutil.integer('s:RoomsBuffer.bufnr')
    )
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
    call s:show_message("Exiting lingr.vim...")

    augroup plugin-lingr-vim
        autocmd! CursorHold,VimLeavePre
    augroup END

    python <<EOM
# coding=utf-8
if lingr_is_alive():
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

    echo "Exiting lingr.vim... done!"
endfunction

python <<EOM
# coding=utf-8

@vimutil.vimfunc('lingr#say')
@vimutil.do_if(lingr_is_alive, error_message = 'lingr.vim is not initialized')
def lingr_vim_say(args):
    text = args[0]
    if not lingr_vim.say(text):
        vimutil.echo_error("Failed to say: {0}".format(text))

@vimutil.vimfunc('lingr#unread_count')
@vimutil.do_if(lingr_is_alive, default = -1)
def lingr_vim_unread_count(args):
    return lingr_vim.unread_count()

@vimutil.vimfunc('lingr#status')
@vimutil.do_if(lingr_is_alive, default = '')
def lingr_vim_status(args):
    return lingr_vim.status_message()

@vimutil.vimfunc('lingr#current_room')
@vimutil.do_if(lingr_is_alive, default = '')
def lingr_vim_current_room(args):
    return vimutil.encode(lingr_vim.rooms[lingr_vim.current_room_id].name)

@vimutil.vimfunc('lingr#member_count')
@vimutil.do_if(lingr_is_alive, default = 0)
def lingr_vim_member_count(args):
    return len(filter(lambda m: hasattr(m, 'presence'),
        lingr_vim.current_members))

@vimutil.vimfunc('lingr#online_member_count')
@vimutil.do_if(lingr_is_alive, default = 0)
def lingr_vim_online_member_count(args):
    return len(filter(lambda m: hasattr(m, 'presence') and m.presence,
        lingr_vim.current_members))

@vimutil.vimfunc('lingr#offline_member_count')
@vimutil.do_if(lingr_is_alive, default = 0)
def lingr_vim_offline_member_count(args):
    return len(filter(lambda m: hasattr(m, 'presence') and not m.presence,
        lingr_vim.current_members))

@vimutil.vimfunc('lingr#get_last_message')
@vimutil.do_if(lingr_is_alive, default = {})
def lingr_vim_get_last_message(args):
    m = lingr_vim.last_message
    result = {}
    if m:
        result['nickname'] = m.nickname
        result['text'] = m.text
    return result

@vimutil.vimfunc('lingr#get_last_member')
@vimutil.do_if(lingr_is_alive, default = {})
def lingr_vim_get_last_member(args):
    m = lingr_vim.last_member
    result = {}
    if m:
        result['name'] = m.name
        result['username'] = m.username
        result['presence'] = m.presence
    return result

@vimutil.vimfunc('lingr#mark_as_read_current_room')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_mark_as_read_current_room(args):
    lingr_vim.set_focus(vimutil.bufname())

@vimutil.vimfunc('lingr#testfunc')
def lingr_vim_testfunc(args):
    return {'args': args, 'num': 10, 'str': 'string'}

EOM

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
    setlocal nomodeline
    if has('conceal')
        setlocal conceallevel=2
        setlocal concealcursor=nc
    endif

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

function! s:BufferBase.polling()
    silent call feedkeys("g\<Esc>", "n")
endfunction

python <<EOM
# coding=utf-8

@vimutil.vimfunc('s:BufferBase.on_enter')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_BufferBase_on_enter(args):
    lingr_vim.set_focus(vimutil.bufname())
    vimutil.let('b:saved_updatetime', vim.eval('&updatetime'))
    vimutil.let('&updatetime', vim.eval('g:lingr_vim_update_time'))

@vimutil.vimfunc('s:BufferBase.on_leave')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_BufferBase_on_leave(args):
    lingr_vim.set_focus(None)
    if vimutil.exists('b:saved_updatetime'):
        vimutil.let('&updatetime', vim.eval('b:saved_updatetime'))

@vimutil.vimfunc('s:BufferBase.rendering')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_BufferBase_rendering(args):
    lingr_vim.process_queue()

EOM
" }}}

" object MessagesBuffer {{{
let s:MessagesBuffer = copy(s:BufferBase)

function! lingr#messages_buffer()
    return s:MessagesBuffer
endfunction

function! s:MessagesBuffer.layout()
    execute 'edit' s:MESSAGES_BUFNAME

    return bufnr('')
endfunction

function! s:MessagesBuffer.setup()
    " option
    setlocal statusline=%f\ (%{lingr#current_room()})\ [%{lingr#status()}]%=%l/%L(%P)

    " autocmd
    autocmd WinEnter <buffer> call s:MessagesBuffer.scroll_to_end()

    " mapping
    nnoremap <silent> <buffer> <Plug>(lingr-messages-messages-buffer-action)
                \ :<C-u>call lingr#messages_buffer().action()<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-forward)
                \ :<C-u>call lingr#messages_buffer().search_delimiter('')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-search-delimiter-backward)
                \ :<C-u>call lingr#messages_buffer().search_delimiter('b')<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-next-room)
                \ :<C-u>call lingr#messages_buffer().select_room(v:count1)<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-select-prev-room)
                \ :<C-u>call lingr#messages_buffer().select_room(- v:count1)<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-show-say-buffer)
                \ :<C-u>call lingr#messages_buffer().show_say_buffer()<CR>
    nnoremap <silent> <buffer> <Plug>(lingr-messages-toggle-favorite)
                \ :<C-u>call lingr#messages_buffer().toggle_favorite(line('.'))<CR>

    nnoremap <silent> <buffer> <Plug>(lingr-messages-quote)
                \ :<C-u>let &operatorfunc='lingr#quote_operator'<CR>g@
    vnoremap <silent> <buffer> <Plug>(lingr-messages-quote)
                \ :<C-u>let &operatorfunc='lingr#quote_operator'<CR>gvg@
    onoremap <silent> <buffer> <Plug>(lingr-messages-quote) g@

    nmap <silent> <buffer> <CR> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> <LeftRelease> <Plug>(lingr-messages-messages-buffer-action)
    nmap <silent> <buffer> } <Plug>(lingr-messages-search-delimiter-forward)
    nmap <silent> <buffer> { <Plug>(lingr-messages-search-delimiter-backward)
    nmap <silent> <buffer> <C-n> <Plug>(lingr-messages-select-next-room)
    nmap <silent> <buffer> <C-p> <Plug>(lingr-messages-select-prev-room)
    nmap <silent> <buffer> s <Plug>(lingr-messages-show-say-buffer)
    nmap <silent> <buffer> f <Plug>(lingr-messages-toggle-favorite)
    map  <silent> <buffer> Q <Plug>(lingr-messages-quote)

    " filetype
    let &filetype = s:MESSAGES_FILETYPE
endfunction

function! s:MessagesBuffer.scroll_to_end()
    0
    redraw
    $
endfunction

function! s:MessagesBuffer.action()
    if !pyutil#get_value('lingr_is_alive()')
        return
    elseif line('.') == 1
        call s:MessagesBuffer.get_archives()
    elseif match(expand('<cWORD>'), s:URL_PATTERN) == 0
        call lingr#open_url(expand('<cWORD>'))
    endif
endfunction

function! s:MessagesBuffer.get_archives()
    if !pyutil#get_value('lingr_is_alive()')
        return
    endif

    let old_line = line('$')
    call s:show_message("Getting archives...")
    python <<EOM
# coding=utf-8
lingr_vim.get_archives()
EOM
    execute line('$') - old_line + 1
    call s:show_message("Getting archives... done!")
endfunction

function! s:MessagesBuffer.search_delimiter(flags)
    call search('^' . s:ARCHIVES_DELIMITER, a:flags)
endfunction

python <<EOM
# coding=utf-8

@vimutil.vimfunc('s:MessagesBuffer.select_room')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_MessagesBuffer_select_room(args):
    lingr_vim.select_room_by_offset(int(args[0]))
    vim.eval('s:MessagesBuffer.scroll_to_end()')

@vimutil.vimfunc('s:MessagesBuffer.show_say_buffer')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_MessagesBuffer_show_say_buffer(args):
    vim.eval('s:SayBuffer.initialize()')
    vim.eval('feedkeys("GA", "n")')
    lingr_vim.set_focus(vimutil.bufname())

@vimutil.vimfunc('s:MessagesBuffer.toggle_favorite')
@vimutil.cursor_preseved
@vimutil.do_if(lingr_is_alive)
def lingr_vim_MessagesBuffer_toggle_favorite(args):
    lingr_vim.toggle_favorite(int(args[0]))
EOM

" }}}

" object MembersBuffer {{{
let s:MembersBuffer = copy(s:BufferBase)

function! lingr#members_buffer()
    return s:MembersBuffer
endfunction

function! s:MembersBuffer.layout()
    execute 'topleft vsplit' s:MEMBERS_BUFNAME
    execute g:lingr_vim_sidebar_width 'wincmd |'

    return bufnr('')
endfunction

function! s:MembersBuffer.setup()
    " option
    setlocal statusline=%f\ (%{lingr#online_member_count()}/%{lingr#member_count()})
    setlocal winfixwidth
    setlocal winfixheight

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-members-open-member)
                \ :<C-u>call lingr#members_buffer().open(line('.'))<CR>

    nmap <buffer> <silent> o <Plug>(lingr-members-open-member)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-members-open-member)

    " filetype
    let &filetype = s:MEMBERS_FILETYPE
endfunction

python <<EOM
# coding=utf-8

@vimutil.vimfunc('s:MembersBuffer.open')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_MembersBuffer_open(args):
    vim.eval('lingr#open_url("http://lingr.com/{0}")'.format(
        lingr_vim.get_member_id(int(args[0]))))

EOM

" }}}

" object RoomsBuffer {{{
let s:RoomsBuffer = copy(s:BufferBase)

function! lingr#rooms_buffer()
    return s:RoomsBuffer
endfunction

function! s:RoomsBuffer.layout()
    execute 'leftabove split' s:ROOMS_BUFNAME
    execute g:lingr_vim_rooms_buffer_height 'wincmd _'
    execute g:lingr_vim_sidebar_width 'wincmd |'

    return bufnr('')
endfunction

function! s:RoomsBuffer.setup()
    " option
    setlocal statusline=%f
    setlocal winfixwidth
    setlocal winfixheight

    " autocmd
    " nothing to do

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-select-room)
                \ :<C-u>call lingr#rooms_buffer().select(line('.'))<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-open-room)
                \ :<C-u>call lingr#rooms_buffer().open(line('.'))<CR>

    nmap <buffer> <silent> <CR> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> <LeftRelease> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> o <Plug>(lingr-rooms-open-room)
    nmap <buffer> <silent> <2-LeftMouse> <Plug>(lingr-rooms-open-room)

    " filetype
    let &filetype = s:ROOMS_FILETYPE
endfunction

python <<EOM
# coding=utf-8

@vimutil.vimfunc('s:RoomsBuffer.select')
@vimutil.cursor_preseved
@vimutil.do_if(lingr_is_alive)
def lingr_vim_RoomsBuffer_select(args):
    lingr_vim.select_room_by_lnum(int(args[0]))

@vimutil.vimfunc('s:RoomsBuffer.open')
@vimutil.do_if(lingr_is_alive)
def lingr_vim_RoomsBuffer_open(args):
    vim.eval('lingr#open_url("http://lingr.com/room/{0}")'.format(
        lingr_vim.get_room_id(int(args[0]))))

EOM
" }}}

" object SayBuffer {{{
let s:SayBuffer = copy(s:BufferBase)

function! lingr#say_buffer()
    return s:SayBuffer
endfunction

function! s:SayBuffer.layout()
    execute 'rightbelow split' s:SAY_BUFNAME
    execute g:lingr_vim_say_buffer_height 'wincmd _'

    return bufnr('')
endfunction

function! s:SayBuffer.setup()
    " option
    setlocal statusline=%f
    setlocal nobuflisted
    setlocal buftype=acwrite

    " autocmd
    autocmd BufEnter <buffer> setlocal buftype=acwrite
    autocmd BufLeave <buffer> setlocal buftype=nofile
    autocmd InsertLeave <buffer> call s:SayBuffer.rendering()
    autocmd BufWriteCmd <buffer> call s:SayBuffer.say()

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-say-say)
                \ :<C-u>call lingr#say_buffer().say() \| call lingr#say_buffer().close()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-say-close)
                \ :<C-u>call lingr#say_buffer().close()<CR>

    nmap <buffer> <silent> <CR> <Plug>(lingr-say-say)
    nmap <buffer> <silent> <Esc> <Plug>(lingr-say-close)

    " for custormizing
    " ex) autocmd FileType lingr-say imap <buffer> <CR> <Plug>(lingr-say-insert-mode-say)
    inoremap <buffer> <silent> <Plug>(lingr-say-insert-mode-say)
                \ <Esc>:<C-u>call lingr#say_buffer().say()<CR>i

    " filetype
    let &filetype = s:SAY_FILETYPE
endfunction

function! s:SayBuffer.close()
    close
endfunction

function! s:SayBuffer.say()
    let text = join(getline(0, line('$')), "\n")
    if len(text) > 0
        call lingr#say(text)
    endif
    %delete _
    setlocal nomodified
endfunction
" }}}
