if exists("b:did_ftplugin")
    finish
endif

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

let s:ARCHIVES_DELIMITER = "^--------------------"
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

autocmd plugin-lingr WinEnter <buffer> silent $


let b:undo_ftplugin = 'setlocal statusline<'
            \ . '| set buftype&'
            \ . '| set swapfile&'
            \ . '| set bufhidden&'
            \ . '| setlocal foldcolumn<'
            \ . '| setlocal modifiable<'
            \ . '| nunmap <buffer> <CR>'
            \ . '| nunmap <buffer> }'
            \ . '| nunmap <buffer> {'
            \ . '| nunmap <buffer> <C-n>'
            \ . '| nunmap <buffer> <C-p>'
            \ . '| nunmap <buffer> o'
            \ . '| autocmd! plugin-lingr WinEnter <buffer>'

let b:did_ftplugin = 1
