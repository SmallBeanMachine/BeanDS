module emu.hw.gpu.gpu3d.rendering_engine;

import core.sync.condition;
import core.sync.mutex;
import core.thread;

import std.algorithm;

import emu;
import util;


bool deboog = false;

alias AnnotatedPolygon = RenderingEngine.AnnotatedPolygon;

final class RenderingEngine {
    struct AnnotatedPolygon {
        struct AnnotatedVertex {
            int index;
            bool left;
        }

        this(Polygon!Point_20_12 p, RenderingEngine rendering_engine) {
            this.orig = p;

            for (int i = 0; i < p.num_vertices; i++) {
                viewport_coords[i] = Point_14_18([
                    rendering_engine.to_screen_coords_x(this.orig.vertices[i].pos[0], this.orig.vertices[i].pos[3]),
                    rendering_engine.to_screen_coords_y(this.orig.vertices[i].pos[1], this.orig.vertices[i].pos[3]),
                    this.orig.vertices[i].pos[2].convert!(14, 18),
                    this.orig.vertices[i].pos[3].convert!(14, 18)
                ]);
                // log_gpu3d("conversion from %f to %f", cast(float) this.orig.vertices[i].pos[2], cast(float) this.orig.vertices[i].pos[2].convert!(14, 18));

                // if (deboog) log_gpu3d("[DEBOOG]    funnycoords: (%f, %f) reprs: (%x %x)",
                //     cast(float) viewport_coords[i][0], 
                //     cast(float) viewport_coords[i][1],
                //     viewport_coords[i][0].repr, 
                //     viewport_coords[i][1].repr,
                // );

                // // log_gpu3d("coord: (%s, %s)", viewport_coords[i][0], viewport_coords[i][1]);

                // if (viewport_coords[i][0])
            }

            this.clockwise = (
                    (this.orig.vertices[1].pos[1] - this.orig.vertices[0].pos[1]) * (this.orig.vertices[2].pos[0] - this.orig.vertices[1].pos[0]) -
                    (this.orig.vertices[1].pos[0] - this.orig.vertices[0].pos[0]) * (this.orig.vertices[2].pos[1] - this.orig.vertices[1].pos[1])
                ) > 0; //(
                // (this.orig.vertices[1].pos[0] - this.orig.vertices[0].pos[0]) * (this.orig.vertices[2].pos[1] - this.orig.vertices[0].pos[1]) -
                // (this.orig.vertices[1].pos[1] - this.orig.vertices[1].pos[0]) * (this.orig.vertices[2].pos[0] - this.orig.vertices[0].pos[0])
            // ) < 0;

            // if (deboog) // log_gpu3d("[DEBOOG] cockwise: %x %s", this.clockwise,
            //     (
            //         (this.orig.vertices[1].pos[1] - this.orig.vertices[0].pos[1]) * (this.orig.vertices[2].pos[0] - this.orig.vertices[1].pos[0]) -
            //         (this.orig.vertices[1].pos[0] - this.orig.vertices[0].pos[0]) * (this.orig.vertices[2].pos[1] - this.orig.vertices[1].pos[1])
            //     )
            // );

            int topleft_vertex_index  = 0;
            int botright_vertex_index = 0;
            int topright_vertex_index = 0;
            int botleft_vertex_index  = 0;

            for (int j = 1; j < p.num_vertices; j++) {
                float topleft_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[topleft_vertex_index][0];
                float topleft_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[topleft_vertex_index][1];
                float botright_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[botright_vertex_index][0];
                float botright_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[botright_vertex_index][1];
                float topright_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[topright_vertex_index][0];
                float topright_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[topright_vertex_index][1];
                float botleft_dx = cast(float) viewport_coords[j][0] - cast(float) viewport_coords[botleft_vertex_index][0];
                float botleft_dy = cast(float) viewport_coords[j][1] - cast(float) viewport_coords[botleft_vertex_index][1];
                // log_gpu3d("sussine[%d]: %f %f %f %f %f %f %f %f %f %f",
                //     j,
                //     cast(float) topleft_dx,
                //     cast(float) topleft_dy,
                //     cast(float) botright_dx,
                //     cast(float) botright_dy,
                //     cast(float) topright_dx,
                //     cast(float) topright_dy,
                //     cast(float) botleft_dx,
                //     cast(float) botleft_dy,
                //     cast(float) topleft_vertex_index,
                //     cast(float) botright_vertex_index
                // );
                if (topleft_dy > 0 || (topleft_dy == 0 && topleft_dx < 0)) topleft_vertex_index = j;
                if (botright_dy < 0 || (botright_dy == 0 && botright_dx > 0)) botright_vertex_index = j;
                if (topright_dy > 0 || (topright_dy == 0 && topright_dx > 0)) topright_vertex_index = j;
                if (botleft_dy < 0 || (botleft_dy == 0 && botleft_dx < 0)) botleft_vertex_index = j;
            }

            annotated_vertices[orig.num_vertices - 1].left = annotated_vertices[orig.num_vertices - 2].left;

            annotated_vertices[0] = AnnotatedVertex(topleft_vertex_index, clockwise);
            // log_gpu3d("topleft vtx: %d", topleft_vertex_index);
            top_y = cast(int) viewport_coords[topleft_vertex_index][1];

            int max_left_vertex_y  = cast(int) viewport_coords[botright_vertex_index][1];
            int max_right_vertex_y = cast(int) viewport_coords[botright_vertex_index][1];
            int max_left_vertex_index = topleft_vertex_index + (clockwise ? -1 : 1);
            int max_right_vertex_index = topright_vertex_index + (clockwise ? 1 : -1);
            if (max_left_vertex_index >= orig.num_vertices) max_left_vertex_index = 0;
            if (max_left_vertex_index < 0) max_left_vertex_index = orig.num_vertices - 1;
            if (max_right_vertex_index >= orig.num_vertices) max_right_vertex_index = 0;
            if (max_right_vertex_index < 0) max_right_vertex_index = orig.num_vertices - 1;

            left_index  = max_left_vertex_index;
            right_index = max_right_vertex_index;
            previous_left_index  = topleft_vertex_index;
            previous_right_index = topright_vertex_index;

            uint dec_index = clockwise ? left_index : right_index;
            uint inc_index = clockwise ? right_index : left_index;
            uint prev_inc_index = inc_index;
            uint prev_dec_index = dec_index;
            inc_index++;
            dec_index--;

            if (dec_index == -1) dec_index = p.num_vertices - 1;
            if (inc_index == p.num_vertices) inc_index = 0;
            
            bool inc_has_reached_destination = false;
            bool dec_has_reached_destination = false;

            int i = 2;
            while (!inc_has_reached_destination || !dec_has_reached_destination) {
                if (dec_has_reached_destination && !inc_has_reached_destination) {
                    annotated_vertices[i] = AnnotatedVertex(inc_index, !clockwise);
                    prev_inc_index = inc_index;
                    inc_has_reached_destination = inc_index == botright_vertex_index;
                    // if (!inc_has_reached_destination) {
                        inc_index++;
                        if (inc_index == p.num_vertices) inc_index = 0;
                        i++;
                    // }
                } else

                if (inc_has_reached_destination && !dec_has_reached_destination) {
                    annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                    prev_dec_index = dec_index;
                    dec_has_reached_destination = dec_index == botright_vertex_index;
                    // if (!dec_has_reached_destination) {
                        dec_index--;
                        if (dec_index == -1) dec_index = orig.num_vertices - 1;
                        i++;
                    // }
                } else

                {
                    if (viewport_coords[prev_inc_index][1] < viewport_coords[prev_dec_index][1]) {
                        annotated_vertices[i] = AnnotatedVertex(dec_index, clockwise);
                        prev_dec_index = dec_index;
                        dec_has_reached_destination = dec_index == botright_vertex_index;
                        // if (!dec_has_reached_destination) {
                            dec_index--;
                            if (dec_index == -1) dec_index = orig.num_vertices - 1;
                            i++;
                        // }
                    } else {
                        annotated_vertices[i] = AnnotatedVertex(inc_index, !clockwise);
                        prev_inc_index = inc_index;
                        inc_has_reached_destination = inc_index == botright_vertex_index;
                        // if (!inc_has_reached_destination) {
                            inc_index++;
                            if (inc_index == p.num_vertices) inc_index = 0;
                            i++;
                        // }
                    }
                }
            }


            for (int j = 0; j < p.num_vertices + 2; j++) {
                // if (deboog)
                    // log_gpu3d("[DEBOOG] annotatedcoords: %d %s", annotated_vertices[j].index, annotated_vertices[j].left ? "left" : "right");

                // // log_gpu3d("coord: (%s, %s)", viewport_coords[i][0], viewport_coords[i][1]);

                // if (viewport_coords[i][0])
            }

            // if (deboog) // log_gpu3d("[DEBOOG] BOT_Y OPTIONS! %s %s", viewport_coords[inc_index][1], viewport_coords[dec_index][1]);
            bot_y = viewport_coords[left_index][1] > viewport_coords[right_index][1] ? cast(int) viewport_coords[left_index][1] : cast(int) viewport_coords[right_index][1];
            annotated_vertex_next = 2;
        }

