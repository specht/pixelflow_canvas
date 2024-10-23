require 'socket'
require 'io/console'

class CrtCanvas
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
    end

    def recreate_screen()
        @screen = [0] * @width * @height * (@color_mode == :rgb ? 3 : 1)
    end

    def set_draw_mode(mode)
        unless DRAW_MODES.keys.include?(mode)
            raise "Invalid draw mode: #{mode}"
        end
        @draw_mode = mode
        recreate_screen()
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

    def set_color_mode(mode)
        unless COLOR_MODES.keys.include?(mode)
            raise "Invalid color mode: #{mode}"
        end
        @color_mode = mode
        recreate_screen()
        @socket.write([2, COLOR_MODES[@color_mode]].pack('CC'))
        @socket.flush
    end

    def set_palette(i, r, g, b)
        i = i % 256
        r = (r % 256) << 2
        g = (g % 256) << 2
        b = (b % 256) << 2
        @socket.write([3, i, r, g, b].pack('CCCCC'))
    end

    def set_advance(mode)
        unless ADVANCE_MODES.keys.include?(mode)
            raise "Invalid advance mode: #{mode}"
        end
        @advance_mode = mode
        @socket.write([4, ADVANCE_MODES[@advance_mode]].pack('CC'))
        @socket.flush
    end

    def move_to(x, y)
        return if x < 0 || x >= @width || y < 0 || y >= @height
        @x = x
        @y = y
        buffer = [5].pack('C')
        buffer += [x].pack((@width < 256) ? 'C' : 'n')
        buffer += [y].pack((@height < 256) ? 'C' : 'n')
        @socket.write(buffer)
        @socket.flush
    end

    def set_pixel(x, y, r, g = 0, b = 0)
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
        return 0 if x < 0 || x >= @width || y < 0 || y >= @height
        if @color_mode == :rgb
            return @screen[(y * @width + x) * 3, 3]
        else
            return @screen[y * @width + x]
        end
    end

    def flip()
        if @draw_mode == :buffered
            @socket.write([7].pack('C'))
            @socket.write(@screen.pack('C*'))
            @socket.flush
        end
    end
end

KEY_MINUS = 45
KEY_PLUS = 43
KEY_UP = 1792833
KEY_DOWN = 1792834
KEY_RIGHT = 1792835
KEY_LEFT = 1792836
KEY_RETURN = 10
KEY_ESCAPE = 27
KEY_SPACE = 32

class Keyboard
    def read_key()
        begin
            STDIN.raw!
            STDIN.echo = false
            x = (STDIN.read_nonblock(4) rescue nil)
            if x
                y = 0
                x.bytes.each { |_| y <<= 8; y += _ }
                x = y
            end
        ensure
            STDIN.cooked!
            STDIN.echo = true
        end
    end
end
