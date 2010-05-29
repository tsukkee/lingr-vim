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

syntax match lingrMessagesGetArchives /\%1l.*/
syntax match lingrMessagesHeader /^[^ ].*(.*):$/
           \ contains=lingrMessagesMine,lingrMessagesMineMarker,
           \          lingrMessagesSpeaker,lingrMessagesTimestamp
syntax match lingrMessagesMine /^.*\ze\*(/ contained
syntax match lingrMessagesMineMarker /\*\ze(/ contained
syntax match lingrMessagesSpeaker /^.*\ze (/ contained
syntax match lingrMessagesTimestamp /(.*)/ contained
syntax match lingrMessagesChangePresence /^-- .*/
syntax match lingrMessagesError /^!!! .*/

highlight default link lingrMessagesMine Identifier
highlight default link lingrMessagesMineMarker Ignore
highlight default link lingrMessagesSpeaker Title
highlight default link lingrMessagesTimestamp Statement
highlight default link lingrMessagesGetArchives Constant
highlight default link lingrMessagesChangePresence Comment
highlight default link lingrMessagesError ErrorMsg

let b:current_syntax = 'lingr-messages'
