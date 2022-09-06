module emu.hw.gpu.gpu3d.polygon;

import emu;
import util;

struct Vertex {
    Point pos;
    int r;
    int g;
    int b;
    Point texcoord;
}

struct Polygon {
    Vertex[10] vertices; // max-gon is ten-gon
    int num_vertices;

    bool uses_textures;

    int texture_vram_offset;
    bool texture_repeat_s_direction;
    bool texture_repeat_t_direction;
    bool texture_flip_s_direction;
    bool texture_flip_t_direction;
    int texture_s_size;
    int texture_t_size;
    TextureFormat texture_format;
    bool texture_color_0_transparent;
    Word palette_base_address;
}

interface PolygonAssembler {
    bool submit_vertex(Vertex vertex);
    Polygon get_polygon(Polygon p);
    void reset();
}

final class TriangleAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        vertices[index] = vertex;
        index++;

        if (index > 2) {
            index = 0;
            return true;
        }

        return false;
    }

    Polygon get_polygon(Polygon p) {
        p.vertices[0..3] = vertices[0..3];
        p.num_vertices = 3;
        return p;
    }

    void reset() {
        index = 0;
    }
}

final class QuadAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        bool new_quad_created = index >= 3;

        vertices[index] = vertex;
        index++;

        if (index >= 4) {
            index = 0;
        }

        return new_quad_created;
    }

    Polygon get_polygon(Polygon p) {
        p.vertices[0..4] = vertices[0..4];
        p.num_vertices = 4;
        return p;
    }

    void reset() {
        index = 0;
    }
}

final class TriangleStripsAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    override bool submit_vertex(Vertex vertex) {
        vertices[index] = vertex;
        index++;

        return index >= 3;
    }

    Polygon get_polygon(Polygon p) {
        p.vertices[0..3] = vertices[0..3];
        p.num_vertices = 3;
        
        vertices[0] = vertices[1];
        vertices[1] = vertices[2];
        index = 2;

        return p;
    }

    void reset() {
        index = 0;
    }
}

final class QuadStripsAssembler : PolygonAssembler {
    int index = 0;
    Vertex[4] vertices;

    static immutable int[4] mapped_indices = [0, 1, 3, 2];

    override bool submit_vertex(Vertex vertex) {
        vertices[mapped_indices[index]] = vertex;
        index++;

        return index >= 4;
    }

    Polygon get_polygon(Polygon p) {     
        p.vertices[0..4] = vertices[0..4];
        p.num_vertices = 4;

        index = 2;
        vertices[0] = vertices[3];
        vertices[1] = vertices[2];
        return p;
    }

    void reset() {
        index = 0;
    }
}