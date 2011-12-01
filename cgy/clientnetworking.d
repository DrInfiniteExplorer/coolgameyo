import std.socket;

struct Receiver {
    ubyte[] data_array;
    size_t progress;

    void readFrom(Socket s) {
        assert (progress <= data_array.length);

        size_t diff = data_array.length - progress;

        if (diff < 4 * 1024) {
            data_array.length += 8 * 1024;
        }

        auto read = s.receive(data_array[progress .. $]);
        assert (read, "remote end closed connection (?) NOT AN ERROR REALLY");
        assert (read > 0, " SOME NOT GOOD THING HAPPENED?!");

        progress += read;
    }

    ubyte[] getValidData() {
        return data_array[0 .. progress];
    }
    void eatData(size_t amount) {
        assert (amount <= progress);
        foreach (i; 0 .. progress - amount) { // MEMMMOVE? :D
            data_array[i] = data_array[i+amount];
        }
        progress -= amount;
    }
}

struct Writer {
    void writeTo(Socket s) {
        // derp derp I do nothing
    }
}


mixin template NetworkCode() {
    std.socket.TcpSocket socket;

    std.socket.SocketSet readSet;
    std.socket.SocketSet writeSet;
    std.socket.SocketSet errorSet;

    Receiver receiver;
    Writer writer;

    //ChangeList

    void connect(string addr, ushort port) {
        auto a = new std.socket.InternetAddress(addr, port);
        socket = new std.socket.TcpSocket(a);
    }

    void updateNetwork(ulong us) {
        if (socket is null) return;

        readSet.add(socket);
        writeSet.add(socket);
        errorSet.add(socket);

        int res = std.socket.Socket.select(readSet, writeSet, errorSet, to!int(us));

        if (res < 0) {
            assert (0, "Interruption, I dont know what this means....:D");
        } else if (res == 0) {
            return;
        } else {
            assert (res > 0);

            if (errorSet.isSet(socket)) {
                assert (0, text("socket says error code ", 
                            socket.ERROR, " :("));
            }
            if (readSet.isSet(socket)) {
                receiver.readFrom(socket);
            }
            if (writeSet.isSet(socket)) {
                writer.writeTo(socket);
            }
        }

        writeln(cast(string)receiver.getValidData());
    }
}
