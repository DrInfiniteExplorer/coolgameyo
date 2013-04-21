module network.server;

import network.common;

mixin template ServerModule() {

    PlayerInformation[string] players; //Index is player name.
    SocketSet recv_set, write_set;
    Socket listener;

    ubyte[] toWrite;

    void initModule() {
        listener = new TcpSocket;
        listener.bind(new InternetAddress(PORT));
        listener.listen(10);

        recv_set = new SocketSet(max_clients + 1);
        write_set = new SocketSet(max_clients);
        toWrite.length = 4;
    }

    bool simpleHandshake(Socket sock) { // Awesome handshake :P
        //sock.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1); //To disable nagle
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
                scope(exit) {
                    sendingSaveGame--;
                }
                scope(failure) {
                    player.disconnect();
                }
                Log("Starting send all things ever thread");

                tcpSendDir(player.commSock, g_worldPath);

            } catch(Exception e) {
                Log("Error while sending all things ever!:");
                Log(e.msg);
            }
        });
    }

    int sendingSaveGame;

    private void accept_new_client() {
        auto newSock = listener.accept();
        if (players.length >= max_clients) {
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
            Log("Player ", playerInfo.name, " from ", playerInfo.address, " successfully connected!");

            playerInfo.dataSock = newSock;
            playerInfo.dataSock.send("Ok!\n");
            playerInfo.connected = true;

            //If noone was receiving a saved game already, remove old temp-changes and save game.
            if(!sendingSaveGame) {
                if(exists("temp/changes")) {
                    deleteFile("temp/changes");
                }
                scheduler.saveGame();
            }
            sendingSaveGame++;
            if(sendingSaveGame > 1) {
                import util.socket : tcpSendFile;
                //Someone was already getting it. Get all changes from then till now and send to new client.
                if(playerInfo.commSock.send("PreChanges\n") != 11){
                    Log("Error sending pre-changes");
                    playerInfo.disconnect();
                    return;
                }
                if(!tcpSendFile(playerInfo.commSock, "temp/changes")) {
                    Log("Errpr sending temp/changes");
                    playerInfo.disconnect();
                    return;
                }
            }
            if(playerInfo.commSock.send("SaveGame\n") != 9) {
                Log("Error sending savegame");
                playerInfo.disconnect();
                return;
            }
            sendEverything(playerInfo); //Spawn new thread to send stuff in the background aye?
            return;
        } else {
            newSock.send("Expected 'comm' or 'data' to identify connection type. Goodbye!\n");
            newSock.close();
            return;
        }
    }

    void handleComm(PlayerInformation player) {
        //falsely assume that all stuff over comm is newline terminated
        // (In future will be async stuff like player positions as well)
        auto line = readLine(player.commSock);
        Log("Player sent: ", line);
        if(line == "ProperlyConnected") {
            auto path = g_worldPath ~ "/players/" ~ player.name ~ ".json";
            //If has unit, send unit-id to be controlled
            if(exists(path)) {
                BREAKPOINT;
            } else {
                //Else add unit & send unit-id to be controlled.
                //For now just ignore unit creation and assume control of unit 0
                player.commSock.send("controlUnit:1\n");
            }
        }
    }

    // todo:
    // figure out sizes of buffers
    //todo: lol buffers
    void doNetworkStuffUntil(long nextSync) {
        //We now have all changes that will be applied this tick in toWrite.
        if(sendingSaveGame) {
            int changeSize = cast(int)toWrite.length;
            append("temp/changes.bin", g_gameTick, changeSize, toWrite);
        }
        recv_set.reset();
        write_set.reset();
        foreach(player ; players) {
            if(!player.connected) continue;
            player.send_index = 0;
            player.recv_index = 0;
        }

        int[2] frameInfo = [g_gameTick, cast(int)toWrite.length];
        foreach(player ; players) {
            if(!player.connected) continue;
            if(player.dataSock.send(frameInfo) != frameInfo.sizeof) {
                Log("Error sending frame info to client, disconnecting");
                player.disconnect();
            }
        }
        foreach(player ; players) {
            if(!player.connected) continue;
            if(player.dataSock.receive(frameInfo) != frameInfo.sizeof) {
                Log("Error receiveing frame info from client, disconnecting");
                player.disconnect();
                continue;
            }
            if(frameInfo[0] != g_gameTick) {
                Log("Client got wrong game tick; wanted ", g_gameTick, " but got ", frameInfo[0]);
                player.disconnect();
                continue;
            }
            player.receiveBuffer.length = frameInfo[1];
            assumeSafeAppend(player.receiveBuffer);
        }

        //When leave this all is sent/received.... ?
        bool stuffToTransfer = true; 
        while (stuffToTransfer) {
            stuffToTransfer = false;
            recv_set.reset();
            write_set.reset();
            recv_set.add(listener);
            foreach(player ; players) {
                if(!player.connected) continue;
                recv_set.add(player.commSock);
                recv_set.add(player.dataSock);
                write_set.add(player.dataSock);
            }
            int n = Socket.select(recv_set, write_set, null, 0);
            BREAK_IF(n == -1);
            foreach (player ; players) {
                if(!player.connected) continue;
                if(recv_set.isSet(player.commSock)) {
                    server.handleComm(player);
                }
                if(recv_set.isSet(player.dataSock)) {
                    ptrdiff_t read = player.dataSock.receive(player.receiveBuffer[player.recv_index .. $]);
                    if(read < 1) { 
                        Log("Error reading changes from client, disconnecting");
                        recv_set.remove(player.commSock);
                        recv_set.remove(player.dataSock);
                        write_set.remove(player.dataSock);
                        player.disconnect();
                        continue;
                    }
                    player.recv_index += read;
                }
                if (write_set.isSet(player.dataSock)) {
                    auto asd = toWrite.length;
                    if(player.send_index != asd) {
                        ptrdiff_t sent = player.dataSock.send(toWrite[player.send_index .. $]);
                        if(sent < 1) {
                            recv_set.remove(player.commSock);
                            recv_set.remove(player.dataSock);
                            write_set.remove(player.dataSock);
                            player.disconnect();
                            continue;
                        }
                        player.send_index += sent;
                    }
                }
                stuffToTransfer |= player.send_index != toWrite.length;
                stuffToTransfer |= player.recv_index != player.receiveBuffer.length;
            }

            if (recv_set.isSet(listener)) {
                accept_new_client();
            }
        }

        PlayerInformation[] toRemove;
        foreach(player ; players) {
            if(player.disconnected) {
                toRemove ~= player;
            }
        }
        foreach(player ; toRemove) {
            players.remove(player.name);
        }

        //Changed into use of variable; have encountered race condition in previous project
        // where the time went into the next frame after the while-check, overflowing the
        // value sent to select / sleep, producing a very long wait.
        auto timeLeft = nextSync - utime();
        recv_set.reset();
        recv_set.add(listener);
        while (timeLeft > 0) {
            int n = Socket.select(recv_set, null, null, timeLeft);
            if (n == 0) {
                break; // this is timeout, means we go on until next tick
            }
            assert (recv_set.isSet(listener));

            accept_new_client();
            timeLeft = nextSync - utime();
        }
        toWrite.length = 0;
        assumeSafeAppend(toWrite);
    }

    void getNetworkChanges(ref ChangeList list) {
        foreach (player; players) {
            list.readFrom(player.receiveBuffer);
        }
    }

    void pushNetworkChanges(ChangeList list) {
        toWrite ~= list.changeListData[];
    }
}

