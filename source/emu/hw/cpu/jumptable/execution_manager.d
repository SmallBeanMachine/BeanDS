// module emu.hw.cpu.jumptable.execution_manager;

// import emu;
// import util;

// pragma(inline, true) {
//     auto create_mask(size_t start, size_t end) {
//         return (1 << (end - start + 1)) - 1;
//     }

//     T bits(T)(T value, size_t start, size_t end) {
//         auto mask = create_mask(start, end);
//         return (value >> start) & mask;
//     }

//     bool bit(T)(T value, size_t index) {
//         return (value >> index) & 1;
//     }
// }

// final class CPUState : ARMStrategy {
//     Word           get_reg(int i);
//     Word           get_reg(int i, CpuMode mode);
//     void           set_reg(int i, Word value);
//     void           set_reg(int i, Word value, CpuMode mode);

//     Word           get_cpsr();
//     Word           get_spsr();
//     void           set_cpsr(Word value);
//     void           set_spsr(Word value);

//     InstructionSet get_instruction_set();
//     Word           get_pipeline_entry(int i);
//     bool           check_cond(uint cond);
//     void           refill_pipeline();
//     void           set_flag(Flag flag, bool value);
//     bool           get_flag(Flag flag);

//     Word           read_word(Word address, AccessType access_type);
//     Half           read_half(Word address, AccessType access_type);
//     Byte           read_byte(Word address, AccessType access_type);

//     void           write_word(Word address, Word value, AccessType access_type);
//     void           write_half(Word address, Half value, AccessType access_type);
//     void           write_byte(Word address, Byte value, AccessType access_type);

//     void           run_idle_cycle();
//     void           set_pipeline_access_type(AccessType access_type);

//     bool           in_a_privileged_mode();
//     void           update_mode();
//     bool           has_spsr();
    
//     void           raise_exception(CpuException exception)();
//     void           halt();
//     void           unhalt();

//     static @property Architecture architecture();
// }
// module emu.hw.cpu.arm7tdmi;

// import emu;

// import util;

// __gshared ARM7TDMI arm7;
// final class ARMInterpretter(
//     Architecture architecture
// ) : ARMStrategy {
//     Word[18 * 7] register_file;
//     Word[18]     regs;

//     Word[2] arm_pipeline;
//     Half[2] thumb_pipeline;
    
//     Mem memory;

//     InstructionSet instruction_set;   

//     bool enabled = false;
//     bool halted  = false; 

//     CpuMode current_mode;

//     AccessType pipeline_access_type;

//     CpuTrace cpu_trace;

//     ulong num_log;

//     JITState* jit_state;
//     IR!(HostReg_x86_64, GuestReg_ARMv4T)* ir;
//     Emitter!(HostReg_x86_64, GuestReg_ARMv4T).Code emitter;

//     this(Mem memory, uint ringbuffer_size) {
//         this.memory = memory;
//     }

//     @property
//     static Architecture architecture() {
//         return architecture;
//     }

//     void run_instruction() {
//         if (halted) return;

//         if (!(cast(bool) get_cpsr()[7]) && interrupt7.irq_pending()) {
//             raise_exception!(CpuException.IRQ);
//         }

//         cpu_trace.capture();

//         if (num_log > 0) {
//             num_log--;
//             log_state();
//         }

//         if (instruction_set == InstructionSet.ARM) {
//             Word opcode = fetch!Word();
//             if (opcode == 0) error_arm7("ARM7 is probably executing data");
//             execute!Word(opcode);
//         } else {
//             Half opcode = fetch!Half();
//             execute!Half(opcode);
//         }
//     }

//     void log_state() {
//         version (quiet) {
//             return;
//         } else {
//             import std.stdio;
//             import std.format;

//             writef("LOG_ARM7 [%04d] ", num_log);
        
//             if (get_flag(Flag.T)) write("THM ");
//             else write("ARM ");

//             write(format("0x%08x ", instruction_set == InstructionSet.ARM ? arm_pipeline[0] : thumb_pipeline[0]));
            
//             for (int j = 0; j < 18; j++)
//                 write(format("%08x ", regs[j]));
            
//             writef(" | ");
//             writef(" %08x", get_reg(sp, MODE_SUPERVISOR));
//             writeln();
//         }
//     }

//     pragma(inline, true) Word get_reg(Reg id) {
//         return get_reg__raw(id, &regs);
//     }

//     pragma(inline, true) void set_reg(Reg id, Word value) {
//         set_reg__raw(id, value, &regs);
//     }

//     pragma(inline, true) Word get_reg(Reg id, CpuMode mode) {
//         bool is_banked = !(mode.REGISTER_UNIQUENESS.bit(id) & 1);

