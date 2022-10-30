module util.bitwise;

import core.bitop;
import std.traits;
import util;

pragma(inline, true) {
    auto create_mask(size_t start, size_t end) {
        if (end - start >= 31) return 0xFFFFFFFF;

        return (1 << (end - start + 1)) - 1;
    }

    T bits(T)(T value, size_t start, size_t end) {
        auto mask = create_mask(start, end);
        return (value >> start) & mask;
    }

    bool bit(T)(T value, size_t index) {
        return (value >> index) & 1;
    }

    pure T rotate_right(T)(T value, size_t shift) 
    if (isIntegral!T) {
        return ror(value, shift);
    }

    s32 sext_32(T)(T value, u32 size) {
        auto negative = value.bit(size - 1);
        s32 result = value;

        if (negative) result |= (((1 << (32 - size)) - 1) << size);
        return result;
    }

    s64 sext_64(u64 value, u64 size) {
        auto negative = (value >> (size - 1)) & 1;
        if (negative) value |= (((1UL << (64UL - size)) - 1UL) << size);
        return value;
    }

    u64 make_u64(u32 hi, u32 lo) {
        return ((cast(u64) hi) << 32) | (cast(u64) lo);
    }
}