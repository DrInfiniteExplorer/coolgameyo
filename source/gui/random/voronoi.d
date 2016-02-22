module gui.random.voronoi;



mixin template RandomVoronoi() {

    GuiElementImage voronoiImg;

    void initVoronoi() {
        voronoiImg = new GuiElementImage(container, Rectd(0, 0, 1, 1));
        renderVoronoi();
    }
    void renderVoronoi() {
        lines = null;
        immutable gridSize = 50;
        auto voronoi = new VoronoiWrapper(gridSize, gridSize, 880128);
        voronoi.setScale(vec2d(800, 600));

        Image img = Image(null, 800, 600);
        foreach(y ; 0 .. 600) {
            foreach(x ; 0 .. 800) {

                int id = voronoi.identifyCell(vec2d(x, y));
                immutable v = 2^^24;

                double ratio = (cast(double)id) / (gridSize*gridSize);
                int c = v - (cast(int)(cast(double)v * ratio));
                char* ptr = cast(char*)&c;
                char r = ptr[0];
                char g = ptr[1];
                char b = ptr[2];
                img.setPixel(x, y, r, g ,b);
            }
        }

        foreach(site ; voronoi.poly.sites) {
            foreach(he ; site.halfEdges) {
                auto a = he.getStartPoint();
                auto b = he.getEndPoint();
                if(a !is null ) {
                    vec2d _b;
                    bool c = true;
                    if(b !is null) {
                        _b = b.pos;
                    } else {
                        c = false;
                        BREAKPOINT;
                    }
                    auto _a = a.pos;
                    //Lines line;
                    //line.setLines(container.getAbsoluteRect, [_a, _b], c ? vec3f(0, 0, 0) : vec3f(0, 0, 1), vec2d(0, 0), vec2d(800, 600));
                    //lines ~= line;
                    img.drawLine(_a.convert!int, _b.convert!int, c ? vec3i(0, 0, 0) : vec3i(0, 0, 255));
                }
            }
        }
        this.voronoiImg.setImage(img);
    }
    void destroyVoronoi() {
        voronoiImg.destroy();
        voronoiImg = null;
        lines = null;
    }
}
