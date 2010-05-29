" Lingr-Vim: Lingr client for Vim
" Version:     0.5.2
" Last Change: 29 May 2010
" Author:      tsukkee <takayuki0510+lingr_vim at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
"
"     日本語参考訳
"     http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
" }}}

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
def _lingr_temp():
    major, minor, micro, releaselevel, serial = sys.version_info
    if major != 2 or minor != 6:
        vim.command('let s:invalid_version = 1')
    else:
        vim.command('let s:invalid_version = 0')
_lingr_temp()
EOM
if s:invalid_version
    echoerr 'This plugin needs python 2.6'
    finish
endif

" define commands
command! -bang LingrLaunch call lingr#launch(<bang>1)


let g:loaded_lingr_vim = 1
