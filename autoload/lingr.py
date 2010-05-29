# coding=utf-8
# Lingr-Vim: Lingr client for Vim
# Version:     0.5.2
# Last Change: 29 May 2010
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

# This code is based on lingr.rb at below URL
# http://github.com/psychs/lingr-irc/blob/master/lingr.rb

import httplib
import socket
import urllib
import time
import logging
import json
import os

class Member(object):
    def __init__(self, res):
        self.username = res["username"]
        self.name = res["name"]
        self.icon_url = res["icon_url"]
        self.timestamp = res["timestamp"]
        self.owner = res["owner"]
        self.presence = res["is_online"]
        self.pokeable = res["pokeable"]

    def __repr__(self):
        return "<{0}.{1} {2.username} {3}>".format(
            __name__, self.__class__.__name__, self, self.name.encode('utf-8'))


class Bots(object):
    def __init__(self, res):
        self.id = res["id"]
        self.name = res["name"]
        self.icon_url = res["icon_url"]
        self.status = res["status"]

    def __repr__(self):
        return "<{0}.{1} {2.name}>".format(
            __name__, self.__class__.__name__, self)


class Room(object):
    def __init__(self, res):
        self.id = res["id"]
        self.name = res["name"]
        self.blurb = res["blurb"]
        self.public = res["is_public"]
        self.backlog = []
        self.members = []
        self.bots = []

        if "messages" in res:
            for m in res["messages"]:
                self.backlog.append(Message(m))

        if "roster" in res:
            if "members" in res["roster"]:
                for m in res["roster"]["members"]:
                    self.members.append(Member(m))
            if "bots" in res["roster"]:
                for b in res["roster"]["bots"]:
                    self.bots.append(Bots(b))

    def add_member(self, member):
        self.members.append(member)

    def find_member_by_username(self, username):
        m = [m for m in self.members if m.username == username]
        return m[0] if len(m) > 0 else None

    def __repr__(self):
        return "<{0}.{1} {2.id}>".format(__name__, self.__class__.__name__, self)


class Message(object):
    TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

    def __init__(self, res):
        self.id = res["id"]
        self.local_id = res["local_id"]
        self.public_session_id = res["public_session_id"]
        self.room = res["room"]
        self.type = res["type"]
        self.nickname = res["nickname"]
        self.speaker_id = res["speaker_id"]
        self.icon_url = res["icon_url"]
        self.text = res["text"]

        # TODO: use GMT?
        t = time.strptime(res["timestamp"], Message.TIMESTAMP_FORMAT)
        self.timestamp = time.localtime(time.mktime(t) - time.timezone)

        self.mine = False

    def decide_mine(self, my_public_session_id):
        self.mine = self.public_session_id == my_public_session_id

    def __repr__(self):
        return "<{0}.{1} {2.speaker_id}: {3}>".format(
            __name__, self.__class__.__name__, self, self.text.encode('utf-8'))


class APIError(Exception):
    def __init__(self, res):
        self.code = res["code"]
        self.detail = res["detail"]

    def __repr__(self):
        return "<{0}.{1} code='{2.code}' detail='{2.detail}'>".format(
            __name__, self.__class__.__name__, self)

    def __str__(self):
        return "[{0}.{1} {2.code}] {2.detail}".format(
            __name__, self.__class__.__name__, self)


