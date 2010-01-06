# vim:set fileencoding=utf-8:

import vim
import lingr
import threading
import time
import logging

class LingrObserver(threading.Thread):
    def __init__(self, lingr):
        super(LingrObserver, self).__init__()
        self.lingr = lingr

    def run(self):
        self.lingr.start()


def make_modifiable(buffer, func):
    def do(*args, **keywords):
        vim.command("call setbufvar({0.number}, '&modifiable', 1)".format(buffer))
        func(*args, **keywords)
        vim.command("call setbufvar({0.number}, '&modifiable', 0)".format(buffer))
    return do


class LingrVim(object):
    JOIN_MESSAGE = "-- {0} is now online"
    LEAVE_MESSAGE = "-- {0} is now offline"
    GET_ARCHIVES_MESSAGE = "[Read more from archives...]"
    MESSAGE_HEADER = "{0} ({1}):"
    ARCHIVES_DELIMITER = "--------------------"
    MEMBERS_STATUSLINE = "lingr-members ({0}/{1})"
    MESSAGES_STATUSLINE = "lingr-messages ({0})"

    def __init__(self, user, password, messages_bufnr, members_bufnr, rooms_bufnr):
        # self.lingr = lingr.Connection(user, password, False, logger=lingr._get_debug_logger())
        self.lingr = lingr.Connection(user, password, False)

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
        self.lingr.destroy_session()
        self.observe.join()

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

        def join_hook(sender, room, member):
            if self.current_room_id == room.id:
                self.messages_buffer.append(\
                    LingrVim.JOIN_MESSAGE.format(member.name.encode('utf-8')))
                self.render_members()

        def leave_hook(sender, room, member):
            if self.current_room_id == room.id:
                self.messages_buffer.append(\
                    LingrVim.LEAVE_MESSAGE.format(member.name.encode('utf-8')))
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

    def get_room_id_by_lnum(self, lnum):
        return self.lingr.rooms.keys()[lnum - 1]

    def select_room_by_lnum(self, lnum):
        self.select_room(self.get_room_id_by_lnum(lnum))

    def select_room_by_offset(self, offset):
        rooms = self.lingr.rooms.keys()
        next = (rooms.index(self.current_room_id) + offset) % len(rooms)
        self.select_room(rooms[next])

    def select_room(self, room_id):
        rooms = self.lingr.rooms.keys()
        if room_id in rooms and self.current_room_id != room_id:
            self.current_room_id = room_id
            self.render_all()

    def get_member_id_by_lnum(self, lnum):
        members = self.lingr.rooms[self.current_room_id].members.values()
        name = self.members_buffer[lnum - 1][:-2]

        return [x for x in members if x.name == name][0].username

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

        self.messages_buffer[0] = LingrVim.GET_ARCHIVES_MESSAGE
        self.last_speaker_id = ""
        for m in self.messages[self.current_room_id]:
            self._show_message(m)

        room_name = self.lingr.rooms[self.current_room_id].name.encode('utf-8')
        statusline = LingrVim.MESSAGES_STATUSLINE.format(room_name)
        vim.command("call setbufvar({0.number}, '&statusline', '{1}')".format(\
            self.messages_buffer, statusline))


    def _render_rooms(self):
        del self.rooms_buffer[:]

        for id, room in self.lingr.rooms.iteritems():
            mark = " *" if id == self.current_room_id else ""
            text = room.name.encode('utf-8') + mark
            self.rooms_buffer.append(text)

        del self.rooms_buffer[0]

    def _render_members(self):
        del self.members_buffer[:]

        members = self.lingr.rooms[self.current_room_id].members.values()
        onlines = filter(lambda x: x.presence, members)
        offlines = filter(lambda x: not x.presence, members)

        for m in onlines:
            owner = '(owner)' if m.owner else ''
            text = m.name.encode('utf-8') + owner + " +"
            self.members_buffer.append(text)

        for m in offlines:
            owner = '(owner)' if m.owner else ''
            text = m.name.encode('utf-8') + owner + " -"
            self.members_buffer.append(text)

        del self.members_buffer[0]

        statusline = LingrVim.MEMBERS_STATUSLINE.format(len(onlines), len(members))
        vim.command("call setbufvar({0.number}, '&statusline', '{1}')".format(\
            self.members_buffer, statusline))

    def _show_message(self, message):
        if message.type == "dummy":
            self.last_speaker_id = ""
            self.messages_buffer.append(LingrVim.ARCHIVES_DELIMITER)
        else:
            if self.last_speaker_id != message.speaker_id:
                text = LingrVim.MESSAGE_HEADER.format(\
                    message.nickname.encode('utf-8'), time.asctime(message.timestamp))
                self.messages_buffer.append(text)
                self.last_speaker_id = message.speaker_id

            # vim.buffer.append() cannot receive newlines
            for text in message.text.split("\n"):
                self.messages_buffer.append(' ' + text.encode('utf-8'))

    def _dummy_message(self):
        return lingr.Message({
            'id': '-1',
            'type': 'dummy',
            'nickname': '-',
            'speaker_id': '-1',
            'public_session_id': '-1',
            'text': '-',
            'timestamp': time.strftime(lingr.Message.TIMESTAMP_FORMAT, time.gmtime())
            })
