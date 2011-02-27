# coding=utf-8:
# vimutil.py: vim utility for python
# Version:     0.0.1
# Last Change: 28 Feb 2011
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

import vim
import re

VIM_ENCODING = vim.eval('&encoding')
ENCODING_MODE = 'ignore'

class VimUtilError(Exception):
    def __init__(self, reason):
        self.reason = reason

    def __repr__(self):
        "<{0}.{1} reason={2.reason}>".format(
            __name__, self.__class__.__name__, self)

# Decorator

def buffer_modifiable(buffer):
    def _(func):
        def __(*args, **keywords):
            vim.command("call setbufvar({0.number}, '&modifiable', 1)".format(buffer))
            result = func(*args, **keywords)
            vim.command("call setbufvar({0.number}, '&modifiable', 0)".format(buffer))
            return result
        return __
    return _

def do_if(condition, default = None, error_message = ''):
    def _(func):
        def __(*args, **keywords):
            if condition():
                return func(*args, **keywords)
            else:
                if error_message:
                    echo_error(str(error_message))
                if default != None:
                    return default
        return __
    return _

def cursor_preseved(func):
    def _(*args, **keywords):
        cursor = vim.current.window.cursor
        result = func(*args, **keywords)
        vim.current.window.cursor = cursor
        return result
    return _

_functions_for_vim = {}
def vimfunc(name):
    def _(func):
        _functions_for_vim[name] = func

        vim.command("""
function! {0}(...)
python <<EOM
# coding=utf-8

vim.command('return ' + {1}.vimliteral({1}._functions_for_vim['{0}'](vim.eval('a:000'))))
EOM
endfunction
        """.format(name, __name__))

        def __(*args, **keywords):
            return func(args)
        return __
    return _

# Function

_none_type    = type(None)
_bool_type    = type(True)
_string_type  = type('')
_unicode_type = type(u'')
_num_type     = type(0)
_array_type   = type([])
_dict_type    = type({})
def vimliteral(obj):
    kind = type(obj)
    if   kind == _none_type:
        return '0'
    elif kind == _bool_type:
        return '1' if obj else '0'
    elif kind == _num_type:
        return str(obj)
    elif kind == _unicode_type:
        return vimliteral(encode(obj))
    elif kind == _string_type:
        return '"' + escape(obj) + '"'
    elif kind == _array_type:
        return '[' + ','.join(map(vimliteral, obj)) + ']'
    elif kind == _dict_type:
        result = []
        for k, v in obj.iteritems():
            result.append(vimliteral(k) + ':' + vimliteral(v))
        return '{' + ','.join(result) + '}'
    else:
        raise VimUtilError('vimliteral: can not convert')

# escape "(double quote) and \(backslash)
# Reference: http://lightson.dip.jp/zope/ZWiki/053_e6_96_87_e5_ad_97_e3_82_92_e3_82_a8_e3_82_b9_e3_82_b1_e3_83_bc_e3_83_97_e3_81_99_e3_82_8b_ef_bc_8f_e3_82_a8_e3_82_b9_e3_82_b1_e3_83_bc_e3_83_97_e3_82_92_e5_a4_96_e3_81_99
_quote_by_backslash = re.compile('(["\\\\])')
def escape(s):
    return _quote_by_backslash.sub(r'\\\1', s)

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
    return s.encode(VIM_ENCODING, ENCODING_MODE)

def decode(s):
    return s.decode(VIM_ENCODING)

def exists(value_name):
    return int(vim.eval('exists("{0}")'.format(value_name)))

def find_buffer(bufnr):
    # indices of vim.buffers are different from bufnrs
    buf = [b for b in vim.buffers if b.number == bufnr]
    return buf[0] if len(buf) > 0 else None

# :echo bufname('') and :py print vim.current.buffer.name are diffeent?
def bufname(expression = ""):
    return vim.eval('bufname("{0}")'.format(expression))

def let(name, value):
    vim.command('let {0} = {1}'.format(name, vimliteral(value)))

def integer(name):
    return int(vim.eval(name))