class Connection(object):
    SESSION_FILE = os.path.expanduser('~/.lingr_session')
    DOMAIN = "lingr.com"
    DOMAIN_OBSERVE = "lingr.com:8080"
    API_PATH = "/api/"
    HEADERS = {"Content-type": "application/x-www-form-urlencoded",
               "User-agent": "Lingr-Vim(http://github.com/tsukkee/lingr-vim)"}

    REQUEST_TIMEOUT = 100 # sec
    RETRY_INTERVAL = 60 # sec

    def __init__(self, user, password, auto_reconnect = True, logger = None):
        self.user = user
        self.password = password
        self.auto_reconnect = auto_reconnect
        self.logger = logger

        self.connected_hooks = []
        self.error_hooks = []
        self.message_hooks = []
        self.join_hooks = []
        self.leave_hooks = []

        self.session = None
        self.counter = None
        self.room_ids = []
        self.rooms = {}

        self.is_alive = False

    def start(self):
        while True:
            try:
                self.start_session()
                self.get_rooms()
                self.show_room(",".join(self.room_ids))
                self.subscribe(",".join(self.room_ids))

                for h in self.connected_hooks:
                    h(self)

                self.is_alive = True
                while(self.is_alive):
                    self.observe()

            except APIError as e:
                if e.code == "invalid_user_credentials":
                    raise e
                self._on_error(e)
                if self.auto_reconnect and self.is_alive:
                    continue # retry
                else:
                    break # finish

            except (socket.error, httplib.HTTPException, ValueError) as e:
            # ValueError can be raised by json.loads
                self._on_error(e)
                if self.auto_reconnect and self.is_alive:
                    continue # retry
                else:
                    break # finish

            else:
                break # finish

    def destroy(self):
        self.is_alive = False
        # self.destroy_session()

    def start_session(self):
        if os.path.exists(Connection.SESSION_FILE):
            session_id = open(Connection.SESSION_FILE, 'r').readline().strip()

            try:
                res = self.verify_session(session_id)
            except APIError as e:
                if e.code == 'invalid_session':
                    self.create_session()
                else:
                    raise e
        else:
            self.create_session()

    def create_session(self):
        self._debug("requesting session/create: " + self.user)
        res = self._post("session/create", {"user": self.user, "password": self.password})
        self._debug("session/create response: " + str(res))

        return self._init_session(res)

    def verify_session(self, session_id):
        self._debug("requesting session/verify: " + session_id)
        res = self._get("session/verify", {"session": session_id})
        self._debug("verify session/response: " + str(res))

        return self._init_session(res)

    def _init_session(self, res):
        self.session = res["session"]
        self.nickname = res["nickname"]
        self.public_id = res["public_id"]
        self.presence = res["is_online"]
        if "user" in res:
            user = res["user"]
            self.name = user["name"]
            self.username = user["username"]

        session_file = open(Connection.SESSION_FILE, 'w')
        session_file.write(self.session)
        session_file.close()

        return res

    def destroy_session(self):
        try:
            self._debug("requesting session/destroy: " + self.session)
            res = self._post("session/destroy", {"session": self.session})
            self._debug("session/destroy response: " + str(res))
            return res

        except Exception as e:
            self._log_error(repr(e))

        finally:
            self.session = None
            self.nickname = None
            self.public_id = None
            self.presence = None
            self.name = None
            self.username = None
            self.rooms = {}

    def set_presence(self, presence):
        self._debug("requesting session/set_presence: " + presence)
        res = self._post("session/set_presence",
            {"session": self.session, "presence": presence, "nickname": self.nickname})
        self._debug("session/set_presence response: " + str(res))
        return res

    def get_rooms(self):
        self._debug("requesting user/get_rooms")
        res = self._get("user/get_rooms", {"session": self.session})
        self._debug("user/get_rooms response: " + str(res))
        self.room_ids = res["rooms"]
        return res

    def show_room(self, room_id):
        self._debug("requesting room/show: " + room_id)
        res = self._get("room/show", {"session": self.session, "room": room_id})
        self._debug("room/show response: " + str(res))

        if "rooms" in res:
            for d in res["rooms"]:
                r = Room(d)
                for m in r.backlog:
                    m.decide_mine(self.public_id)
                self.rooms[r.id] = r

        return res

    def get_archives(self, room_id, max_message_id, limit = 100):
        self._debug("requesting room/get_archives: " + room_id + " " + str(max_message_id))
        res = self._get("room/get_archives",
            {"session": self.session, "room": room_id, "before": max_message_id, "limit": limit})
        self._debug("room/get_archives response: " + str(res))
        return res

    def subscribe(self, room_id, reset = True):
        self._debug("requesting room/subscribe: " + room_id)
        res = self._post("room/subscribe",
            {"session": self.session, "room": room_id, "reset": str(reset).lower()})
        self._debug("room/subscribe response: " + str(res))
        if not self.counter:
            self.counter = res["counter"]
        return res

    def unsubscribe(self, room_id):
        self._debug("requesting room/unsubscribe: " + room_id)
        res = self._post("room/unsubscribe", {"session": self.session, "room": room_id})
        self._debug("room/unsubscribe response: " + str(res))
        return res

    def say(self, room_id, text):
        self._debug("requesting room/say: " + room_id + " " + text)
        res = self._post("room/say",
            {"session": self.session, "room": room_id, "nickname": self.nickname, "text": text.encode('utf-8')})
        self._debug("room/say response: " + str(res))
        return res

    def observe(self):
        self._debug("requesting event/observe: " + str(self.counter))
        res = self._get("event/observe", {"session": self.session, "counter": self.counter})
        self._debug("event/observe response: " + str(res))

        if "counter" in res:
            self.counter = res["counter"]

        if "events" in res:
            for event in res["events"]:
                if "message" in event:
                    d = event["message"]
                    if d["room"] in self.rooms:
                        room = self.rooms[d["room"]]
                        m = Message(d)
                        m.decide_mine(self.public_id)
                        for h in self.message_hooks:
                            h(self, room, m)

                elif "presence" in event:
                    d = event["presence"]
                    if d["room"] in self.rooms:
                        room = self.rooms[d["room"]]
                        username = d["username"]
                        member = room.find_member_by_username(username)
                        if not member:
                            return # can't find member

                        status = d["status"] if "status" in d else None
                        if status == "online":
                            member.presence = True
                            for h in self.join_hooks:
                                h(self, room, member)

                        elif status == "offline":
                            member.presence = False
                            for h in self.leave_hooks:
                                h(self, room, member)

    def _on_error(self, e):
        self._log_error(repr(e))

        for h in self.error_hooks:
            h(self, e)

        if self.auto_reconnect and self.is_alive:
            time.sleep(Connection.RETRY_INTERVAL)

    def _get(self, path, params = None):
        is_observe = path == "event/observe"
        domain = Connection.DOMAIN_OBSERVE if is_observe else Connection.DOMAIN
        url = Connection.API_PATH + path
        if params:
            url += '?' + urllib.urlencode(params)

        connection = httplib.HTTPConnection(domain, timeout=Connection.REQUEST_TIMEOUT)
        try:
            connection.request("GET", url, headers=Connection.HEADERS)
            res = json.loads(connection.getresponse().read())
        except socket.timeout as e:
            self._debug("get request timed out: " + url)
            if is_observe:
                res = { "status" : "ok" }
            else:
                raise e

        connection.close()

        if res["status"] == "ok":
            return res
        else:
            raise APIError(res)

    def _post(self, path, params = None):
        url = Connection.API_PATH + path
        params = urllib.urlencode(params) if params else ""

        connection = httplib.HTTPConnection(Connection.DOMAIN, timeout=Connection.REQUEST_TIMEOUT)
        try:
            connection.request("POST", url, params, Connection.HEADERS)
            res = json.loads(connection.getresponse().read())
        except socket.timeout as e:
            self._debug("post request timed out: " + url)
            raise e

        connection.close()

        if res["status"] == "ok":
            return res
        else:
            raise APIError(res)

    def _debug(self, text):
        if self.logger:
            self.logger.debug(text)

    def _log(self, text):
        if self.logger:
            self.logger.info(text)

    def _log_error(self, text):
        if self.logger:
            self.logger.error(text)


def _get_debug_logger(log_file = ""):
    if not hasattr(_get_debug_logger, 'count'):
        _get_debug_logger.count = -1
    _get_debug_logger.count += 1
    logger = logging.getLogger("lingr.py-" + str(_get_debug_logger.count))

    logger.setLevel(logging.DEBUG)

    if log_file:
        ch = logging.FileHandler(log_file, "a")
    else:
        ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    formatter = logging.Formatter("%(asctime)s-%(name)s-%(levelname)s-%(message)s")

    ch.setFormatter(formatter)
    logger.addHandler(ch)

    return logger
