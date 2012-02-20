module modelparser.md5parser;

import std.stdio, std.exception, std.range, std.regex, std.algorithm;
import std.conv, std.string, std.file, std.typecons;

import util.util;
import stolen.quaternion;

class MD5ParserException : Exception {
    this(string msg, string file, size_t line) {
        super(text(file, "(", line, "): ", msg));
    }
}

alias enforceEx!MD5ParserException md5enforce;

final class Joint {
    string name;
    Joint parent;
    vec3d pos;
    quaternion orientation;
}

final class Vert {
    float s, t;
    Weight[] weights;
}

final class Tri {
    Vert[3] verts;
}

final class Weight {
    Joint joint;
    float bias;
    vec3d pos;
}


final class Mesh {
    string shader;
    Vert[] verts;
    Tri[] tris;
    Weight[] weights;
}

final class MD5FileData {
    size_t MD5Version; // should be 10 :p
    string commandline;

    Joint[] joints;
    Mesh[] meshes;

    this() {}
}



MD5FileData parse(string data) {
    auto lines = filter!(a => !a.empty)(
            map!(a => to!string(a.until("//")).strip())(data.split("\n")));
    string[][] tokens = array(map!(
                a => array(std.regex.splitter(a, regex(r"\s+"))))(lines));

    foreach (line; tokens) {
        writeln(line);
    }

    MD5FileData ret = new MD5FileData;
    auto nums = parseHeader(ret, tokens);

    size_t numJoints = nums[0];
    size_t numMeshes = nums[1];

    writeln("parsed header!");
    writeln(ret.commandline);
    writeln(numJoints);
    writeln(numMeshes);

    ret.joints = parseJoints(tokens, numJoints);

    writeln("parsed joints");

    md5enforce(numJoints == ret.joints.length);

    while (canFindMesh(tokens)) {
        ret.meshes ~= parseMesh(tokens, ret.joints);
    }
    writeln("parsed meshes");

    md5enforce(numMeshes == ret.meshes.length);
    return ret;
}

void extract(Ts...)(string[] tokens, Ts ts) {
    md5enforce(tokens.length == ts.length);
    foreach (i, t; ts) {
        static if (is(typeof(t) T : T*)) {
            *t = to!T(tokens[i]);
        } else {
            static assert (is(typeof(t) == string));
            md5enforce(tokens[i] == t, 
                    "Mismatch! (" ~ tokens[i] ~ " != " ~ t ~ ")");
        }
    }
}

Tuple!(size_t, size_t) parseHeader(MD5FileData ret, ref string[][] tokens) {
    md5enforce(tokens.length > 4);

    extract(tokens[0], "MD5Version", "10");
    ret.MD5Version = 10;

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
    md5enforce(tokens.length >= numJoints + 2);

    Joint[] ret;
    int[] parent_indices;
    extract(tokens.front, "joints", "{");
    tokens.popFront();
    foreach (line; tokens[0 .. numJoints]) {
        Joint j = new Joint;
        string name;
        int parent_index;
        float x, y, z;
        float a, b, c;
        extract(line, &name, &parent_index, 
                "(", &j.pos.X, &j.pos.Y, &j.pos.Z, ")", 
                "(", &j.orientation.X, &j.orientation.Y, &j.orientation.Z, ")");
        j.name = name[1 .. $-1];

        // TODO: calculate_quad_w(j.orientation);

        ret ~= j;
        parent_indices ~= parent_index;
    }

    foreach (i, joint; ret) {
        if (parent_indices[i] != -1) {
            joint.parent = ret[parent_indices[i]];
        }
    }

    tokens = tokens[numJoints .. $];
    extract(tokens.front, "}");
    tokens.popFront();

    return ret;
}

Mesh parseMesh(ref string[][] tokens, Joint[] joints) {
    md5enforce(tokens.length >= 6);
    extract(tokens[0], "mesh", "{");

    Mesh m = new Mesh;

    size_t[] vert_weight_indices, vert_weight_lengths;

    string shader;
    extract(tokens[1], "shader", &shader);
    m.shader = shader[1 .. $-1];

    size_t numverts;
    extract(tokens[2], "numverts", &numverts);

    tokens = tokens[3 .. $];
    foreach (i; 0 .. numverts) {
        Vert v = new Vert;

        size_t index, length;
        extract(tokens[i], 
                "vert", to!string(i), "(", &v.s, &v.t, ")", &index, &length);


        m.verts ~= v;
        vert_weight_indices ~= index;
        vert_weight_lengths ~= length;
    }

    tokens = tokens[numverts .. $];

    size_t numtris;
    extract(tokens.front, "numtris", &numtris);
    tokens.popFront();

    foreach (i; 0 .. numtris) {
        Tri t = new Tri;
        size_t[3] ks;
        extract(tokens[i], "tri", to!string(i), &ks[0], &ks[1], &ks[2]);
        t.verts[0] = m.verts[ks[0]];
        t.verts[1] = m.verts[ks[1]];
        t.verts[2] = m.verts[ks[2]];

        m.tris ~= t;
    }

    tokens = tokens[numtris .. $];

    size_t numweights;
    extract(tokens.front, "numweights", &numweights);
    tokens.popFront();

    foreach (i; 0 .. numweights) {
        Weight w = new Weight;

        size_t joint_index;

        float x,y,z;
        extract(tokens[i], "weight", to!string(i),
                &joint_index, &w.bias, "(", &x, &y, &z, ")");

        w.joint = joints[joint_index];

        m.weights ~= w;
    }

    tokens = tokens[numweights .. $];

    extract(tokens.front, "}");
    tokens.popFront();

    foreach (i, vert; m.verts) {
        vert.weights = m.weights[vert_weight_indices[i]
            .. vert_weight_indices[i] + vert_weight_lengths[i]];
    }

    return m;
}

bool canFindMesh(ref string[][] tokens) {
    return !tokens.empty && tokens.front[0] == "mesh";
}

