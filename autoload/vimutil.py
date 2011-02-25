# coding=utf-8:
# vimutil.py: vim utility for python
# Version:     0.0.1
# Last Change: 25 Feb 2011
# Author:      tsukkee <takayuki0510+lingr_vim at gmail.com>
# Licence:     The MIT License {{{
#     Permission is hereby granted, free of charge, to any person obtaining a copy
#     of this software and associated documentation files (the "Software"), to deal
#     in the Software without restriction, including without limitation the rights
#     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#     copies of the Software, and to permit persons to whom the Software is
#     furnished to do so, subject to the following conditions:
#
#     The above copyright notice and this permission notice shall be included in
#     all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#     THE SOFTWARE.
# }}}

import re
import vim

VIM_ENCODING = vim.eval('&encoding')

# Decorator

def buffer_modifiable(buffer):
    def _(func):
        def __(*args, **keywords):
            vim.command("call setbufvar({0.number}, '&modifiable', 1)".format(buffer))
            func(*args, **keywords)
            vim.command("call setbufvar({0.number}, '&modifiable', 0)".format(buffer))
        return __
    return _

def do_if_available(condition, error_message = False):
    def _(func):
        def __(*args, **keywords):
            if condition():
                func(*args, **keywords)
            elif error_message:
                echo_error(error_message)
        return __
    return _

def cursor_preseved(func):
    def _(*args, **keywords):
        cursor = vim.current.window.cursor
        func(*args, **keywords)
        vim.current.window.cursor = cursor
    return _

_functions_for_vim = {}
def vimfunc(name):
    def _(func):
        _functions_for_vim[name] = func

        vim.command("""
            function! {0}(...)
                python vim.command('return "' +  {1}.escape(str({1}._functions_for_vim['{0}'](vim.eval('a:000')))) + '"')
            endfunction
        """.format(name, __name__))

        def __(*args, **keywords):
            return func(args)
        return __
    return _

# Function

# escape "(double quote) and \(backslash)
# Reference: http://lightson.dip.jp/zope/ZWiki/053_e6_96_87_e5_ad_97_e3_82_92_e3_82_a8_e3_82_b9_e3_82_b1_e3_83_bc_e3_83_97_e3_81_99_e3_82_8b_ef_bc_8f_e3_82_a8_e3_82_b9_e3_82_b1_e3_83_bc_e3_83_97_e3_82_92_e5_a4_96_e3_81_99
_quote_by_backslash = re.compile(u'(["\\\\])')
def escape(s):
    return _quote_by_backslash.sub(ur'\\\1', s)

def echo_message(message):
    vim.command('echomsg "{0}"'.format(escape(message)))

def echo_error(message):
    vim.command('echohl ErrorMsg')
    echo_message(message)
    vim.command('echohl None')

def redraw_statusline():
    # force redraw statusline. see :help 'statusline'
    vim.command('let &ro=&ro')

def encode(s):
    return s.encode(VIM_ENCODING, 'ignore')

def decode(s):
    return s.decode(VIM_ENCODING)

def exists(value_name):
    return int(vim.eval('exists("{0}")'.format(value_name)))

def find_buffer(bufnr):
    buf = [b for b in vim.buffers if b.number == bufnr]
    return buf[0] if len(buf) > 0 else None

# :echo bufname('') and :py print vim.current.buffer.name are diffeent?
def bufname(expression = ""):
    return vim.eval('bufname("{0}")'.format(expression))

def let(name, value):
    vim.eval('let {0} = "{1}"', name, escape(value))

def integer(name):
    return int(vim.eval(name))


