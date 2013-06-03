module network.client;

import util.socket : readString, sendString;
import network.common;
import core.sync.mutex;

__gshared string[] commandsToSend;
__gshared Mutex commandsToSendMutex;

shared static this() {
    commandsToSendMutex = new Mutex;
}

mixin template ClientModule() {

    SocketSet recv_set;
    Socket commSock;
    Socket dataSock;
    int magicNumber;
    ubyte[] receiveBuffer;
    size_t recv_index;


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

        msg("Looking up address...");
        auto address = new std.socket.InternetAddress(host, PORT);

        msg("Trying to connect to ", address);
        commSock = connectTimeout(address, dur!"seconds"(10));
        enforce(commSock, "Timeout connecting comm sock to server!");
        simpleHandshake(commSock);
        enforce(commSock.send("comm\n") == 5, "Failed to send connection type for communication socket");
        enforce(commSock.send("Username:" ~ g_playerName ~ "\n") == 10 + g_playerName.length, "Failed to send username");
        auto response = readLine(commSock);
        enforce(response == "Ok!", "Error connecting to server: " ~ response);
        int[] _magic = (&magicNumber)[0..1];
        enforce(commSock.receive(_magic) == 4, "Error recieving magic identification number");
        msg("Connected! ½-way there!");

        dataSock = connectTimeout(address, dur!"seconds"(10));
        enforce(dataSock, "Timeout connecting datasock to server!");
        simpleHandshake(dataSock);
        enforce(dataSock.send("data\n") == 5, "Failed to send connection type for data socket");
        enforce(dataSock.send(_magic) == 4, "Error echoing magic number");
        response = readLine(dataSock);
        enforce(response == "Ok!", "Error recieving ack from server: " ~ response);
        msg("Fully connected yeah!");

        scope(failure) {
            BREAKPOINT();
        }

        //Set up thread to reveive changes in background while we receive the game state.
        dummyThread = spawnThread(&dummyClientNetwork);
        // WILL READ FROM DATASOCK

        //Send pre-changes before save?
        msg("Will read response from servoar");
        response = readLine(commSock);
        if(response == "PreChanges") {
            msg("Will download stuff");
            //Reveive file with changes; format is same as change-frame
            mkdir(g_worldPath ~ "/temp");
            tcpReceiveFile(commSock, g_worldPath ~ "/temp/changes");

            response = readLine(commSock);
        }
        enforce(response == "SaveGame", "Error; did not receive 'SaveGame' from server");

        msg("Will download gamestate from server");
        //Prepare to receiveive all the game data everrrrr!
        tcpReceiveDir(commSock, g_worldPath);
        msg("Gamestate downloaded, starting game yeah!");

        //Now set up mechanism to signal the dummythread when the game is loaded
        //and all changes up till now are applied, so that it quits 'in sync' and the real
        //network code can run wild.
    }

    void handleComm() {
        //Assume falsely that all comm is newline terminated
        auto line = readString(commSock);
        if(line is null) {
            LogError("Received null from commSock");
            BREAKPOINT;
        }
        msg("!!!!!! COMM MESSAGE !!!!\n", "   ", line, "\b\n\n");
        if(line.startsWith("controlUnit:")) {
            auto id = to!int(line[line.lastIndexOf(':')+1 .. $]);
            auto unit = Clans().getUnitById(id);
            setActiveUnit(unit);
        }
    }

    void sendCommand(string command) {
        synchronized(commandsToSendMutex) {
            commandsToSend ~= command;
        }
    }

    void doNetworkStuffUntil(long nextSync) {
        recv_index = 0;

        int[2] frameInfo = [g_gameTick, 0];
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
        frameInfo[1] = 0; // Nothing to send over data socket
        if(dataSock.send(frameInfo) != frameInfo.sizeof) {
            Log("Error sending frame info to client, disconnecting");
            BREAKPOINT;
        }


        synchronized(commandsToSendMutex) {
            foreach(command ; commandsToSend) {
                commSock.sendString(command);
            }
            commandsToSend.length = 0;
            assumeSafeAppend(commandsToSend);
        }


        //When leave this all is sent/received.... ?
        bool stuffToTransfer = true;
        while (stuffToTransfer) {
            stuffToTransfer = false; 
            recv_set.reset();
            recv_set.add(commSock);
            recv_set.add(dataSock);

            int n = Socket.select(recv_set, null, null, 0);
            if(recv_set.isSet(commSock)) {
                handleComm();
            }
            if(recv_set.isSet(dataSock)) {
                if(recv_index != receiveBuffer.length) {
                    ptrdiff_t read = dataSock.receive(receiveBuffer[recv_index .. $]);
                    if(read < 1) {
                        Log("Error reading changes from server, disconnecting");
                        BREAKPOINT;
                    }
                    recv_index += read;
                }
            }
            stuffToTransfer = recv_index != receiveBuffer.length;
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
    }

    void getNetworkChanges(ref ChangeList list) {
        list.readFrom(receiveBuffer);
    }

    void dummyClientNetwork() { 
        msg("Starting dummy client network work");
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
                ptrdiff_t read = dataSock.receive(receiveBuffer[recv_index .. $]);
                if(read < 1) {
                    Log("Pre:Error reading changes from server, disconnecting");
                    BREAKPOINT;
                }
                recv_index += read;
            }
        }
    }

}
