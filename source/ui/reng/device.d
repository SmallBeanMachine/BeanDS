module ui.reng.device;

import emu.hw;
import raylib;
import re;
import std.format;
import std.string;
import ui.device;
import ui.reng;

class RengMultimediaDevice : MultiMediaDevice {
    enum SAMPLE_RATE            = 48_000;
    enum SAMPLES_PER_UPDATE     = 4096;
    enum BUFFER_SIZE_MULTIPLIER = 3;
    enum NUM_CHANNELS           = 2;

    enum FAST_FOWARD_KEY        = Keys.KEY_TAB;

    RengCore reng_core;
    DSVideo  ds_video;
    AudioStream stream;

    bool fast_foward;

    string rom_title;
    int fps;

    this(int screen_scale, bool full_ui) {
        Core.target_fps = 999;
        reng_core = new RengCore(screen_scale, full_ui);

        InitAudioDevice();
        SetAudioStreamBufferSizeDefault(SAMPLES_PER_UPDATE);
        stream = LoadAudioStream(SAMPLE_RATE, 16, NUM_CHANNELS);
        PlayAudioStream(stream);
        
        ds_video = Core.jar.resolve!DSVideo().get; 
    }

    override {
        // video stuffs
        void present_videobuffers(Pixel[192][256]* buffer_top, Pixel[192][256]* buffer_bot) {
            for (int y = 0; y < 192; y++) {
            for (int x = 0; x < 256;  x++) {
                    ds_video.videobuffer_top[y * 256 + x] = 
                        ((*buffer_top)[x][y].r << 2 <<  0) |
                        ((*buffer_top)[x][y].g << 2 <<  8) |
                        ((*buffer_top)[x][y].b << 2 << 16) |
                        0xFF000000;
                    ds_video.videobuffer_bot[y * 256 + x] = 
                        ((*buffer_bot)[x][y].r << 2 <<  0) |
                        ((*buffer_bot)[x][y].g << 2 <<  8) |
                        ((*buffer_bot)[x][y].b << 2 << 16) |
                        0xFF000000;
            }
            }
        }

        void set_fps(int fps) {
            this.fps = fps;
            redraw_title();
        }

        void update_rom_title(string rom_title) {
            import std.string;
            this.rom_title = rom_title.splitLines[0].strip;
            redraw_title();
        }

        void update_icon(Pixel[32][32] buffer_texture) {
            import std.stdio;

            uint[32 * 32] icon_texture;

            for (int x = 0; x < 32; x++) {
            for (int y = 0; y < 32; y++) {
                icon_texture[y * 32 + x] = 
                    (buffer_texture[x][y].r << 2 <<  0) |
                    (buffer_texture[x][y].g << 2 <<  8) |
                    (buffer_texture[x][y].b << 2 << 16) |
                    (buffer_texture[x][y].a << 3 << 24);
            }
            }

            ds_video.update_icon(icon_texture);
        }

        // 2 cuz stereo
        short[NUM_CHANNELS * SAMPLES_PER_UPDATE * BUFFER_SIZE_MULTIPLIER] buffer;
        int buffer_cursor = 0;

        void push_sample(Sample s) {
            buffer[buffer_cursor + 0] = s.L;
            buffer[buffer_cursor + 1] = s.R;
            buffer_cursor += 2;
        }

        void update() {
            handle_input();
            handle_audio();
            reng_core.update_pub();
        }

        void draw() {
            reng_core.draw_pub();
        }

        bool should_cycle_nds() {
            return buffer_cursor < NUM_CHANNELS * BUFFER_SIZE_MULTIPLIER * SAMPLES_PER_UPDATE - (SAMPLE_RATE / 60) * 2;
        }

        void handle_input() {
            import std.algorithm.comparison;

            update_key(DSKeyCode.PEN_DOWN, Input.is_mouse_down(MOUSE_LEFT_BUTTON));

            auto mouse_position = Input.mouse_position();

            update_touchscreen_position(
                clamp(cast(int) mouse_position.x,       0, 256),
                clamp(cast(int) mouse_position.y - 192, 0, 192)
            );
            
            static foreach (re_key, gba_key; keys) {
                update_key(gba_key, Input.is_key_down(re_key));
            }

            fast_foward = Input.is_key_down(FAST_FOWARD_KEY);
        }

        bool should_fast_forward() {
            return fast_foward;
        }
    }

    void redraw_title() {
        import std.format;
        ds_video.update_title("%s [FPS: %d]".format(rom_title, fps));
    }

    void handle_audio() {
        if (IsAudioStreamProcessed(stream)) {
            UpdateAudioStream(stream, cast(void*) buffer, SAMPLES_PER_UPDATE);
            
            for (int i = 0; i < NUM_CHANNELS * SAMPLES_PER_UPDATE * (BUFFER_SIZE_MULTIPLIER - 1); i++) {
                buffer[i] = buffer[i + NUM_CHANNELS * SAMPLES_PER_UPDATE];
            }

            buffer_cursor -= NUM_CHANNELS * SAMPLES_PER_UPDATE;
            if (buffer_cursor < 0) buffer_cursor = 0;

            if (fast_foward) buffer_cursor = 0;
        }
    }

    enum keys = [
        Keys.KEY_Z     : DSKeyCode.A,
        Keys.KEY_X     : DSKeyCode.B,
        Keys.KEY_SPACE : DSKeyCode.SELECT,
        Keys.KEY_ENTER : DSKeyCode.START,
        Keys.KEY_RIGHT : DSKeyCode.RIGHT,
        Keys.KEY_LEFT  : DSKeyCode.LEFT,
        Keys.KEY_UP    : DSKeyCode.UP,
        Keys.KEY_DOWN  : DSKeyCode.DOWN,
        Keys.KEY_A     : DSKeyCode.X,
        Keys.KEY_S     : DSKeyCode.Y,
        Keys.KEY_E     : DSKeyCode.R,
        Keys.KEY_Q     : DSKeyCode.L
    ];
}