//         if (!is_banked && (current_mode.REGISTER_UNIQUENESS.bit(id) & 1)) {
//             return get_reg(id);
//         } else {
//             return get_reg__raw(id, cast(Word[18]*) (&register_file[mode.OFFSET]));
//         }
//     }

//     pragma(inline, true) void set_reg(Reg id, Word value, CpuMode mode) {
//         bool is_banked = !(mode.REGISTER_UNIQUENESS.bit(id) & 1);

//         if (!is_banked && (current_mode.REGISTER_UNIQUENESS.bit(id) & 1)) {
//             set_reg(id, value);
//         } else {
//             set_reg__raw(id, value, cast(Word[18]*) (&register_file[mode.OFFSET]));
//         }
//     }

//     pragma(inline, true) Word get_reg__raw(Reg id, Word[18]* regs) {
//         Word result;

//         if (unlikely(id == pc)) {
//             result = (*regs)[pc] - (instruction_set == InstructionSet.ARM ? 4 : 2);
//         } else {
//             result = (*regs)[id];
//         }
        
//         version (ift) { IFTDebugger.commit_reg_read(HwType.NDS7, id, current_mode, result); }
//         return result;
//     }

//     pragma(inline, true) void set_reg__raw(Reg id, Word value, Word[18]* regs) {
//         (*regs)[id] = value;

//         if (id == pc) {        
//             (*regs)[pc] &= instruction_set == InstructionSet.ARM ? ~3 : ~1;
//             pipeline_access_type = AccessType.NONSEQUENTIAL;
//             refill_pipeline();
//         }

//         version (ift) { IFTDebugger.commit_reg_write(HwType.NDS7, id, current_mode, value); }
//     }

//     pragma(inline, true) void align_pc(CpuMode mode) {
//         regs[mode.OFFSET + pc] &= instruction_set == InstructionSet.ARM ? ~3 : ~1;
//     }

//     InstructionSet get_instruction_set() { 
//         return instruction_set; 
//     }

//     Word get_pipeline_entry(int i) {
//         return Word(
//             instruction_set == InstructionSet.ARM ? 
//             arm_pipeline[i] :
//             thumb_pipeline[i]
//         ); 
//     }


//     void enable() {
//         this.halted = false;
//     }

//     void disable() {
//         this.halted = true;
//     }

//     void halt() {
//         this.halted = true;
//     }

//     void unhalt() {
//         this.halted = false;
//     }

//     void set_mode(CpuMode new_mode)() {
//         int mask;
//         mask = current_mode.REGISTER_UNIQUENESS;
        
//         // writeback
//         for (int i = 0; i < 18; i++) {
//             if (mask & 1) {
//                 register_file[MODE_USER.OFFSET + i] = regs[i];
//             } else {
//                 register_file[current_mode.OFFSET + i] = regs[i];
//             }

//             mask >>= 1;
//         }

//         mask = new_mode.REGISTER_UNIQUENESS;
//         for (int i = 0; i < 18; i++) {
//             if (mask & 1) {
//                 regs[i] = register_file[MODE_USER.OFFSET + i];
//             } else {
//                 regs[i] = register_file[new_mode.OFFSET + i];
//             }

//             mask >>= 1;
//         }

//         set_cpsr((get_cpsr() & 0xFFFFFFE0) | new_mode.CPSR_ENCODING);
        
//         instruction_set = get_flag(Flag.T) ? InstructionSet.THUMB : InstructionSet.ARM;
//         current_mode = new_mode;
//     }

//     Word get_cpsr() {
//         return regs[16];
//     }

//     // user and system modes dont have spsr. spsr reads return cpsr.
//     Word get_spsr() {
//         if (current_mode == MODE_USER || current_mode == MODE_SYSTEM) {
//             return get_cpsr();
//         }

//         return regs[17];
//     }

//     void set_cpsr(Word cpsr) {
//         regs[16] = cpsr;
//         instruction_set = get_flag(Flag.T) ? instruction_set.THUMB : instruction_set.ARM;
//     }

//     void set_spsr(Word spsr) {
//         regs[17] = spsr;
//     }

//     void refill_pipeline() {
//         if (instruction_set == InstructionSet.ARM) {
//             fetch!Word();
//             fetch!Word();
//         } else {
//             fetch!Half();
//             fetch!Half();
//         }
//     }

