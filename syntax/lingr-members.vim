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

if exists('b:current_syntax')
    finish
endif

syntax match lingrMembersOnline /.*\ze +$/
syntax match lingrMembersOffline /.*\ze -$/
syntax match lingrMembersBot /.*\ze \*$/
syntax match lingrMembersMarker /[-+*]$/

highlight default link lingrMembersOnline String
highlight default link lingrMembersOffline Comment
highlight default link lingrMembersBot Special
highlight default link lingrMembersMarker Ignore

let b:current_syntax = 'lingr-members'
