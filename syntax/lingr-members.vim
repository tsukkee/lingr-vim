if exists('b:current_syntax')
    finish
endif

syntax match lingrMembersOnline /.*\ze +$/
syntax match lingrMembersOffline /.*\ze -$/
syntax match lingrMembersMarker /[-+]$/

highlight default link lingrMembersOnline String
highlight default link lingrMembersOffline Comment
highlight default link lingrMembersMarker Ignore

let b:current_syntax = 'lingr-members'
