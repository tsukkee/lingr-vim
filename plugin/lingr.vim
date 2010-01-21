if exists('g:loaded_lingr_vim')
    finish
endif

" check Vim version
if !exists('v:version') || v:version < 700
    echoerr 'This plugin needs Vim 7.0 or higher (7.2 is recommended)'
    finish
endif

" check +python
if !has('python')
    echoerr 'This plugin needs +python (Python 2.6)'
    finish
endif

" check python version
python <<EOM
# coding=utf-8
import vim
import sys
major, minor, micro, releaserevel, serial = sys.version_info
if major != 2 or minor != 6:
    vim.command('let s:invalid_version = 1')
else:
    vim.command('let s:invalid_version = 0')
EOM
if s:invalid_version
    echoerr 'This plugin needs python 2.6'
    finish
endif

" define commands
command! -bang LingrLaunch call lingr#launch(<bang>1)


let g:loaded_lingr_vim = 1
