

module util.httpupload;


import std.conv;
import std.regex;
import std.stdio;
import std.socket;
import std.socketstream;
import std.stream;


string sendFile(string host, int port, string path, string name, string filename, char[] data, string returnWhat=null, string mime="application/octet-stream") {
    Socket sock = new TcpSocket(new InternetAddress("luben.se", 80));
    scope(exit) sock.close();
    Stream ss   = new SocketStream(sock);

    char[] Body =
        "--AaB03x\r\n"
        "content-disposition: form-data; name=\""~name~"\"; filename=\""~filename~"\"\r\n"
        "Content-Type: "~mime~"\r\n" ~
    
        //"Content-Length: " ~to!string(data.length)~"\r\n"
        "\r\n"
        ~data~"\r\n"
        "--AaB03x--"
        "\r\n\r\n\r\n\r\n";

    string len = to!string(Body.length);

    char[] arr; //Lolol this avoids type errors below :P
    arr.length=0;

    char[] header =
        "POST "~path~" HTTP/1.1\r\n"
        "Host: "~host~"\r\n"
        "User-Agent: Mozilla/5.0\r\n"
        "Content-type: multipart/form-data, boundary=AaB03x\r\n"
        "Content-Length: "~len~"\r\n"
        "\r\n" ~arr;

    ss.writeString(header ~ Body);

    if (returnWhat is null) return null;

    if (returnWhat == "body") {
        bool foundBody = false;

        int length = -1;
        while (!ss.eof() && !foundBody)
        {
            auto line = ss.readLine();
            auto ex = regex(r"(C|c)ontent-(L|l)ength: (\d+)");
            auto m = match(line, ex);
            if(!m.empty) {
                length = to!int(m.captures[3]);
            }
            if(line == "") {
                foundBody = true;
            }
            writeln(line);
        }
        if(length == -1) {
            return null;
        }
        char[] content;
        content.length = length;
        ss.readBlock(content.ptr, length);

        writeln(content);

        return to!string(content);
    }

    /* //Debug stuff
    while (!ss.eof())
    {
    auto line = ss.readLine();
    writeln(line);
    }
    // */

    return null;
}

