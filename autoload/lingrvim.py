# vim:set fileencoding=utf-8:

import vim
import lingr
import threading
import logging

class LingrObserver(threading.Thread):
    def __init__(self, lingr):
        self.lingr = lingr
        self.alive = True

    def run(self):
        while(self.alive):
            lingr.observe()

class LingrVim(object):
    def __init__(self, user, password, bufnr):
        self.lingr = lingr.Connection(user, password)
        self.buffer = vim.buffers[bufnr]
        self.current_room = ""

    def setup(self):
        def connected_hook(sender):
            pass

        def error_hook(sender, error):
            pass

        def message_hook(sender, room_id, message):
            pass

        def join_hook(sender, room_id, member):
            pass

        def leave_hook(sender, room_id, member):
            pass

        lingr.connected_hooks.append(connected_hook)
        lingr.error_hooks.append(error_hook)
        lingr.message_hooks.append(message_hook)
        lingr.join_hooks.append(join_hook)
        lingr.leave_hooks.append(leave_hook)

        observer = LingrObserver(lingr)
        observer.start()

    def say(self, text):
        if self.current_room:
            self.lingr.say(self.current_room, text)

    def destroy(self):
        self.observer.alive = False
        self.observer.join()
