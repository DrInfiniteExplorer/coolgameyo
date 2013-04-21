module network.common;

import std.ascii : isAlphaNum;
import std.random : unpredictableSeed;
import std.socket;


import log : Log;
import modules.module_;

import util.socket : readLine, tcpSendDir;
import util.util;

enum max_clients = 13;

enum PORT = 1337;
immutable HANDSHAKE_A = "CoolGameYo?\n";
immutable HANDSHAKE_B = "CoolGameYo!!!\n";
immutable HANDSHAKE_C = "Oh yeah! Give me a name!\n";
