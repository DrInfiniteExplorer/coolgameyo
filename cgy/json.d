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


import std.range, std.algorithm, std.stdio, std.exception, std.conv;
import std.file, std.traits;

struct Value {
    enum Type : ubyte { string, number, object, array, bool_, null_, } 

    Type type;

    union { // tagged by type
        string str_;
        real num_;
        Value[string] pairs;
        Value[] elements;   // TODO: Make getter setter range thing
        bool boolval;
    }

    bool opIn_r(string name) {
        enforce (type == Type.object);
        return !!(name in pairs); //TODO: WTF is !! ????
    }
    Value opIndex(string name) {
        enforce (type == Type.object);
        return pairs[name];
    }
    Value opIndex(size_t index) {
        enforce (type == Type.array);
        return elements[index];
    }
    string str() @property const {
        if (type == Type.string) return str_;
        if (type == Type.null_) return null;
        enforce(0, "Not a string or null");
        return "";
    }
    real num() @property const {
        enforce (type == Type.number);
        return num_;
    }
    bool boolVal() @property const {
        enforce (type == Type.bool_); 
        return boolval;
    }

    bool opCast(T : bool)() const { return boolVal; }
    bool isNull() @property const { return type !is Type.null_; }

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
    this(real n) { type = Type.number; num_ = n; }
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

    real eatReal(ref string s, bool negative, real n) {
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
        auto r = text(negative ? "-" : "", n, old[0 .. old.length - s.length]);
        //msg(s);
        return to!real(r); // BUG LINE?
    }

    struct Token {
        Tag tag;
        union {
            string str; 
            real num;
        }
        this(Tag t) { tag = t; }
        this(string s) { tag = Tag.string; str = s; }
        this(real n) { tag = Tag.number; num = n; }
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
                          return Token(eatReal(s, false, c-'0'));
                default:
                          assert (false, text("invalid json, no case for ", c));
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
                    text("Expected ", tag, ", found ", front.tag));
            popFront();
        }
        this(string data) {
            s = data;
            popFront();
        }
    }

    Value parseValue(string s) { return parseValue(new Input(s)); }
    Value parseValue(Input i) {
        string s; real n;
        //msg(to!string(i.front.tag));
        switch (i.front.tag) {
            case Tag.string: s = i.front.str; i.popFront(); return Value(s);
            case Tag.number: n = i.front.num; i.popFront(); return Value(n);
            case Tag.lmus: return parseObject(i);
            case Tag.lbra: return parseArray(i);
            case Tag.true_: i.popFront(); return Value(true);
            case Tag.false_: i.popFront(); return Value(false);
            case Tag.null_: i.popFront(); return Value.nullValue();
            default:
                enforce(0, "json.d parseValue got to default case, error!");
                return Value(false);
        }
    }

    Value parseObject(Input i) {
        i.skip(Tag.lmus);
        Value[string] blep;
        while (i.front.tag != Tag.rmus) {
            enforce(i.front.tag == Tag.string);
            string s = i.front.str;
            i.popFront();
            //msg("parsed ", s);
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
        while (true) {
            blep ~= parseValue(i);
            if (i.front.tag != Tag.comma) break;
            else i.popFront();
        }
        i.skip(Tag.rbra);
        return Value(blep);
    }
}

alias Parser.parseValue parse;


T read(T)(string s) { return read!T(parse(s)); }
T read(T)(Value val) {
    static if (isNumeric!T) {
        return to!T(val.num);
    } else static if (is (T : string)) {
        return val.str;
    } else static if (is (T : bool)) {
        return val.boolVal;
    } else static if (is (T == struct)) {
        T t;
        update!T(&t, val);
        return t;
    } else static if (is (T U : U[])) {
        U[] us;
        foreach (e; val.elements) {
            us ~= read!U(e);
        }
        return us;
    } else {
        msg("Json cannot read '", M.stringof, " ", m,
                "' in ", T.stringof,
                " because I don't know what it is!");
    }
}

void update(T)(T* t, string s) { return update!T(t, parse(s)); }
void update(T)(T* t, Value val) {
    foreach (m; __traits(allMembers, T)) {
        alias typeof(__traits(getMember, *t, m)) M;
        static if (isSomeFunction!(__traits(getMember, T, m))){
            continue;
        } else {
            if (m !in val) continue;
            static if (is (M == struct)) {
                update(&__traits(getMember, *t, m), val[m]);            
            } else static if (__traits(compiles, read!M(val[m]))){
                __traits(getMember, *t, m) = read!M(val[m]);
            }
        }
    }
}

Value encode(T)(T t) {
    static if (isNumeric!T || is (T : string) || is (T : bool)) {
        return Value(t);
    } else static if (is (T == struct)) {
        Value[string] blep;
        foreach (m; __traits(allMembers, T)) { 
            static if (isSomeFunction!(__traits(getMember, T, m))) {
                continue;
            } else {
                blep[m] = encode(__traits(getMember, t, m));
            }
        }
        return Value(blep);
    } else static if (is (T U : U[])) {
        return Value(array(map!(encode!U)(t)));
    } else {
        pragma (msg, "cannot encode ", T);
        assert (0);
    }
}

// lat sta!
// den som andrar detta far stryk!
string prettyfyJSON(string text){
	int tabs = 0;
	text = std.array.replace(text, "," ,",\n");
	text = std.array.replace(text, "{" ,"{\n");
	text = std.array.replace(text, "}" ,"\n}");
	string[] asdf = std.string.splitLines(text);
	text = "";
	foreach(fdsa; asdf){
		if (indexOf(fdsa, "}") != -1){
			tabs--;
		}
		for (int a = 0; a < tabs; a++){
			std.array.insertInPlace(fdsa, 0, "  ");
		}
		if (indexOf(fdsa, "{") != -1){
			tabs++;
		}
		text = text ~ fdsa;
		text = text ~ "\n";
	}
	
	return text;
}
