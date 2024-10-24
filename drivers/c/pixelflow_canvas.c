#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <time.h>

#define RGB 0
#define PALETTE 1

#define ADVANCE_RIGHT 0
#define ADVANCE_DOWN 1

#define DRAW_DIRECT 0
#define DRAW_BUFFERED 1

#include "pixelflow_canvas.h"

double current_time() {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

Canvas* init_canvas(int width, int height, int color_mode) {
    Canvas *canvas = (Canvas *)malloc(sizeof(Canvas));
    canvas->width = 320;
    canvas->height = 180;
    canvas->x = 0;
    canvas->y = 0;
    canvas->color_mode = RGB;
    canvas->advance_mode = ADVANCE_RIGHT;
    canvas->draw_mode = DRAW_DIRECT;
    canvas->palette = (unsigned char *)malloc(768);
    memset(canvas->palette, 0, 768);

    struct sockaddr_in server_addr;
    canvas->socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(19223);
    inet_pton(AF_INET, "127.0.0.1", &server_addr.sin_addr);
    connect(canvas->socket_fd, (struct sockaddr*)&server_addr, sizeof(server_addr));

    set_size(canvas, width, height);
    if (color_mode) set_color_mode(canvas, color_mode);
    canvas->last_timestamp = current_time();

    return canvas;
}

void set_size(Canvas *canvas, int width, int height) {
    canvas->x = 0;
    canvas->y = 0;
    canvas->width = width;
    canvas->height = height;
    recreate_screen(canvas);

    unsigned char buffer[5];
    buffer[0] = 1;
    buffer[1] = (width >> 8) & 0xFF;
    buffer[2] = width & 0xFF;
    buffer[3] = (height >> 8) & 0xFF;
    buffer[4] = height & 0xFF;

    write(canvas->socket_fd, buffer, 5);
    fsync(canvas->socket_fd);
}

void set_color_mode(Canvas *canvas, int mode) {
    if (mode != RGB && mode != PALETTE) {
        printf("Invalid color mode: %d\n", mode);
        return;
    }
    canvas->color_mode = mode;
    recreate_screen(canvas);

    unsigned char buffer[2];
    buffer[0] = 2;
    buffer[1] = mode;
    write(canvas->socket_fd, buffer, 2);
    fsync(canvas->socket_fd);
}

void recreate_screen(Canvas *canvas) {
    int size = canvas->width * canvas->height * (canvas->color_mode == RGB ? 3 : 1);
    canvas->screen = (unsigned char *)malloc(size);
    memset(canvas->screen, 0, size);
}

void move_to(Canvas *canvas, int x, int y) {
    if (x < 0 || x >= canvas->width || y < 0 || y >= canvas->height) return;
    canvas->x = x;
    canvas->y = y;

    unsigned char buffer[5];
    int size = 1;
    buffer[0] = 5;
    if (canvas->width <= 256) {
        buffer[size++] = x & 0xff;
    } else {
        buffer[size++] = (x >> 8) & 0xff;
        buffer[size++] = x & 0xff;
    }
    if (canvas->height <= 256) {
        buffer[size++] = y & 0xff;
    } else {
        buffer[size++] = (y >> 8) & 0xff;
        buffer[size++] = y & 0xff;
    }

    write(canvas->socket_fd, buffer, size);
    fsync(canvas->socket_fd);
}

void set_pixel(Canvas *canvas, int x, int y, int r, int g, int b) {
    if (x < 0 || x >= canvas->width || y < 0 || y >= canvas->height) return;
    if (x != canvas->x || y != canvas->y) {
        move_to(canvas, x, y);
    }

    if (canvas->color_mode == RGB) {
        int offset = (y * canvas->width + x) * 3;
        canvas->screen[offset] = r;
        canvas->screen[offset + 1] = g;
        canvas->screen[offset + 2] = b;
    } else {
        int offset = y * canvas->width + x;
        canvas->screen[offset] = r;
    }

    if (canvas->draw_mode == DRAW_DIRECT) {
        unsigned char buffer[4];
        buffer[0] = 6;
        if (canvas->color_mode == RGB) {
            buffer[1] = r;
            buffer[2] = g;
            buffer[3] = b;
            write(canvas->socket_fd, buffer, 4);
        } else {
            buffer[1] = r;
            write(canvas->socket_fd, buffer, 2);
        }
    }
    fsync(canvas->socket_fd);
    canvas->x++;
    if (canvas->x >= canvas->width) {
        canvas->x = 0;
        canvas->y = (canvas->y + 1) % canvas->height;
    }
}

int main() {
    Canvas *canvas = init_canvas(256, 256, RGB);
    set_pixel(canvas, 0, 0, 0, 255, 255);
    for (int x = 0; x < 256; x++) {
        set_pixel(canvas, x, 0, x, 0, 0);
        set_pixel(canvas, x, 2, 0, x, 0);
        set_pixel(canvas, x, 4, 0, 0, x);
    }

    // flip(canvas);
    return 0;
}
