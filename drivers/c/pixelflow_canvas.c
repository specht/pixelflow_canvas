#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <time.h>

#include "pixelflow_canvas.h"

int width = 320;
int height = 180;
int x = 0;
int y = 0;
int socket_fd = 0;
uint8_t* screen = NULL;
ColorMode color_mode = COLOR_MODE_RGB;
AdvanceMode advance_mode = ADVANCE_MODE_RIGHT;
DrawMode draw_mode = DRAW_MODE_DIRECT;

void recreate_screen() {
    if (screen) {
        free(screen);
        screen = NULL;
    }
    int size = width * height * (color_mode == COLOR_MODE_RGB ? 3 : 1);
    screen = (uint8_t *)malloc(size);
    memset(screen, 0, size);
}

void set_size(int _width, int _height) {
    x = 0;
    y = 0;
    width = _width;
    height = _height;
    recreate_screen();
    unsigned char buffer[5];
    buffer[0] = 1;
    buffer[1] = (width >> 8) & 0xFF;
    buffer[2] = width & 0xFF;
    buffer[3] = (height >> 8) & 0xFF;
    buffer[4] = height & 0xFF;
    write(socket_fd, buffer, 5);
    fsync(socket_fd);
}

void canvas_init(int _width, int _height, ColorMode color_mode) {
    width = _width;
    height = _height;
    x = 0;
    y = 0;
    canvas_set_color_mode(color_mode);
    canvas_set_advance_mode(ADVANCE_MODE_RIGHT);
    canvas_set_draw_mode(DRAW_MODE_DIRECT);
    struct sockaddr_in server_addr;
    socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(19223);
    inet_pton(AF_INET, "127.0.0.1", &server_addr.sin_addr);
    connect(socket_fd, (struct sockaddr*)&server_addr, sizeof(server_addr));
    set_size(_width, _height);
}

void canvas_dispose() {
    if (screen) {
        free(screen);
        screen = NULL;
    }
    close(socket_fd);
}

void canvas_set_color_mode(ColorMode mode) {
    color_mode = mode;
    unsigned char buffer[2];
    buffer[0] = 2;
    buffer[1] = mode;
    write(socket_fd, buffer, 2);
    fsync(socket_fd);
}

void canvas_set_advance_mode(AdvanceMode mode) {
    advance_mode = mode;
    unsigned char buffer[2];
    buffer[0] = 4;
    buffer[1] = mode;
    write(socket_fd, buffer, 2);
    fsync(socket_fd);
}

void canvas_set_draw_mode(DrawMode mode) {
    draw_mode = mode;
}

void canvas_flip() {
    if (draw_mode == DRAW_MODE_BUFFERED) {
        unsigned char buffer[1];
        buffer[0] = 7;
        write(socket_fd, buffer, 1);
        fsync(socket_fd);
    }
}

void canvas_ensure_max_fps(int fps) {
    // TODO: Implement this
}

void set_palette(int i, uint8_t r, uint8_t g, uint8_t b) {
    unsigned char buffer[5];
    buffer[0] = 3;
    buffer[1] = i;
    buffer[2] = r;
    buffer[3] = g;
    buffer[4] = b;
    write(socket_fd, buffer, 5);
    fsync(socket_fd);
}

void move_to(int _x, int _y) {
    if (_x < 0 || _x >= width || _y < 0 || _y >= height) {
        return;
    }
    x = _x;
    y = _y;
    unsigned char buffer[5];
    buffer[0] = 5;
    int size = 1;
    if (width > 256) {
        buffer[size++] = (x >> 8) & 0xFF;
        buffer[size++] = x & 0xFF;
    } else {
        buffer[size++] = x;
    }
    if (height > 256) {
        buffer[size++] = (y >> 8) & 0xFF;
        buffer[size++] = y & 0xFF;
    } else {
        buffer[size++] = y;
    }
    write(socket_fd, buffer, size);
    fsync(socket_fd);
}

void set_pixel_rgb(int _x, int _y, uint8_t r, uint8_t g, uint8_t b) {
    if (color_mode != COLOR_MODE_RGB) return;
    if (_x < 0 || _x >= width || _y < 0 || _y >= height) return;
    if (_x != x || _y != y) move_to(_x, _y);
    int offset = (y * width + x) * 3;
    screen[offset + 0] = r;
    screen[offset + 1] = g;
    screen[offset + 2] = b;
    if (draw_mode == DRAW_MODE_DIRECT) {
        unsigned char buffer[4];
        buffer[0] = 6;
        buffer[1] = r;
        buffer[2] = g;
        buffer[3] = b;
        write(socket_fd, buffer, 4);
        fsync(socket_fd);
    }
    if (advance_mode == ADVANCE_MODE_RIGHT) {
        x++;
        if (x >= width) {
            x = 0;
            y = (y + 1) % height;
        }
    } else {
        y++;
        if (y >= height) {
            y = 0;
            x = (x + 1) % width;
        }
    }
}

uint32_t get_pixel_rgb(int _x, int _y) {
    if (color_mode != COLOR_MODE_RGB) return 0;
    if (_x < 0 || _x >= width || _y < 0 || _y >= height) return 0;
    int offset = (_y * width + _x) * 3;
    return (screen[offset + 0] << 16) | (screen[offset + 1] << 8) | screen[offset + 2];
}

void set_pixel(int _x, int _y, uint8_t c) {
    if (color_mode != COLOR_MODE_PALETTE) return;
    if (_x < 0 || _x >= width || _y < 0 || _y >= height) return;
    if (_x != x || _y != y) move_to(_x, _y);
    int offset = y * width + x;
    screen[offset] = c;
    if (draw_mode == DRAW_MODE_DIRECT) {
        unsigned char buffer[2];
        buffer[0] = 6;
        buffer[1] = c;
        write(socket_fd, buffer, 2);
        fsync(socket_fd);
    }
    if (advance_mode == ADVANCE_MODE_RIGHT) {
        x++;
        if (x >= width) {
            x = 0;
            y = (y + 1) % height;
        }
    } else {
        y++;
        if (y >= height) {
            y = 0;
            x = (x + 1) % width;
        }
    }

}

uint8_t get_pixel(int _x, int _y) {
    if (color_mode != COLOR_MODE_PALETTE) return 0;
    if (_x < 0 || _x >= width || _y < 0 || _y >= height) return 0;
    int offset = _y * width + _x;
    return screen[offset];
}
