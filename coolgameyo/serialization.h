#pragma once

#include <sstream>
#include <functional>


/** Blah blah

USAGE:

auto mymempool = malloc(1024);
auto insert = mymempool;
int read = 0;


auto f = [&](void* ptr, size_t size) {
    memmove(insert, ptr, size);
    insert += size;
}

serialize(mytile1, f);
serialize(mytile3, f);
serialize(mytile2, f);
serialize(mytile4, f);

friend.send(mymempool, insert - mymempool);


// on friends side

read += deserialize(mytile1, mymempool + read, 1024 - read);
read += deserialize(mytile2, mymempool + read, 1024 - read);
read += deserialize(mytile3, mymempool + read, 1024 - read);
read += deserialize(mytile4, mymempool + read, 1024 - read);


or something like that.

Tile needs the functions writeTo(function) and readFrom(void*, size)

*/



template <typename T>
void serialize(const T& t, std::function<void(void*,size_t)> f) {
    t.writeTo(f);
}

template <typename T>
size_t deserialize(T& t, void* ptr, size_t size)
{
    return t.readFrom(ptr, size);
}