#ifndef FUNCTIONS_H
#define FUNCTIONS_H

#pragma once
/****************** Include Files ********************/
#include "xparameters.h" //necessary for MicroBlaze system parameters

#include <stdio.h>
#include <stdint.h>
//#include <omp.h>

/****************** Defines ********************/
#define AXI_BASE_ADDRESS 0x40000000 //Need to be changed later
#define AXI_OFFSET_STEP 0x4 //Offset between continuous slaves

#define FRAME_WIDTH 640
#define FRAME_HEIGHT 480

#define FRAME_A 0x80000000  // Framebuffer memory base in GPU
#define FRAME_B 0x81000000
#define MAGIC_COLOR 0x05              // Transparency color

// Base address of base sprite (Hardcode)
#define MARIO_BASE  0x00000000
#define TILE_BASE   0x0000030C
#define ENEMY_BASE  0x000007D5
#define FLAG_BASE   0x00000B59
#define COIN_BASE   0x00001531
#define START_BASE  0x00001619
#define END_BASE    0x0004C6E9
#define FAIL_BASE   0x000976E9
#define BLANK       0X000E26E9



//Sprite dimentions
#define MARIO_WIDTH 26
#define MARIO_HEIGHT 30

#define ENEMY_WIDTH 40
#define ENEMY_HEIGHT 20

#define COIN_WIDTH 40
#define COIN_HEIGHT 20

#define FLAG_WIDTH 40
#define FLAG_HEIGHT 20

#define TILE_WIDTH 35
#define TILE_HEIGHT 35


/****************** Functions ********************/
// destReg = register destination
// srcReg1 = register 1 in function
// srcReg2 = register 2 in function
// isImmediate  = determine whether have immediate in this function
// isSubtract = determine whether is subtraction
// immediate = immediate
// proceedPositive = Proceed if Positive (same for proceedNegative, proceedZero)
//skipLines = how many lines skips

// Add/Subtract
void makeAddSubtractInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isImmediate, uint8_t isSubtract, uint8_t srcReg2, int16_t immediate);

// AND/OR
void makeAndOrInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isOr, uint8_t isImmediate, uint8_t srcReg2, uint8_t signExtend, uint16_t immediate);

// Multiply
void makeMultiplyInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isImmediate, uint8_t srcReg2, int16_t immediate);

// Bit-shifting
void makeBitShiftInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t isLeftShift, uint8_t shiftAmount);

// Compare (subtract from) Immediate
void makeCompareImmediateInstruction(uint8_t proceedPositive, uint8_t proceedZero, uint8_t proceedNegative, uint8_t skipLines, uint8_t srcReg, int16_t immediate);

// Compare (subtract from) Dual Source
void makeCompareDualSourceInstruction(uint8_t proceedPositive, uint8_t proceedZero, uint8_t proceedNegative, uint8_t skipLines, uint8_t srcReg1, uint8_t srcReg2);

// Load Shared Memory Register + Register
void makeLoadSharedMemoryRRInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t srcReg2);

// Load Shared Memory Immediate + Register
void makeLoadSharedMemoryIRInstruction(uint8_t destReg, uint8_t srcReg, uint32_t immediate);

// Load Global Memory Immediate + Register
void makeLoadGlobalMemoryIRInstruction(uint8_t destReg, uint8_t srcReg, uint32_t immediate);

// Load Global Memory Register + Register
void makeLoadGlobalMemoryRRInstruction(uint8_t destReg, uint8_t srcReg1, uint8_t srcReg2);

// Store Shared Memory Immediate + Register
void makeStoreSharedMemoryIRInstruction(uint8_t regWrite, uint8_t srcReg, int32_t offset);

// Store Shared Memory Register + Register
void makeStoreSharedMemoryRRInstruction(uint8_t regWrite, uint8_t srcReg1, uint8_t srcReg2);

// Store Global Memory Immediate + Register
void makeStoreGlobalMemoryIRInstruction(uint8_t regWrite, uint8_t srcReg, uint8_t byteControl, int16_t offset);

// Store Global Memory Register + Register
void makeStoreGlobalMemoryRRInstruction(uint8_t regWrite, uint8_t srcReg1, uint8_t srcReg2, uint8_t byteControl);

// Send Instruction to AXI Bus
void sendInstructionToAXISlave(uint32_t instruction, uint32_t slaveIndex);

// drawSprite
void drawSprite(uint32_t frameBufferBase, int x, int y, uint32_t spriteBase, int spriteWidth, int spriteHeight, int frameWidth, uint8_t magicColor);

void broadcastDrawSpriteInstructions(uint32_t frameBufferBase, int x, int y, uint32_t spriteBase, int spriteWidth, int spriteHeight, int frameWidth, int rowsPerCore, uint8_t magicColor);

#endif
