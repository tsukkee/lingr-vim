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

highlight default link lingrMessagesMine Identifier
highlight default link lingrMessagesMineMarker Ignore
highlight default link lingrMessagesSpeaker Title
highlight default link lingrMessagesTimestamp Statement
highlight default link lingrMessagesGetArchives Constant
highlight default link lingrMessagesChangePresence Comment

let b:current_syntax = 'lingr-messages'
