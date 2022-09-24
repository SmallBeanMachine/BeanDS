module emu.hw.cpu.jumptable.barrel_shifter;

import emu.hw.cpu;
import emu.hw.cpu.jumptable;
import util;

struct BarrelShifter {
    Word result;
    bool carry;
}

BarrelShifter barrel_shift(int shift_type, bool is_immediate, T : ArmCPU)(T cpu, Word operand, Word shift) {
    Word result;
    bool carry;

    // "static switch" doesnt exist, sadly
    static if (shift_type == 0) { // LSL
        if (shift == 0) {
            result = operand;
            carry  = cpu.get_flag(Flag.C);
        } else if (shift < 32) {
            result = operand << shift;
            carry  = operand[32 - shift];
        } else if (shift == 32) {
            result = 0;
            carry  = operand[0];
        } else {
            result = 0;
            carry  = (result == 32) ? operand[0] : 0;
        }
    }

    static if (shift_type == 1) { // LSR
        static if (is_immediate) if (shift == 0) shift = 32;

        if (shift == 0) {
            result = operand;
            carry  = cpu.get_flag(Flag.C);
        } else if (shift < 32) {
            result = operand >> shift;
            carry  = operand[shift - 1];
        } else if (shift == 32) {
            result = 0;
            carry  = operand[31];
        } else {
            result = 0;
            carry  = 0;
        }
    }

    static if (shift_type == 2) { // ASR
        static if (is_immediate) if (shift == 0) shift = 32;

        if (shift == 0) {
            result = operand;
            carry  = cpu.get_flag(Flag.C);
        } else if (shift < 32) {
            result = sext_32(operand >> shift, 32 - shift);
            carry  = operand[shift - 1];
        } else {
            result = operand[31] ? 0xFFFFFFFF : 0x00000000;
            carry  = operand[31];
        }
    }

    static if (shift_type == 3) { // ROR
        static if (!is_immediate) {
            if ((shift & 0xFF) == 0) {
                result = operand;
                carry  = cpu.get_flag(Flag.C);
            } else if ((shift & 0x1F) == 0) {
                result = operand;
                carry  = operand[31];
            } else {
                shift &= 0x1F;
                result = operand.rotate_right(shift);
                carry  = operand[shift - 1];
            }
        } else {
            if (shift == 0) {
                result = cpu.get_flag(Flag.C) << 31 | (operand >> 1);
                carry  = operand[0];
            } else {
                result = operand.rotate_right(shift);
                carry  = operand[shift - 1];
            }
        }
    }

    return BarrelShifter(result, carry);
}