        int annotated_vertex_next;
        AnnotatedVertex[10] annotated_vertices;
        int previous_left_index;
        int previous_right_index;
        int left_index;
        int right_index;
        int top_y;
        int bot_y;
        
        Polygon!Point_20_12 orig;
        bool clockwise;
        Point_14_18[10] viewport_coords;
    }

    GPU3D parent;

    int num_polygons = 0;

    Pixel[] scanline;

    AnnotatedPolygon[0x1000] annotated_polygons;

    Mutex     start_rendering_mutex;
    Condition start_rendering_condvar;
    Thread    rendering_thread;

    Mutex     rendering_scanline_mutex;
    int       rendering_scanline;
    bool      is_rendering;

    this(GPU3D parent) {
        this.parent = parent;
        this.start_rendering_mutex    = new Mutex();
        this.start_rendering_condvar  = new Condition(start_rendering_mutex);
        this.rendering_thread         = new Thread(&rendering_thread_handler).start();
        this.rendering_scanline_mutex = new Mutex();
        this.is_rendering             = false;
    }

    void vblank() {
        annotate_polygons();
    }

    Coord_14_18 get_slope(Coord_14_18 dy, Coord_14_18 dx) {
        if (dx == 0) return Coord_14_18.from_repr(0x7FFFFFFF);
        if (dy == 0) return Coord_14_18.from_repr(0x00000001);
        // log_gpu3d("getting slope from dx dy %f %f", cast(float) dx, cast(float) dy);
        return dy / dx;
    }

