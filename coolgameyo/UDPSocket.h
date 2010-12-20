#pragma once

#include "include.h"


class UDPSocket
{
public:
	UDPSocket(void);
	UDPSocket(SOCKET sock); /* Populate the m_socket with this sock. Set is connected. Yeah awesome. */
	UDPSocket(const UDPSocket &o);
	~UDPSocket(void);

	/* Make socket operations asynchronous? */

	bool Connect(/* Address, */ int port); /* Maybe sometime in the future, also support passing port and address! *snicker* */

	/* Maybe support features like, durr.. waiting first, and/or ehr.. channels? stuff? */
	s32 Send(void *Data, u32 Count);
	s32 Recv(void *Data, u32 BuffSize);



private:
	/* Socket data stuff */
	SOCKET	m_socket;
	bool	m_isConnected;
};

class UDPServerSocket
{
public:
	UDPServerSocket(int port, int backlog=2);
	UDPServerSocket(const UDPServerSocket& o);
	~UDPServerSocket();

	bool NewClient(); //Returns true if we can get a client without blocking
	UDPSocket GetClient();

private:
	SOCKET m_socket;
	fd_set m_acceptFD;
};
