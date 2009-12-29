setlocal statusline=lingr-rooms
set buftype=nofile
set noswapfile
set bufhidden=hide
setlocal foldcolumn=0

function! s:select_room()
python <<EOM
# coding=utf-8
bufnum, lnum, col, off = vim.eval('getpos(".")')
room_id = lingr_vim.lingr.rooms.keys()[int(lnum) - 1]
if lingr_vim.current_room != room_id:
    lingr_vim.current_room = room_id
    lingr_vim.render_all()
    vim.eval('setpos(".", [%s, %s, %s, %s])' % (bufnum, lnum, col, off))
EOM
endfunction

nnoremap <buffer> <silent> <Plug>(lingr-vim-select-room)
            \ :<C-u>call <SID>select_room()<CR>
nmap <buffer> <silent> <CR> <Plug>(lingr-vim-select-room)
