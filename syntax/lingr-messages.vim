syntax match lingrMessagesSpeaker display '^[^ ].*\ze (.*):$'
syntax match lingrMessagesTimestamp display '^[^ ].* \zs(.*)\ze:$'
execute 'syntax keyword lingrMessagesGetArchives display ' escape(lingr#get_archives_message(), ' ')

highlight def link lingrMessagesSpeaker Title
highlight def link lingrMessagesTimestamp Statement
highlight def link lingrMessagesGetArchives Constant

