module emu.hw.cpu.jumptable.jumptable_arm;

import core.bitop;

import emu.hw.cpu;
import emu.hw.memory;

import util;

template execute_arm(T : ArmCPU) {
    alias JumptableEntry = void function(T cpu, Word opcode);

    static void create_undefined_instruction(T cpu, Word opcode) {
        error_unimplemented("Tried to execute undefined ARM instruction: %08x", opcode);
    }

    static void create_branch(bool branch_with_link)(T cpu, Word opcode) {
        if (opcode[28..31] == 0xF && v5TE!T) {
            s32 offset = sext_32(opcode[0..23], 24) * 4 + branch_with_link * 2;
            Word address = cpu.get_reg(pc) + offset;

            cpu.set_flag(Flag.T, true);
            cpu.set_reg(lr, cpu.get_reg(pc) - 4);
            cpu.set_reg(pc, address);
        } else {
            static if (branch_with_link) cpu.set_reg(lr, cpu.get_reg(pc) - 4);
            s32 offset = sext_32(opcode[0..23], 24) * 4;
            cpu.set_reg(pc, cpu.get_reg(pc) + offset);
        }
    }

    static void create_branch_exchange_with_link(T cpu, Word opcode) {
        Reg rm = opcode[0..3];
        Word address = cpu.get_reg(rm);
        auto next_pc = cpu.get_reg(pc) - 4;

        cpu.set_flag(Flag.T, address[0]);
        cpu.set_reg(lr, next_pc);
        cpu.set_reg(pc, address);
    }

    static void create_branch_exchange(T cpu, Word opcode) {
        Reg rm = opcode[0..3];
        Word address = cpu.get_reg(rm);

        cpu.set_flag(Flag.T, cast(bool) address[0]);
        cpu.set_reg(pc, address & ~1);
    }

    static void create_mrs(bool transfer_spsr)(T cpu, Word opcode) {
        Reg rd = opcode[12..15];
        static if (transfer_spsr) cpu.set_reg(rd, cpu.get_spsr());
        else                      cpu.set_reg(rd, cpu.get_cpsr());
    }

    static void create_msr(bool is_immediate, bool transfer_spsr)(T cpu, Word opcode) {
        static if (is_immediate) {
            auto immediate = opcode[0..7];
            auto shift     = opcode[8..11] * 2;
            Word operand = immediate.rotate_right(shift);
        } else {
            Word operand = cpu.get_reg(opcode[0..3]);
        }

        static if (transfer_spsr) {
            if (cpu.has_spsr()) {
                if (opcode[16]) cpu.set_spsr((cpu.get_spsr() & 0xFFFFFF00) | (operand & 0x000000FF));
                if (opcode[17]) cpu.set_spsr((cpu.get_spsr() & 0xFFFF00FF) | (operand & 0x0000FF00));
                if (opcode[18]) cpu.set_spsr((cpu.get_spsr() & 0xFF00FFFF) | (operand & 0x00FF0000));
                if (opcode[19]) cpu.set_spsr((cpu.get_spsr() & 0x00FFFFFF) | (operand & 0xFF000000));
            }
        } else {
            if (cpu.in_a_privileged_mode()) {
                if (opcode[16]) cpu.set_cpsr((cpu.get_cpsr() & 0xFFFFFF00) | (operand & 0x000000FF));
                if (opcode[17]) cpu.set_cpsr((cpu.get_cpsr() & 0xFFFF00FF) | (operand & 0x0000FF00));
                if (opcode[18]) cpu.set_cpsr((cpu.get_cpsr() & 0xFF00FFFF) | (operand & 0x00FF0000));
            }
                if (opcode[19]) cpu.set_cpsr((cpu.get_cpsr() & 0x00FFFFFF) | (operand & 0xFF000000));
        
            bool bit_T_changed = cast(bool) (operand[5] ^ cpu.get_flag(Flag.T));
            if (opcode[16] && cpu.in_a_privileged_mode()) {
                if (bit_T_changed) cpu.refill_pipeline();
            }

            cpu.update_mode();
        }
    }

    static void create_multiply(bool multiply_long, bool signed, bool accumulate, bool update_flags)(T cpu, Word opcode) {
        Reg rd = opcode[16..19];
        Reg rn = opcode[12..15];
        Reg rs = opcode[ 8..11];
        Reg rm = opcode[ 0..3];

        static if (multiply_long) {
            static if (signed) {
                s64 operand1 = sext_64(cpu.get_reg(rm), 32);
                s64 operand2 = sext_64(cpu.get_reg(rs), 32);
            } else {
                u64 operand1 = cpu.get_reg(rm);
                u64 operand2 = cpu.get_reg(rs);
            }
        } else {
            u32 operand1 = cpu.get_reg(rm);
            u32 operand2 = cpu.get_reg(rs);
        }
        
        u64 result = cast(u64) (operand1 * operand2);

        static if (accumulate) {
            static if (multiply_long) {
                result += ((cast(u64) cpu.get_reg(rd)) << 32UL) + (cast(u64) cpu.get_reg(rn));
            } else {
                result += cpu.get_reg(rn);
            }
        }

        int idle_cycles = calculate_multiply_cycles!(signed || !multiply_long)(cast(Word) operand2);
        static if (multiply_long) idle_cycles++;
        static if (accumulate)    idle_cycles++;
        for (int i = 0; i < idle_cycles; i++) cpu.run_idle_cycle();

        static if (multiply_long) {
            bool modifying_pc = unlikely(rd == pc || rn == pc);
            bool overflow = result >> 63;
        } else {
            bool modifying_pc = unlikely(rd == pc);
            bool overflow = (result >> 31) & 1;
        }

        if (update_flags) {
            if (modifying_pc) {
                cpu.set_cpsr(cpu.get_spsr());
                cpu.update_mode();
            } else {
                cpu.set_flag(Flag.Z, result == 0);
                cpu.set_flag(Flag.N, overflow);
            }
        }

        static if (multiply_long) {
            cpu.set_reg(rd, Word(result >> 32));
            cpu.set_reg(rn, Word(result & 0xFFFFFFFF));
        } else {
            cpu.set_reg(rd, Word(result & 0xFFFFFFFF));
        }
    }

    static void create_multiply_xy(int operation, bool x, bool y)(T cpu, Word opcode) {
        Reg rm = opcode[0 .. 4];
        Reg rs = opcode[8 ..11];
        Reg rn = opcode[12..15];
        Reg rd = opcode[16..19];

        static if (x) s32 operand1 = sext_32(cpu.get_reg(rm)[16..31], 16);
        else          s32 operand1 = sext_32(cpu.get_reg(rm)[0 ..15], 16);
        static if (y) s32 operand2 = sext_32(cpu.get_reg(rs)[16..31], 16);
        else          s32 operand2 = sext_32(cpu.get_reg(rs)[0 ..15], 16);

        final switch (operation) {
            case 0: {
                s32 add_operand_1 = operand1 * operand2;
                s32 add_operand_2 = cpu.get_reg(rn);
                s32 result = add_operand_1 + add_operand_2;

                if (add_operand_1 >= 0 && add_operand_2 >= 0 && result <= 0) {
                    cpu.set_flag(Flag.Q, true);
                } else if (add_operand_1 < 0 && add_operand_2 < 0 && result > 0) {
                    cpu.set_flag(Flag.Q, true);
                }

                cpu.set_reg(rd, Word(result));
                break;
            }
            
            case 1: {
                s64 operand1_w = sext_64(cpu.get_reg(rm), 32);
                s64 operand2_w = sext_64(operand2, 32);

                static if (x) {
                    s32 result = cast(s32) ((operand1_w * operand2_w) >> 16) & 0xFFFF_FFFF;
                    cpu.set_reg(rd, Word(result));
                } else {
                    s32 add_operand_1 = cast(s32) ((operand1_w * operand2_w) >> 16) & 0xFFFF_FFFF;
                    
                    s32 add_operand_2 = cpu.get_reg(rn);
                    s32 result = add_operand_1 + add_operand_2;

                    if (add_operand_1 >= 0 && add_operand_2 >= 0 && result <= 0) {
                        cpu.set_flag(Flag.Q, true);
                    } else if (add_operand_1 < 0 && add_operand_2 < 0 && result > 0) {
                        cpu.set_flag(Flag.Q, true);
                    }

                    cpu.set_reg(rd, Word(result));
                }
                
                break;
            }

            case 2: {
                s64 add_operand_1 = operand1 * operand2;
                s64 add_operand_2 = (cast(u64) cpu.get_reg(rn)) | ((cast(u64) cpu.get_reg(rd)) << 32);
                s64 result = add_operand_1 + add_operand_2;

                cpu.set_reg(rn, Word(result & 0xFFFF_FFFF));
                cpu.set_reg(rd, Word(result >> 32));
                break;
            }

            case 3: {
                s32 result = operand1 * operand2;
                cpu.set_reg(rd, Word(result));
                break;
            }

        }
    }

    static void create_data_processing(bool is_immediate, int shift_type, bool register_shift, bool update_flags, int operation)(T cpu, Word opcode) {
        Reg rn = opcode[16..19];
        Reg rd = opcode[12..15];
        Reg rs = opcode[0..  4];
        int pc_additional_shift_amount = 0;

        Word get_reg__shift(Reg reg) {
            if (unlikely(reg == pc)) return cpu.get_reg(pc) + pc_additional_shift_amount;
            else return cpu.get_reg(reg);
        }
    
        static if (is_immediate) {
            Word immediate     = opcode[0..7];
            Word shift         = opcode[8..11] * 2;
            Word operand2      = immediate.rotate_right(shift);
            bool shifter_carry = shift == 0 ? cpu.get_flag(Flag.C) : operand2[31];
        } else {
            static if (register_shift) {
                cpu.run_idle_cycle();
                pc_additional_shift_amount = 4;
                Word shift = get_reg__shift(opcode[8..11]) & 0xFF;
            } else {
                Word shift = opcode[7..11];
            }

            Word immediate = get_reg__shift(opcode[0..3]);
            BarrelShifter shifter = barrel_shift!(shift_type, !register_shift)(cpu, immediate, shift);
            Word operand2 = shifter.result;

            bool shifter_carry = shifter.carry;
        }

        bool is_pc = rd == pc;

        Word operand1 = get_reg__shift(rn);

        static if (operation == 0 || operation == 1 || operation == 8 || operation == 9 || operation >= 12) {
            if (update_flags && !is_pc) cpu.set_flag(Flag.C, shifter_carry); 
        }

        if (update_flags && is_pc) {
            cpu.set_cpsr(cpu.get_spsr());
            cpu.update_mode();
        }

        static if (operation ==  0) { cpu.and(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  1) { cpu.eor(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  2) { cpu.sub(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  3) { cpu.rsb(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  4) { cpu.add(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  5) { cpu.adc(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  6) { cpu.sbc(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  7) { cpu.rsc(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation ==  8) { cpu.tst(rd, operand1, operand2,       update_flags && !is_pc); }
        static if (operation ==  9) { cpu.teq(rd, operand1, operand2,       update_flags && !is_pc); }
        static if (operation == 10) { cpu.cmp(rd, operand1, operand2,       update_flags && !is_pc); }
        static if (operation == 11) { cpu.cmn(rd, operand1, operand2,       update_flags && !is_pc); }
        static if (operation == 12) { cpu.orr(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation == 13) { cpu.mov(rd,           operand2,       update_flags && !is_pc); }
        static if (operation == 14) { cpu.bic(rd, operand1, operand2, true, update_flags && !is_pc); }
        static if (operation == 15) { cpu.mvn(rd,           operand2,       update_flags && !is_pc); }
    }

    static void create_half_data_transfer(bool pre, bool up, bool is_immediate, bool writeback, bool load, bool signed, bool half)(T cpu, Word opcode) {
        Reg rd = opcode[12..15];
        Reg rn = opcode[16..19];

        static if (is_immediate) {
            Word offset = opcode[0..3] | (opcode[8..11] << 4);
        } else {
            Word offset = cpu.get_reg(opcode[0..3]);
        }

        Word address = cpu.get_reg(rn);
        enum dir = up ? 1 : -1;
        Word writeback_value = address + dir * offset;
        static if (pre) address = writeback_value;

        static if (load && writeback) cpu.set_reg(rn, writeback_value);

        static if (load) {
            static if (signed) {
                static if (half) cpu.ldrsh(rd, address);
                else             cpu.ldrsb(rd, address);
            } else {
                cpu.ldrh(rd, address);
            }
        } else {
            static if (v5TE!T && signed) {
                // arm is starting to have a worse opcode encoding.
                // in v5te theyre trying to be backwards compatible with 
                // v4t. so they shoehorn opcodes in the weirdest of places
                // in v4t, decoding an addressing mode 3 instruction is 
                // super simple: theres 3 bits. load. signed. half. if 
                // load is false, the opcode is strh. else, if signed is 
                // false, the opcode is ldrh. else, depending on half, the 
                // opcode is either ldrsh or ldrsb.
                // but now, with v5te, they needed to shoehorn the load 
                // double word opcode somewhere. so where did they put it? 
                // here. they decided that if load is false and signed is 
                // true, THEN ITS A LOAD DOUBLE WORD OPCODE. LOAD DOUBLE 
                // WORD IS NOT EVEN SIGNED LET ALONE A STORE AAAAAAAAAAAAA
                // AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

                // i love arm
                // "better than no comments i suppose" - Mesi

                // ADDENDUM: i wrote this comment 2-3 months ago when i was
                // first working on v5TE. i have since learned that not only
                // did i completely forget to implement STRD, but LDRD/STRD
                // are differentiated using the HALF bit! if the half bit is
                // 0, it's LDRD. if it's 1, it's STRD. animals.
                static if (half) {
                    cpu.strd(rd, address);
                } else {
                    cpu.ldrd(rd, address);
                }
            } else {
                cpu.strh(rd, address);
            }
        }

        static if (!load && writeback) cpu.set_reg(rn, writeback_value);
    }

    static void create_single_data_transfer(bool is_register_offset, int shift_type, bool pre, bool up, bool byte_access, bool writeback, bool load)(T cpu, Word opcode) {
        Reg rd = opcode[12..15];
        Reg rn = opcode[16..19];

        // 37881100
        // rn = 8
        // rd = 1

        static if (is_register_offset) {
            Reg rm = opcode[0..3];

            auto shift = opcode[7..11];
            Word offset = barrel_shift!(shift_type, true)(cpu, cpu.get_reg(rm), shift).result;
        } else { // immediate offset
            Word offset = opcode[0..11];
        }
        
        Word address = cpu.get_reg(rn);
        enum dir = up ? 1 : -1;
        Word writeback_value = address + dir * offset;
        static if (pre) address = writeback_value;

        if (opcode == 0x37881100) {
            log_arm9("info: single data transfer: rn = %x, rd = %x, offset = %x, pre = %x, up = %x, byte_access = %x, writeback = %x, load = %x, address = %x", rn, rd, offset, pre, up, byte_access, writeback, load, address);
        }

        static if (load && writeback) cpu.set_reg(rn, writeback_value);

        static if ( byte_access &&  load) cpu.ldrb(rd, address);
        static if (!byte_access &&  load) cpu.ldr (rd, address);
        static if ( byte_access && !load) cpu.strb(rd, address);
        static if (!byte_access && !load) cpu.str (rd, address);

        static if (!load && writeback) cpu.set_reg(rn, writeback_value);
    }

    static void create_swap(bool byte_swap)(T cpu, Word opcode) {
        Reg rm = opcode[0.. 3];
        Reg rd = opcode[12..15];
        Reg rn = opcode[16..19];

        Word address = cpu.get_reg(rn);

        static if (byte_swap) {
            Word value = cpu.read_byte(address, AccessType.NONSEQUENTIAL);
            cpu.write_byte(address, cast(Byte) (cpu.get_reg(rm) & 0xFF), AccessType.NONSEQUENTIAL);
        } else {
            Word value = cpu.read_word_and_rotate(address, AccessType.NONSEQUENTIAL);
            cpu.write_word(address, cpu.get_reg(rm), AccessType.NONSEQUENTIAL);
        }

        cpu.set_reg(rd, value);
    }

    static void create_ldm_stm(bool pre, bool up, bool s, bool writeback, bool load)(T cpu, Word opcode) {
        Reg rn = opcode[16..19];

        auto rlist = opcode[0..15];
        auto reg_count = popcnt(rlist);

        Word address = cpu.get_reg(rn);
        Word start_address     = address;
        Word writeback_address = address;

        if (rlist == 0) {
            static if (pre == up) address += 4;
            static if (!up)       address -= 64;
            
            if (v4T!T) {
                static if (load) {
                    cpu.set_reg(pc, cpu.read_word(address & ~3, AccessType.NONSEQUENTIAL));
                    cpu.run_idle_cycle();
                } else {
                    cpu.write_word(address & ~3, cpu.get_reg(pc) + 4, AccessType.NONSEQUENTIAL);
                }
            }

            static if (up) cpu.set_reg(rn, cpu.get_reg(rn) + 64);
            else           cpu.set_reg(rn, cpu.get_reg(rn) - 64);
            return;
        }

        static if (pre == up) address += 4;
        static if (!up)       address -= reg_count * 4;

        static if (up)        writeback_address += reg_count * 4;
        else                  writeback_address -= reg_count * 4;

        auto mask = 1;
        int  num_transfers = 0;

        static if (load) bool pc_loaded = false;

        static if (s) bool pc_included = opcode[15];

        bool register_in_rlist = cast(bool) ((opcode >> rn) & 1);
        bool is_first_access = true;

        AccessType access_type = AccessType.NONSEQUENTIAL;

        static if (s) {
            Word old_cpsr = cpu.get_cpsr();

            if (!(load && pc_included)) {
                Word new_cpsr = old_cpsr;
                new_cpsr[0..4] = MODE_USER.CPSR_ENCODING;
                cpu.set_cpsr(new_cpsr);
            }
        }

        for (int i = 0; i < 16; i++) {
            if (rlist & mask) {
                static if (s) {
                    import std.stdio;
                    static if (load) {
                        if (pc_included) cpu.set_reg(i, cpu.read_word(address, access_type));
                        else             cpu.set_reg(i, cpu.read_word(address, access_type), MODE_USER);
                    } else {
                        if (i == pc) cpu.write_word(address, cpu.get_reg(pc, MODE_USER) + 4, access_type);
                        else         cpu.write_word(address, cpu.get_reg(i,  MODE_USER),     access_type);
                    }
                } else {
                    static if (load) {
                        if (i == pc) {
                            Word value = cpu.read_word(address, access_type);
                            static if (v5TE!T) cpu.set_flag(Flag.T, value[0]);
                            cpu.set_reg(i, value);
                        } else cpu.set_reg(i, cpu.read_word(address, access_type));
                    } else {
                        if (i == pc) cpu.write_word(address, cpu.get_reg(pc) + 4, access_type);
                        else         cpu.write_word(address, cpu.get_reg(i), access_type);
                    }
                }

                address += 4;

                static if (load) {
                    num_transfers++;
                    if (i == pc) {
                        pc_loaded = true;
                    }
                }

                static if (writeback && !load) {
                    if (is_first_access) cpu.set_reg(rn, writeback_address);
                    is_first_access = false;
                }

                access_type = AccessType.SEQUENTIAL;
            }

            mask <<= 1; 
        }

        static if (load) cpu.run_idle_cycle();

        static if (load && s) if (pc_loaded) {
            cpu.set_cpsr(cpu.get_spsr());
            cpu.update_mode();
        }

        static if (s) {
            if (!(load && pc_included)) {
                cpu.set_cpsr(old_cpsr);
            }
        }

        static if (writeback && load) {
            static if (v5TE!T){
                if (register_in_rlist) {
                    if (rlist == 1 << rn || rlist >> (rn + 1) > 0) {
                        cpu.set_reg(rn, writeback_address);
                    }
                } else {
                    cpu.set_reg(rn, writeback_address);
                }
            }

            static if (v4T!T) {
                if (!register_in_rlist) cpu.set_reg(rn, writeback_address);
            }
        }

        static if (writeback && !load) cpu.set_reg(rn, writeback_address);
    }

    static void create_clz(T cpu, Word opcode) {
        Reg rm = opcode[0 .. 3];
        Reg rd = opcode[12..15];

        Word operand = cpu.get_reg(rm);
        Word result = (operand == 0) ? 32 : (31 - bsr(operand));

        cpu.set_reg(rd, result);
    }

    static void create_saturating_arithmetic(bool multiply, bool add)(T cpu, Word opcode) {
        Reg rm = opcode[0 .. 3];
        Reg rd = opcode[12..15];
        Reg rn = opcode[16..19];

        bool saturated = false;

        s32 operand1 = cpu.get_reg(rm);
        s32 operand2 = cpu.get_reg(rn);

        static if (multiply) {
            if (operand2 >= 0 && operand2 > 0x3FFF_FFFF) {
                operand2  = 0x7FFF_FFFF;
                saturated = true;
            } else if (operand2 < 0 && operand2 < 0xC000_0000) {
                operand2  = 0x8000_0000;
                saturated = true;
            } else {
                operand2 *= 2;
            }
        }

        static if (!add) {
            operand2 = -operand2;
        }

        s32 result = operand1 + operand2;
        if (operand1 >= 0 && operand2 >= 0 && result <= 0) {
            result = 0x7FFF_FFFF;
            saturated = true;
        } else if (operand1 < 0 && operand2 < 0 && result > 0) {
            result = 0x8000_0000;
            saturated = true;
        }

        cpu.set_reg(rd, cast(Word) result);
        cpu.set_flag(Flag.Q, saturated);
    }

    static void create_coprocessor(bool read)(T cpu, Word opcode) {
        Reg rd = opcode[12..15];

        static if (read) {
            Word result = cp15.read(
                opcode[5 .. 7],
                opcode[16..19],
                opcode[0 .. 3]
            );
            cpu.set_reg(rd, result);
        } else {
            cp15.write(
                opcode[5 .. 7],
                opcode[16..19],
                opcode[0 .. 3],
                cpu.get_reg(rd)
            );
        }
    }

    static void create_swi(T cpu, Word opcode) {
        cpu.swi();
    }

    static JumptableEntry[4096] jumptable = (() {
        JumptableEntry[4096] jumptable;

        static foreach (entry; 0 .. 4096) {{
            enum Word static_opcode = cast(Word) (entry.bits(0, 3) << 4) | (entry.bits(4, 11) << 20);

            if (v5TE!T && (entry & 0b1111_1111_1111) == 0b0001_0010_0011) {
                jumptable[entry] = &create_branch_exchange_with_link;
            } else

            if ((entry & 0b1111_0000_0000) == 0b1111_0000_0000) {
                jumptable[entry] = &create_swi;
            } else

            if ((entry & 0b1111_1011_1111) == 0b0001_0000_1001) {
                enum byte_swap = static_opcode[22];
                jumptable[entry] = &create_swap!byte_swap;
            } else

            if (v5TE!T && (entry & 0b1111_1001_1001) == 0b0001_0000_1000) {
                enum x         = static_opcode[5];
                enum y         = static_opcode[6];
                enum operation = static_opcode[21..22];
                jumptable[entry] = &create_multiply_xy!(operation, x, y);
            } else

            if ((entry & 0b1100_0000_0000) == 0b0100_0000_0000) {
                enum is_register_offset = static_opcode[25];
                enum shift_type         = static_opcode[5..6];
                enum pre                = static_opcode[24];
                enum up                 = static_opcode[23];
                enum byte_access        = static_opcode[22];
                enum writeback          = static_opcode[21] || !pre; // post-indexing implies writeback
                enum load               = static_opcode[20];
                jumptable[entry] = &create_single_data_transfer!(is_register_offset, shift_type, pre, up, byte_access, writeback, load);
            } else

            if (((entry & 0b1111_1100_1111) == 0b0000_0000_1001) ||
                ((entry & 0b1111_1000_1111) == 0b0000_1000_1001)) {
                enum multiply_long = static_opcode[23];
                enum signed        = static_opcode[22];
                enum accumulate    = static_opcode[21];
                enum update_flags  = static_opcode[20];
                jumptable[entry] = &create_multiply!(multiply_long, signed, accumulate, update_flags);
            } else

            if ((entry & 0b1110_0000_1001) == 0b0000_0000_1001) {        
                enum pre           = static_opcode[24];
                enum up            = static_opcode[23];
                enum is_immediate  = static_opcode[22];
                enum writeback     = static_opcode[21] || !pre; // post-indexing implies writeback
                enum load          = static_opcode[20];
                enum signed        = static_opcode[6];
                enum half          = static_opcode[5];
                jumptable[entry] = &create_half_data_transfer!(pre, up, is_immediate, writeback, load, signed, half);
            } else

            if ((entry & 0b1110_0000_0000) == 0b1010_0000_0000) {
                enum branch_with_link = static_opcode[24];
                jumptable[entry] = &create_branch!branch_with_link;
            } else

            if ((entry & 0b1111_1011_1111) == 0b0001_0000_0000) {
                enum transfer_spsr = static_opcode[22];
                jumptable[entry] = &create_mrs!transfer_spsr;
            } else

            if (((entry & 0b1111_1011_0000) == 0b0011_0010_0000) ||
                ((entry & 0b1111_1011_1111) == 0b0001_0010_0000)) {
                enum is_immediate  = static_opcode[25];
                enum transfer_spsr = static_opcode[22];
                jumptable[entry] = &create_msr!(is_immediate, transfer_spsr);
            } else

            if ((entry & 0b1111_1111_1111) == 0b0001_0010_0001) {
                jumptable[entry] = &create_branch_exchange;
            } else

            if ((entry & 0b1110_0000_0000) == 0b1000_0000_0000) {
                enum pre       = static_opcode[24];
                enum up        = static_opcode[23];
                enum s         = static_opcode[22];
                enum writeback = static_opcode[21];
                enum load      = static_opcode[20];
                jumptable[entry] = &create_ldm_stm!(pre, up, s, writeback, load);
            } else

            if (v5TE!T && (entry & 0b1111_1001_1111) == 0b0001_0000_0101) {
                enum multiply = static_opcode[22];
                enum add      = static_opcode[21];
                
                jumptable[entry] = &create_saturating_arithmetic!(multiply, !add);
            } else

            if (v5TE!T && (entry & 0b1111_1111_1111) == 0b0001_0110_0001) {
                jumptable[entry] = &create_clz;
            } else

            if (((entry & 0b1110_0000_0000) == 0b0010_0000_0000) ||
                ((entry & 0b1110_0000_0001) == 0b0000_0000_0000) ||
                ((entry & 0b1110_0000_1001) == 0b0000_0000_0001)) {
                enum is_immediate   = static_opcode[25];
                enum shift_type     = static_opcode[5..6];
                enum register_shift = static_opcode[4];
                enum update_flags   = static_opcode[20];
                enum operation      = static_opcode[21..24];

                jumptable[entry] = &create_data_processing!(is_immediate, shift_type, register_shift, update_flags, operation);
            } else

            if ((entry & 0b1111_0000_0000) == 0b1110_0000_0000) {
                enum read = static_opcode[20];
                jumptable[entry] = &create_coprocessor!read;
            } else
            
            jumptable[entry] = &create_undefined_instruction;
        }}

        return jumptable;
    })();
}