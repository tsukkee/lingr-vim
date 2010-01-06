if exists("b:did_ftplugin")
    finish
endif

setlocal statusline=lingr-members
set buftype=nofile
set noswapfile
set bufhidden=hide
setlocal foldcolumn=0

function! s:open_member()
    python <<EOM
# coding=utf-8
import vim
bufnum, lnum, col, off = vim.eval('getpos(".")')
member_id = lingr_vim.get_member_id_by_lnum(int(lnum))
vim.command('call lingr#open_url("http://lingr.com/{0}")'.format(member_id))
EOM
endfunction

nnoremap <buffer> <silent> <Plug>(lingr-members-open-member)
            \ :<C-u>call <SID>open_member()<CR>

nmap <buffer> <silent> o <Plug>(lingr-members-open-member)

let b:undo_ftplugin = 'setlocal statusline<'
            \ . '| set buftype&'
            \ . '| set swapfile&'
            \ . '| set bufhidden&'
            \ . '| setlocal foldcolumn<'
            \ . '| setlocal modifiable<'
            \ . '| nunmap <buffer> o'

let b:did_ftplugin = 1
