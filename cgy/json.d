// cool json library
// by plol
//
// bugs: when reading a struct it does not check that all values in the struct
//         are read,
//       doesn't check that all values are used when reading a struct
//       probably more stuff
//       the float recognising code is retarded

// TODO: kommentera!

module json;


import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.stdio;
import std.traits;

class JsonException : Exception {
    this(string s) {
        super(s);
    }
}

struct Value {
    enum Type : ubyte { string, number, object, array, bool_, null_, } 

    Type type;

    union { // tagged by type
        string str_;
        double num_;
        Value[string] pairs;
        Value[] elements;
        bool boolval;
    }

    bool opIn_r(string name) {
        enforce (type == Type.object, new JsonException(text(
                    "Attempted to opIn_r a non-object (", this, ")")));
        return !!(name in pairs);
    }

    void opIndexAssign(Value v, string name) {
        enforce (type == Type.object, new JsonException(text(
            "Attempted to index a non-object with string (",
            this, ")")));
        pairs[name] = v;
    }
    
    ref Value opIndex(string name) {
        enforce (type == Type.object, new JsonException(text(
                    "Attempted to index a non-object with string (",
                    this, ")")));
        enforce(name in pairs, new JsonException(name ~ " not found"));
        return pairs[name];
    }
    
    ref Value opIndex(size_t index) {
        enforce (type == Type.array);
        return elements[index];
    }
    string str() @property const {
        if (type == Type.string) return str_;
        if (type == Type.null_) return null;
        enforce(0, new JsonException("Not a string or null"));
        return "";
    }
    double num() @property const {
        enforce (type == Type.number, new JsonException("Not a number"));
        return num_;
    }
    bool boolVal() @property const {
        enforce (type == Type.bool_, new JsonException("Not a bool")); 
        return boolval;
    }

    bool opCast(T : bool)() const { return boolVal; }
    bool isNull() @property const { return type !is Type.null_; }


    size_t arrayLength() const @property {
        enforce (type == Type.array, new JsonException(text("Cant do arrayLength on json-value when type is ", type)));
        return elements.length;
    }

    auto asArray() {
        enforce (type == Type.array, new JsonException(text("Cant do asArray on json-value when type is ", type)));
        return elements;
    }

    auto asObject() {
        enforce (type == Type.object, new JsonException(text("Cant do asObject on json-value when type is ", type)));
        return pairs;
    }

    bool opEquals(ref const Value other) const {
        if (type != other.type) return false;
        final switch (type) {
            case Type.string: return str_ == other.str_;
            case Type.number: return num_ == other.num_;
            case Type.object: // y u no work, ==
                              if (pairs.length != other.pairs.length) {
                                  return false;
                              }
                              foreach (k,v; pairs) {
                                  if (k !in other.pairs) return false;
                                  if (v != other.pairs[k]) return false;
                              }
                              return true;
            case Type.array: return elements == other.elements;
            case Type.bool_: return boolval == other.boolval;
            case Type.null_: return true;
        }
    }

    this(string s) { type = Type.string; str_ = s; }
    this(double n) { type = Type.number; num_ = n; }
    this(Value[string] p) { type = Type.object; pairs = p; }
    this(Value[] e) { type = Type.array; elements = e; }
    this(bool b) { type = Type.bool_; boolval = b; }
    static Value nullValue() { Value v; v.type = Type.null_; return v; }

    string toString() {
        string ret;
        string[] keys;
        Value[] vals;
        final switch (type) {
            case Type.string: return text('"', str_, '"');
            case Type.number: return text(num_);
            case Type.object:
                              keys = pairs.keys;
                              if (keys.empty) return "{}";
                              ret = "{";
                              ret ~= text('"',keys.front,
                                      "\":", pairs[keys.front]);
                              keys.popFront();
                              foreach (k; keys) {
                                  ret ~= text(",\"",k, "\":", pairs[k]);
                              }
                              ret ~= "}";
                              return ret;
            case Type.array:
                              return to!string(elements);
            case Type.bool_: return text(boolval);
            case Type.null_: return "null";
        }
    }
}

