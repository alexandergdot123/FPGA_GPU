
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
        adjacentCheckRead, //check adjacency
        adjacentCheckWrite, //check adjacency

        adjacentReadOffAxisFirstLoadMasters,
        adjacentReadOffAxisFirstSearchHeader1,
        adjacentReadOffAxisFirstSearchHeader2,//unused
        adjacentReadOffAxisFirstCheckHit,
        adjacentReadOffAxisFirstCacheHitDistributeData,
        adjacentReadOffAxisFirstCacheMissGlobalRead1,
        adjacentReadOffAxisFirstCacheMissGlobalRead2,
        adjacentReadOffAxisFirstCacheMissDistributeData,

        adjacentReadRegularLoadMasters,
        adjacentReadRegularSearchHeader1,
        adjacentReadRegularSearchHeader2,//unused
        adjacentReadRegularCheckHit,
        adjacentReadRegularCacheHitDistributeData,
        adjacentReadRegularCacheMissGlobalRead1,
        adjacentReadRegularCacheMissGlobalRead2,
        adjacentReadRegularCacheMissDistributeData,

        nonAdjacentReadLoadMasters,
        nonAdjacentReadSearchHeader1,
        nonAdjacentReadSearchHeader2,//unused
        nonAdjacentReadCheckHit,
        nonAdjacentReadCacheHitDistributeData,
        nonAdjacentReadCacheMissGlobalRead1,
        nonAdjacentReadCacheMissGlobalRead2,
        nonAdjacentReadCacheMissDistributeData,//I need to do this 24 times.

        //Now for writes
        adjacentWriteOffAxisFirstLoadMasters,
        adjacentWriteOffAxisFirstSearchHeader,
        adjacentWriteOffAxisFirstCheckHit,
        adjacentWriteOffAxisFirstPartialWrite,
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
        adjacentWriteOffAxisLastSearchHeader,
        adjacentWriteOffAxisLastCheckHit,
        adjacentWriteOffAxisLastPartialWrite,
        adjacentWriteOffAxisLastOnlyGlobal,
        adjacentWriteOffAxisLastGlobalWait,
    
        nonAdjacentWriteLoadMasters,
        nonAdjacentWriteSearchHeader1,
        nonAdjacentWriteCheckHit,
        nonAdjacentWritePartialWrite,
        nonAdjacentWriteGlobal1,
        nonAdjacentWriteGlobal2
    } memState;
endpackage

