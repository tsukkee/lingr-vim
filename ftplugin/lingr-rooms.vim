if exists("b:did_ftplugin")
    finish
endif

setlocal statusline=lingr-rooms
set buftype=nofile
set noswapfile
set bufhidden=hide
setlocal foldcolumn=0

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


nnoremap <buffer> <silent> <Plug>(lingr-rooms-select-room)
            \ :<C-u>call <SID>select_room()<CR>
nnoremap <buffer> <silent> <Plug>(lingr-rooms-open-room)
            \ :<C-u>call <SID>open_room()<CR>

nmap <buffer> <silent> <CR> <Plug>(lingr-rooms-select-room)
nmap <buffer> <silent> o <Plug>(lingr-rooms-open-room)

let b:undo_ftplugin = 'setlocal statusline<'
            \ . '| set buftype&'
            \ . '| set swapfile&'
            \ . '| set bufhidden&'
            \ . '| setlocal foldcolumn<'
            \ . '| setlocal modifiable<'
            \ . '| nunmap <buffer> <CR>'
            \ . '| nunmap <buffer> o'

let b:did_ftplugin = 1