struct Parser { 
static:
    enum Tag : ubyte {
        invalid, lmus, rmus, lbra, rbra, string, number, 
        colon, true_, false_, null_, comma
    }

    double eatReal(ref string s, bool negative, char n) {
        auto old = s;
        bool end;
        while (!end) {
            switch (s.front) {
                case '0': .. case '9': case 'e', 'E', '+', '-', '.':
                          s.popFront();
                          break;
                default:
                          end = true;
            }
        }

        ptrdiff_t diff = old.length - s.length;
        if(negative) {
            string numStr = old[0 .. diff];
            double ret = to!double(numStr);
            return -ret;
        } else {
            string numStr = n ~ old[0 .. diff];
            double ret = to!double(numStr);
            return ret;
        }

    }

    struct Token {
        Tag tag;
        union {
            string str; 
            double num;
        }
        this(Tag t) { tag = t; }
        this(string s) { tag = Tag.string; str = s; }
        this(double n) { tag = Tag.number; num = n; }
        static Token get(ref string s) {
            auto old = s;
            auto c = s.front;
            s.popFront();
            switch (c) {
                case '{': return Token(Tag.lmus);
                case '}': return Token(Tag.rmus);
                case '[': return Token(Tag.lbra);
                case ']': return Token(Tag.rbra);
                case ':': return Token(Tag.colon);
                case ',': return Token(Tag.comma);
                case '"': 
                          while (s.front != '"') {
                              s.popFront();
                              if (s.front == '\\') {
                                  s.popFront();
                                  s.popFront();
                              }
                          }
                          s.popFront();
                          return Token(old[1 .. old.length - s.length-1]);
                case 't':
                          enforce(s[0 .. 3] == "rue");
                          s.popFrontN(3);
                          return Token(Tag.true_);
                case 'f':
                          enforce(s[0 .. 4] == "alse");
                          s.popFrontN(4);
                          return Token(Tag.false_);
                case 'n':
                          enforce(s[0 .. 3] == "ull");
                          s.popFrontN(3);
                          return Token(Tag.null_);
                case '-':
                          return Token(eatReal(s, true, 0));
                case '0': .. case '9':
                          return Token(eatReal(s, false, cast(char)c));
                default:
                          enforce(false, new JsonException(
                                      text("invalid json, no case for ", c)));
                          assert (0);
            }
        }
    }

    final class Input {
        string s;
        Token front;
        void popFront() {
            skipWhitespace();
            if (!s.empty) front = Token.get(s);
        }
        bool empty() @property const {
            return s.empty;
        }
        void skipWhitespace() {
            if (s.empty) return;
            switch (s.front) {
                case ' ', '\t', '\n', '\r': s.popFront(); return skipWhitespace();
                default: return;
            }
        }
        void skip(Tag tag) {
            enforce(front.tag == tag,
                    new JsonException(
                        text("Expected ", tag, ", found ", front.tag, "\n", s)));
            popFront();
        }
        this(string data) {
            s = data;
            popFront();
        }
    }

    Value parseValue(string s) { return parseValue(new Input(s)); }
    Value parseValue(Input i) {
        string s; double n;
        switch (i.front.tag) {
            case Tag.string: s = i.front.str; i.popFront(); return Value(s);
            case Tag.number: n = i.front.num; i.popFront(); return Value(n);
            case Tag.lmus: return parseObject(i);
            case Tag.lbra: return parseArray(i);
            case Tag.true_: i.popFront(); return Value(true);
            case Tag.false_: i.popFront(); return Value(false);
            case Tag.null_: i.popFront(); return Value.nullValue();
            default:
                enforce(0, new JsonException(
                            "json.d parseValue got to default case, error!"));
                return Value(false);
        }
    }

