module util.bitwise;

import std.traits;

pragma(inline, true) {
    auto create_mask(size_t start, size_t end) {
        return (1 << (end - start + 1)) - 1;
    }

    T bits(T)(T value, size_t start, size_t end) {
        auto mask = create_mask(start, end);
        return (value >> start) & mask;
    }

    T bit(T)(T value, size_t index) {
        return (value >> index) & 1;
    }

    pure T rotate_right(T)(T value, size_t shift) 
    if (isIntegral!T) {
        return cast(T) ((value >> shift) | (value << (T.sizeof * 8 - shift)));
    }
}