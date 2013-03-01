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
immutable HANDSHAKE_C = "Oh yeah! Give me a name!\n";

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
                if(playerInfo.dataSock.send("PreChanges\n") != 11){
                    Log("Error sending pre-changes");
                    playerInfo.disconnect();
                    return;
                }
                if(!tcpSendFile(playerInfo.dataSock, "temp/changes")) {
                    Log("Errpr sending temp/changes");
                    playerInfo.disconnect();
                    return;
                }
            }
            if(playerInfo.dataSock.send("SaveGame\n") != 9) {
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
            int changeSize = toWrite.length;
            append("temp/changes.bin", g_gameTick, changeSize, toWrite);
        }
        recv_set.reset();
        write_set.reset();
        foreach(player ; players) {
            if(!player.connected) continue;
            player.send_index = 0;
            player.recv_index = 0;
        }
        
        int[2] frameInfo = [g_gameTick, toWrite.length];
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
                    int read = player.dataSock.receive(player.receiveBuffer[player.recv_index .. $]);
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
                        int sent = player.dataSock.send(toWrite[player.send_index .. $]);
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


mixin template ClientModule() {

    SocketSet recv_set, write_set;
    Socket commSock;
    Socket dataSock;
    int magicNumber;
    ubyte[] receiveBuffer;
    ubyte[] toWrite;
    size_t send_index;
    size_t recv_index;


    WorldProxy  clientChangeProxy;
    Unit        activeUnit;
    UnitPos     activeUnitPos;

    Thread dummyThread;
    bool doneLoading; // maybe make shared for automagic memory barrier ?

    void simpleHandshake(Socket sock) {
        //sock.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1); //To disable nagle
        enforce(readLine(sock) == HANDSHAKE_A[0..$-1], "Handshake A failed");
        enforce(sock.send(HANDSHAKE_B) == HANDSHAKE_B.length, "Handshake B failed");
        enforce(readLine(sock) == HANDSHAKE_C[0..$-1], "Handshake C failed");
    }

    void initModule(string host) {
        import util.socket;
        recv_set = new SocketSet(2);
        write_set = new SocketSet(1);

        auto address = new std.socket.InternetAddress(host, PORT);

        pragma(msg, "Add code to set connection timeout");
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

        scope(failure) {
            BREAKPOINT();
        }

        //Set up thread to reveive changes in background while we receive the game state.
        dummyThread = spawnThread(&dummyClientNetwork);
        
        //Send pre-changes before save?
        response = readLine(dataSock);
        if(response == "PreChanges") {
            //Reveive file with changes; format is same as change-frame
            mkdir(g_worldPath ~ "/temp");
            tcpReceiveFile(dataSock, g_worldPath ~ "/temp/changes");

            response = readLine(dataSock);
        }
        enforce(response == "SaveGame", "Error; did not receive 'SaveGame' from server");

        //Prepare to receiveive all the game data everrrrr!
        tcpReceiveDir(commSock, g_worldPath);

        //Now set up mechanism to signal the dummythread when the game is loaded
        //and all changes up till now are applied, so that it quits 'in sync' and the real
        //network code can run wild.
    }

    void handleComm() {
        //Assume falsely that all comm is newline terminated
        auto line = readLine(commSock);
        if(line is null) {
            BREAKPOINT;
        }
        msg("!!!!!! COMM MESSAGE !!!!\n", "   ", line, "\b\n\n");
        if(line.startsWith("controlUnit:")) {
            auto id = to!int(line[line.lastIndexOf(':')+1 .. $]);
            auto unit = Clans().getUnitById(id);
            setActiveUnit(unit);
        }
    }

    void doNetworkStuffUntil(long nextSync) {
        recv_index = 0;
        send_index = 0;

        int[2] frameInfo = [g_gameTick, toWrite.length];
        if(dataSock.receive(frameInfo) != frameInfo.sizeof) {
            Log("Error receiveing frame info from server, disconnecting");
            BREAKPOINT;
        }
        if(frameInfo[0] != g_gameTick) {
            Log("Client got wrong game tick");
            BREAKPOINT;
        }
        receiveBuffer.length = frameInfo[1];
        assumeSafeAppend(receiveBuffer);
        frameInfo[1] = toWrite.length;
        if(dataSock.send(frameInfo) != frameInfo.sizeof) {
            Log("Error sending frame info to client, disconnecting");
            BREAKPOINT;
        } 

        //When leave this all is sent/received.... ?
        bool stuffToTransfer = true;
        while (stuffToTransfer) {
            stuffToTransfer = false; 
            recv_set.reset();
            write_set.reset();
            recv_set.add(commSock);
            recv_set.add(dataSock);
            write_set.add(dataSock);
            int n = Socket.select(recv_set, write_set, null, 0);
            if(recv_set.isSet(commSock)) {
                handleComm();
            }
            if(recv_set.isSet(dataSock)) {
                if(recv_index != receiveBuffer.length) {
                    int read = dataSock.receive(receiveBuffer[recv_index .. $]);
                    if(read < 1) {
                        Log("Error reading changes from server, disconnecting");
                        BREAKPOINT;
                    }
                    recv_index += read;
                }
            }
            if (write_set.isSet(dataSock)) {
                if(send_index != toWrite.length) {
                    auto len = toWrite.length;
                    int sent = dataSock.send(toWrite[send_index .. $]);
                    if(sent < 1) {
                        BREAKPOINT;
                    }
                    send_index += sent;
                }
            }
            stuffToTransfer |= send_index != toWrite.length;
            stuffToTransfer |= recv_index != receiveBuffer.length;
        }

        //Changed into use of variable; have encountered race condition in previous project
        // where the time went into the next frame after the while-check, overflowing the
        // value sent to select / sleep, producing a very long wait.
        auto timeLeft = nextSync - utime();
        recv_set.reset();
        recv_set.add(commSock);
        while (timeLeft > 0) {
            int n = Socket.select(recv_set, null, null, timeLeft);
            if (n == 0) {
                break; // this is timeout, means we go on until next tick
            }
            handleComm();
        }
        toWrite.length = 0;
        assumeSafeAppend(toWrite);
    }

    void getNetworkChanges(ref ChangeList list) {
        list.readFrom(receiveBuffer);
    }

    void pushChanges() {
        synchronized(clientChangeProxy) {
            if(activeUnit) {
                clientChangeProxy.moveUnit(activeUnit, activeUnitPos, 1);
            }
            pushChanges(clientChangeProxy.changeList);
            clientChangeProxy.changeList.reset(); //Think reset here is the right place?
        }
    }

    void pushChanges(ChangeList list) {
        toWrite ~= list.changeListData[];
    }

    void dummyClientNetwork() {
        while(!doneLoading) {
            int[2] frameInfo = [g_gameTick, 0];
            auto ret = dataSock.receive(frameInfo);
            if(ret != frameInfo.sizeof) {
                Log("Pre:Error receiveing frame info from server, disconnecting");
                BREAKPOINT;
            }
            receiveBuffer.length += frameInfo[1];
            g_gameTick = frameInfo[0];
            frameInfo[1] = 0;
            if(dataSock.send(frameInfo) != frameInfo.sizeof) {
                Log("Pre:Error sending frame info to client, disconnecting");
                BREAKPOINT;
            }
            assumeSafeAppend(receiveBuffer);

            while(recv_index != receiveBuffer.length) {
                int read = dataSock.receive(receiveBuffer[recv_index .. $]);
                if(read < 1) {
                    Log("Pre:Error reading changes from server, disconnecting");
                    BREAKPOINT;
                }
                recv_index += read;
            }
        }
    }

}
