module modules.network;

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
immutable HANDSHAKE_C = "Oh yeah! Give me name!\n";

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

    bool simpleHandshake(Socket sock) { // Awesome handshake :P
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
  
    void sendEverything(PlayerInformation player) {
        spawnThread({
            try {
                while(scheduler.shouldSerialize) {
                }
                auto sock = player.dataSock;
                scope(exit) {
                    sendingSaveGame--;
                }
                scope(success) {
                    clients ~= Client(sock, [], 0, 0);
                }
                scope(failure) {
                    sock.close();
                }
                Log("Starting send all things ever thread");
                sock.send("Sending all things ever to client\n");
                tcpSendDir(sock, g_worldPath);
                sock.send("All things sent to client\n");
            } catch(Exception e) {
                Log("Error while sending all things ever!:");
                Log(e.msg);
            }
        });
    }

    int sendingSaveGame;

    private void accept_new_client() {
        auto newSock = listener.accept();
        if (clients.length >= max_clients) {
            Log("Too many clients!");
            newSock.send("Too many clients!\n");
            newSock.close();
            return;
        }

        auto remoteAddress = newSock.remoteAddress;
        auto remoteName = remoteAddress.toAddrString;
        Log("Client connection from: ", remoteName);

        simpleHandshake(newSock);
        //client or data socket: after handshake, client sends "comm" or "data".
        auto connectionType = readLine(newSock);
        if(connectionType == "comm") {
            //Open communication socket:
            // aquire user information
            auto userInfo  = readLine(newSock);
            // Validate user information etc
            if(!startsWith(userInfo, "Username:")) {
                Log("Recieved bad user information: ", userInfo);
                newSock.send("Malformed user information: Expected 'Username:[name]\n");
                newSock.close();
                return;
            }
            auto userName = userInfo[9..$];
            if(!all!isAlphaNum(userName)) {
                Log("Recieved bad username: ", userName);
                newSock.send("Expects alphanumeric username.\n");
                newSock.close();
                return;
            }
            //  if already have said user, send "no" and close socket.
            if(userName in players) {
                Log("Player already connected!");
                newSock.send("A player with that name is already connected.\n");
                newSock.close();
                return;
            }
            //  any other error send message etc
            // Suggest random identification number to client
            newSock.send("Ok!\n");
            auto playerInfo = new PlayerInformation;
            playerInfo.name = userName;
            playerInfo.address = remoteName;
            playerInfo.magicNumber = unpredictableSeed;
            players[userName] = playerInfo;
            playerInfo.commSock = newSock;
            int[] magic = (&playerInfo.magicNumber)[0..1];
            newSock.send(magic);
            return;
            // return; wait for new connection to be data socket.
        } else if(connectionType == "data") {
            //open data socket:
            // socket sends previously randomized magic value
            int magic;
            int[] _magic = (&magic)[0..1];
            if(newSock.receive(_magic) != magic.sizeof) {
                Log("Couldn't get magic number from client data connection!");
                newSock.send("No\n");
                newSock.close();
                return;
            }
            // if no matching comm-ip + value send "sorry no u"
            PlayerInformation playerInfo;
            foreach(player ; players) {
                if(player.address == remoteName && player.magicNumber == magic) {
                    playerInfo = player;
                }
            }
            if(!playerInfo) {
                Log("Could not identify connecting player with address '", remoteAddress, "' and magic number: ", magic);
                newSock.send("No\n");
                newSock.close();
                return;
            }
            playerInfo.dataSock = newSock;
            playerInfo.dataSock.send("Ok!\n");
            // start world data transfer thread.
            if(!sendingSaveGame) {
                scheduler.saveGame();
            }
            sendingSaveGame++;
            sendEverything(playerInfo); //Spawn new thread to send stuff in the background aye?
            Log("Player ", playerInfo.name, " from ", playerInfo.address, " successfully connected!");
            return;
        } else {
            newSock.send("Expected 'comm' or 'data' to identify connection type. Goodbye!\n");
            newSock.close();
            return;
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
    Socket commSock;
    Socket dataSock;
    int magicNumber;
    ubyte[] recv;
    ubyte[] toWrite;
    size_t send_index;
    size_t recv_index;


    ChangeList client_changes;

    void simpleHandshake(Socket sock) {
        enforce(readLine(sock) == HANDSHAKE_A[0..$-1], "Handshake A failed");
        enforce(sock.send(HANDSHAKE_B) == HANDSHAKE_B.length, "Handshake B failed");
        enforce(readLine(sock) == HANDSHAKE_C[0..$-1], "Handshake C failed");
    }

    void initClientModule(string host) {
        import util.socket;
        recv_set = new SocketSet(1);
        write_set = new SocketSet(1);

        auto address = new std.socket.InternetAddress(host, PORT);

        commSock = new std.socket.TcpSocket(address);
        simpleHandshake(commSock);
        enforce(commSock.send("comm\n") == 5, "Failed to send connection type for communication socket");
        enforce(commSock.send("Username:" ~ g_playerName ~ "\n") == 10 + g_playerName.length, "Failed to send username");
        auto response = readLine(commSock);
        enforce(response == "Ok!", "Error connecting to server: " ~ response);
        int[] _magic = (&magicNumber)[0..1];
        enforce(commSock.receive(_magic) == 4, "Error recieving magic identification number");

        dataSock = new std.socket.TcpSocket(address);
        simpleHandshake(dataSock);
        enforce(dataSock.send("data\n") == 5, "Failed to send connection type for data socket");
        enforce(dataSock.send(_magic) == 4, "Error echoing magic number");
        response = readLine(dataSock);
        enforce(response == "Ok!", "Error recieving ack from server: " ~ response);

        //Prepare to receiveive all the game data everrrrr!
        msg(readLine(dataSock));
        tcpReceiveDir(dataSock, g_worldPath);
        msg(readLine(dataSock));
        



    }

}
