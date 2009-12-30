syntax match lingrRoomsActive display '.*\ze \*$'
syntax match lingrRoomsMarker display '\*$'

highlight def link lingrRoomsActive Title
highlight def link lingrRoomsMarker NonText
