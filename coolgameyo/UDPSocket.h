#pragma once

#include "include.h"

class UDPSocket
{
public:
	UDPSocket(void);
	~UDPSocket(void);

	/* Make socket operations asynchronous? */

	bool Connect(); /* Maybe sometime in the future, also support passing port and address! *snicker* */
	bool Host(int port);

	/* Maybe support features like, durr.. waiting first, and/or ehr.. channels? stuff? */
	unsigned int Send(/*Whereto?, */ void *Data, u32 Count);
	unsigned int Recv(/*Wherefrom?, */, void *Data, u32 BuffSize);



private:
	/* Socket data stuff */
	SOCKET m_socket;
};

