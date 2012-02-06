module entities.workshop;

import entities.entity;

struct Recipy {
    Entity[] inputs;
    Entity[] outputs;
    int time;
    // like animations and whatev
}

struct Workshop {
    // workshop related state, etC
    Recipy[] recipies;
}
