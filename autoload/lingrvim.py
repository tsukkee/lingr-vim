# vim:set fileencoding=utf-8:

import vim
import lingr
import threading
import time
import logging

class LingrObserver(threading.Thread):
    def __init__(self, lingr):
        threading.Thread.__init__(self)
        self.lingr = lingr

    def run(self):
        self.lingr.start()


def do_buffer_command(buffer, command):
    current_bufnr = vim.eval('bufnr("")')
    bufnum, lnum, col, off = vim.eval('getpos(".")')

    vim.command('silent buffer ' + str(buffer.number))
    vim.command(command)

    vim.command('silent buffer ' + current_bufnr)
    vim.eval('setpos(".", [%s, %s, %s, %s])' % (bufnum, lnum, col, off))


def make_modifiable(buffer, func):
    def do(*args, **keywords):
        lazyredraw_save = vim.eval('&lazyredraw')
        do_buffer_command(buffer, 'silent setlocal modifiable')
        func(*args, **keywords)
        do_buffer_command(buffer, 'silent setlocal nomodifiable')
        vim.command('let &lazyredraw = ' + lazyredraw_save)
    return do


class LingrVim(object):
    def __init__(self, user, password, messages_bufnr, members_bufnr, rooms_bufnr):
        self.lingr = lingr.Connection(user, password, logger = lingr._get_debug_logger())
        # self.lingr = lingr.Connection(user, password)

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

        # for display messages
        self.current_room_id = ""
        self.last_speaker_id = ""
        self.messages = {} # {"room1": [message1, message2], "room2": [message1 ...

    def __del__(self):
        print "__del__ start"
        self.lingr.destroy_session()
        self.observe.join()
        print "__del__ end"

    def setup(self):
        def connected_hook(sender):
            # get messages
            for id, room in sender.rooms.iteritems():
                self.messages[id] = []
                for m in room.backlog:
                    self.messages[id].append(m)

            self.current_room_id = sender.rooms.keys()[0]
            self.render_all()

        def error_hook(sender, error):
            print "Lingr error: " + str(error)

        def message_hook(sender, room, message):
            self.messages[room.id].append(message)
            if self.current_room_id == room.id:
                self._show_message(message)
                do_buffer_command(self.messages_buffer, 'silent normal! G')

        def join_hook(sender, room, member):
            if self.current_room_id == room.id:
                self.messages_buffer.append(\
                    "-- " + member.name.encode('utf-8') + " is now online")
                self.render_members()

        def leave_hook(sender, room, member):
            if self.current_room_id == room.id:
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

    def select_room_by_lnum(self, lnum):
        rooms = self.lingr.rooms.keys()
        if lnum <= len(rooms):
            self.select_room(rooms[lnum - 1])

    def select_room(self, room_id):
        rooms = self.lingr.rooms.keys()
        if room_id in rooms and self.current_room_id != room_id:
            self.current_room_id = room_id
            self.render_all()

    def get_archives(self):
        messages = self.messages[self.current_room_id]
        res = self.lingr.get_archives(\
            self.current_room_id, messages[0].id)

        archives = []
        for m in res["messages"]:
            archives.append(lingr.Message(m))
        archives.append(self._dummy_message())

        self.messages[self.current_room_id] = archives + messages
        self.render_messages()

    def say(self, text):
        if self.current_room_id:
            self.lingr.say(self.current_room_id, text)

    def render_all(self):
        self.render_messages()
        self.render_rooms()
        self.render_members()

    def _render_messages(self):
        del self.messages_buffer[:]
        self.messages_buffer[0] = "[Read more from archives...]"
        self.last_speaker_id = ""
        for m in self.messages[self.current_room_id]:
            self._show_message(m)

    def _render_rooms(self):
        del self.rooms_buffer[:]

        is_first = True
        for id, room in self.lingr.rooms.iteritems():
            mark = " *" if id == self.current_room_id else ""
            text = room.name.encode('utf-8') + mark
            if is_first:
                self.rooms_buffer[0] = text
                is_first = False
            else:
                self.rooms_buffer.append(text)

    def _render_members(self):
        del self.members_buffer[:]

        members = self.lingr.rooms[self.current_room_id].members.values()
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

    def _show_message(self, message):
        if self.last_speaker_id != message.speaker_id:
            speaker = message.nickname.encode('utf-8')\
                + ' (' + time.asctime(message.timestamp) + '):'
            self.messages_buffer.append(speaker)
            self.last_speaker_id = message.speaker_id

        # vim.buffer.append() cannot receive newlines
        for text in message.text.split("\n"):
            self.messages_buffer.append(' ' + text.encode('utf-8'))

    def _dummy_message(self):
        return lingr.Message({\
            'id': '-1',\
            'type': 'dummy',\
            'nickname': '-----',\
            'speaker_id': '-1',\
            'public_session_id': '-1',\
            'text': '-----',\
            'timestamp': '0'\
            }) # TODO: use time to get archives

