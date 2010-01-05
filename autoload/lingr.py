# vim:set fileencoding=utf-8:

# This code is based on lingr.rb at below URL
# http://github.com/psychs/lingr-irc/blob/master/lingr.rb

import urllib
import httplib
import time
import json
import logging

class Member(object):
    def __init__(self, res):
        self.username = res["username"]
        self.name = res["name"]
        self.icon_url = res["icon_url"]
        self.owner = res["owner"]
        self.presence = res["presence"] == "online"

    def __repr__(self):
        return "<{0}.{1} {2.username} {3}>".format(\
            __name__, self.__class__.__name__, self, self.name.encode('utf-8'))


class Room(object):
    def __init__(self, res):
        self.id = res["id"]
        self.name = res["name"]
        self.blurb = res["blurb"]
        self.public = res["public"]
        self.backlog = []
        self.members = {}

        if "messages" in res:
            for m in res["messages"]:
                self.backlog.append(Message(m))

        if "roster" in res:
            if "members" in res["roster"]:
                for u in res["roster"]["members"]:
                    m = Member(u)
                    self.members[m.username] = m

    def add_member(self, member):
        self.members[member.username] = member

    def __repr__(self):
        return "<{0}.{1} {2.id}>".format(__name__, self.__class__.__name__, self)


class Message(object):
    TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

    def __init__(self, res):
        self.id = res["id"]
        self.type = res["type"]
        self.nickname = res["nickname"]
        self.speaker_id = res["speaker_id"]
        self.public_session_id = res["public_session_id"]
        self.text = res["text"]

        t = time.strptime(res["timestamp"], Message.TIMESTAMP_FORMAT)
        self.timestamp = time.localtime(time.mktime(t) - time.timezone)

        self.mine = False

    def decide_mine(self, my_public_session_id):
        mine = self.public_session_id == my_public_session_id

    def __repr__(self):
        return "<{0}.{1} {2.speaker_id}: {3}>".format(\
            __name__, self.__class__.__name__, self, self.text.encode('utf-8'))


class APIError(Exception):
    def __init__(self, res):
        self.code = res["code"]
        self.detail = res["detail"]

    def __repr__(self):
        return "<{0}.{1} code='{2.code}' detail='{2.detail}'>".format(
            __name__, self.__class__.__name__, self)


class Connection(object):
    DOMAIN = "lingr.com"
    DOMAIN_OBSERVE = "lingr.com:8080"
    API_PATH = "/api/"
    HEADERS = {"Content-type": "application/x-www-form-urlencoded"}

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
        self.room_ids = []
        self.connection = None

    def __del__(self):
        pass

    def start(self):
        try:
            self.create_session()
            self.get_rooms()
            self.show_room(",".join(self.room_ids))
            self.subscribe(",".join(self.room_ids))

            for h in self.connected_hooks:
                h(self)

            while(True):
                self.observe()

        except APIError as e:
            if e.code == "invalid_user_credentials":
                raise e
            self._on_error(e)
            if self.auto_reconnect:
                pass # TODO: retry

        except (http.HTTPException, ValueError) as e:
        # ValueError can be raised by json.loads
            self._on_error(e)
            if self.auto_reconnect:
                pass # TODO: retry

    def create_session(self):
        self._debug("requesting session/create: " + self.user)
        res = self._post("session/create", {"user": self.user, "password": self.password})
        self._debug("session/create response: " + str(res))

        self.session = res["session"]
        self.nickname = res["nickname"]
        self.public_id = res["public_id"]
        self.presence = res["presence"]
        if "user" in res:
            user = res["user"]
            self.name = user["name"]
            self.username = user["username"]
        self.rooms = {}
        return res

    def destroy_session(self):
        try:
            if self.connection:
                self.connection.close()
                self.connection = None

            self._debug("requesting session/destroy")
            res = self._post("session/destroy", {"session": self.session})
            self._debug("session/destroy response: " + str(res))

            self.session = None
            self.nickname = None
            self.public_id = None
            self.presence = None
            self.name = None
            self.username = None
            self.rooms = {}
            return res
        except Exception as e:
            self._log_error(str(e))

    def set_presence(self, presence):
        self._debug("requesting session/set_presence: " + presence)
        res = self._post("session/set_presence",\
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
        res = self._get("room/get_archives",\
            {"session": self.session, "room": room_id, "before": max_message_id, "limit": limit})
        self._debug("room/get_archives response: " + str(res))
        return res

    def subscribe(self, room_id, reset = True):
        self._debug("requesting room/subscribe: " + room_id)
        res = self._post("room/subscribe",\
            {"session": self.session, "room": room_id, "reset": str(reset).lower()})
        self._debug("room/subscribe response: " + str(res))
        self.counter = res["counter"]
        return res

    def unsubscribe(self, room_id):
        self._debug("requesting room/unsubscribe: " + room_id)
        res = self._post("room/unsubscribe", {"session": self.session, "room": room_id})
        self._debug("room/unsubscribe response: " + str(res))
        return res

    def say(self, room_id, text):
        res = self._post("room/say",\
            {"session": self.session, "room": room_id, "nickname": self.nickname, "text": text})
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
                        status = d["status"] if "status" in d else None
                        if status == "online":
                            if username in room.members:
                                m = room.members[username]
                                m.presence = True
                                for h in self.join_hooks:
                                    h(self, room, m)

                        elif status == "offline":
                            if username in room.members:
                                m = room.members[username]
                                m.presence = False
                                for h in self.leave_hooks:
                                    h(self, room, m)


    def _on_error(self, e):
        self._log_error("error: " + str(e))
        if self.session:
            self.destroy_session()
        for h in self.error_hooks:
            h(self, e)
        if self.auto_reconnect:
            time.sleep(Connection.RETRY_INTERVAL)

    def _get(self, path, params = None):
        is_observe = path == "event/observe"
        domain = Connection.DOMAIN_OBSERVE if is_observe else Connection.DOMAIN
        url = Connection.API_PATH + path
        if params:
            url += '?' + urllib.urlencode(params)

        connection = httplib.HTTPConnection(domain, timeout=Connection.REQUEST_TIMEOUT)
        if is_observe:
            self.connection = connection
        try:
            connection.request("GET", url, headers=Connection.HEADERS)
            res = json.loads(connection.getresponse().read())
        except httplib.HTTPException as e:
            if is_observe:
                res = { "status" : "ok" }
            else:
                raise e

        connection.close()
        if is_observe:
            self.connection = None

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
        except httplib.HTTPException as e:
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


def _get_debug_logger():
    logger = logging.getLogger("lingr.py")
    logger.setLevel(logging.DEBUG)

    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    formatter = logging.Formatter("%(asctime)s-%(name)s-%(levelname)s-%(message)s")

    ch.setFormatter(formatter)
    logger.addHandler(ch)

    return logger