    Value parseObject(Input i) {
        i.skip(Tag.lmus);
        Value[string] blep;
        while (i.front.tag != Tag.rmus) {
            enforce(i.front.tag == Tag.string, new JsonException("derp"));
            string s = i.front.str;
            i.popFront();
            i.skip(Tag.colon);
            blep[s] = parseValue(i);
            if (i.front.tag != Tag.comma) break;
            else i.popFront();
        }
        i.skip(Tag.rmus);
        return Value(blep);
    }

    Value parseArray(Input i) {
        i.skip(Tag.lbra);
        Value[] blep;
        while (i.front.tag != Tag.rbra) {
            blep ~= parseValue(i);
            if (i.front.tag != Tag.comma) break;
            else i.popFront();
        }
        i.skip(Tag.rbra);
        return Value(blep);
    }
}

alias Parser.parseValue parse;

T read(T)(string s) {
    T t;
    read!T(s, t);    
    return t;
}
T read(T)(Value v) {
    T t;
    read!T(v, t);
    return t;
}
void read(T)(string s, ref T t)  if(! is( T : Value)) {
    return read!T(t, parse(s));
}
void read(T)(Value val, ref T t) if(! is( T : Value)) {
    static if( is( T : Value)) {
        t = val;
    }
    else static if (isNumeric!T) {
        t = to!T(val.num);
    } else static if (is (T : string)) {
        t = val.str;
    } else static if (is (T : bool)) {
        t = val.boolVal;
    } else static if (is (T U : U[])) {
        foreach (e; val.elements) {
            t ~= read!U(e);
        }
    } else static if (is (T U : U[string])) { //Map of things with string as key
        foreach(key, value ; val.pairs) {            
            t[key] = read!U(value);
        }
    } else static if (is (T U : U[V], V)) { //Map of things with ANYTHING! as key
        //see comment in encode
        foreach(e; val.elements) {
            auto key = read!V(e[0]);
            auto value = read!U(e[1]);
            t[key] = value;
        }
    } else static if (__traits(compiles, t.fromJSON(val))) {
        static if( is( T qwerty == class) || is(T ytrewq == interface)) {
            enforce(t !is null, "t of type " ~ T.stringof ~ " is null!");
        }
        t.fromJSON(val);
    } else static if (__traits(compiles, T.insert)) {
        alias typeof(T.removeAny()) Type;
        foreach( e; val.elements) {
            t.insert(read!Type(e));
        }
    } else static if (is (T == struct)) {
        update!T(&t, val);
    } else {
        pragma(msg, text("Json cannot read '", T.stringof, " ", T.stringof,
                "' in ", T.stringof,
                " because I don't know what it is!"));
    }
}

template RealThing(alias Class, string Member) {
    static if(__traits(compiles, typeof(__traits(getMember, Class, Member)))) {
		immutable bool RealThing = true;
	} else {
		immutable bool RealThing = false;
	}
}




private void update(T)(T* t, string s) { return update!T(t, parse(s)); }
private void update(T)(T* t, Value val) {
    enforce(t !is null, "Can not update t of type " ~ T.stringof ~ " because t is null!");
    foreach (m; __traits(allMembers, T)) {

        static if( RealThing!(t, m)) {
            alias typeof(__traits(getMember, *t, m)) M;
            static if (isSomeFunction!(__traits(getMember, T, m))){
                continue;
            } else {
                if (m !in val) continue;
                static if (__traits(compiles, read!M(val[m]))){
                    val[m].read!M(__traits(getMember, *t, m));
                } else static if (is (M == struct)) {
                    update(&__traits(getMember, *t, m), val[m]);
                }
            }
        } else {
        }
    }    
}


