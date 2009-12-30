syntax match lingrMembersOnline display '.*\ze +$'
syntax match lingrMembersOffline display '.*\ze -$'
syntax match lingrMembersMarker display '[-+]$'

highlight def link lingrMembersOnline String
highlight def link lingrMembersOffline Comment
highlight def link lingrMembersMarker NonText
