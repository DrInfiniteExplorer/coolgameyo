module util.socket;

import std.socket;


// Very unefficient method to read a line.
string readLine(Socket sock) {
    string ret;
    char _character;
    char[] character = (&_character)[0..1];
    while(sock.receive(character) > 0) {
        if(_character == '\n') {
            return ret;
        }
        ret ~= _character;
    }
    return null;
}