//     bool check_cond(uint cond) {
//         switch (cond) {
//             case 0x0: return ( get_flag(Flag.Z));
//             case 0x1: return (!get_flag(Flag.Z));
//             case 0x2: return ( get_flag(Flag.C));
//             case 0x3: return (!get_flag(Flag.C));
//             case 0x4: return ( get_flag(Flag.N));
//             case 0x5: return (!get_flag(Flag.N));
//             case 0x6: return ( get_flag(Flag.V));
//             case 0x7: return (!get_flag(Flag.V));
//             case 0x8: return ( get_flag(Flag.C) && !get_flag(Flag.Z));
//             case 0x9: return (!get_flag(Flag.C) ||  get_flag(Flag.Z));
//             case 0xA: return ( get_flag(Flag.N) ==  get_flag(Flag.V));
//             case 0xB: return ( get_flag(Flag.N) !=  get_flag(Flag.V));
//             case 0xC: return (!get_flag(Flag.Z) && (get_flag(Flag.N) == get_flag(Flag.V)));
//             case 0xD: return ( get_flag(Flag.Z) || (get_flag(Flag.N) != get_flag(Flag.V)));
//             case 0xE: return true;
//             case 0xF: error_arm7("ARM7 opcode has a condition of 0xF"); return false;

//             default: assert(0);
//         }
//     }

//     void raise_exception(CpuException exception)() {
//         // interrupts not allowed if the cpu itself has interrupts disabled.
//         Word cpsr = regs[16];

//         if ((exception == CpuException.IRQ && cpsr[7]) ||
//             (exception == CpuException.FIQ && cpsr[6])) {
//             return;
//         }

//         enum mode = get_mode_from_exception!(exception);

//         register_file[mode.OFFSET + 14] = regs[pc] - 2 * (get_flag(Flag.T) ? 2 : 4);
//         if (exception == CpuException.IRQ) {
//             register_file[mode.OFFSET + 14] += 4; // in an IRQ, the linkage register must point to the next instruction + 4
//         }

//         register_file[mode.OFFSET + 17] = cpsr;
//         set_mode!(mode);
//         cpsr = get_cpsr();

//         cpsr |= (1 << 7); // disable normal interrupts

//         static if (exception == CpuException.Reset || exception == CpuException.FIQ) {
//             cpsr |= (1 << 6); // disable fast interrupts
//         }
//         regs[16] = cpsr;

//         regs[pc] = get_address_from_exception!(exception);

//         set_flag(Flag.T, false);

//         refill_pipeline();
//         halted = false;
//     }

//     static uint get_address_from_exception(CpuException exception)() {
//         final switch (exception) {
//             case CpuException.Reset:             return 0x0000_0000;
//             case CpuException.Undefined:         return 0x0000_0004;
//             case CpuException.SoftwareInterrupt: return 0x0000_0008;
//             case CpuException.PrefetchAbort:     return 0x0000_000C;
//             case CpuException.DataAbort:         return 0x0000_0010;
//             case CpuException.IRQ:               return 0x0000_0018;
//             case CpuException.FIQ:               return 0x0000_001C;
//         }
//     }

//     static CpuMode get_mode_from_exception(CpuException exception)() {
//         final switch (exception) {
//             case CpuException.Reset:             return MODE_SUPERVISOR;
//             case CpuException.Undefined:         return MODE_UNDEFINED;
//             case CpuException.SoftwareInterrupt: return MODE_SUPERVISOR;
//             case CpuException.PrefetchAbort:     return MODE_ABORT;
//             case CpuException.DataAbort:         return MODE_ABORT;
//             case CpuException.IRQ:               return MODE_IRQ;
//             case CpuException.FIQ:               return MODE_FIQ;
//         }
//     }

//     static string get_exception_name(CpuException exception)() {
//         final switch (exception) {
//             case CpuException.Reset:             return "RESET";
//             case CpuException.Undefined:         return "UNDEFINED";
//             case CpuException.SoftwareInterrupt: return "SWI";
//             case CpuException.PrefetchAbort:     return "PREFETCH ABORT";
//             case CpuException.DataAbort:         return "DATA ABORT";
//             case CpuException.IRQ:               return "IRQ";
//             case CpuException.FIQ:               return "FIQ";
//         }
//     }

//     void set_flag(Flag flag, bool value) {
//         Word cpsr = get_cpsr();
//         cpsr[flag] = value;
//         set_cpsr(cpsr);

//         if (flag == Flag.T) {
//             instruction_set = value ? InstructionSet.THUMB : InstructionSet.ARM;
//         }
//     }

//     bool get_flag(Flag flag) {
//         return cast(bool) get_cpsr()[flag];
//     }

//     void set_pipeline_access_type(AccessType access_type) {
//         this.pipeline_access_type = access_type;
//     }

//     void run_idle_cycle() {
//         // TODO: replace with proper idling that actually takes up cpu cycles
//         pipeline_access_type = AccessType.NONSEQUENTIAL;
//     }

