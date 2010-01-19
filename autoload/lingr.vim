" Constants {{{
let s:MESSAGES_BUFNAME = 'lingr-messages'
let s:MESSAGES_FILETYPE = 'lingr-messages'
let s:ROOMS_BUFNAME = 'lingr-rooms'
let s:ROOMS_FILETYPE = 'lingr-rooms'
let s:MEMBERS_BUFNAME = 'lingr-members'
let s:MEMBERS_FILETYPE = 'lingr-members'
let s:SAY_BUFNAME = 'lingr-say'
let s:SAY_FILETYPE = 'lingr-say'
let s:SIDEBAR_WIDTH = 25
let s:ROOMS_BUFFER_HEIGHT = 10
let s:SAY_BUFFER_HEIGHT = 3
let s:ARCHIVES_DELIMITER = "^--------------------"
let s:URL_PATTERN = '^https\?://[^ ]*'
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

    command! LingrExit call lingr#exit()
endfunction

function! lingr#exit()
    echo "Exiting Lingr-Vim..."
    sleep 1m
    redraw

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
    if !exists('g:lingr_command_to_open_url')
        " Mac
        if has('mac') || has('macunix') || system('uname') =~? '^darwin'
            let g:lingr_command_to_open_url = 'open "%s"'
        " Windows
        elseif has('win32') || ('win64')
            let g:lingr_command_to_open_url = 'start rundll32 url.dll,FileProtocolHandler "%s"'
        " KDE
        elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
            let g:lingr_command_to_open_url = 'kfmclient exec "%s" &'
        " GNOME
        elseif exists('$GNOME_DESKTOP_SESSION_ID')
            let g:lingr_command_to_open_url = 'gnome-open "%s" &'
        " Xfce
        elseif executable(vimshell#getfilename('exo-open'))
            let g:lingr_command_to_open_url = 'exo-open "%s" &'
        else
            " TODO: other OS support?
            let g:lingr_command_to_open_url = ""
        endif
    endif

    if match(a:url, s:URL_PATTERN) == 0 && g:lingr_command_to_open_url != ""
        echo "open url:" a:url . "..."
        sleep 1m
        redraw
        execute 'silent !' printf(g:lingr_command_to_open_url, shellescape(a:url, 'shell'))
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
    autocmd BufEnter <buffer> call s:on_buffer_enter()
    autocmd BufLeave <buffer> call s:on_buffer_leave()
endfunction

function! s:setup_messages_buffer()
    " split
    execute 'edit' s:MESSAGES_BUFNAME
    let &filetype = s:MESSAGES_FILETYPE

    call s:setup_buffer_base()

    " option
    setlocal statusline=lingr-messages

    " autocmd
    autocmd WinEnter <buffer> silent $

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
    execute s:SIDEBAR_WIDTH 'wincmd |'

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
    execute s:ROOMS_BUFFER_HEIGHT 'wincmd _'

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
    autocmd WinLeave <buffer> call s:close_say_buffer()

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-say-say)
                \ :<C-u>call <SID>say_buffer_contents()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-say-close)
                \ :<C-u>call <SID>close_say_buffer()<CR>
    nmap <buffer> <silent> <CR> <Plug>(lingr-say-say)
    nmap <buffer> <silent> <Esc> <Plug>(lingr-say-close)

    " window size
    execute s:SAY_BUFFER_HEIGHT 'wincmd _'

    return bufnr('')
endfunction
" }}}

" for all buffer {{{
function! s:on_buffer_enter()
    python <<EOM
# coding=utf-8
# after lingr_vim has initialized
if lingr_vim and lingr_vim.current_room_id:
    lingr_vim.set_focus(True)
EOM
endfunction

function! s:on_buffer_leave()
    python <<EOM
# coding=utf-8
# after lingr_vim has initialized
if lingr_vim and lingr_vim.current_room_id:
    lingr_vim.set_focus(False)
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
    echo "Getting archives..."
    sleep 1m
    redraw
    python <<EOM
# coding=utf-8
lingr_vim.get_archives()
EOM
    echo "Getting archives... done!"
endfunction

function! s:search_delimiter(flags)
    call search(s:ARCHIVES_DELIMITER, a:flags)
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
