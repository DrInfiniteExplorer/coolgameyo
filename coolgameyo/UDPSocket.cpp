#include "UDPSocket.h"

#ifdef WIN32
static bool g_inited = false;
static WSADATA wsaData;
static WORD wVersionRequested;
static void initNetwork(){
    wVersionRequested = MAKEWORD(2, 2);

    int err = WSAStartup(wVersionRequested, &wsaData);
    if(err){
        /* Log error etc */
        printf("WSAStartup error: %d\n", err);
        BREAKPOINT;
    }
    g_inited = true;
}
#define INITNETWORK if(!g_inited){ initNetwork(); }
#else
#define INITNETWORK
#endif


UDPSocket::UDPSocket(void)
{
    INITNETWORK;

    m_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(INVALID_SOCKET == m_socket){
        printf("Could not create socket lol!\n");
        BREAKPOINT;
    }
    m_isConnected = false;
}

UDPSocket::UDPSocket(SOCKET sock)
{
    m_socket = sock;
    m_isConnected = true;
}


UDPSocket::UDPSocket(const UDPSocket &o)
{
    printf("Implement\n");
    BREAKPOINT;
}

UDPSocket::~UDPSocket(void)
{
    if (SOCKET_ERROR == shutdown(m_socket, /* SD_BOTH*/ 2)) {
        printf("Lol couldnt shutdown socket?\n");
        BREAKPOINT;
    }

    if (SOCKET_ERROR == closesocket(m_socket)) {
        printf("Wut lol couldnt close socket? :S\n");
        BREAKPOINT;
    }
}

bool UDPSocket::connect(/* Address, */ int port)
{
    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(port);

    if (SOCKET_ERROR == connect(m_socket, (const sockaddr*)&addr, sizeof(addr))) {
        printf("connect failed\n");
        BREAKPOINT;

        //Eventually return false here, maybe more diagnostic errors and stuff also.
    }

    m_isConnected = true;
    return m_isConnected;
}

s32 UDPSocket::send(void *data, u32 count)
{
    s32 ret = send(m_socket, (char*)data, count, 0);
    if (SOCKET_ERROR == ret) {
        printf("Socket error in send! probably a closed socket!!\n");
        BREAKPOINT;
    }

    return ret;
}

s32 UDPSocket::recv(void *data, u32 buffSize)
    {
    s32 gotted = recv(m_socket, (char*)data, buffSize, 0);
    if (SOCKET_ERROR == gotted) {
        printf("Socker error in recv!!\n");
        BREAKPOINT;
    }
    if (!gotted) {
        printf("Socket gracefully closed @otherside!!\n");
        BREAKPOINT;
    }
    return gotted;
}











UDPServerSocket::UDPServerSocket(int port, int backlog)
    {
    INITNETWORK;

    m_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (INVALID_SOCKET == m_socket) {
        printf("Could not create server socket lol!\n");
        BREAKPOINT;
    }

    /* Put in private Host()-function yeah. */
    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY; /* inet_addr("127.0.0.1"); */
    addr.sin_port = htons(port);

    if (SOCKET_ERROR == bind(m_socket, (const sockaddr*)&addr, sizeof(addr))) {
        printf("Binding server socket failed!!! port: %d\n", port);
        BREAKPOINT;
    }


    if (SOCKET_ERROR == listen(m_socket, backlog)) {
        printf("Listen on server socket failed!!\n");
        BREAKPOINT;
    }
    FD_ZERO(&m_acceptFD);
    FD_SET(m_socket, &m_acceptFD);
}

UDPServerSocket::UDPServerSocket(const UDPServerSocket& o)
{
    printf("Implement\n");
    BREAKPOINT;
}


UDPServerSocket::~UDPServerSocket()
{
    if (SOCKET_ERROR == shutdown(m_socket, /* SD_BOTH*/ 2)) {
        printf("Lol couldnt shutdown server socket?\n");
        BREAKPOINT;
    }

    if (SOCKET_ERROR == closesocket(m_socket)) {
        printf("Wut lol couldnt close server socket? :S\n");
        BREAKPOINT;
    }
}

TIMEVAL nonblock= {0, 0};

bool UDPServerSocket::newClient()
{
    if (SOCKET_ERROR == select(1, &m_acceptFD, NULL, NULL, &nonblock)) {
        printf("Durr select failed on server socket\n");
        BREAKPOINT;
    }
    if (FD_ISSET(m_socket, &m_acceptFD)) {
        FD_CLR(m_socket, &m_acceptFD);
        return true;
    }
    return false;
}

UDPSocket UDPServerSocket::getClient()
{
    SOCKET clientSocket;
    #ifdef CHECK_CONNECTING_ADDRESS
    /* Must be the same format as the one used to create m_socket, i think */
    /* See addr-parameter @ http://msdn.microsoft.com/en-us/library/ms737526%28VS.85%29.aspx */
    sockaddr_in addr; 
    int addrSize = sizeof(addr);
    clientSocket = accept(m_socket, (sockaddr*)&addr, &addrSize);
    #endif
    clientSocket = accept(m_socket, NULL, NULL);

    if (INVALID_SOCKET == clientSocket) {
        printf("Got invalid socket from accept!\n");
        BREAKPOINT;
    }

    return UDPSocket(clientSocket);
}

