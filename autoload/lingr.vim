function! lingr#launch()
    " get username and password
    let s:lingr_vim_user = exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let s:lingr_vim_password = exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : input('Lingr password? ')

    " import lingrvim
    let pwd = expand('%:p:h')
    python <<EOM
import vim
import sys

sys.path.append(vim.eval('pwd'))
import lingr
import lingrvim

lingr_vim = lingrvim.LingrVim(vim.eval('s:lingr_vim_user'), vim.eval('s:lingr_vim_password'), 0)
EOM
endfunction

function! lingr#setup_buffer()

endfunction

function! lingr#say(text)
    python lingr_vim.say(vim.eval('a:text'))
endfunction
