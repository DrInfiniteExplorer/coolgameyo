

module scene.modelnode;

import util.util;

import scene.scenemanager;

import graphics.models.cgymodel;


class ModelNode : SceneNode {
    vec3d position;

    uint[] texIdx;
    CGYMesh[] meshes;
    AnimationState animState;

    int snapJoint = -1;

    this(cgyModel model, AnimationState _animState) {
        meshes = model.meshes;
        texIdx.length = meshes.length;
        animState = _animState;
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        destroyed = true;
    }

    void setPosition(vec3d pos) {
        position = pos;
    }

    vec3d getPosition() {
        return position;
    }
    uint getTexIdx(int idx) const {
        return texIdx[idx];
    }

    SceneNodeType getType() {
        return SceneNodeType.Model;
    }

    //Set to -1 to use vertex bones.
    void snapToJoint(int joint) {
        snapJoint = joint;
    }

    void render() {
    }

    void setTexture(int meshId, SceneManager sceneManager, string texture) {
        auto mesh = meshes[meshId];
        if(mesh.texture is null) {
            mesh.texture = sceneManager.loadArrayTexture(texture, texIdx[meshId]);
        } else {
            texIdx[meshId] = mesh.texture.loadImage(texture);
        }
    }

}