    void annotate_polygons() {
        // // log_gpu3d("annotating %x polygons", num_polygons);
        for (int i = 0; i < num_polygons; i++) {
            // log_gpu3d("Annotating Polygon #%d!", i);
            deboog = true || i == 1;
            annotated_polygons[i] = AnnotatedPolygon(parent.rendering_buffer[i], this);
        }
    }

    Coord_14_18 to_screen_coords_x(Coord_20_12 x, Coord_20_12 w) {
        Coord_14_18 xprime = x.convert!(14, 18);
        Coord_14_18 wprime = w.convert!(14, 18);
        // log_gpu3d("prime stuff: %f %f %f %f", cast(float) x, cast(float) xprime,cast(float) w, cast(float) wprime);
        // log_gpu3d("calculation stuff: %f %f %f %f %f %f",
        //     cast(float) (xprime + wprime).to_unsigned_float,
        //     cast(float) (wprime * 2).to_unsigned_float,
        //     cast(float) ((parent.viewport_x2 - parent.viewport_x1)),
        //     cast(float) (((parent.viewport_x2 - parent.viewport_x1) / (wprime * 2))).to_unsigned_float,
        //     cast(float) ((xprime + wprime) * ((parent.viewport_x2 - parent.viewport_x1) / (wprime * 2))).to_unsigned_float,
        //     cast(float) ((xprime + wprime) * ((parent.viewport_x2 - parent.viewport_x1) / (wprime * 2)) + parent.viewport_x1).to_unsigned_float
        // );
        auto blah = ((xprime + wprime) * ((parent.viewport_x2 - parent.viewport_x1) / (wprime * 2)));
        // log_gpu3d("result: %f %x", blah.to_unsigned_float, blah.repr);
        return blah;
    }