//     bool in_a_privileged_mode() {
//         return current_mode != MODE_USER;
//     }

//     void update_mode() {
//         int mode_bits = get_cpsr()[0..4];
//         static foreach (i; 0 .. 7) {
//             if (MODES[i].CPSR_ENCODING == mode_bits) {
//                 set_mode!(MODES[i]);
//             }
//         }
//     }

//     bool has_spsr() {
//         return !(current_mode == MODE_USER || current_mode == MODE_SYSTEM);
//     }

//     T internal_read(T)(Word address) {
//         pipeline_access_type = AccessType.NONSEQUENTIAL;

//         T result;
//         static if (is (T == Word)) result = memory.read_word(address);
//         static if (is (T == Half)) result = memory.read_half(address);
//         static if (is (T == Byte)) result = memory.read_byte(address);

//         for (int i = 0; i < T.sizeof; i++) {
//             version (ift) { IFTDebugger.commit_mem_read(HwType.NDS9, address + i, Word(result.get_byte(i))); }
//         }
//         return result;
//     }

//     void internal_write(T)(Word address, T value) {
//         pipeline_access_type = AccessType.NONSEQUENTIAL;

//         static if (is (T == Word)) memory.write_word(address, value);
//         static if (is (T == Half)) memory.write_half(address, value);
//         static if (is (T == Byte)) memory.write_byte(address, value);

//         for (int i = 0; i < T.sizeof; i++) {
//             version (ift) { IFTDebugger.commit_mem_write(HwType.NDS9, address + i, Word(value.get_byte(i))); }
//         }
//     }

//     Word read_word(Word address, AccessType access_type) { return internal_read!Word(address); }
//     Half read_half(Word address, AccessType access_type) { return internal_read!Half(address); }
//     Byte read_byte(Word address, AccessType access_type) { return internal_read!Byte(address); }

//     void write_word(Word address, Word value, AccessType access_type) { internal_write!Word(address, value); }
//     void write_half(Word address, Half value, AccessType access_type) { internal_write!Half(address, value); }
//     void write_byte(Word address, Byte value, AccessType access_type) { internal_write!Byte(address, value); }
// }
// // template (is_jit, HostReg) {
// //     final class ExecutionManager {
// //         static if (is_jit) {
// //             alias _IR = IR!(HostReg, GuestReg_ARMv4T);
// //             __gshared static IR* ir;

// //             final class MemoryUnitWrapper(T) {
// //                 int id;

// //                 this(S)(S value) {
// //                     this.value = MemoryUnit!T(cast(T) value);
// //                 }
                
// //                 this(T value) {
// //                     this.value = MemoryUnit!T(value);
// //                 }
                
// //                 MemoryUnitWrapper!T opUnary(string s)() {
// //                     ir.emit_unary!s(id);
// //                     return this;
// //                 }

// //                 MemoryUnitWrapper!T opBinary(string s)(MemoryUnit!T other) {
// //                     ir.emit_binary_var!s(id, other.id);
// //                     return this;
// //                 }

// //                 MemoryUnitWrapper!T opBinary(string s)(T other) {
// //                     ir.emit_binary_imm!s(id, other);
// //                     return this;
// //                 }

// //                 MemoryUnitWrapper!T opSlice(size_t start, size_t end) {
// //                     ir.emit_bits(id, start, end);
// //                     return this;
// //                 }

// //                 bool opIndex(size_t index) {
// //                     ir.emit_bit(id, index);
// //                     return this;
// //                 }

// //                 MemoryUnitWrapper!T rotate_right(int shift) {
// //                     ir.emit_ror(id, shift);
// //                     return this;
// //                 }

// //                 void opSliceAssign(S)(S value_s, size_t start, size_t end) {
// //                     ir.emit_bits_assign(id, start, end, value_s);
// //                 }

// //                 void opIndexAssign(S)(S value_s, size_t index) {
// //                     ir.emit_bit_assign(id, index, value_s);
// //                 }

// //                 void opIndexOpAssign(string s)(bool value, size_t index) {
// //                     ir.emit_binary_imm!s(id, value << index);
// //                 }

// //                 // void opAssign(S value) {
// //                 //     ir.emit_assign(id, value);
// //                 // }
// //             }

// //             void get_reg(Reg reg) {
// //                 ir.emit_get_reg(reg);
// //             }

// //             void set_reg(Reg reg, Word value) {
// //                 ir.emit_set_reg(reg, value.id);
// //             }
// //         } else {
// //             alias MemoryUnitWrapper(T) = MemoryUnit!T;
// //         }
// //     }
// // }