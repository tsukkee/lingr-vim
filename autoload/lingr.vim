let s:MESSAGES_BUFNAME = 'lingr-messages'
let s:MESSAGES_FILETYPE = 'lingr-messages'
let s:ROOMS_BUFNAME = 'lingr-rooms'
let s:ROOMS_FILETYPE = 'lingr-rooms'
let s:MEMBERS_BUFNAME = 'lingr-members'
let s:MEMBERS_FILETYPE = 'lingr-members'
let s:SIDEBAR_WIDTH = 25
let s:ROOMS_BUFFER_HEIGHT = 10

function! lingr#launch()
    " get username and password
    let s:user = exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let s:password = exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    " setup buffer
    let [messages_bufnr, rooms_bufnr, members_bufnr] = lingr#setup_buffer()

    " import lingrvim
    python <<EOM
# coding=utf-8
import lingr
import lingrvim

lingr_vim = lingrvim.LingrVim(\
    vim.eval('s:user'), vim.eval('s:password'), int(vim.eval('messages_bufnr')),\
        int(vim.eval('rooms_bufnr')), int(vim.eval('members_bufnr')))
lingr_vim.setup()
EOM
endfunction

function! lingr#setup_buffer()
    execute 'edit +setfiletype\ ' . s:MESSAGES_FILETYPE s:MESSAGES_BUFNAME
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    let messages_bufnr = bufnr('')

    execute 'topleft vsplit' s:MEMBERS_BUFNAME
    let &filetype = s:MEMBERS_FILETYPE
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    let members_bufnr = bufnr('')
    execute s:SIDEBAR_WIDTH 'wincmd |'

    execute 'split' s:ROOMS_BUFNAME
    let &filetype = s:ROOMS_FILETYPE
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal bufhidden=hide
    let rooms_bufnr = bufnr('')
    execute s:ROOMS_BUFFER_HEIGHT 'wincmd _'

    return [messages_bufnr, rooms_bufnr, members_bufnr]
endfunction

function! lingr#say(text)
    python <<EOM
# coding=utf-8
lingr_vim.say(vim.eval('a:text'))
EOM
endfunction
