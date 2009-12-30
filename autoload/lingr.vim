let s:MESSAGES_BUFNAME = 'lingr-messages'
let s:MESSAGES_FILETYPE = 'lingr-messages'
let s:ROOMS_BUFNAME = 'lingr-rooms'
let s:ROOMS_FILETYPE = 'lingr-rooms'
let s:MEMBERS_BUFNAME = 'lingr-members'
let s:MEMBERS_FILETYPE = 'lingr-members'
let s:SIDEBAR_WIDTH = 25
let s:ROOMS_BUFFER_HEIGHT = 10
let s:GET_ARCHIVES_MESSAGE = "[Get more from archives...]"

function! lingr#launch()
    " get username and password
    let s:user = exists('g:lingr_vim_user')
                \ ? g:lingr_vim_user
                \ : input('Lingr username? ')

    let s:password = exists('g:lingr_vim_password')
                \ ? g:lingr_vim_password
                \ : inputsecret('Lingr password? ')

    " setup buffer
    let messages_bufnr = s:setup_buffer(
                \ 'edit',
                \ s:MESSAGES_BUFNAME,
                \ s:MESSAGES_FILETYPE,
                \ 'normal! G')
    let members_bufnr = s:setup_buffer(
                \ 'topleft vsplit',
                \ s:MEMBERS_BUFNAME,
                \ s:MEMBERS_FILETYPE,
                \ s:SIDEBAR_WIDTH . ' wincmd |')
    let rooms_bufnr = s:setup_buffer(
                \ 'leftabove split',
                \ s:ROOMS_BUFNAME,
                \ s:ROOMS_FILETYPE,
                \ s:ROOMS_BUFFER_HEIGHT . ' wincmd _')

    " import lingrvim
    python <<EOM
# coding=utf-8
import lingr
import lingrvim

lingr_vim = lingrvim.LingrVim(\
    vim.eval('s:user'),\
    vim.eval('s:password'),\
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


function! lingr#get_archives_message()
    return s:GET_ARCHIVES_MESSAGE
endfunction


function! s:setup_buffer(command, bufname, filetype, after)
    execute a:command a:bufname
    let &filetype = a:filetype
    execute a:after
    return bufnr('')
endfunction


