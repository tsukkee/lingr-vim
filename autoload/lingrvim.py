# vim:set fileencoding=utf-8:

import vim
import lingr
import threading
import logging

class LingrObserver(threading.Thread):
    def __init__(self, lingr):
        threading.Thread.__init__(self)
        self.lingr = lingr

    def run(self):
        self.lingr.start()

class LingrVim(object):
    def __init__(self, user, password, bufnr):
        self.lingr = lingr.Connection(user, password, logger = lingr._get_debug_logger())
        self.buffer = vim.buffers[bufnr - 1]
        self.current_room = "vim" # TODO: should choose room

    def setup(self):
        def connected_hook(sender):
            if sender.rooms.has_key(self.current_room):
                for m in sender.rooms[self.current_room].backlog:
                    self.buffer.append(m.text.encode('utf-8'))

        def error_hook(sender, error):
            pass

        def message_hook(sender, room_id, message):
            if self.current_room == room_id:
                self.buffer.append(message.text.encode('utf-8'))

        def join_hook(sender, room_id, member):
            pass

        def leave_hook(sender, room_id, member):
            pass

        self.lingr.connected_hooks.append(connected_hook)
        self.lingr.error_hooks.append(error_hook)
        self.lingr.message_hooks.append(message_hook)
        self.lingr.join_hooks.append(join_hook)
        self.lingr.leave_hooks.append(leave_hook)

        observer = LingrObserver(self.lingr)
        observer.start()

    def say(self, text):
        if self.current_room:
            self.lingr.say(self.current_room, text)

    def destroy(self):
        self.observer.alive = False
        self.observer.join()
