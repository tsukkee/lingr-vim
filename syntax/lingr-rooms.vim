if exists('b:current_syntax')
    finish
endif

syntax match lingrRoomsActive /.*\ze \*$/
syntax match lingrRoomsMarker /\*$/
syntax match lingrRoomsUnread /(\*)$/

highlight default link lingrRoomsActive Title
highlight default link lingrRoomsMarker Ignore
highlight default link lingrRoomsUnread ErrorMsg

let b:current_syntax = 'lingr-rooms'
