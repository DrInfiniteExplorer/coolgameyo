module playerinformation;

import std.socket;
import unit;
import cgy.util.util;
import cgy.logger.log;

final class PlayerInformation {
    string name;
    string address;
    int magicNumber;    //Magic identification number of player.
    Socket commSock;
    Socket dataSock;

    ubyte[] receiveBuffer;
    int send_index;
    int recv_index;

    int unitId;
    Unit unit;

    bool connected;
    bool disconnected;

    void disconnect() {
        Log("Disconnecting ", name);
        if(commSock) {
            commSock.shutdown(SocketShutdown.BOTH);
            commSock.close();
        }
        if(dataSock) {
            dataSock.shutdown(SocketShutdown.BOTH);
            dataSock.close();
        }
        receiveBuffer.length = 0;
        connected = false;
        disconnected = true;
    }
}
