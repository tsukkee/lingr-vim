let s:BUFNAME = 'lingr-vim'

function! lingr#launch()
    " get username and password
    let s:user = exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let s:password = exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    " setup buffer
    let bufnr = lingr#setup_buffer()

    " import lingrvim
    python <<EOM
# coding=utf-8
import lingr
import lingrvim

lingr_vim = lingrvim.LingrVim(\
    vim.eval('s:user'), vim.eval('s:password'), int(vim.eval('bufnr')))
lingr_vim.setup()
EOM
endfunction

function! lingr#setup_buffer()
    execute 'edit +setfiletype\ lingr' s:BUFNAME
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    return bufnr('%')
endfunction

function! lingr#say(text)
    python <<EOM
# coding=utf-8
lingr_vim.say(vim.eval('a:text'))
EOM
endfunction
