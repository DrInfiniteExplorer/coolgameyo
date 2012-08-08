module graphics.models.cgymodel;

import std.stdio;

import util.util;
import stolen.quaternion;

import graphics.ogl;
import scene.texturearray;

import modelparser.cgyparser;

struct cgyVertex {
    vec3f pos;
    float st[2];
    vec3f normal;
    ubyte[4] bones;
    float[4] weights;
}

struct cgyJoint {
    int parent;
    vec3f position;
    quaternion rotation;
}

struct cgyTri {
    uint idx[3];
}

final class CGYMesh {
    cgyVertex[] vertices;
    cgyTri[] triangles;
    uint meshVBO;
    uint idxVBO;
    TextureArray texture;
    string shader = "shaders/models/scenenode";
    string name;
}

final class cgyModel {


    string[] jointNames;
    cgyJoint[] joints;
    CGYMesh[] meshes;

    bool _clearMeshes = false;
    bool _uploadMeshData = false;

    this() {
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        clearMeshes();
        destroyed = true;
    }

    void loadMesh(cgyFileData meshData) {

        joints.length = meshData.joints.length;
        jointNames.length = meshData.joints.length;
        foreach(idx, joint ; meshData.joints) {
            jointNames[idx] = joint.name;
            joints[idx].parent = joint.parent;
            joints[idx].position = joint.pos.convert!float();
            writeln(joints[idx].position, " ", joint.pos.convert!float());
            joints[idx].rotation = joint.orientation;
        }

        meshes.length = meshData.meshes.length;

        foreach(idx, mesh ; meshData.meshes) {
            auto newMesh = new CGYMesh();
            meshes[idx] = newMesh;
            //TODO: Fix thingy mahjingy
            //newMesh.shader = mesh.shader;
            newMesh.name = mesh.name;

            newMesh.vertices.length = mesh.verts.length;
            foreach(idx, vertex ; mesh.verts) {
                cgyVertex* vert = &newMesh.vertices[idx];
                vert.pos = vertex.pos;
                vert.st[0] = vertex.s;
                vert.st[1] = vertex.t;
                vert.weights[] = vertex.weight[];
                foreach( i ; 0 .. 4) {
                    vert.bones[i] = cast(ubyte)vertex.jointId[i];
                }
            }


            newMesh.triangles.length = mesh.tris.length;
            foreach(idx, triangle ; mesh.tris) {
                cgyTri* tri = &newMesh.triangles[idx];
                tri.idx[] = triangle.verts[];
            }
        }

        _uploadMeshData = true;

    }

    void uploadMeshData() {
        foreach(idx, mesh ; meshes) {
            uploadMeshData(mesh);
        }
    }

    void uploadMeshData(CGYMesh mesh) {
        clearMesh(mesh); //No fancy partial uploading here!
        glGenBuffers(1, &mesh.meshVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.meshVBO);
        auto geometrySize = mesh.vertices.length * cgyVertex.sizeof;
        glBufferData(GL_ARRAY_BUFFER, geometrySize, mesh.vertices.ptr, GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glGenBuffers(1, &mesh.idxVBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.idxVBO);
        auto idxSize = 3 * mesh.triangles.length * uint.sizeof;
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, idxSize, mesh.triangles.ptr, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    void clearMeshes() {
        foreach(idx, mesh ; meshes) {
            clearMesh(mesh);
        }

    }
    void clearMesh(CGYMesh mesh) {
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glDeleteBuffers(1, &mesh.idxVBO);
        glDeleteBuffers(1, &mesh.meshVBO);
        mesh.idxVBO = 0;
        mesh.meshVBO = 0;
    }

    void prepare() {
        if(_uploadMeshData) {
            _uploadMeshData = false;
            uploadMeshData();
        }
    }

    /* Simple renderindation */
    void render() {
        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        glEnableVertexAttribArray(2); glError();
        glEnableVertexAttribArray(3); glError();
        glEnableVertexAttribArray(4); glError();

/*
        float st[2];
        vec3f pos;
        vec3f normal;
        char[4] bones;
        float[4] weights;
*/
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, null /* offset in vbo */); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().pos.offsetof); glError();
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().normal.offsetof); glError();
        glVertexAttribPointer(3, 4, GL_UNSIGNED_BYTE, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().bones.offsetof); glError();
        glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().weights.offsetof); glError();

        foreach(mesh ; meshes) {
            glBindBuffer(GL_ARRAY_BUFFER, mesh.meshVBO); glError();
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.idxVBO); glError();
            glDrawElements(GL_TRIANGLES, mesh.triangles.length, GL_UNSIGNED_INT, /*offset in idx-vbo*/cast(void*)0); glError();
        }

        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(2); glError();
        glDisableVertexAttribArray(3); glError();
        glDisableVertexAttribArray(4); glError();

    }
}


