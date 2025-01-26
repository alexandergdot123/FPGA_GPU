
package gpuCoreTypes;

    typedef enum {
        Decode, 
        Add1,
        Add2,
        Bitwise1,
        Bitwise2,
        Multiply1,
        Multiply2,
        Multiply3,
        Multiply4,
        BitShift1,
        BitShift2,
        CompareImmediate1,
        CompareImmediate2,
        CompareDual1,
        CompareDual2,
        LoadSharedImmediate1,
        LoadSharedReg1,
        LoadGlobalImmediate1,
        LoadGlobalReg1,
        StoreSharedImmediate1,
        StoreSharedReg1,
        StoreGlobalImmediate1,
        StoreGlobalReg1,
        LoadSharedImmediate2,
        LoadSharedReg2,
        LoadGlobalImmediate2,
        LoadGlobalReg2,
        StoreSharedImmediate2,
        StoreSharedReg2,
        StoreGlobalImmediate2,
        StoreGlobalReg2,
        StoreMemoryDataShared,
        StoreMemoryDataGlobal,
        WriteMemoryDataShared,
        WriteMemoryDataGlobal,
        ReadMemoryDataShared,
        ReadMemoryDataGlobal,
        StoreReadMemoryData,
        Bad
    } state_t;
    
    
    typedef enum {
        Idle, 
        adjacentCheckRead,
        adjacentCheckWrite,

        adjacentReadOffAxisFirstLoadMasters,
        adjacentReadOffAxisFirstSearchHeader1,
        adjacentReadOffAxisFirstSearchHeader2,
        adjacentReadOffAxisFirstCheckHit,
        adjacentReadOffAxisFirstCacheHitDistributeData,
        adjacentReadOffAxisFirstCacheMissGlobalRead1,
        adjacentReadOffAxisFirstCacheMissGlobalRead2,
        adjacentReadOffAxisFirstCacheMissDistributeData, //in the case of a miss, write the data to cache

        adjacentReadRegularLoadMasters,
        adjacentReadRegularSearchHeader1,
        adjacentReadRegularSearchHeader2,
        adjacentReadRegularCheckHit,
        adjacentReadRegularCacheHitDistributeData,
        adjacentReadRegularCacheMissGlobalRead1,
        adjacentReadRegularCacheMissGlobalRead2,
        adjacentReadRegularCacheMissDistributeData, //in the case of a miss, write the data to cache
        //I may need more states to accommodate the last non-filled read if there was an off axis read. I don't think so though.

        nonAdjacentReadLoadMasters,
        nonAdjacentReadSearchHeader1,
        nonAdjacentReadSearchHeader2,
        nonAdjacentReadCheckHit,
        nonAdjacentReadCacheHitDistributeData,
        nonAdjacentReadCacheMissGlobalRead1,
        nonAdjacentReadCacheMissGlobalRead2,
        nonAdjacentReadCacheMissDistributeData,//I need to do this 32 times.

        //Now for writes
        adjacentWriteOffAxisFirstLoadMasters,
        adjacentWriteOffAxisFirstSearchHeader,//also write to global here too.
        adjacentWriteOffAxisFirstCheckHit,
        adjacentWriteOffAxisFirstPartialWrite,//and here, write to only PART of the data Bram if it hit. Otherwise don't update cache
        adjacentWriteOffAxisFirstOnlyGlobal,
        adjacentWriteOffAxisFirstGlobalWait,
        
        adjacentWriteRegularLoadMasters,
        adjacentWriteRegularSearchHeader,
        adjacentWriteRegularCheckHit,
        adjacentWriteRegularWriteBoth,
        adjacentWriteRegularWriteOnlyGlobal,
        adjacentWriteRegularGlobalWait,
        
        
        adjacentWriteOffAxisMiddleLoadMasters,
        adjacentWriteOffAxisMiddleSearchHeader,
        adjacentWriteOffAxisMiddleCheckHit,
        adjacentWriteOffAxisMiddleWriteBoth,
        adjacentWriteOffAxisMiddleWriteOnlyGlobal,
        adjacentWriteOffAxisMiddleGlobalWait,
        
        
        adjacentWriteOffAxisLastLoadMasters,
        adjacentWriteOffAxisLastSearchHeader,//also write to global here too.
        adjacentWriteOffAxisLastCheckHit,
        adjacentWriteOffAxisLastPartialWrite,//and here, write to only PART of the data Bram if it hit. Otherwise don't update cache
        adjacentWriteOffAxisLastOnlyGlobal,
        adjacentWriteOffAxisLastGlobalWait,
    
        nonAdjacentWriteLoadMasters, //I'm going to need to do this 32 times. So likely 32*5=160 cycles.
        nonAdjacentWriteSearchHeader1,
        nonAdjacentWriteCheckHit,
        nonAdjacentWritePartialWrite,
        nonAdjacentWriteGlobal1,
        nonAdjacentWriteGlobal2
    } memState;
endpackage

