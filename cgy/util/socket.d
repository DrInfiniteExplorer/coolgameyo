module util.socket;

import std.socket;
import util.util : msg, BREAK_IF;
import util.filesystem: mkdir;


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

unittest {
    import std.file : dirEntries, SpanMode, DirEntry;
    auto startDir = "data//";
    foreach(DirEntry dirEntry ; dirEntries(startDir, SpanMode.breadth)) {
        BREAK_IF(dirEntry.name()[0 .. startDir.length] != startDir);
    }
}

void tcpSendDir(Socket sock, string dirPath) {
    import std.file : dirEntries, SpanMode, DirEntry;
    dirPath ~= "/"; //As long as the unit test above doesnt fail, this should be ok!! :D
    foreach(DirEntry dirEntry ; dirEntries(dirPath, SpanMode.breadth)) {
        auto relativeName = dirEntry.name()[dirPath.length .. $];
        msg("Will send file: ", relativeName);
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
        msg("Will receive ", filename);
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

    // Shouldn't need the write-part, but it seems that if it is first opened
    // as readwrite (for example the heightmap) then it can't be opened for
    // read after that, but a readwrite is fine.
    // read = GENERIC_READ, FILE_SHARE_READ
    // readwride = GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE
    // see http://msdn.microsoft.com/en-us/library/windows/desktop/aa363874%28v=vs.85%29.aspx
    // for a table of compabilities.
    auto memfile = new MmFile(filePath, MmFile.Mode.readWrite, 0, null, 0);
    scope(exit) delete memfile;
    auto filePtr = cast(byte[])memfile[];
    int sentSoFar = 0;
    int totalSize = filePtr.length;

    if(sock.send((&totalSize)[0..1]) != 4) {
        msg("Error sending file size: " ~ filePath);
        return false;
    }

    while(sentSoFar != totalSize) {
        int toSend = min(bufferSize, totalSize - sentSoFar);
        int sent = sock.send(filePtr[sentSoFar .. sentSoFar + toSend]);
        if(sent < 1) {
            msg("Socket error while sending file: " ~ filePath);
            return false;
        }
        sentSoFar += sent;
    }
    return true;
}

bool tcpReceiveFile(Socket sock, string filePath, int bufferSize = int.max) {
    import std.algorithm : min;
    import std.mmfile;
    int readSoFar = 0;
    int totalSize;

    if(sock.receive((&totalSize)[0..1]) != 4) {
        msg("Error receiving file size: " ~ filePath);
        return false;
    }

    auto memfile = new MmFile(filePath, MmFile.Mode.readWriteNew, totalSize, null, 0);
    scope(exit) delete memfile;
    auto filePtr = cast(byte[])memfile[];

    while(readSoFar != totalSize) {
        int toRead = min(bufferSize, totalSize - readSoFar);
        int read = sock.receive(filePtr[readSoFar .. readSoFar + toRead]);
        if(read < 1) {
            msg("Socket error while receiving file: " ~ filePath);
            return false;
        }
        readSoFar += read;
    }
    return true;
}
