# vim:set fileencoding=utf-8:
# Lingr-Vim: Lingr client for Vim
# Version:     0.0.1
# Last Change: 2010 Jan 21
# Author:      tsukkee <takayuki0510+lingr_vim at gmail.com>
# Licence:     The MIT License {{{
#     Permission is hereby granted, free of charge, to any person obtaining a copy
#     of this software and associated documentation files (the "Software"), to deal
#     in the Software without restriction, including without limitation the rights
#     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#     copies of the Software, and to permit persons to whom the Software is
#     furnished to do so, subject to the following conditions:
#
#     The above copyright notice and this permission notice shall be included in
#     all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#     THE SOFTWARE.
#
#     日本語参考訳
#     http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license
# }}}

import vim
import lingr
import threading
import time
import logging

VIM_ENCODING = vim.eval('&encoding')

class LingrObserver(threading.Thread):
    def __init__(self, lingr):
        super(LingrObserver, self).__init__()
        self.lingr = lingr

    def run(self):
        try:
            self.lingr.start()
        except lingr.APIError as e:
            echo_error(e.detail)


class RenderOperation(object):
    CONNECTED, MESSAGE, PRESENCE, UNREAD = range(4)

    def __init__(self, type, params = {}):
        self.type = type
        self.params = params


def make_modifiable(buffer, func):
    def do(*args, **keywords):
        vim.command("call setbufvar({0.number}, '&modifiable', 1)".format(buffer))
        func(*args, **keywords)
        vim.command("call setbufvar({0.number}, '&modifiable', 0)".format(buffer))
    return do

def echo(message):
    vim.command('echo "{0}"'.format(message))

def echo_message(message):
    vim.command('echomsg "{0}"'.format(message))

def echo_error(message):
    vim.command('echoerr "Lingr-Vim Error: {0}"'.format(message))


