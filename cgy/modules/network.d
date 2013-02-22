module modules.network;

import modules.module_;

import std.socket;
import util.socket : readLine, tcpSendDir;
import util.util;

enum max_clients = 13;

enum PORT = 1337;
immutable HANDSHAKE_A = "CoolGameYo?\n";
immutable HANDSHAKE_B = "CoolGameYo!!!\n";
immutable HANDSHAKE_C = "Oh yeah!\n";

mixin template ServerModule() {

    static struct Client {
        Socket socket;
        ubyte[] recv;
        size_t send_index;
        size_t recv_index;
        bool disconnected;
    }

    SocketSet recv_set, write_set;
    Socket listener;

    Client[] clients;
    ubyte[] toWrite;

    ChangeList client_changes;

     void initServerModule() {
        listener = new TcpSocket;
        listener.bind(new InternetAddress(PORT));
        listener.listen(10);

        recv_set = new SocketSet(max_clients + 1);
        write_set = new SocketSet(max_clients);
        toWrite.length = 4;
    }

    bool handshake(Socket sock) { // Awesome handshake :P
        if(sock.send(HANDSHAKE_A) != HANDSHAKE_A.length) {
            sock.close();
            return false;
        }
        if(readLine(sock) != HANDSHAKE_B[0..$-1]) {
            sock.close();
            return false;
        }
        return sock.send(HANDSHAKE_C) == HANDSHAKE_C.length;
    }
  
    void sendEverything(Socket sock) {
        spawnThread({
            while(scheduler.shouldSerialize) {
            }
            msg("Starting send all things ever thread");
            sock.send("Sending all things ever to client\n");
            tcpSendDir(sock, g_worldPath);
            sock.send("All things sent to client\n");

            sendingSaveGame--;
            clients ~= Client(sock, [], 0, 0);
        });
    }

    int sendingSaveGame;

    private void accept_new_client() {
        auto newsock = listener.accept();
        if (clients.length < max_clients) {
            if(!handshake(newsock)) {
                msg("Client failed handshake :(");
            }
            if(!sendingSaveGame) {
                scheduler.saveGame();
            }
            sendingSaveGame++;
            sendEverything(newsock); //Spawn new thread to send stuff in the background aye?
        } else {
            msg("Too many clients!");
            newsock.close();
        }
    }




    // todo:
    // figure out sizes of buffers

    void doNetworkStuffUntil(long nextSync) {
        finalizeNetworkChangePush();
        recv_set.reset();
        foreach(ref client ; clients) {
            client.send_index = 0;
            client.recv_index = 0;
            recv_set.add(client.socket);
        }

        //When leave this all is sent/received.... ?
        int max_n = 1;
        while (true) {
            
            scope (exit) {
                recv_set.reset();
                write_set.reset();
            }

            recv_set.add(listener);
            foreach (ref client; clients) {
                if(client.disconnected) continue;
                if (client.send_index < toWrite.length) {
                    write_set.add(client.socket);
                    max_n += 1;
                }
                if (client.recv_index < client.recv.length) {
                    max_n += 1;
                }
            }

            //Hum.
            // WHAT IF we dont know we should receieveveve anything yet but dont have anything to send? D:
            // Solved by maxn = 1 on first run herp derp
            //nooeesss it wont get added to the set D:
            //Solved by them reads always being part of the set
            if (max_n == 0) {
                break; // nothing left to send/recv
            }
            max_n = 0;

            int n = Socket.select(recv_set, write_set, null, 0);

            foreach (ref client; clients) {
                auto socket = client.socket;
                if (recv_set.isSet(socket)) {
                    int read;
                    if(client.recv_index == 0) {
                        int sizeToRead;
                        void[] buff = (cast(void*)&sizeToRead)[0..4];
                        read = socket.receive(buff);
                        if(read != 4) {
                            msg("some network error, disconnecting");
                            client.disconnected = true;
                            continue;
                        }
                        client.recv.length = sizeToRead;
                        //assumeSafeAppend ?
                    } else {
                        read = socket.receive(
                                client.recv[client.recv_index .. $]);
                        if(read < 1) {
                            msg("some network error, disconnecting");
                            client.disconnected = true;
                            continue;
                        }

                        client.recv_index += read;
                    }
                }
                if (write_set.isSet(socket)) {
                    int sent = socket.send(
                            toWrite[client.send_index .. $]);
                    if(sent < 1) {
                        msg("some network error, disconnecting");
                        client.disconnected = true;
                        continue;
                    }

                    client.send_index += sent;
                }
            }

            if (recv_set.isSet(listener)) {
                accept_new_client();
            }
        }

        clients = remove!q{a.disconnected}(clients);

        //Changed into use of variable; have encountered race condition in previous project
        // where the time went into the next frame after the while-check, overflowing the
        // value sent to select / sleep, producing a very long wait.
        auto timeLeft = nextSync - utime();
        while (timeLeft > 0) {
            scope (exit) {
                recv_set.reset();
            }
            recv_set.add(listener);

            int n = Socket.select(recv_set, null, null, timeLeft);
            if (n == 0) {
                break; // this is timeout, means we go on until next tick
            }
            assert (recv_set.isSet(listener));

            accept_new_client();
            timeLeft = nextSync - utime();
        }
        toWrite.length = 4;
        assumeSafeAppend(toWrite);
    }

    void getNetworkChanges(ref ChangeList list) {
        foreach (client; clients) {
            list.readFrom(client.recv);
        }
    }

    void pushNetworkChanges(ChangeList list) {
        //toWrite.length += list.changeListData.length;
        //toWrite[4 .. $] = list.changeListData[];
        toWrite ~= list.changeListData[];
    }

    void finalizeNetworkChangePush() {
        uint total_size = toWrite.length - 4;
        toWrite[0..4] = *cast(ubyte[4]*)&total_size;
    }

}


mixin template ClientModule() {

    SocketSet recv_set, write_set;
    Socket socket;
    ubyte[] recv;
    ubyte[] toWrite;
    size_t send_index;
    size_t recv_index;


    ChangeList client_changes;

    void initClientModule(string host) {
        auto a = new std.socket.InternetAddress(host, PORT);
        socket = new std.socket.TcpSocket(a);
        recv_set = new SocketSet(1);
        write_set = new SocketSet(1);
        import util.socket;

        enforce(readLine(socket) == HANDSHAKE_A[0..$-1], "Handshake A failed");
        enforce(socket.send(HANDSHAKE_B) == HANDSHAKE_B.length, "Handshake B failed");
        enforce(readLine(socket) == HANDSHAKE_C[0..$-1], "Handshake C failed");

        //Prepare to receiveive all the game data everrrrr!

        msg(readLine(socket));
        tcpReceiveDir(socket, g_worldPath);
        msg(readLine(socket));



    }

}
