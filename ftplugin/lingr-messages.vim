setlocal statusline=lingr-messages
set buftype=nofile
set noswapfile
set bufhidden=hide
setlocal foldcolumn=0

function! s:get_archives()
    let [bufnum, lnum, col, off] = getpos('.')
    if lnum == 1
        python <<EOM
# coding=utf-8
lingr_vim.get_archives()
EOM
    endif
endfunction

nnoremap <silent> <buffer> <Plug>(lingr-messages-get-archives)
            \ :<C-u>call <SID>get_archives()<CR>
nmap <silent> <buffer> <CR> <Plug>(lingr-messages-get-archives)
