module scene.instancemanager;


import std.algorithm;
import std.exception;

import scene.scenemanager;
import scene.modelnode;
import graphics.models.cgymodel;

import graphics.ogl;

final class InstanceManager {
    ModelNode[] nodes;
    CGYMesh mesh;

    this(CGYMesh _mesh) {
        mesh = _mesh;
    }

    bool dirty;
    uint instanceVBO;
    size_t instanceSize;
    InstanceData instanceData[];


    void uploadInstanceData() {
        //TODO: Enable partial uploads?
        if(instanceSize == instanceData.length) {
            //All fine!
        } else{

            auto cap = instanceData.capacity;
            if(instanceSize != cap) {
                //Different size, we has capacity?
                instanceSize =  cap;
                glDeleteBuffers(1, &instanceVBO);
                glGenBuffers(1, &instanceVBO);
                glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
                size_t size = InstanceData.sizeof * instanceSize;
                glBufferData(GL_ARRAY_BUFFER, size, null, GL_DYNAMIC_DRAW);
            }
        }
        size_t size = InstanceData.sizeof * instanceData.length;
        glBufferSubData(GL_ARRAY_BUFFER, 0, size, instanceData.ptr);

        dirty = false;
    }

    void register(ModelNode modelNode) {
        nodes ~= modelNode;
        instanceData.length = instanceData.length + 1;
    }
    void unregister(ModelNode modelNode) {
        auto idx = countUntil(nodes, modelNode);
        enforce(-1 != idx, "Error, trying to remove unexistant thing from InstanceManager");
        nodes[idx] = nodes[$-1];
        nodes.length = nodes.length - 1;
        instanceData[idx] = instanceData[$-1];
        instanceData.length = instanceData.length - 1;
    }

    void render() {
        if(dirty) {
            uploadInstanceData();
        }

        /*

        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        glEnableVertexAttribArray(2); glError();
        glEnableVertexAttribArray(3); glError();
        glEnableVertexAttribArray(4); glError();
        glBindBuffer(GL_ARRAY_BUFFER, mesh.meshVBO);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().st.offsetof); glError();
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().pos.offsetof); glError();
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().normal.offsetof); glError();
        glVertexAttribPointer(3, 4, GL_UNSIGNED_BYTE, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().bones.offsetof); glError();
        glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().weights.offsetof); glError();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.idxVBO); glError();


        glBindBuffer(GL_ARRAY_BUFFER, instanceVBO); glError();

        glEnableVertexAttribArray(5); glError();
        glEnableVertexAttribArray(6); glError();
        glEnableVertexAttribArray(7); glError();
        glEnableVertexAttribArray(8); glError();
        glVertexAttribDivisor(5, 1); glError();
        glVertexAttribDivisor(6, 1); glError();
        glVertexAttribDivisor(7, 1); glError();
        glVertexAttribDivisor(8, 1); glError();

        glVertexAttribPointer(5, 3, GL_FLOAT, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().pos.offsetof); glError();
        glVertexAttribPointer(6, 3, GL_FLOAT, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().rot.offsetof); glError();
        glVertexAttribPointer(7, 1, GL_UNSIGNED_BYTE, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().animationIndex.offsetof); glError();
        glVertexAttribPointer(8, 1, GL_UNSIGNED_BYTE, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().frameIndex.offsetof); glError();

        glDrawElementsInstanced(GL_TRIANGLES, mesh.triangles.length, GL_UNSIGNED_INT, cast(void*)0, instanceData.length); glError();

        glVertexAttribDivisor(5, 0); glError();
        glVertexAttribDivisor(6, 0); glError();
        glVertexAttribDivisor(7, 0); glError();
        glVertexAttribDivisor(8, 0); glError();

        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(2); glError();
        glDisableVertexAttribArray(3); glError();
        glDisableVertexAttribArray(4); glError();

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();

        //Bind mesh data & textures
        //Aquire instance-vbo's
        //glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
        //foreach(instance ; modelList) {
        //Populate instance-vbo's
        //}
        //Render instances
        */

    }
}
