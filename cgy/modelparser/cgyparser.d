module modelparser.cgyparser;

import std.stdio, std.exception, std.range, std.regex, std.algorithm;
import std.conv, std.string, std.file, std.typecons;
import std.math;

import util.util;
import stolen.quaternion;

class cgyParserException : Exception {
    this(string msg, string file, size_t line) {
        super(text(file, "(", line, "): ", msg));
    }
}

alias enforceEx!cgyParserException cgyenforce;

final class Joint {
    string name;
    int parent;
    vec3f pos;
    quaternion orientation;
}

final class Vert {
    vec3f pos;
    float s, t;
    int jointId[4];
    float weight[4];
}

final class Tri {
    uint[3] verts;
}



final class Mesh {
    string shader;
    string name;
    Vert[] verts;
    Tri[] tris;
}

final class cgyFileData {
    size_t cgyVersion; // should be 10 :p
    string commandline;

    Joint[] joints;
    Mesh[] meshes;

    this() {}
}


cgyFileData parseModel(string data) {
    auto lines = filter!(a => !a.empty)(
            map!(a => to!string(a.until("//")).strip())(data.split("\n")));
    string[][] tokens = array(map!(
                a => array(std.regex.splitter(a, regex(r"\s+"))))(lines));

    /*
    foreach (line; tokens) {
        writeln(line);
    }
    */

    cgyFileData ret = new cgyFileData;
    auto nums = parseHeader(ret, tokens);

    size_t numJoints = nums[0];
    size_t numMeshes = nums[1];

    //writeln("parsed header!");
    //writeln(ret.commandline);
    //writeln(numJoints);
    //writeln(numMeshes);

    ret.joints = parseJoints(tokens, numJoints);

    //writeln("parsed joints");

    cgyenforce(numJoints == ret.joints.length);

    while (canFindMesh(tokens)) {
        ret.meshes ~= parseMesh(tokens, ret.joints);
    }
    //writeln("parsed meshes");

    cgyenforce(numMeshes == ret.meshes.length);
    return ret;
}

void extract(Ts...)(string[] tokens, Ts ts) {
    cgyenforce(tokens.length == ts.length);
    foreach (i, t; ts) {
        static if (is(typeof(t) T : T*)) {
            *t = to!T(tokens[i]);
        } else {
            static assert (is(typeof(t) == string));
            cgyenforce(tokens[i] == t, 
                    "Mismatch! (" ~ tokens[i] ~ " != " ~ t ~ ")");
        }
    }
}

Tuple!(size_t, size_t) parseHeader(cgyFileData ret, ref string[][] tokens) {
    cgyenforce(tokens.length > 4);

    extract(tokens[0], "cgyVersion", "10");
    ret.cgyVersion = 10;

    string commandline;
    extract(tokens[1], "commandline", &commandline);
    ret.commandline = commandline[1 .. $-1];

    size_t numJoints, numMeshes;

    extract(tokens[2], "numJoints", &numJoints);
    extract(tokens[3], "numMeshes", &numMeshes);

    tokens = tokens[4 .. $];

    return tuple(numJoints, numMeshes);
}


Joint[] parseJoints(ref string[][] tokens, size_t numJoints) {
    cgyenforce(tokens.length >= numJoints + 2);

    Joint[] ret;

    extract(tokens.front, "joints", "{");
    tokens.popFront();
    ret.length = numJoints;
    foreach (idx, line; tokens[0 .. numJoints]) {
        Joint j = new Joint();
        ret[idx] = j;
        string name;
        int parent_index;
        extract(line, &name, &j.parent, 
                "(", &j.pos.x, &j.pos.y, &j.pos.z, ")", 
                "(", &j.orientation.X, &j.orientation.Y, &j.orientation.Z, ")");
        j.name = name[1 .. $-1];

        //writeln(j.pos);

        auto tmp = 1.0f - 
            j.orientation.X*j.orientation.X -
            j.orientation.Y*j.orientation.Y -
            j.orientation.Z*j.orientation.Z;
        if(tmp <= 0.0f) {
            j.orientation.W = 0.0f;
        } else {
            j.orientation.W = -sqrt(tmp);
        }


        // TODO: calculate_quad_w(j.orientation);
    }

    tokens = tokens[numJoints .. $];
    extract(tokens.front, "}");
    tokens.popFront();

    return ret;
}

Mesh parseMesh(ref string[][] tokens, Joint[] joints) {
    cgyenforce(tokens.length >= 6);
    extract(tokens[0], "mesh", "{");

    Mesh m = new Mesh;

    size_t[] vert_weight_indices, vert_weight_lengths;

    string name;
    extract(tokens[1], "name", &name);
    m.name = name[1 .. $-1];

    string shader;
    extract(tokens[2], "shader", &shader);
    m.shader = shader[1 .. $-1];

    size_t numverts;
    extract(tokens[3], "numverts", &numverts);

    tokens = tokens[4 .. $];
    foreach (i; 0 .. numverts) {
        Vert v = new Vert;

        size_t index, length;
        extract(tokens[i], 
                "vert", to!string(i), &v.pos.x, &v.pos.y, &v.pos.z,
                "(", &v.s, &v.t, ")",
                "(", &v.jointId[0], &v.jointId[1], &v.jointId[2], &v.jointId[3],
                &v.weight[0], &v.weight[1], &v.weight[2], &v.weight[3], ")");


        m.verts ~= v;
        vert_weight_indices ~= index;
        vert_weight_lengths ~= length;
    }

    tokens = tokens[numverts .. $];

    size_t numtris;
    extract(tokens.front, "numtris", &numtris);
    tokens.popFront();


    foreach (i; 0 .. numtris) {
        Tri tri = new Tri();
        extract(tokens[i], "tri", to!string(i), &tri.verts[0], &tri.verts[1], &tri.verts[2]);
        m.tris ~= tri;
    }

    tokens = tokens[numtris .. $];

    extract(tokens.front, "}");
    tokens.popFront();

    return m;
}

bool canFindMesh(ref string[][] tokens) {
    return !tokens.empty && tokens.front[0] == "mesh";
}

