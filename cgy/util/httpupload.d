

module util.httpupload;


import std.conv;
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
        string ret = "";
        while (!ss.eof())
        {
            auto line = ss.readLine();
            if(foundBody) {
                ret ~= line ~"\n";
            }
            if(line == "") {
                foundBody = true;
            }
            writeln(line);
        }

        return ret;
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

