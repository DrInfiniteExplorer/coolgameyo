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
}
#endif


UDPSocket::UDPSocket(void)
{
#ifdef WIN32
	if(!g_inited){
		initNetwork();
	}
#endif

	m_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if(INVALID_SOCKET == m_socket){
		printf("Could not create socket lol!\n");
		BREAKPOINT;
	}

}


UDPSocket::~UDPSocket(void)
{
	if(SOCKET_ERROR == shutdown(m_socket, /* SD_BOTH*/ 2)){
		printf("Lol couldnt shutdown socket?\n");
		BREAKPOINT;
	}

	if(SOCKET_ERROR == closesocket(m_socket)){
		printf("Wut lol couldnt close socket? :S\n");
		BREAKPOINT;
	}
}


bool UDPSocket::Host(int port){ /* Make special class UDPServerSocket that only creates, binds, listens and accepts? */
	sockaddr_in addr;
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = INADDR_ANY; /* inet_addr("127.0.0.1"); */
	addr.sin_port = htons(port);

	if(SOCKET_ERROR == bind(m_socket, (const sockaddr*)&addr, sizeof(addr))){
		printf("Binding socket failed!!! port: %d\n", port);
		BREAKPOINT;
	}


	if(SOCKET_ERROR == listen(m_socket, 2)){
		printf("Listen on socket failed!!\n");
		BREAKPOINT;
	}

	/* Derp now allow stuff to happen derp */

}