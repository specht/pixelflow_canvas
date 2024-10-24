# frozen_string_literal: true

require_relative "pixelflow_canvas/version"
require 'socket'
require 'time'

module Pixelflow
    class Canvas
        COLOR_MODES = {
            :rgb => 0,
            :palette => 1,
        }
        ADVANCE_MODES = {
            :right => 0,
            :down => 1
        }
        DRAW_MODES = {
            :direct => 0,
            :buffered => 1
        }
        def initialize(width, height, color_mode = nil)
            @width = 320
            @height = 180
            @x = 0
            @y = 0
            @color_mode = :rgb
            @advance_mode = :right
            @draw_mode = :direct
            @palette = [0] * 768
            @socket = TCPSocket.new('127.0.0.1', 19223)
            set_size(width, height)
            set_color_mode(color_mode) if color_mode
            @last_timestamp = Time.now.to_f
        end

        def set_size(width, height)
            @x = 0
            @y = 0
            @width = width
            @height = height
            recreate_screen()
            @socket.write([1, width, height].pack('Cnn'))
            @socket.flush
        end

        def recreate_screen()
            @screen = [0] * @width * @height * (@color_mode == :rgb ? 3 : 1)
        end

        def set_color_mode(mode)
            unless COLOR_MODES.keys.include?(mode)
                raise "Invalid color mode: #{mode}"
            end
            @color_mode = mode
            recreate_screen()
            @socket.write([2, COLOR_MODES[@color_mode]].pack('CC'))
            @socket.flush
        end

        def set_advance_mode(mode)
            unless ADVANCE_MODES.keys.include?(mode)
                raise "Invalid advance mode: #{mode}"
            end
            @advance_mode = mode
            @socket.write([4, ADVANCE_MODES[@advance_mode]].pack('CC'))
            @socket.flush
        end

        def set_draw_mode(mode)
            unless DRAW_MODES.keys.include?(mode)
                raise "Invalid draw mode: #{mode}"
            end
            @draw_mode = mode
        end

        def flip()
            if @draw_mode == :buffered
                @socket.write([7].pack('C'))
                @socket.write(@screen.pack('C*'))
                @socket.flush
            end
        end

        def ensure_max_fps(fps)
            fps1 = 1.0 / fps
            t = Time.now.to_f
            dt = t - @last_timestamp
            sleep(fps1 - dt) if dt < fps1
            @last_timestamp = t
        end

        def set_palette(i, r, g, b)
            i = i % 256
            r = (r % 256) << 2
            g = (g % 256) << 2
            b = (b % 256) << 2
            @socket.write([3, i, r, g, b].pack('CCCCC'))
        end

        def move_to(x, y)
            x = x.to_i
            y = y.to_i
            return if x < 0 || x >= @width || y < 0 || y >= @height
            @x = x
            @y = y
            buffer = [5].pack('C')
            buffer += [x].pack((@width <= 256) ? 'C' : 'n')
            buffer += [y].pack((@height <= 256) ? 'C' : 'n')
            @socket.write(buffer)
            @socket.flush
        end

        def set_pixel(x, y, r, g = 0, b = 0)
            x0 = x0.to_i
            y0 = y0.to_i
            x1 = x1.to_i
            y1 = y1.to_i
            return if x < 0 || x >= @width || y < 0 || y >= @height
            unless x == @x && y == @y
                move_to(x, y)
            end
            if @color_mode == :rgb
                offset = (@y * @width + @x) * 3
                @screen[offset + 0] = r
                @screen[offset + 1] = g
                @screen[offset + 2] = b
            else
                offset = @y * @width + @x
                @screen[offset] = r
            end
            if @draw_mode == :direct
                if @color_mode == :rgb
                    @socket.write([6, r, g, b].pack('CCCC'))
                else
                    @socket.write([6, r].pack('CC'))
                end
                @socket.flush()
            end
            if @advance_mode == :right
                @x += 1
                if @x >= @width
                    @x = 0
                    @y = (@y + 1) % @height
                end
            else
                @y += 1
                if @y >= @height
                    @y = 0
                    @x = (@x + 1) % @width
                end
            end
        end

        def get_pixel(x, y)
            x0 = x0.to_i
            y0 = y0.to_i
            x1 = x1.to_i
            y1 = y1.to_i
            return 0 if x < 0 || x >= @width || y < 0 || y >= @height
            if @color_mode == :rgb
                return @screen[(y * @width + x) * 3, 3]
            else
                return @screen[y * @width + x]
            end
        end

        def draw_rect(x0, y0, x1, y1, color)
            x0 = x0.to_i
            y0 = y0.to_i
            x1 = x1.to_i
            y1 = y1.to_i
            (x0..x1).each do |x|
                set_pixel(x, y0, color)
            end
            (x0..x1).each do |x|
                set_pixel(x, y1, color)
            end
            (y0+1..y1-1).each do |y|
                set_pixel(x0, y, color)
                set_pixel(x1, y, color)
            end
        end

        def fill_rect(x0, y0, x1, y1, color)
            x0 = x0.to_i
            y0 = y0.to_i
            x1 = x1.to_i
            y1 = y1.to_i
            (y0..y1).each do |y|
                (x0..x1).each do |x|
                    set_pixel(x, y, color)
                end
            end
        end

        def draw_line(x0, y0, x1, y1, color)
            x0 = x0.to_i
            y0 = y0.to_i
            x1 = x1.to_i
            y1 = y1.to_i
            dx = (x1 - x0).abs
            dy = (y1 - y0).abs
            sx = x0 < x1 ? 1 : -1
            sy = y0 < y1 ? 1 : -1
            err = dx - dy
            loop do
                set_pixel(x0, y0, color)
                break if x0 == x1 && y0 == y1
                e2 = 2 * err
                if e2 > -dy
                    err -= dy
                    x0 += sx
                end
                if e2 < dx
                    err += dx
                    y0 += sy
                end
            end
        end

        def draw_circle(x, y, radius, color)
            x = x.to_i
            y = y.to_i
            radius = radius.to_i
            f = 1 - radius
            ddF_x = 1
            ddF_y = -2 * radius
            xx = 0
            yy = radius
            set_pixel(x, y + radius, color)
            set_pixel(x, y - radius, color)
            set_pixel(x + radius, y, color)
            set_pixel(x - radius, y, color)
            while xx < yy
                if f >= 0
                    yy -= 1
                    ddF_y += 2
                    f += ddF_y
                end
                xx += 1
                ddF_x += 2
                f += ddF_x
                set_pixel(x + xx, y + yy, color)
                set_pixel(x - xx, y + yy, color)
                set_pixel(x + xx, y - yy, color)
                set_pixel(x - xx, y - yy, color)
                set_pixel(x + yy, y + xx, color)
                set_pixel(x - yy, y + xx, color)
                set_pixel(x + yy, y - xx, color)
                set_pixel(x - yy, y - xx, color)
            end
        end

        def fill_circle(x, y, r, color)
            x = x.to_i
            y = y.to_i
            r = r.to_i
            f = 1 - r
            ddF_x = 1
            ddF_y = -2 * r
            xx = 0
            yy = r
            (y - r..y + r).each do |i|
                set_pixel(x, i, color)
            end
            while xx < yy
                if f >= 0
                    yy -= 1
                    ddF_y += 2
                    f += ddF_y
                end
                xx += 1
                ddF_x += 2
                f += ddF_x
                (y - yy..y + yy).each do |i|
                    set_pixel(x + xx, i, color)
                    set_pixel(x - xx, i, color)
                end
                (y - xx..y + xx).each do |i|
                    set_pixel(x + yy, i, color)
                    set_pixel(x - yy, i, color)
                end
            end
        end

        def draw_ellipse(x, y, a, b, color)
            x = x.to_i
            y = y.to_i
            a = a.to_i
            b = b.to_i
            a2 = a * a
            b2 = b * b
            fa2 = 4 * a2
            fb2 = 4 * b2
            x0 = 0
            y0 = b
            sigma = 2 * b2 + a2 * (1 - 2 * b)
            while b2 * x0 <= a2 * y0
                set_pixel(x + x0, y + y0, color)
                set_pixel(x - x0, y + y0, color)
                set_pixel(x + x0, y - y0, color)
                set_pixel(x - x0, y - y0, color)
                if sigma >= 0
                    sigma += fa2 * (1 - y0)
                    y0 -= 1
                end
                sigma += b2 * ((4 * x0) + 6)
                x0 += 1
            end
            x0 = a
            y0 = 0
            sigma = 2 * a2 + b2 * (1 - 2 * a)
            while a2 * y0 <= b2 * x0
                set_pixel(x + x0, y + y0, color)
                set_pixel(x - x0, y + y0, color)
                set_pixel(x + x0, y - y0, color)
                set_pixel(x - x0, y - y0, color)
                if sigma >= 0
                    sigma += fb2 * (1 - x0)
                    x0 -= 1
                end
                sigma += a2 * ((4 * y0) + 6)
                y0 += 1
            end
        end

        def fill_ellipse(x, y, a, b, color)
            x = x.to_i
            y = y.to_i
            a = a.to_i
            b = b.to_i
            a2 = a * a
            b2 = b * b
            fa2 = 4 * a2
            fb2 = 4 * b2
            x0 = 0
            y0 = b
            sigma = 2 * b2 + a2 * (1 - 2 * b)
            while b2 * x0 <= a2 * y0
                (x - x0..x + x0).each do |i|
                    set_pixel(i, y + y0, color)
                    set_pixel(i, y - y0, color)
                end
                if sigma >= 0
                    sigma += fa2 * (1 - y0)
                    y0 -= 1
                end
                sigma += b2 * ((4 * x0) + 6)
                x0 += 1
            end
            x0 = a
            y0 = 0
            sigma = 2 * a2 + b2 * (1 - 2 * a)
            while a2 * y0 <= b2 * x0
                (x - x0..x + x0).each do |i|
                    set_pixel(i, y + y0, color)
                    set_pixel(i, y - y0, color)
                end
                if sigma >= 0
                    sigma += fb2 * (1 - x0)
                    x0 -= 1
                end
                sigma += a2 * ((4 * y0) + 6)
                y0 += 1
            end
        end

        def draw_quadratic_bezier(x0, y0, x1, y1, x2, y2, color, steps = 100)
            steps = steps.to_i
            xp = nil
            yp = nil
            (0..steps).each do |i|
                t = i.to_f / steps
                x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t ** 2 * x2
                y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t ** 2 * y2
                if xp && yp
                    draw_line(xp.to_i, yp.to_i, x.to_i, y.to_i, color)
                end
                xp = x
                yp = y
            end
        end

        def draw_cubic_bezier(x0, y0, x1, y1, x2, y2, x3, y3, color, steps = 100)
            steps = steps.to_i
            xp = nil
            yp = nil
            (0..steps).each do |i|
                t = i.to_f / steps
                x = (1 - t) ** 3 * x0 + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t ** 2 * x2 + t ** 3 * x3
                y = (1 - t) ** 3 * y0 + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t ** 2 * y2 + t ** 3 * y3
                if xp && yp
                    draw_line(xp.to_i, yp.to_i, x.to_i, y.to_i, color)
                end
                xp = x
                yp = y
            end
        end

        def draw_triangle(x0, y0, x1, y1, x2, y2, color)
            draw_line(x0, y0, x1, y1, color)
            draw_line(x1, y1, x2, y2, color)
            draw_line(x2, y2, x0, y0, color)
        end
    end
end