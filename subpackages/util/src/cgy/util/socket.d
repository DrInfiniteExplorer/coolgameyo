module cgy.util.socket;

import std.conv : to;
import std.socket;

import cgy.debug_.debug_ : BREAK_IF;
import cgy.logger.log;
import cgy.util.filesystem: mkdir, fileSize, writeText;


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

void sendAll(T)(Socket sock, immutable T[] buffer) {
    size_t sent = 0;
    while(sent != buffer.length) {
        auto tmp = sock.send(buffer[sent .. $]);
        BREAK_IF(tmp < 1);
        sent += tmp;
    }
}

void readAll(T)(Socket sock, T[] buffer) {
    size_t read = 0;
    while(read != buffer.length) {
        auto tmp = sock.receive(buffer[read .. $]);
        BREAK_IF(tmp < 1);
        read += tmp;
    }
}

void sendString(Socket sock, string line) {
    int[1] length;
    length[0] = cast(int)line.length;
    BREAK_IF(sock.send(length) != int.sizeof);
    sock.sendAll(line);
}


string readString(Socket sock) {
    int[1] length;
    BREAK_IF(sock.receive(length) != int.sizeof);
    char[] str;
    str.length = length[0];
    sock.readAll(str);
    return cast(immutable)str;

}

void tcpSendDir(Socket sock, string dirPath) {
    import std.file : dirEntries, SpanMode, DirEntry;
    dirPath ~= "/"; //As long as the unit test above doesnt fail, this should be ok!! :D
    foreach(DirEntry dirEntry ; dirEntries(dirPath, SpanMode.breadth)) {
        auto relativeName = dirEntry.name()[dirPath.length .. $];
        Log("Will send file: ", relativeName);
        sock.send(dirEntry.isDir() ? "D" : "F");
        sock.send(relativeName);
        sock.send("\n");
        if(dirEntry.isFile()) {
            tcpSendFile(sock, dirEntry.name);
        }
    }
    sock.send("EndOfDirectory\n");
}

void tcpReceiveDir(Socket sock, string dirPath) {
    import std.file : dirEntries;
    mkdir(dirPath);
    string filename;
    filename = readLine(sock);
    while(filename != "EndOfDirectory") {
        Log("Will receive ", filename);
        auto Type = filename[0];
        filename = filename[1..$];
        auto fullPath = dirPath ~ "/" ~ filename;
        if(Type == 'D') {
            mkdir(fullPath);
        } else if(Type == 'F') {
            tcpReceiveFile(sock, fullPath);
        }
        filename = readLine(sock);
    }
}


bool tcpSendFile(Socket sock, string filePath, int bufferSize = int.max) {
    import std.mmfile;
    import std.algorithm : min;

    ulong size = fileSize(filePath);

    MmFile memfile;
    byte[] filePtr;
    size_t sentSoFar = 0;

    // MmFiles crash when loading zero-length files.
    if(size > 0) {
        // Shouldn't need the write-part, but it seems that if it is first opened
        // as readwrite (for example the heightmap) then it can't be opened for
        // read after that, but a readwrite is fine.
        // read = GENERIC_READ, FILE_SHARE_READ
        // readwride = GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE
        // see http://msdn.microsoft.com/en-us/library/windows/desktop/aa363874%28v=vs.85%29.aspx
        // for a table of compabilities.
        memfile = new MmFile(filePath, MmFile.Mode.readWrite, 0, null, 0);
        filePtr = cast(byte[])memfile[];

        BREAK_IF(filePtr.length != size);
        BREAK_IF(size > uint.max);
    }
    scope(exit) {
        if(memfile) {
            delete memfile;
        }
    }

    uint totalSize = cast(uint)size;

    uint[1] sendSize;
    sendSize[0] = cast(uint)totalSize;

    if(sock.send(sendSize) != sendSize.sizeof) {
        Log("Error sending file size: " ~ filePath);
        return false;
    }

    while(sentSoFar != totalSize) {
        size_t toSend = min(bufferSize, totalSize - sentSoFar);
        ptrdiff_t sent = sock.send(filePtr[sentSoFar .. sentSoFar + toSend]);
        if(sent < 1) {
            Log("Socket error while sending file: " ~ filePath);
            return false;
        }
        sentSoFar += sent;
    }
    return true;
}

bool tcpReceiveFile(Socket sock, string filePath, int bufferSize = int.max) {
    import std.algorithm : min;
    import std.mmfile;
    size_t readSoFar = 0;
    size_t totalSize;
    uint[1] size;

    if(sock.receive(size) != size.sizeof) {
        Log("Error receiving file size: " ~ filePath);
        return false;
    }
    totalSize = size[0];
    if(totalSize == 0) {
        writeText(filePath, "");
        return true;
    }

    auto memfile = new MmFile(filePath, MmFile.Mode.readWriteNew, totalSize, null, 0);
    scope(exit) delete memfile;
    auto filePtr = cast(byte[])memfile[];

    while(readSoFar != totalSize) {
        size_t toRead = min(bufferSize, totalSize - readSoFar);
        ptrdiff_t read = sock.receive(filePtr[readSoFar .. readSoFar + toRead]);
        if(read < 1) {
            Log("Socket error while receiving file: " ~ filePath);
            return false;
        }
        readSoFar += read;
    }
    return true;
}

// Manually create socket, set as nonblocking, connect and/or wait for the timeout.
TcpSocket connectTimeout(std.socket.Address addr, Duration timeout) {

    TcpSocket sock = new TcpSocket(addr.addressFamily());
    sock.blocking = false;
    SocketSet set = new SocketSet(1);
    set.reset();
    set.add(sock);
    sock.connect(addr);
    if( 1 == Socket.select(null, set, null, timeout) ) {
        sock.blocking = true;
        return sock;
    }
    sock.close();
    return null;
}
