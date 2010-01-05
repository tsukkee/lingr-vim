if exists('b:current_syntax')
    finish
endif

syntax match lingrMessagesGetArchives /\%1l.*/
syntax match lingrMessagesHeader /^[^ ].* (.*):$/
           \ contains=lingrMessagesSpeaker,lingrMessagesTimestamp
syntax match lingrMessagesSpeaker /^[^ ][^(]*/ contained
syntax match lingrMessagesTimestamp /(.*)/ contained


highlight default link lingrMessagesSpeaker Title
highlight default link lingrMessagesTimestamp Statement
highlight default link lingrMessagesGetArchives Constant

let b:current_syntax = 'lingr-messages'