    Coord_14_18 to_screen_coords_y(Coord_20_12 y, Coord_20_12 w) {
        // log_gpu3d("viewport stuff: %d %d %d %d", parent.viewport_y1, parent.viewport_y2, parent.viewport_x1, parent.viewport_x2);
        Coord_14_18 yprime = y.convert!(14, 18);
        Coord_14_18 wprime = w.convert!(14, 18);
        // log_gpu3d("prime stuff: %f %f %f %f", cast(float) y, cast(float) yprime,cast(float) w, cast(float) wprime);
        // log_gpu3d("calculation stuff: %f %f %f %f %f %f", cast(float) yprime, cast(float) wprime, cast(float) yprime + wprime, cast(float) (yprime + wprime) * (parent.viewport_y2 - parent.viewport_y1),
        // cast(float) (wprime * 2) + parent.viewport_y1), cast(float) ((yprime + wprime) * (parent.viewport_y2 - parent.viewport_y1) / (wprime * 2) + parent.viewport_y1));
        // log_gpu3d("calculation stuff: %f %f %f %f %f",
        //     cast(float) (yprime + wprime),
        //     cast(float) (wprime * 2),
        //     cast(float) ((parent.viewport_y2 - parent.viewport_y1)),
        //     cast(float) (((parent.viewport_y2 - parent.viewport_y1) / (wprime * 2))),
        //     cast(float) ((yprime + wprime) * ((parent.viewport_y2 - parent.viewport_y1) / (wprime * 2)))
        // );
        return ((yprime + wprime) * ((parent.viewport_y2 - parent.viewport_y1) / (wprime * 2)) + parent.viewport_y1);
    }

    Coord_14_18[3] get_interpolation_weights(Coord_14_18 x1, Coord_14_18 x2, Coord_14_18 x3, Coord_14_18 y1, Coord_14_18 y2, Coord_14_18 y3, Coord_14_18 px, Coord_14_18 py) {
        Coord_14_18 w1 = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coord_14_18 w2 = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / ((y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3));
        Coord_14_18 w3 = 1 - w1 - w2;
        return [w1, w2, w3];
    }

    // tysm https://melonds.kuribo64.net/comments.php?id=85
    // not a perfect implementation of the above yet but... 
    // TODO???: maybe make interpolation more accurate?
    Coord_14_18 get_interpolation_factor(Coord_14_18 xmax, Coord_14_18 x, Coord_14_18 w0, Coord_14_18 w1) {
        return ((xmax - x) * 1) / ((xmax - x) * 1 + x * 1);
    }

    Coord_14_18 interpolate(T)(T a0, T a1, Coord_14_18 factor) {
        return (1 - factor) * a0 + factor * a1;
    }

    void rendering_thread_handler() {
        while (true) {
            synchronized (start_rendering_mutex) {
                start_rendering_condvar.wait();
            }
                
            synchronized (rendering_scanline_mutex) {
                rendering_scanline = -1;
                is_rendering       = true;
            }
            
            annotate_polygons();

            for (int scanline = 0; scanline < 192; scanline++) {
                render(scanline);
                
                synchronized (rendering_scanline_mutex) {
                    rendering_scanline = scanline;
                }
            }

            synchronized (rendering_scanline_mutex) {
                is_rendering = false;
            }
        }
    }

    void begin_rendering_frame() {
        synchronized (start_rendering_mutex) {
            start_rendering_condvar.notify();
        }
    }

    void wait_for_rendering_to_finish(int scanline) {
        while (true) {
            synchronized (rendering_scanline_mutex) {
                if (!is_rendering || rendering_scanline >= scanline) return;
            }
        }
    }

