
module util.queue;

import std.exception;

class Queue(T) {
    struct Node {
        Node* next;
        T value;
        this(Node* n, T t) { next = n; value = t; }
    }
    Node* first, last;

    void insert(T t) {
        if (last is null) {
            last = new Node(null, t);
            first = last;
        } else {
            last.next = new Node(null, t);
            last = last.next;
        }
    }
    T removeAny() {
        enforce(!empty);
        T ret = first.value;

        first = first.next;
        if (first is null) last = null;

        return ret;
    }
    bool empty() @property const {
        return first is null;
    }


    static struct Range {
        Node* node;

        T front() @property {
            return node.value;
        }
        void popFront() {
            node = node.next;
        }
        bool empty() @property {
            return node is null;
        }
    }

    Range opSlice() { return Range(first); }
}
