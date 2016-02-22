

module scene.meshnode;

import util.util;

import scene.scenemanager;

import graphics.models.cgymodel;


class MeshNode : SceneNode {
    vec3d position;

    CGYMesh mesh;
    AnimationState animState;

    int snapJoint = -1;

    this(CGYMesh _mesh, AnimationState _animState) {
        mesh = _mesh;
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


    SceneNodeType getType() {
        return SceneNodeType.Model;
    }

    //Set to -1 to use vertex bones.
    void snapToJoint(int joint) {
        snapJoint = joint;
    }

    void render() {
    }

    //Sets the texture of the mesh, and returns the sub-index in the texture array.
    uint setTexture(SceneManager sceneManager, string texture) {
        if(mesh.texture is null) {
            uint idx;
            mesh.texture = sceneManager.loadArrayTexture(texture, idx);
            return idx;
        } else {
            return mesh.texture.loadImage(texture);
        }
    }

}
