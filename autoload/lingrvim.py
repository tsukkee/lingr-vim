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


def do_buffer_command(buffer, command):
    current_bufnr = vim.eval('bufnr("")')
    vim.command('silent buffer ' + str(buffer.number))
    vim.command(command)
    vim.command('silent buffer ' + current_bufnr)


def make_modifiable(buffer, func):
    def do(*args, **keywords):
        do_buffer_command(buffer, 'silent setlocal modifiable')
        func(*args, **keywords)
        do_buffer_command(buffer, 'silent setlocal nomodifiable')
    return do


class LingrVim(object):
    def __init__(self, user, password, messages_bufnr, members_bufnr, rooms_bufnr):
        # self.lingr = lingr.Connection(user, password, logger = lingr._get_debug_logger())
        self.lingr = lingr.Connection(user, password)

        # buffers
        self.messages_buffer = vim.buffers[messages_bufnr - 1]
        self.members_buffer = vim.buffers[members_bufnr - 1]
        self.rooms_buffer = vim.buffers[rooms_bufnr - 1]

        # generate render functions
        self.render_messages = \
            make_modifiable(self.messages_buffer, self._render_messages)
        self.render_members = \
            make_modifiable(self.members_buffer, self._render_members)
        self.render_rooms = \
            make_modifiable(self.rooms_buffer, self._render_rooms)

        # self.current_room = "vim" # TODO: should choose room

        self.messages = {} # {"room1": [member1, member2], "room2": [member1 ...

    def setup(self):
        def connected_hook(sender):
            # get messages
            for id, room in sender.rooms.iteritems():
                self.messages[id] = []
                for m in room.backlog:
                    self.messages[id].append(m)

            self.current_room = sender.rooms.keys()[0]
            self.render_all()

        def error_hook(sender, error):
            print "Lingr error: " + str(error)

        def message_hook(sender, room, message):
            self.messages[room.id].append(message)
            if self.current_room == room.id:
                self.messages_buffer.append(message.nickname.encode('utf-8') + '::')

                # vim.buffer.append() cannot receive newlines
                for text in message.text.split("\n"):
                    self.messages_buffer.append(text.encode('utf-8'))

        def join_hook(sender, room, member):
            if self.current_room == room.id:
                self.messages_buffer.append(\
                    "-- " + member.name.encode('utf-8') + " is now online")
                self.render_members()

        def leave_hook(sender, room, member):
            if self.current_room == room.id:
                self.messages_buffer.append(\
                    "-- " + member.name.encode('utf-8') + " is now offline")
                self.render_members()

        self.lingr.connected_hooks.append(connected_hook)
        self.lingr.error_hooks.append(error_hook)
        self.lingr.message_hooks.append(\
            make_modifiable(self.messages_buffer, message_hook))
        self.lingr.join_hooks.append(\
            make_modifiable(self.messages_buffer, join_hook))
        self.lingr.leave_hooks.append(\
            make_modifiable(self.messages_buffer, leave_hook))

        observer = LingrObserver(self.lingr)
        observer.start()

    def say(self, text):
        if self.current_room:
            self.lingr.say(self.current_room, text)

    def render_all(self):
        self.render_messages()
        self.render_rooms()
        self.render_members()

    def _render_messages(self):
        del self.messages_buffer[:]
        self.messages_buffer[0] = "[get more archive]"
        for m in self.messages[self.current_room]:
            self.messages_buffer.append(m.nickname.encode('utf-8') + '::')

            # vim.buffer.append() cannot receive newlines
            for text in m.text.split("\n"):
                self.messages_buffer.append(text.encode('utf-8'))

    def _render_rooms(self):
        del self.rooms_buffer[:]

        is_first = True
        for id, room in self.lingr.rooms.iteritems():
            mark = " *" if id == self.current_room else ""
            text = room.name.encode('utf-8') + mark
            if is_first:
                self.rooms_buffer[0] = text
                is_first = False
            else:
                self.rooms_buffer.append(text)

    def _render_members(self):
        del self.members_buffer[:]

        members = self.lingr.rooms[self.current_room].members.values()
        members.sort(key=lambda x: not x.presence)

        is_first = True
        for m in members:
            owner = '(owner)' if m.owner else ''
            online = ' +' if m.presence else ' -'
            text = m.name.encode('utf-8') + owner + online
            if is_first:
                self.members_buffer[0] = text
                is_first = False
            else:
                self.members_buffer.append(text)
