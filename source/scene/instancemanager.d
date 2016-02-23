module scene.instancemanager;


import std.algorithm;
import std.exception;
import std.stdio;

import scene.scenemanager;
import scene.meshnode;
import graphics.camera;
import graphics.models.cgymodel;

import graphics.ogl;

final class InstanceManager {

    InstanceData**[] instancePtrArray;
    CGYMesh mesh;
    SceneManager sceneManager;
    SceneNodeShader shader;

    this(SceneManager _sceneManager, CGYMesh _mesh) {
        sceneManager = _sceneManager;
        mesh = _mesh;
    }

    bool dirty;
    uint instanceVBO;
    size_t instanceSize;
    InstanceData[] instanceData;


    void uploadInstanceData() {
        //TODO: Enable partial uploads?
        if(instanceSize == instanceData.length) {
            //All fine!
        } else{

            auto cap = instanceData.capacity;
            if(instanceSize != cap) {
                //Different size, we has capacity?
                instanceSize =  cap;
                ReleaseBuffer(instanceVBO);
                size_t size = InstanceData.sizeof * instanceSize;
                instanceVBO = CreateBuffer(BufferType.Array, size, null, GL_DYNAMIC_DRAW);
            }
        }
        size_t size = InstanceData.sizeof * instanceData.length;
        glBindBuffer(GL_ARRAY_BUFFER, instanceVBO); glError();
        glBufferSubData(GL_ARRAY_BUFFER, 0, size, instanceData.ptr); glError();
        
        dirty = false;
    }

    void register(InstanceData** ptrPtr) {
        instancePtrArray ~= ptrPtr;
        auto ptr = instanceData.ptr;
        instanceData.length = instanceData.length + 1;
        if(ptr !is instanceData.ptr) {
            foreach(idx, _ptrPtr ; instancePtrArray) {
                *_ptrPtr = &instanceData[idx];
            }
        } else {
            *ptrPtr = &instanceData[$-1];
        }
    }
    void unregister(InstanceData** ptrPtr) {
        auto idx = countUntil(instancePtrArray, ptrPtr);
        enforce(-1 != idx, "Error, trying to remove unexistant thing from InstanceManager");
        auto ptr = instanceData.ptr;
        instanceData[idx] = instanceData[$-1];
        instanceData.length = instanceData.length - 1;
        instancePtrArray[idx] = instancePtrArray[$-1];
        instancePtrArray.length = instancePtrArray.length - 1;

        if(ptr !is instanceData.ptr) {
            foreach(instanceIdx, _ptrPtr ; instancePtrArray) {
                *ptrPtr = &instanceData[instanceIdx];
            }
        }
    }

    void render(Camera camera) {
        uploadInstanceData();

        if(instanceVBO == 0) {
            return;
        }
        if(shader is null) {
            shader = sceneManager.getShader(mesh.shader);
        }
        mesh.texture.bind();
        glError();
        shader.use();
        auto transform = camera.getProjectionMatrix() * camera.getTargetMatrix();
        shader.setUniform(shader.VP, transform); 

        glEnableVertexAttribArray(0); glError();
        glEnableVertexAttribArray(1); glError();
        /*
        glEnableVertexAttribArray(2); glError();
        glEnableVertexAttribArray(3); glError();
        glEnableVertexAttribArray(4); glError();
        */
        glBindBuffer(GL_ARRAY_BUFFER, mesh.meshVBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().pos.offsetof); glError();
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().st.offsetof); glError();
        /*
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().normal.offsetof); glError();
        glVertexAttribPointer(3, 1, GL_UNSIGNED_INT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().bones.offsetof); glError();
        glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, cgyVertex.sizeof, cast(void*)cgyVertex().weights.offsetof); glError();
        */
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.idxVBO); glError();


        glBindBuffer(GL_ARRAY_BUFFER, instanceVBO); glError();

        glEnableVertexAttribArray(5); glError();
        glEnableVertexAttribArray(9); glError();
        glEnableVertexAttribArray(10); glError();
        /*
        glEnableVertexAttribArray(6); glError();
        glEnableVertexAttribArray(7); glError();
        glEnableVertexAttribArray(8); glError();
        */
        glVertexAttribDivisor(5, 1); glError();
        glVertexAttribDivisor(9, 1); glError();
        glVertexAttribDivisor(10, 1); glError();
        /*
        glVertexAttribDivisor(6, 1); glError();
        glVertexAttribDivisor(7, 1); glError();
        glVertexAttribDivisor(8, 1); glError();

        */
        glVertexAttribPointer(5, 3, GL_FLOAT, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().pos.offsetof); glError();
        glVertexAttribIPointer(9, 1, GL_UNSIGNED_INT, InstanceData.sizeof, cast(void*)InstanceData().texIdx.offsetof); glError();
        glVertexAttribPointer(10, 3, GL_FLOAT, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().scale.offsetof); glError();
        /*
        glVertexAttribPointer(6, 3, GL_FLOAT, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().rot.offsetof); glError();
        glVertexAttribPointer(7, 1, GL_UNSIGNED_BYTE, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().animationIndex.offsetof); glError();
        glVertexAttribPointer(8, 1, GL_UNSIGNED_BYTE, GL_FALSE, InstanceData.sizeof, cast(void*)InstanceData().frameIndex.offsetof); glError();
        */

        glDrawElementsInstanced(GL_TRIANGLES, 3*cast(int)mesh.triangles.length, GL_UNSIGNED_INT, cast(void*)0, cast(int)instanceData.length); glError();
        //glDrawElements(GL_TRIANGLES, 3*mesh.triangles.length, GL_UNSIGNED_INT, cast(void*)0);

        glVertexAttribDivisor(5, 0); glError();
        glVertexAttribDivisor(9, 0); glError();
        glVertexAttribDivisor(10, 0); glError();
        /*
        glVertexAttribDivisor(6, 0); glError();
        glVertexAttribDivisor(7, 0); glError();
        glVertexAttribDivisor(8, 0); glError();
        */
        glDisableVertexAttribArray(0); glError();
        glDisableVertexAttribArray(1); glError();
        glDisableVertexAttribArray(5); glError();
        glDisableVertexAttribArray(9); glError();
        glDisableVertexAttribArray(10); glError();
        /*
        glDisableVertexAttribArray(2); glError();
        glDisableVertexAttribArray(3); glError();
        glDisableVertexAttribArray(4); glError();
        glDisableVertexAttribArray(5); glError();
        glDisableVertexAttribArray(6); glError();
        glDisableVertexAttribArray(7); glError();
        glDisableVertexAttribArray(8); glError();
        */
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); glError();
        glBindBuffer(GL_ARRAY_BUFFER, 0); glError();
        shader.use(false);

        //Bind mesh data & textures
        //Aquire instance-vbo's
        //glBindBuffer(GL_ARRAY_BUFFER, instanceVBO);
        //foreach(instance ; modelList) {
        //Populate instance-vbo's
        //}
        //Render instances

    }
}
