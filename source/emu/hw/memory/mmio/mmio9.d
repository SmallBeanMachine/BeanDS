module emu.hw.memory.mmio.mmio9;

import emu.hw;

import util;

__gshared MMIO!mmio9_registers mmio9;

static const mmio9_registers = [
    MMIORegister("gpu_engine_a",          "DISPCNT",        0x0400_0000,  4, READ_WRITE),
    MMIORegister("gpu",                   "DISPSTAT9",      0x0400_0004,  2, READ_WRITE),
    MMIORegister("gpu",                   "VCOUNT",         0x0400_0006,  2, READ),
    MMIORegister("gpu_engine_a.ppu",      "BGxCNT",         0x0400_0008,  2, READ_WRITE).repeat(4, 2),
    MMIORegister("gpu_engine_a.ppu",      "BGxHOFS",        0x0400_0010,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_a.ppu",      "BGxVOFS",        0x0400_0012,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_a.ppu",      "BGxPA",          0x0400_0020,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "BGxPB",          0x0400_0022,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "BGxPC",          0x0400_0024,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "BGxPD",          0x0400_0026,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "BGxX",           0x0400_0028,  4,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "BGxY",           0x0400_002C,  4,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_a.ppu",      "WINxH",          0x0400_0040,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_a.ppu",      "WINxV",          0x0400_0044,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_a.ppu",      "WININ",          0x0400_0048,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu",      "WINOUT",         0x0400_004A,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu",      "MOSAIC",         0x0400_004C,  2,      WRITE),
    MMIORegister("gpu_engine_a.ppu",      "BLDCNT",         0x0400_0050,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu",      "BLDALPHA",       0x0400_0052,  2, READ_WRITE),
    MMIORegister("gpu_engine_a.ppu",      "BLDY",           0x0400_0054,  2,      WRITE),
    MMIORegister("dma9",                  "DMAxSAD",        0x0400_00B0,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",                  "DMAxDAD",        0x0400_00B4,  4, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",                  "DMAxCNT_L",      0x0400_00B8,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",                  "DMAxCNT_H",      0x0400_00BA,  2, READ_WRITE).repeat(4, 12),
    MMIORegister("dma9",                  "DMAxFILL",       0x0400_00E0,  4, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",               "TMxCNT_L",       0x0400_0100,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("timers9",               "TMxCNT_H",       0x0400_0102,  2, READ_WRITE).repeat(4, 4),
    MMIORegister("input",                 "KEYINPUT",       0x0400_0130,  2, READ),
    MMIORegister("ipc9",                  "IPCSYNC",        0x0400_0180,  4, READ_WRITE),
    MMIORegister("ipc9",                  "IPCFIFOCNT",     0x0400_0184,  4, READ_WRITE),
    MMIORegister("ipc9",                  "IPCFIFOSEND",    0x0400_0188,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("ipc9",                  "IPCFIFORECV",    0x0410_0000,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("auxspi",                "AUXSPICNT9",     0x0400_01A0,  2, READ_WRITE),
    MMIORegister("auxspi",                "AUXSPIDATA9",    0x0400_01A2,  2, READ_WRITE),
    MMIORegister("cart",                  "ROMCTRL",        0x0400_01A4,  4, READ_WRITE),
    MMIORegister("cart",                  "ROMDATAOUT",     0x0400_01A8,  8,      WRITE),
    MMIORegister("cart",                  "ROMRESULT",      0x0410_0010,  4, READ      ).dont_decompose_into_bytes(),
    MMIORegister("slot",                  "EXMEMCNT",       0x0400_0204,  2, READ_WRITE),
    MMIORegister("interrupt9",            "IME",            0x0400_0208,  4, READ_WRITE),
    MMIORegister("interrupt9",            "IE",             0x0400_0210,  4, READ_WRITE),
    MMIORegister("interrupt9",            "IF",             0x0400_0214,  4, READ_WRITE),
    MMIORegister("vram",                  "VRAMCNT",        0x0400_0240, 10, READ_WRITE).filter!((int i) => i != 7)(),
    MMIORegister("wram",                  "WRAMCNT",        0x0400_0247,  1, READ_WRITE),
    MMIORegister("math_div",              "DIVCNT",         0x0400_0280,  4, READ_WRITE),
    MMIORegister("math_div",              "DIV_NUMER",      0x0400_0290,  8, READ_WRITE),
    MMIORegister("math_div",              "DIV_DENOM",      0x0400_0298,  8, READ_WRITE),
    MMIORegister("math_div",              "DIV_RESULT",     0x0400_02A0,  8, READ),
    MMIORegister("math_div",              "DIVREM_RESULT",  0x0400_02A8,  8, READ),
    MMIORegister("math_sqrt",             "SQRTCNT",        0x0400_02B0,  4, READ_WRITE),
    MMIORegister("math_sqrt",             "SQRT_RESULT",    0x0400_02B4,  4, READ),
    MMIORegister("math_sqrt",             "SQRT_PARAM",     0x0400_02B8,  8, READ_WRITE),
    MMIORegister("nds",                   "POSTFLG",        0x0400_0300,  4, READ_WRITE),
    MMIORegister("gpu",                   "POWCNT1",        0x0400_0304,  2, READ_WRITE),
    MMIORegister("gpu_engine_b",          "DISPCNT",        0x0400_1000,  4, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu",      "BGxCNT",         0x0400_1008,  2, READ_WRITE).repeat(4, 2),
    MMIORegister("gpu_engine_b.ppu",      "BGxHOFS",        0x0400_1010,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_b.ppu",      "BGxVOFS",        0x0400_1012,  2,      WRITE).repeat(4, 4),
    MMIORegister("gpu_engine_b.ppu",      "BGxPA",          0x0400_1020,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "BGxPB",          0x0400_1022,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "BGxPC",          0x0400_1024,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "BGxPD",          0x0400_1026,  2,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "BGxX",           0x0400_1028,  4,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "BGxY",           0x0400_102C,  4,      WRITE).repeat(2, 16),
    MMIORegister("gpu_engine_b.ppu",      "WINxH",          0x0400_1040,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_b.ppu",      "WINxV",          0x0400_1044,  2,      WRITE).repeat(2, 2),
    MMIORegister("gpu_engine_b.ppu",      "WININ",          0x0400_1048,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu",      "WINOUT",         0x0400_104A,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu",      "MOSAIC",         0x0400_104C,  2,      WRITE),
    MMIORegister("gpu_engine_b.ppu",      "BLDCNT",         0x0400_1050,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu",      "BLDALPHA",       0x0400_1052,  2, READ_WRITE),
    MMIORegister("gpu_engine_b.ppu",      "BLDY",           0x0400_1054,  2,      WRITE),
    MMIORegister("gpu3d",                 "DISP3DCNT",      0x0400_0060,  2, READ_WRITE),
    MMIORegister("gpu3d",                 "GXSTAT",         0x0400_0600,  4, READ_WRITE),
    MMIORegister("gpu3d.geometry_engine", "GXFIFO",         0x0400_0400, 64,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_MODE",       0x0400_0440,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_PUSH",       0x0400_0444,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_POP",        0x0400_0448,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_STORE",      0x0400_044C,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_RESTORE",    0x0400_0450,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_IDENTITY",   0x0400_0454,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_LOAD_4x4",   0x0400_0458,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_LOAD_4x3",   0x0400_045C,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_MULT_4x4",   0x0400_0460,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_MULT_4x3",   0x0400_0464,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_MULT_3x3",   0x0400_0468,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_SCALE",      0x0400_046C,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "MTX_TRANS",      0x0400_0470,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "COLOR",          0x0400_0480,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "NORMAL",         0x0400_0484,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "TEXCOORD",       0x0400_0488,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_16",         0x0400_048C,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_10",         0x0400_0490,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_XY",         0x0400_0494,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_XZ",         0x0400_0498,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_YZ",         0x0400_049C,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VTX_DIFF",       0x0400_04A0,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "POLYGON_ATTR",   0x0400_04A4,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "TEXIMAGE_PARAM", 0x0400_04A8,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "PLTT_BASE",      0x0400_04AC,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "DIF_AMB",        0x0400_04C0,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "SPE_EMI",        0x0400_04C4,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "LIGHT_VECTOR",   0x0400_04C8,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "LIGHT_COLOR",    0x0400_04CC,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "SHININESS",      0x0400_04D0,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "BEGIN_VTXS",     0x0400_0500,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "END_VTXS",       0x0400_0504,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "SWAP_BUFFERS",   0x0400_0540,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VIEWPORT",       0x0400_0580,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "BOX_TEST",       0x0400_05C0,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "POS_TEST",       0x0400_05C4,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VEC_TEST",       0x0400_05C8,  4,      WRITE).dont_decompose_into_bytes(),
    MMIORegister("gpu3d.geometry_engine", "VEC_RESULT",     0x0400_0630,  6, READ),
];
