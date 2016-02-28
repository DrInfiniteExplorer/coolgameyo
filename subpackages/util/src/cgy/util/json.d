module cgy.util.json;

import std.conv : to;
import std.stdio : writeln;
import std.file : readText;
import std.json : JSONValue, parseJSON, JSONException;

import painlessjson;

void unJSON(T)(in JSONValue val, ref T t) {
    t = painlessjson.fromJSON!T(val);
}

JSONValue loadJSON(immutable in string path) {
    try {
        return path.readText.parseJSON;
    }
    catch(JSONException e)
    {
        writeln("Error reading " ~ path);
        writeln(e.to!string);
        throw e;
    }
}

