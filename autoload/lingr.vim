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

function! lingr#launch()
    " get username and password
    let user = exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let password = exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    wincmd o
    let messages_bufnr = s:setup_messages_buffer()
    let members_bufnr = s:setup_members_buffer()
    let rooms_bufnr = s:setup_rooms_buffer()

    " import lingrvim
    python <<EOM
# coding=utf-8
import lingr
import lingrvim

if lingr_vim:
    del lingr_vim

lingr_vim = lingrvim.LingrVim(\
    vim.eval('user'),\
    vim.eval('password'),\
    int(vim.eval('messages_bufnr')),\
    int(vim.eval('members_bufnr')),\
    int(vim.eval('rooms_bufnr')))

lingr_vim.setup()
EOM
endfunction

function! lingr#say(text)
    python <<EOM
# coding=utf-8
lingr_vim.say(vim.eval('a:text'))
EOM
endfunction

" Reference: wwwsearch.vim
" (http://github.com/kana/config/blob/master/vim/dot.vim/autoload/wwwsearch.vim)
function! lingr#open_url(url)
    if !exists('g:lingr_command_to_open_url')
        if has('mac') || has('macunix') || system('uname') =~? '^darwin'
            let g:lingr_command_to_open_url = 'open %s'
        elseif has('win32') || ('win64')
            let g:lingr_command_to_open_url = 'start rundll32 url.dll,FileProtocolHandler %s'
        else
            " TODO: other OS support?
            let g:lingr_command_to_open_url = ""
        endif
    endif

    if match(a:url, '^https\?://[^ ]*') == 0 && g:lingr_command_to_open_url != ""
        execute 'silent !' printf(g:lingr_command_to_open_url, shellescape(a:url, 'shell'))
    endif
endfunction


function! s:setup_buffer(command, bufname, filetype, after)
    execute a:command a:bufname
    let &filetype = a:filetype
    execute a:after
    return bufnr('')
endfunction

function! s:setup_messages_buffer()
    " split
    execute 'edit' s:MESSAGES_BUFNAME
    let &filetype = s:MESSAGES_FILETYPE

    " option
    setlocal statusline=lingr-messages
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldcolumn=0

    " autocmd
    autocmd! * <buffer>
    autocmd WinEnter <buffer> silent $

    " mapping
    nnoremap <silent> <buffer> <Plug>(lingr-messages-get-archives)
                \ :<C-u>call <SID>get_archives()<CR>
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
    nnoremap <silent> <buffer> <Plug>(lingr-messages-open-url-under-cursor)
                \ :<C-u>call lingr#open_url(expand('<cWORD>'))<CR>

    nmap <silent> <buffer> <CR> <Plug>(lingr-messages-get-archives)
    nmap <silent> <buffer> } <Plug>(lingr-messages-search-delimiter-forward)
    nmap <silent> <buffer> { <Plug>(lingr-messages-search-delimiter-backward)
    nmap <silent> <buffer> <C-n> <Plug>(lingr-messages-select-next-room)
    nmap <silent> <buffer> <C-p> <Plug>(lingr-messages-select-prev-room)
    nmap <silent> <buffer> o <Plug>(lingr-messages-open-url-under-cursor)

    " window size
    " nothing to do

    return bufnr('')
endfunction

function! s:setup_members_buffer()
    " split
    execute 'topleft vsplit' s:MEMBERS_BUFNAME
    let &filetype = s:MEMBERS_FILETYPE

    " option
    setlocal statusline=lingr-members
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldcolumn=0

    " autocmd
    autocmd! * <buffer>

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-members-open-member)
                \ :<C-u>call <SID>open_member()<CR>

    nmap <buffer> <silent> o <Plug>(lingr-members-open-member)

    " window size
    execute s:SIDEBAR_WIDTH 'wincmd |'

    return bufnr('')
endfunction

function! s:setup_rooms_buffer()
    " split
    execute 'leftabove split' s:ROOMS_BUFNAME
    let &filetype = s:ROOMS_FILETYPE

    " option
    setlocal statusline=lingr-rooms
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldcolumn=0

    " autocmd
    autocmd! * <buffer>

    " mapping
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-select-room)
                \ :<C-u>call <SID>select_room()<CR>
    nnoremap <buffer> <silent> <Plug>(lingr-rooms-open-room)
                \ :<C-u>call <SID>open_room()<CR>

    nmap <buffer> <silent> <CR> <Plug>(lingr-rooms-select-room)
    nmap <buffer> <silent> o <Plug>(lingr-rooms-open-room)

    " window size
    execute s:ROOMS_BUFFER_HEIGHT 'wincmd _'

    return bufnr('')
endfunction

function! s:setup_say_buffer()
    " split
    execute 'rightbelow split' s:SAY_BUFNAME
    let &filetype = s:SAY_FILETYPE

    " option
    setlocal statusline=lingr-say
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal foldcolumn=0
    setlocal nobuflisted

    " autocmd
    autocmd! * <buffer>
    autocmd WinLeave <buffer> close
    autocmd BufLeave <buffer> close

    " mapping

    " window size
    execute s:SAY_BUFFER_HEIGHT 'wincmd _'

    return bufnr('')
endfunction


function! s:get_archives()
    let [bufnum, lnum, col, off] = getpos('.')
    if lnum == 1
        python <<EOM
# coding=utf-8
lingr_vim.get_archives()
EOM
    endif
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

function! s:open_member()
    python <<EOM
# coding=utf-8
import vim
bufnum, lnum, col, off = vim.eval('getpos(".")')
member_id = lingr_vim.get_member_id_by_lnum(int(lnum))
vim.command('call lingr#open_url("http://lingr.com/{0}")'.format(member_id))
EOM
endfunction

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
