#include "pixelflow_canvas.h"

// Compile with: gcc -o test test.c pixelflow_canvas.c

void main() {
    canvas_init(64, 64, COLOR_MODE_RGB);
    set_pixel_rgb(0, 0, 255, 0, 0);
    canvas_dispose();
}