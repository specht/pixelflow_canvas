#pragma once
#include <stdint.h>

typedef enum {
    COLOR_MODE_RGB = 0,
    COLOR_MODE_PALETTE = 1
} ColorMode;

typedef enum {
    ADVANCE_MODE_RIGHT = 0,
    ADVANCE_MODE_DOWN = 1
} AdvanceMode;

typedef enum {
    DRAW_MODE_DIRECT = 0,
    DRAW_MODE_BUFFERED = 1
} DrawMode;

extern void canvas_init(int width, int height, ColorMode color_mode);
extern void canvas_dispose();
extern void canvas_set_color_mode(ColorMode mode);
extern void canvas_set_advance_mode(AdvanceMode mode);
extern void canvas_set_draw_mode(DrawMode mode);
extern void canvas_flip();
extern void canvas_ensure_max_fps(int fps);
extern void set_palette(int i, uint8_t r, uint8_t g, uint8_t b);
extern void move_to(int x, int y);
extern void set_pixel_rgb(int x, int y, uint8_t r, uint8_t g, uint8_t b);
extern uint32_t get_pixel_rgb(int x, int y);
extern void set_pixel(int x, int y, uint8_t c);
extern uint8_t get_pixel(int x, int y);

// typedef struct {
//     int width;
//     int height;
//     int x;
//     int y;
//     int color_mode;
//     int advance_mode;
//     int draw_mode;
//     unsigned char *palette;
//     unsigned char *screen;
//     int socket_fd;
//     double last_timestamp;
// } Canvas;

// void set_size(Canvas *canvas, int width, int height);
// void set_color_mode(Canvas *canvas, int mode);
// void recreate_screen(Canvas *canvas);
// void move_to(Canvas *canvas, int x, int y);
// void set_pixel(Canvas *canvas, int x, int y, int r, int g, int b);
// void flip(Canvas *canvas);

