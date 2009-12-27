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
    def __init__(self, user, password, messages_bufnr, rooms_bufnr, members_bufnr):
        # self.lingr = lingr.Connection(user, password, logger = lingr._get_debug_logger())
        self.lingr = lingr.Connection(user, password)

        # buffers
        self.messages_buffer = vim.buffers[messages_bufnr - 1]
        self.rooms_buffer = vim.buffers[rooms_bufnr - 1]
        self.members_buffer = vim.buffers[members_bufnr - 1]

        self.current_room = "vim" # TODO: should choose room

        self.messages = {} # {"room1": [member1, member2], "room2": [member1 ...

    def setup(self):
        def connected_hook(sender):
            for id, room in sender.rooms.iteritems():
                # get messages
                self.messages[id] = []
                for m in room.backlog:
                    self.messages[id].append(m)

            self.render_all()

        def error_hook(sender, error):
            print "Lingr error: " + str(error)

        def message_hook(sender, room, message):
            self.messages[room.id].append(message)
            if self.current_room == room.id:
                for text in message.text.split("\n"):
                    self.messages_buffer.append(text.encode('utf-8'))

        def join_hook(sender, room, member):
            if self.current_room == room.id:
                self.messages_buffer.append("-- " + member.name.encode('utf-8') + " is now online")
            self.render_members()

        def leave_hook(sender, room, member):
            if self.current_room == room.id:
                self.messages_buffer.append("-- " + member.name.encode('utf-8') + " is now offline")
            self.render_members()

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

    def render_all(self):
        self.render_messages()
        self.render_rooms()
        self.render_members()

    def render_messages(self):
        del self.messages_buffer[:]
        self.messages_buffer[0] = "[get more archive]"
        for m in self.messages[self.current_room]:
            # vim.buffer.append() cannot receive newlines
            for text in m.text.split("\n"):
                self.messages_buffer.append(text.encode('utf-8'))

    def render_rooms(self):
        del self.rooms_buffer[:]
        self.rooms_buffer[0] = "-- Rooms --"
        for id, room in self.lingr.rooms.iteritems():
            self.rooms_buffer.append(id.encode('utf-8'))

    def render_members(self):
        del self.members_buffer[:]
        members = self.lingr.rooms[self.current_room].members.values()

        online_members = []
        offline_members = []
        for m in members:
            if m.presence:
                online_members.append(m)
            else:
                offline_members.append(m)

        self.members_buffer[0] = "-- Online --"
        for member in online_members:
            self.members_buffer.append(member.name.encode('utf-8'))

        self.members_buffer.append("-- Offline --")
        for member in offline_members:
            self.members_buffer.append(member.name.encode('utf-8'))