class LingrVim(object):
    JOIN_MESSAGE         = "-- {0} is now online"
    LEAVE_MESSAGE        = "-- {0} is now offline"
    GET_ARCHIVES_MESSAGE = "[Read more from archives...]"
    MESSAGE_HEADER       = "{0}({1}):"
    MEMBERS_STATUSLINE   = "lingr-members ({0}/{1})"
    MESSAGES_STATUSLINE  = "lingr-messages ({0})"

    def __init__(self, user, password, messages_bufnr, members_bufnr, rooms_bufnr):
        if int(vim.eval('exists("g:lingr_vim_debug_log_file")')):
            echo_message("Lingr-Vim starts with debug mode")
            self.lingr = lingr.Connection(user, password, False,\
                logger=lingr._get_debug_logger(vim.eval('g:lingr_vim_debug_log_file')))
        else:
            self.lingr = lingr.Connection(user, password, False) # TODO: use auto_reconnect

        # buffers
        # indices of vim.buffers are different from bufnrs
        def find_buffer(bufnr):
            return [b for b in vim.buffers if b.number == bufnr][0]
        self.messages_buffer = find_buffer(messages_bufnr)
        self.members_buffer = find_buffer(members_bufnr)
        self.rooms_buffer = find_buffer(rooms_bufnr)

        # generate render functions
        self.render_messages =\
            make_modifiable(self.messages_buffer, self._render_messages)
        self.render_members =\
            make_modifiable(self.members_buffer, self._render_members)
        self.render_rooms =\
            make_modifiable(self.rooms_buffer, self._render_rooms)
        self.show_message =\
            make_modifiable(self.messages_buffer, self._show_message)
        self.show_presence_message =\
            make_modifiable(self.messages_buffer, self._show_presence_message)

        # for display messages
        self.current_room_id = ""
        self.last_speaker_id = ""
        self.messages = {} # {"room1": [message1, message2], "room2": [message1 ...
        self.unread_counts = {} # {"room1": 2, "room2": 0 ...
        self.focused_buffer = None

        # for threading
        self.render_queue = [] # for RenderOperation
        self.queue_lock = threading.Lock()

    def __del__(self):
        self.destroy()

    def has_initialized(self):
        return self.current_room_id != ""

    def setup(self):
        def connected_hook(sender):
            # get messages
            for id, room in sender.rooms.iteritems():
                self.messages[id] = []
                for m in room.backlog:
                    self.messages[id].append(m)
                self.unread_counts[id] = 0

            self.current_room_id = sender.rooms.keys()[0]

            self.push_operation(RenderOperation(RenderOperation.CONNECTED))
            vim.command('doautocmd CursorHold') # redraw contents

            current_bufnr = int(vim.eval("bufnr('')"))
            if self.messages_buffer.number == current_bufnr\
                or self.members_buffer.number == current_bufnr\
                or self.rooms_buffer.number == current_bufnr:
                self.focused_buffer = vim.eval("bufname('')")

            echo('Lingr-Vim has connected to Lingr')

        def error_hook(sender, error):
            echo_error(repr(error))
            if sender.auto_reconnect:
                echo_message('Lingr-Vim will try re-connect after {0} seconds later'\
                    .format(lingr.Connection.RETRY_INTERVAL))

        def message_hook(sender, room, message):
            self.messages[room.id].append(message)
            if self.current_room_id == room.id:
                self.push_operation(RenderOperation(RenderOperation.MESSAGE,\
                    {"message": message}))
            if not self.focused_buffer or self.current_room_id != room.id:
                self.unread_counts[room.id] += 1
                self.push_operation(RenderOperation(RenderOperation.UNREAD, {}))

        def join_hook(sender, room, member):
            if self.current_room_id == room.id:
                self.push_operation(RenderOperation(RenderOperation.PRESENCE,\
                    {"is_join": True, "member": member}))

        def leave_hook(sender, room, member):
            if self.current_room_id == room.id:
                self.push_operation(RenderOperation(RenderOperation.PRESENCE,\
                    {"is_join": False, "member": member}))

        self.lingr.connected_hooks.append(connected_hook)
        self.lingr.error_hooks.append(error_hook)
        self.lingr.message_hooks.append(message_hook)
        self.lingr.join_hooks.append(join_hook)
        self.lingr.leave_hooks.append(leave_hook)

        LingrObserver(self.lingr).start()

    def destroy(self):
        if self.lingr.is_alive:
            self.lingr.destroy_session()

    def set_focus(self, focused):
        if focused:
            self.focused_buffer = focused
            self.unread_counts[self.current_room_id] = 0
            self.render_rooms()
        else:
            self.focused_buffer = None

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
            self.unread_counts[room_id] = 0
            self.render_all()

    def get_member_id_by_lnum(self, lnum):
        members = self.lingr.rooms[self.current_room_id].members.values()
        name = self.members_buffer[lnum - 1][:-2] # TODO: fix for owner

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
            return self.lingr.say(self.current_room_id, text.decode(VIM_ENCODING))
        else:
            return False

    def unread_count(self):
        def sum(a, b):
            return a + b
        return reduce(sum, self.unread_counts.values())

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

        room_name = self.lingr.rooms[self.current_room_id].name.encode(VIM_ENCODING)
        statusline = LingrVim.MESSAGES_STATUSLINE.format(room_name)
        vim.command("call setbufvar({0.number}, '&statusline', '{1}')".format(\
            self.messages_buffer, statusline))

    def _render_rooms(self):
        del self.rooms_buffer[:]

        for id, room in self.lingr.rooms.iteritems():
            mark = " *" if id == self.current_room_id else ""
            unread = " (" + str(self.unread_counts[id]) + ")"\
                if self.unread_counts[id] > 0 else ""
            text = room.name.encode(VIM_ENCODING) + mark + unread
            self.rooms_buffer.append(text)

        del self.rooms_buffer[0]

    def _render_members(self):
        del self.members_buffer[:]

        members = self.lingr.rooms[self.current_room_id].members.values()
        onlines = filter(lambda x: x.presence, members)
        offlines = filter(lambda x: not x.presence, members)

        for m in onlines:
            owner = '(owner)' if m.owner else ''
            text = m.name.encode(VIM_ENCODING) + owner + " +"
            self.members_buffer.append(text)

        for m in offlines:
            owner = '(owner)' if m.owner else ''
            text = m.name.encode(VIM_ENCODING) + owner + " -"
            self.members_buffer.append(text)

        del self.members_buffer[0]

        statusline = LingrVim.MEMBERS_STATUSLINE.format(len(onlines), len(members))
        vim.command("call setbufvar({0.number}, '&statusline', '{1}')".format(\
            self.members_buffer, statusline))

    def _show_message(self, message):
        if message.type == "dummy":
            self.last_speaker_id = ""
            self.messages_buffer.append(vim.eval('s:ARCHIVES_DELIMITER'))
        else:
            if self.last_speaker_id != message.speaker_id:
                name = message.nickname.encode(VIM_ENCODING)
                mine = "*" if message.speaker_id == self.lingr.username else " "
                t = time.strftime(vim.eval('g:lingr_vim_time_format'), message.timestamp)
                text = LingrVim.MESSAGE_HEADER.format(name + mine, t)
                self.messages_buffer.append(text)
                self.last_speaker_id = message.speaker_id

            # vim.buffer.append() cannot receive newlines
            for text in message.text.split("\n"):
                self.messages_buffer.append(' ' + text.encode(VIM_ENCODING))

    def _show_presence_message(self, is_join, member):
        format = LingrVim.JOIN_MESSAGE if is_join\
            else LingrVim.LEAVE_MESSAGE
        self.messages_buffer.append(\
            format.format(member.name.encode(VIM_ENCODING)))

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

    def push_operation(self, operation):
        self.queue_lock.acquire()
        self.render_queue.append(operation)
        self.queue_lock.release()

    def process_queue(self):
        if len(self.render_queue) == 0:
            return

        self.queue_lock.acquire()
        for op in self.render_queue:
            if op.type == RenderOperation.CONNECTED:
                self.render_all()

            elif op.type == RenderOperation.MESSAGE:
                self.show_message(op.params["message"])
                self._auto_scroll()

            elif op.type == RenderOperation.PRESENCE:
                self.show_presence_message(op.params["is_join"], op.params["member"])
                self.render_members()
                self._auto_scroll()

            elif op.type == RenderOperation.UNREAD:
                self.render_rooms()

        self.render_queue = []
        self.queue_lock.release()

    def _auto_scroll(self):
        if self.focused_buffer == vim.eval('s:MESSAGES_BUFNAME')\
            and int(vim.eval("line('$') - line('.') < g:lingr_vim_remain_height_to_auto_scroll")):
                vim.command('silent $')
