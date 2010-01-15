if exists('b:current_syntax')
    finish
endif

syntax match lingrRoomsActive /.*\ze \*$/
syntax match lingrRoomsMarker /\*$/

highlight default link lingrRoomsActive Title
highlight default link lingrRoomsMarker Ignore

let b:current_syntax = 'lingr-rooms'
