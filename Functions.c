#include "Functions.h"

// HelperFunction For Creating Instruction
uint32_t createInstruction(uint8_t opcode, uint32_t fields) {
    return (opcode << 28) | fields;
}

// Add/Subtract
void makeAddSubtractInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isImmediate, uint8_t isSubtract, uint8_t srcReg2, int16_t immediate) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (isImmediate << 21) | (isSubtract << 20);
    if (isImmediate) {
        instruction |= (immediate & 0xFFFF);
    } else {
        instruction |= (srcReg2 << 17);
    }
    uint32_t result = createInstruction(0x0, instruction);
    sendInstructionToAXISlave(result, 0);
}

// AND/OR
void makeAndOrInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isOr, uint8_t isImmediate, uint8_t srcReg2, uint8_t signExtend, uint16_t immediate) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (isOr << 21) | (isImmediate << 20);
    if (isImmediate) {
        instruction |= (signExtend << 19) | (immediate & 0xFFFF);
    } else {
        instruction |= (srcReg2 << 17);
    }
    uint32_t result =  createInstruction(0x1, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Multiply
void makeMultiplyInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isImmediate, uint8_t srcReg2, int16_t immediate) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (isImmediate << 21);
    if (isImmediate) {
        instruction |= (immediate & 0xFFFF);
    } else {
        instruction |= (srcReg2 << 17);
    }
    uint32_t result = createInstruction(0x2, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Bit-shifting
void makeBitShiftInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isLeftShift, uint8_t shiftAmount) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (isLeftShift << 21) | (shiftAmount << 18);
    uint32_t result = createInstruction(0x3, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Compare (subtract from) Immediate
void makeCompareImmediateInstruction(uint8_t proceedPositive, uint8_t proceedZero, uint8_t proceedNegative, uint8_t skipLines, uint8_t srcReg, int16_t immediate) {
    uint32_t instruction = (proceedPositive << 27) | (proceedZero << 26) | (proceedNegative << 25) | (skipLines << 19) | (srcReg << 16) | (immediate & 0xFFFF);
    uint32_t result = createInstruction(0x4, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Compare (subtract from) Dual Source
void makeCompareDualSourceInstruction(uint8_t proceedPositive, uint8_t proceedZero, uint8_t proceedNegative, uint8_t skipLines, uint8_t srcReg1, uint8_t srcReg2) {
    uint32_t instruction = (proceedPositive << 27) | (proceedZero << 26) | (proceedNegative << 25) | (skipLines << 19) | (srcReg1 << 16) | (srcReg2 << 13);
    uint32_t result = createInstruction(0x5, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Load Shared Memory Register + Register
void makeLoadSharedMemoryRRInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t srcReg2) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (srcReg2 << 19);
    uint32_t result =  createInstruction(0x9, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Load Shared Memory Immediate + Register
void makeLoadSharedMemoryIRInstruction(uint8_t destReg, uint8_t srcReg, uint32_t immediate) {
    uint32_t instruction = (destReg << 25) | (srcReg << 22) | (immediate & 0x3FFFFF);
    uint32_t result =  createInstruction(0x8, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Load Global Memory Immediate + Register
void makeLoadGlobalMemoryIRInstruction(uint8_t destReg, uint8_t srcReg, uint32_t immediate) {
    uint32_t instruction = (destReg << 25) | (srcReg << 22) | (immediate & 0x3FFFFF);
    uint32_t result = createInstruction(0xA, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Load Global Memory Register + Register
void makeLoadGlobalMemoryRRInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t srcReg2) {
    uint32_t instruction = (destReg << 25) | (srcReg1 << 22) | (srcReg2 << 19);
    uint32_t result = createInstruction(0xB, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Store Shared Memory Immediate + Register
void makeStoreSharedMemoryIRInstruction(uint8_t regWrite, uint8_t srcReg, int32_t offset) {
    uint32_t instruction = (regWrite << 25) | (srcReg << 22) | (offset & 0x3FFFF);
    uint32_t result =  createInstruction(0xC, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Store Shared Memory Register + Register
void makeStoreSharedMemoryRRInstruction(uint8_t regWrite, uint8_t srcReg1, uint8_t srcReg2) {
    uint32_t instruction = (regWrite << 25) | (srcReg1 << 22) | (srcReg2 << 19);
    uint32_t result = createInstruction(0xD, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Store Global Memory Immediate + Register
void makeStoreGlobalMemoryIRInstruction(uint8_t regWrite, uint8_t srcReg, uint8_t byteControl, int16_t offset) {
    uint32_t instruction = (regWrite << 25) | (srcReg << 22) | (byteControl << 18) | (offset & 0xFFFF);
    uint32_t result = createInstruction(0xE, instruction);
    sendInstructionToAXISlave(result, 0);
}

// Store Global Memory Register + Register
void makeStoreGlobalMemoryRRInstruction(uint8_t regWrite, uint8_t srcReg1, uint8_t srcReg2, uint8_t byteControl) {
    uint32_t instruction = (regWrite << 25) | (srcReg1 << 22) | (srcReg2 << 19) | (byteControl << 15);
    uint32_t result = createInstruction(0xF, instruction);
    sendInstructionToAXISlave(result, 0);
}

// HelperFunction to send a 32-bit instruction to an AXI slave (temporary)
void sendInstructionToAXISlave(uint32_t instruction, uint32_t slaveIndex) {
    // Get the target address
    uint32_t targetAddress = AXI_BASE_ADDRESS + (slaveIndex * AXI_OFFSET_STEP);
    // Send
    *(volatile uint32_t *)targetAddress = instruction;
}

void drawSprite(uint32_t frameBufferBase, int x, int y,
                uint32_t spriteBase, int spriteWidth, int spriteHeight,
                int frameWidth, uint8_t magicColor) {
    int rowsPerCore = (spriteHeight + 15) / 16; // Divide workload among 16 cores

    // Broadcast instructions to all cores
    broadcastDrawSpriteInstructions(frameBufferBase, x, y, spriteBase,
                                     spriteWidth, spriteHeight, frameWidth,
                                     rowsPerCore, magicColor);
}

void broadcastDrawSpriteInstructions(uint32_t frameBufferBase, int x, int y,
                                     uint32_t spriteBase, int spriteWidth,
                                     int spriteHeight, int frameWidth,
                                     int rowsPerCore, uint8_t magicColor) {

    for (int reg = 0; reg < 7; reg++) {
    	makeAndOrInstruction(reg, reg, 0, 1, 0, 0, 0); // reg = reg AND 0
    }
    //Storing the frameBufferBase at the Reg 0
    uint32_t topHalf = frameBufferBase >> 16;
    makeAddSubtractInstruction(0, 0, 1, 0, 0, topHalf);
    makeBitShiftInstruction(0,0,1, 4);
    uint32_t bottomHalf = frameBufferBase & 0x0000FFFF;
    makeAddSubtractInstruction(0, 0, 1, 0, 0, bottomHalf);

    //Storing the spriteBase at the Reg 3
    uint32_t topHalf2 = spriteBase >> 16;
    makeAddSubtractInstruction(3, 3, 1, 0, 3, topHalf2);
    makeBitShiftInstruction(3,3,1, 4);
    uint32_t bottomHalf2 = spriteBase & 0x0000FFFF;
    makeAddSubtractInstruction(3, 3, 1, 0, 3, bottomHalf2);

    // Core-level workload control using ThreadID (manual assignment)
    makeMultiplyInstruction(6, 7, 1, 0, rowsPerCore);          // reg 6 = ThreadID * rowsPerCore (startRow)

    for (int row = 0; row < rowsPerCore; row++) {
        makeAddSubtractInstruction(1, 6, 1, 0, row, 0); // reg 1 = currentRow = startRow + row

        for (int col = 0; col < spriteWidth; col++) {
            // Skip processing if currentRow >= spriteHeight
            makeCompareImmediateInstruction(0, 1, 1, 19, 1, spriteHeight);  // if currentRow >= spriteHeight, skip next 19 lines (don't do anything until next loop)

            // Calculate sprite pixel address
            makeAndOrInstruction(2, 2, 0, 1, 0, 0, 0);  //Clear reg 2
            makeMultiplyInstruction(2, 1, 1, 0, spriteWidth); //reg2 = currentRow * spriteWidth
            makeAddSubtractInstruction(2, 2, 0, 0, 1, 0); // reg 2 = reg2 + reg1
            makeAddSubtractInstruction(2, 2, 0, 0, 3, 0); // reg 2 = reg2 + reg 3 (spriteBase)

            // Load sprite pixel value into reg 4
            makeLoadGlobalMemoryIRInstruction(4, 2, 0);

            // Skip pixel if it matches magicColor
            makeCompareImmediateInstruction(0, 1, 0, 13, 4, magicColor); // if reg 4 == magicColor, skip 13 lines

            // Calculate framebuffer address for pixel
            makeAndOrInstruction(2, 2, 0, 1, 0, 0, 0);  //Clear reg 2
            makeCompareImmediateInstruction(0, 0, 1, 11, 2, x); // skip 13 lines if x is negative
            makeAddSubtractInstruction(5, 1, 1, 0, 1, y);   // reg 5 =  (currentRow + y)
            makeAddSubtractInstruction(2, 1, 1, 0, 1, y); // reg 2 =  (currentRow + y)
            makeAddSubtractInstruction(2, 2, 1, 0, 1, 1); // reg 2 =  (currentRow + y + 1)
            makeCompareImmediateInstruction(0, 1, 1, 7, 5, 480); // if frame row is larger than screen, don't draw
            makeMultiplyInstruction(5, 5, 1, 5, frameWidth); // reg5 = (currentRow + y) * frameWidth
            makeMultiplyInstruction(2, 2, 1, 2, frameWidth); // reg2 = (currentRow + y + 1) * frameWidth , which will be the start of next line
            makeAddSubtractInstruction(5, 5, 1, 0, 5, x); // reg5 = (currentRow + y) * frameWidth + x
            makeAddSubtractInstruction(5, 5, 1, 0, 5, col); //reg 5 = (currentRow + y) * frameWidth + x  + col
            makeCompareDualSourceInstruction(0, 1, 1, 2, 5, 2); // if reg5 >= reg 2, skip drawing
            makeAddSubtractInstruction(5, 5, 0, 0, 0, 0); // reg 5 = reg 5 + reg 0 (framebufferAddress)

            // Store pixel value to framebuffer
            makeStoreGlobalMemoryRRInstruction(4, 5, 15, 0);
        }
    }
}
