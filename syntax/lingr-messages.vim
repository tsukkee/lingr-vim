if exists('b:current_syntax')
    finish
endif

syntax match lingrMessagesGetArchives /\%1l.*/
syntax match lingrMessagesHeader /^[^ ].* (.*):$/
           \ contains=lingrMessagesSpeaker,lingrMessagesTimestamp
syntax match lingrMessagesSpeaker /^[^ ][^(]*/ contained
syntax match lingrMessagesTimestamp /(.*)/ contained
syntax match lingrMessagesChangePresence /^-- .*/

highlight default link lingrMessagesSpeaker Title
highlight default link lingrMessagesTimestamp Statement
highlight default link lingrMessagesGetArchives Constant
highlight default link lingrMessagesChangePresence Comment

let b:current_syntax = 'lingr-messages'
