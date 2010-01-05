if exists("b:did_ftplugin")
    finish
endif

setlocal statusline=lingr-members
set buftype=nofile
set noswapfile
set bufhidden=hide
setlocal foldcolumn=0

let b:undo_ftplugin = 'setlocal statusline<'
            \ . '| set buftype&'
            \ . '| set swapfile&'
            \ . '| set bufhidden&'
            \ . '| setlocal foldcolumn<'
            \ . '| setlocal modifiable<'

let b:did_ftplugin = 1
