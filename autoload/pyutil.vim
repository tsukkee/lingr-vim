" pyutil.vim: python utility for vim
" Version:     0.0.1
" Last Change: 28 Feb 2011
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
" }}}

let s:path = expand('<sfile>:p:h')

function! pyutil#version()
    " check +python
    if !has('python')
        return [0, 0, 0, 0, 0]
    endif

    " check python version
    let result = []
    python <<EOM
# coding=utf-8
import vim
import sys

def _pyutil_temp():
    for i in sys.version_info:
        vim.eval('add(result, "{0}")'.format(i))
_pyutil_temp()
EOM
    return result
endfunction

function! pyutil#use()
    call pyutil#append_path(s:path)
endfunction

function! pyutil#append_path(path)
    python <<EOM
# coding=utf-8
import vim
import sys
if not vim.eval('a:path') in sys.path:
    sys.path.append(vim.eval('a:path'))
EOM
endfunction

function! pyutil#get_value(name)
    python<<EOM
# coding=utf-8
import vimutil
vim.command('return {0}'.format(vimutil.vimliteral(eval(vim.eval('a:name')))))
EOM
endfunction


