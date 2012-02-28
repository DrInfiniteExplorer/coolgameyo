module graphics.models.cgymodel;

import util.util;
import stolen.quaternion;

import graphics.ogl;

import modelparser.cgyparser;

struct cgyVertex {
    float st[2];
    vec3f pos;
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

struct cgyMesh {
    cgyVertex[] vertices;
    cgyTri[] triangles;
    uint meshVBO;
    uint idxVBO;
}

class cgyModel {


    string[] jointNames;
    cgyJoint[] joints;
    cgyMesh[] meshes;

    void loadMesh(cgyFileData meshData) {

        clearMeshes();

        joints.length = meshData.joints.length;
        jointNames.length = meshData.joints.length;
        foreach(idx, joint ; meshData.joints) {
            jointNames[idx] = joint.name;
            joints[idx].parent = joint.parent;
            joints[idx].position = convert!float(joint.pos);
            joints[idx].rotation = joint.orientation;
        }

        meshes.length = meshData.meshes.length;

        foreach(idx, mesh ; meshData.meshes) {
            cgyMesh* meshPtr = &meshes[idx];
            meshPtr.vertices.length = mesh.verts.length;
            foreach(idx, vertex ; mesh.verts) {
                cgyVertex* vert = &meshPtr.vertices[idx];
                vert.st[0] = vertex.s;
                vert.st[1] = vertex.t;
                vert.bones[] = 0;
                vert.weights[] = 0.0f;
                vert.pos.set(0.0f, 0.0f, 0.0f);
                float weightSum = 0.0f;
                foreach(idx, weight ; vertex.weights) {

                    vec3f unWeighted = 
                        joints[weight.jointId].position +
                        joints[weight.jointId].rotation * weight.pos;
                    vert.pos += unWeighted * weight.bias;

                    vert.bones[idx] = cast(char)weight.jointId;
                    vert.weights[idx] = weight.bias;
                    weightSum += weight.bias;
                }
            }


            meshPtr.triangles.length = mesh.tris.length;
            foreach(idx, triangle ; mesh.tris) {
                cgyTri* tri = &meshPtr.triangles[idx];
                tri.idx[] = triangle.verts[];
            }
        }

        uploadMeshData();

    }

    void uploadMeshData() {
        foreach(idx, mesh ; meshes) {
            uploadMeshData(mesh);
        }
    }

    void uploadMeshData(cgyMesh mesh) {
        clearMesh(mesh); //No fancy partial uploading here!
        glGenBuffers(1, &mesh.meshVBO);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.meshVBO);
        auto geometrySize = mesh.vertices.length * cgyVertex.sizeof;
        glBufferData(GL_ARRAY_BUFFER, geometrySize, mesh.vertices.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &mesh.idxVBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.idxVBO);
        auto idxSize = 3 * mesh.triangles.length * uint.sizeof;
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, idxSize, mesh.triangles.ptr, GL_STATIC_DRAW);
    }

    void clearMeshes() {
        foreach(idx, mesh ; meshes) {
            clearMesh(mesh);
        }
        meshes = null;

    }
    void clearMesh(cgyMesh mesh) {
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glDeleteBuffers(1, &mesh.idxVBO);
        glDeleteBuffers(1, &mesh.meshVBO);
        mesh.idxVBO = 0;
        mesh.meshVBO = 0;
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