    // ya this is NOT correct at all and WILL break games (e.g. mario kart).
    // TODO: make the timings of the rendering engine actually decent
    void render(int scanline) {
        parent.start_rendering_scanline(scanline);
        
        auto effective_scanline = 192 - scanline;

        // if (num_polygons>15) num_polygons = 15;

        for (int i = 0; i < num_polygons; i++) {
            log_gpu3d("rendering funky polygon #%d", i);
            auto p = annotated_polygons[i];
            auto left_xy  = p.viewport_coords[p.left_index] [0..2];
            auto right_xy = p.viewport_coords[p.right_index][0..2];

            // log_gpu3d("determined. do we even render? %d >= %d >= %d.", p.top_y, effective_scanline, p.bot_y);
            if (p.top_y >= effective_scanline && effective_scanline >= p.bot_y) {
                auto start_x = (effective_scanline - cast(int) left_xy[1]) / 
                    get_slope(
                        p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                        p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                    ) + cast(int) left_xy[0];

                auto end_x = (effective_scanline - cast(int) right_xy[1]) / 
                    get_slope(
                        p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                        p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    ) + cast(int) right_xy[0];

                // log_gpu3d("determined slopes: (left: %f, right: %f)", 
                //     cast(float) get_slope(
                //         p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                //         p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                //     ),
                //     cast(float) get_slope(
                //         p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                //         p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                //     )
                // );
                // log_gpu3d("determined components to calculate left slope: (%f %f), (%f %f)", 
                //     cast(float) p.viewport_coords[p.previous_left_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.previous_left_index][1].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.left_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.left_index][1].to_unsigned_float
                // );
                // log_gpu3d("determined components to calculate right slope: (%f %f), (%f %f)", 
                //     cast(float) p.viewport_coords[p.previous_right_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.previous_right_index][1].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.right_index][0].to_unsigned_float,
                //     cast(float) p.viewport_coords[p.right_index][1].to_unsigned_float
                // );

                int effective_start_x = start_x.integral_part;
                int effective_end_x   = end_x.integral_part;

                if (start_x < 0)   effective_start_x = 0;
                if (start_x > 255) effective_start_x = 255;
                if (end_x < 0)     effective_end_x = 0;
                if (end_x > 255)   effective_end_x = 255;

                // stupid hack
                // if (start_x <= )

                if (effective_start_x == 0 && effective_end_x == 0) {
                    log_gpu3d("bug!");

                    log_gpu3d("determined slopes: (left: %f, right: %f)", 
                        cast(float) get_slope(
                            p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1], 
                            p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0]
                        ),
                        cast(float) get_slope(
                            p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1], 
                            p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                        )
                    );
                    log_gpu3d("determined components to calculate left slope: (%f %f), (%f %f)", 
                        cast(float) p.viewport_coords[p.previous_left_index][0].to_unsigned_float,
                        cast(float) p.viewport_coords[p.previous_left_index][1].to_unsigned_float,
                        cast(float) p.viewport_coords[p.left_index][0].to_unsigned_float,
                        cast(float) p.viewport_coords[p.left_index][1].to_unsigned_float
                    );
                    log_gpu3d("determined components to calculate right slope: (%f %f), (%f %f)", 
                        cast(float) p.viewport_coords[p.previous_right_index][0].to_unsigned_float,
                        cast(float) p.viewport_coords[p.previous_right_index][1].to_unsigned_float,
                        cast(float) p.viewport_coords[p.right_index][0].to_unsigned_float,
                        cast(float) p.viewport_coords[p.right_index][1].to_unsigned_float
                    );
                    log_gpu3d("the sussy subtractions: %s %s %s %s", 
                        p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1],
                        p.viewport_coords[p.previous_left_index][0] - p.viewport_coords[p.left_index][0],
                        p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1],
                        p.viewport_coords[p.previous_right_index][0] - p.viewport_coords[p.right_index][0]
                    );
                }

                auto factor_l = get_interpolation_factor(
                    p.viewport_coords[p.previous_left_index][1] - p.viewport_coords[p.left_index][1],
                    effective_scanline - p.viewport_coords[p.left_index][1],
                    p.viewport_coords[p.previous_left_index][3],
                    p.viewport_coords[p.left_index][3]
                );

                auto factor_r = get_interpolation_factor(
                    p.viewport_coords[p.previous_right_index][1] - p.viewport_coords[p.right_index][1],
                    effective_scanline - p.viewport_coords[p.right_index][1],
                    p.viewport_coords[p.previous_right_index][3],
                    p.viewport_coords[p.right_index][3]
                );

                for (int x = effective_start_x; x < effective_end_x; x++) {
                    auto w_l = interpolate(p.viewport_coords[p.previous_left_index][3], p.viewport_coords[p.left_index][3], factor_l);
                    auto w_r = interpolate(p.viewport_coords[p.previous_right_index][3], p.viewport_coords[p.right_index][3], factor_r);
                    auto z_l = interpolate(p.viewport_coords[p.previous_left_index][2], p.viewport_coords[p.left_index][2], factor_l);
                    auto z_r = interpolate(p.viewport_coords[p.previous_right_index][2], p.viewport_coords[p.right_index][2], factor_r);

                    auto factor_scanline = get_interpolation_factor(
                        Coord_14_18(cast(int) end_x - cast(int) start_x),
                        Coord_14_18(x - cast(int) start_x),
                        w_l,
                        w_r
                    );

                    int r;
                    int g;
                    int b;
                    int a = 0;

                    factor_l = clamp(factor_l, Coord_14_18(0.0f), Coord_14_18(1.0f));
                    factor_r = clamp(factor_r, Coord_14_18(0.0f), Coord_14_18(1.0f));

                    if (p.orig.uses_textures) {
                        auto texcoord_s_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[0].convert!(14, 18), p.orig.vertices[p.left_index].texcoord[0].convert!(14, 18), factor_l);
                        auto texcoord_s_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[0].convert!(14, 18), p.orig.vertices[p.right_index].texcoord[0].convert!(14, 18), factor_r);
                        auto texcoord_t_l = interpolate(p.orig.vertices[p.previous_left_index].texcoord[1].convert!(14, 18), p.orig.vertices[p.left_index].texcoord[1].convert!(14, 18), factor_l);
                        auto texcoord_t_r = interpolate(p.orig.vertices[p.previous_right_index].texcoord[1].convert!(14, 18), p.orig.vertices[p.right_index].texcoord[1].convert!(14, 18), factor_r);

                        auto texcoord_s = interpolate(texcoord_s_l, texcoord_s_r, 1 - factor_scanline);
                        auto texcoord_t = interpolate(texcoord_t_l, texcoord_t_r, 1 - factor_scanline);
                        
                        auto color = get_color_from_texture(cast(int) texcoord_s, cast(int) texcoord_t, p, p.orig.palette_base_address);
                        r = cast(int) color[0] << 1;
                        g = cast(int) color[1] << 1;
                        b = cast(int) color[2] << 1;
                        a = cast(int) color[3];
                    } else {
                        auto r_l = interpolate(p.orig.vertices[p.previous_left_index].r << 4, p.orig.vertices[p.left_index].r << 4, factor_l);
                        auto r_r = interpolate(p.orig.vertices[p.previous_right_index].r << 4, p.orig.vertices[p.right_index].r << 4, factor_r);
                        auto g_l = interpolate(p.orig.vertices[p.previous_left_index].g << 4, p.orig.vertices[p.left_index].g << 4, factor_l);
                        auto g_r = interpolate(p.orig.vertices[p.previous_right_index].g << 4, p.orig.vertices[p.right_index].g << 4, factor_r);
                        auto b_l = interpolate(p.orig.vertices[p.previous_left_index].b << 4, p.orig.vertices[p.left_index].b << 4, factor_l);
                        auto b_r = interpolate(p.orig.vertices[p.previous_right_index].b << 4, p.orig.vertices[p.right_index].b << 4, factor_r);

                        // log_gpu3d("The result of interpolation: %f %f %d %f %f %f %f %f %f", 
                        //     cast(float) end_x,
                        //     cast(float) start_x, 
                        //     x, 
                        //     cast(float) r_l, 
                        //     cast(float) r_r, 
                        //     cast(float) p.orig.vertices[p.previous_left_index].r,
                        //     cast(float) p.orig.vertices[p.left_index].r,
                        //     cast(float) factor_l,
                        //     cast(float) factor_scanline
                        // );

                        r = cast(int) interpolate(r_l, r_r, 1 - factor_scanline) >> 3;
                        g = cast(int) interpolate(g_l, g_r, 1 - factor_scanline) >> 3;
                        b = cast(int) interpolate(b_l, b_r, 1 - factor_scanline) >> 3;
                        a = 31;
                    }
                
                    // TODO: we will only need either z or w, never both. only calculate the one we need (assuming interpolation is a bottleneck)
                    Coord_14_18 z = interpolate(z_l, z_r, 1 - factor_scanline);
                    Coord_14_18 w = interpolate(w_l, w_r, 1 - factor_scanline);
                    parent.plot(scanline, Pixel(r, g, b, a), x, z, w);
                }
            }

            if (effective_scanline == p.bot_y) {
                p.top_y = p.bot_y;

                if (p.annotated_vertices[p.annotated_vertex_next].left) {
                    p.previous_left_index = p.left_index;
                    p.left_index = p.annotated_vertices[p.annotated_vertex_next].index;
                } else {
                    p.previous_right_index = p.right_index;
                    p.right_index = p.annotated_vertices[p.annotated_vertex_next].index;
                }

                p.bot_y = max(cast(int) p.viewport_coords[p.left_index][1], cast(int) p.viewport_coords[p.right_index][1]);
                p.annotated_vertex_next++;

                // log_gpu3d("determined annotated vertex next: %d, %d, %d, %d, %d", p.annotated_vertex_next, p.top_y, p.bot_y, p.left_index, p.right_index);
            }

            annotated_polygons[i] = p;
        }
            
        parent.stop_rendering_scanline();
    }
}