Value encode(T)(T t) {
    static if( is(T : Value)) {
        return t;
    }
    else static if (isNumeric!T || is (T : string) || is (T : bool)) { //Normal primitive
        return Value(t);
    } else static if (is (T U : U[])) { //Array of things

        return Value(array(map!(encode!U)(t[])));
    } else static if (is (T U : U[string])) { //Map of things with string as key
        Value[string] ret;
        foreach(key, value ; t) {
            ret[key] = encode(value);
        }
        return Value(ret);

    } else static if (is (T U : U[V], V)) { //Map of things
        // it is encoded as an array of two-object arrays; all kind of things can now be keys.
        Value ret[];
        foreach(key, value ; t) {
            ret ~= Value([encode(key), encode(value)]);
        }
        return Value(ret);


    } else static if (__traits(compiles, t.toJSON())) { //Has method to serialize
        return t.toJSON();
    } else static if (is (T == struct)) {
        Value[string] blep;
        foreach (m; __traits(allMembers, T)) { 
            static if (RealThing!(t, m)) {
                static if (isSomeFunction!(__traits(getMember, T, m))) {
                    continue;
                } else {
                    blep[m] = encode(__traits(getMember, t, m));
                }
            } 
        }
        return Value(blep);
    } else {
        pragma (msg, "cannot encode ", T);
        static assert (0);
    }
}

// Loads the root Value and saves into value.
// Returns true if the file exists, false otherwise
bool loadJSON(string path, out Value value) {
    if (exists(path)) {
        string idContent = readText(path);
        value = json.parse(idContent);
        return true;
    }
    return false;
}

Value loadJSON(string path) {
    Value val;
    enforce(loadJSON(path, val), "Can't load json file:" ~ path);
    return val;
}

void saveJSON(Value value, string path, bool prettify = true) {
    std.file.write(path, prettify ? prettifyJSON(value) : to!string(value));
}

//Example:
//makeJSONObject("renderSettings", renderSettings.serializableSettings,
//               "controlSettings", controlSettings.serializableSettings).saveJSON("settings.json");
//
Value makeJSONObject(T...)(T t) if( (t.length % 2) == 0) {
    Value[string] map;
    Value ret = Value(map);
    ret.populateJSONObject(t);
    return ret;
}
//Use this one to update an existing value with new keys
void populateJSONObject(T ...)(ref Value map, T t) if( (t.length % 2) == 0) {
    foreach(idx, what ; t) {
        static if( (idx % 2) == 0) {
            auto key = t[idx];
            auto value=t[idx+1];
            map[key] = encode(value);
        }
    }
}

//Example:
//loadJSON("settings.json").readJSONObject( "renderSettings", &renderSettings.serializableSettings,
//                                          "controlSettings", &controlSettings.serializableSettings);
//
void readJSONObject(T...)(Value value, T t) if( (t.length % 2) == 0) {
    enforce(value.type == Value.Type.object, "Can't read a non-object json-value as an object, merplerp");
    foreach(idx, what ; t) {
        static if( (idx % 2) == 0) {
            auto key = t[idx];
            auto valuePtr=t[idx+1];
            assert(isPointer!(typeof(valuePtr)));

            if(key in value) {
                static if( is(typeof(valuePtr) == Value*)) {
                    *valuePtr = value[key];
                } else {
                    value[key].read(*valuePtr);
                }
            }
        }
    }
}

// lat sta!
// den som andrar detta far stryk!
string prettifyJSON(Value val){
    return prettifyJSON(to!string(val));
}
string prettifyJSON(string text){
	int tabs = 0;
	text = std.array.replace(text, "," ,",\n");
	text = std.array.replace(text, "{" ,"{\n");
	text = std.array.replace(text, "}" ,"\n}");
	string[] asdf = std.string.splitLines(text);
	text = "";
	foreach(fdsa; asdf){
		if (countUntil(fdsa, "}") != -1){
			tabs--;
		}
		for (int a = 0; a < tabs; a++){
			std.array.insertInPlace(fdsa, 0, "  ");
		}
		if (countUntil(fdsa, "{") != -1){
			tabs++;
		}
		text = text ~ fdsa;
		text = text ~ "\n";
	}
	
	return text;
}


/*
Does not work. Fix plol! :D
unittest {

    string complexString = "abc\"def\"ghi\0åäö'";

    auto val = encode(complexString);

    auto str = to!string(val);
    val = parse(str);
    
    string decoded;
    val.read(decoded);
    BREAK_IF(decoded != complexString);

}
*/
