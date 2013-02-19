module modules.network;

import modules.module_;

import std.socket;

enum max_clients = 13;

class ServerModule : Module {

    static struct Client {
        Socket socket;
        ubyte[] recv;
        size_t send_index;
        size_t recv_index;
    }

    SocketSet recv_set, write_set;
    Socket listener;

    Client[] clients;
    ubyte[] toWrite;

    ChangeList client_changes;

   
    private void accept_new_client() {
        auto newsock = listener.accept();
        if (clients.length < max_clients) {
            clients ~= Client(newsock, [], 0, 0);
        } else {
            msg("Too many clients!");
            newsock.close();
        }
    }

    this() {
        listener = new TcpSocket;
        listener.bind(new InternetAddress(13337));
        listener.listen(10);

        recv_set = new SocketSet(max_clients + 1);
        write_set = new SocketSet(max_clients);
    }

    // todo:
    // figure out sizes of buffers

    void doNetworkStuffUntil(long nextSync) {

        while (true) {

            scope (exit) {
                recv_set.reset();
                write_set.reset();
            }

            recv_set.add(listener);
            int max_n;
            foreach (ref client; clients) {
                if (client.send_index < toWrite.length) {
                    write_set.add(client);
                    max_n += 1;
                }
                if (client.recv_index < client.recv.length) {
                    recv_set.add(client);
                    max_n += 1;
                }
            }

            if (max_n == 0) {
                break; // nothing left to send/recv
            }

            int n = Socket.select(recv_set, write_set, null);

            foreach (ref client; clients) {
                if (recv_set.isSet(client)) {
                    int read = client.socket.receive(
                            client.recv[client.recv_index .. $]);
                    enforce (read > 0, "some network error");
                    client.recv_index += read;
                }
                if (write_set.isSet(client)) {
                    int sent = client.socket.send(
                            toWrite[client.send_index .. $]);
                    enfocrce(sent > 0, "some network error");
                    client.send_index += sent;
                }
            }

            if (recv_set.isSet(listener)) {
                accept_new_client();
            }
        }

        while (utime() < nextSync) {
            scope (exit) {
                recv_set.reset();
            }
            recv_set.add(listener);

            int n = Socket.select(recv_set, null, null, nextSync - utime());
            if (n == 0) {
                break; // this is timeout, means we go on until next tick
            }
            assert (recv_set.isSet(listener));

            accept_new_client();
        }
    }

    ChangeList getNetworkChanges() {
        foreach (client; clients) {
            client_changes.readFrom(client.recv);
        }
    }

    void pushNetworkChanges(ChangeList list) {
    }

    void finalizeNetworkChangePush() {
        uint total_size = toWrite.length - 4;
        toWrite[0..4] = *cast(ubyte[4]*)&total_size;
    }

    override void update(WorldState world, Scheduler scheduler) {

    }
    
    override void serializeModule() {
        assert (0);
    }
    override void deserializeModule() {
        assert (0);
    }
}


class ClientModule : Module {

    override void update(WorldState world, Scheduler scheduler) {
    }

    override void serializeModule() {
        assert (0);
    }
    override void deserializeModule() {
        assert (0);
    }
}
