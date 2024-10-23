#!/usr/bin/env ruby

require './crt_canvas.rb'

width = 256
height = 128
canvas = CrtCanvas.new(width, height, :palette)
canvas.set_draw_mode(:buffered)
heat = 48

(0...16).each do |i|
    canvas.set_palette(i, i * 2, 0, 0);
    canvas.set_palette(i + 16, (i + 16) * 2, 0, 0);
    canvas.set_palette(i + 32, 63, i * 4, 0);
    canvas.set_palette(i + 48, 63, 63, i * 4);
end

keyboard = Keyboard.new

loop do
    skip_new_flame = false
    c = keyboard.read_key()
    if c
        puts c
        if c == KEY_DOWN
            heat -= 1
            heat = 0 if heat < 0
            puts "Heat: #{heat}"
        elsif c == KEY_UP
            heat += 1
            heat = 63 if heat > 63
            puts "Heat: #{heat}"
        elsif c == KEY_SPACE
            skip_new_flame = true
        end
    end
    unless skip_new_flame
        (0..1).each do |y|
            (10..246).each do |x|
                canvas.set_pixel(x, height - y, heat)
            end
        end
    end
    (0...128).each do |y|
        (0...256).each do |x|
            c = canvas.get_pixel(x, y + 1) << 1
            c += canvas.get_pixel(x - 1, y)
            c += canvas.get_pixel(x + 1, y)
            c >>= 2
            c += rand(7) - 3 if c > 0
            c = 0 if c < 0
            c = 63 if c > 63

            canvas.set_pixel(x, y, c)
        end
    end
    canvas.flip()
end
