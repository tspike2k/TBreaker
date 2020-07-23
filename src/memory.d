// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module memory;

public @nogc nothrow:

public import core.stdc.string: memset, memcpy;

// TODO: Move this to a containers.d file?
struct BucketArray(T, ulong bucketSize, Allocator)
{
    struct Bucket(T)
    {
        T[bucketSize] elements;
        ulong count;
        
        Bucket!T* next;
    };

    Bucket!T first;
    Bucket!T* last;
    alias first this;
    
    Allocator* allocator;
    
    void make(Allocator* a)
    {
        last = &first;
        allocator = a;
    }
    
    void push(in T t)
    {
        assert(last.count < last.elements.length);
        last.elements[last.count++] = t;
        if(last.count == last.elements.length)
        {
            auto wasLast = last;
            last = allocType!(Bucket!T)(allocator);
            wasLast.next = last;
        }
    }
}

// TODO: Test this data structure!
struct FreeList(T, Allocator)
{    
    T* first;
    T* firstFree;
    
    Allocator* allocator;
    
    void make(Allocator* a)
    {
        allocator = a;
    }
    
    T* add()
    {
        auto entry = firstFree;
        if(entry)
        {
            firstFree = entry.next;
        }
        else
        {
            entry = allocType!(T)(allocator);
        }
        
        if(first)
        {
            first.prev = entry;
        }
        
        entry.next = first;
        entry.prev = null;
        first = entry;
        
        return entry;
    }
    
    void remove(T* entry)
    {
        auto prev = entry.prev;
        prev.next = entry.next;
        
        entry.next = firstFree;
        entry.prev = null;
        firstFree = entry;
    }
    
    void free()
    {
        static if(__traits(compiles, free(allocator, firstFree)))
        {
            // TODO: Free all entries, one by one, if the allocator supports it            
        }
    }
}

// TODO: Add more allocators than just a MemoryArena

struct MemoryArena
{
    void* base;
    ulong length;
    ulong used;
    MemoryArenaFrame* lastFrame;
};

struct MemoryArenaFrame
{
    private ulong memoryRollbackLocation;
    MemoryArenaFrame* nextFrame;
};


//
// TODO: Pass (and use) memory alignment for allocation functions
//

void* allocRaw(MemoryArena* arena, ulong size)
{
    assert(size > 0);
    assert(arena.used + size < arena.length);
    assert(arena.used + size > arena.used);
    
    void* result = (cast(ubyte*)arena.base + arena.used);
    memset(result, 0, size);
    arena.used += size;
    
    return result;
}

T[] allocArray(T)(MemoryArena* arena, ulong count)
{
    assert(count > 0);    
    T* mem = cast(T*)allocRaw(arena, T.sizeof*count);
    T[] result = mem[0 .. count];
    return result;
}

T* allocType(T)(MemoryArena* arena)
{
    import meta : hasMember;
    T* result = cast(T*)allocRaw(arena, T.sizeof);
    
    return result;
}

void pushFrame(MemoryArena* arena)
{
    auto memRestore = arena.used;
    MemoryArenaFrame* topFrame = allocType!MemoryArenaFrame(arena);
    
    topFrame.memoryRollbackLocation = memRestore;
    topFrame.nextFrame = arena.lastFrame;
    arena.lastFrame = topFrame;
}

void popFrame(MemoryArena* arena)
{
    assert(arena.lastFrame);
    arena.used = arena.lastFrame.memoryRollbackLocation;
    arena.lastFrame = arena.lastFrame.nextFrame;
}

void reset(MemoryArena* arena)
{
    arena.used = 0;
    arena.lastFrame = null;
}

void clearToZero(T)(T* t)
{
    pragma(inline, true);
    memset(t, 0, T.sizeof);
}

// NOTE: UDAs used to tag serializable members
enum NoSerialize;
enum ToSerialize;
struct ArrayLen {string expr;}

ulong serialize(T)(FileHandle* file, ulong filePos, in T t)
{
    import meta;
    
    ulong bytesWritten = 0;
    
    static if(is(T == union))
    {
        static assert(getSymbolsByUDA!(T, ToSerialize).length <= 1);        
        
        static if (getSymbolsByUDA!(T, ToSerialize).length == 1)
        {
            //pragma(msg, T.stringof ~ "." ~ getSymbolsByUDA!(T, ToSerialize)[0].stringof ~ " marked as ToSerialize");
            bytesWritten += serialize(file, filePos+bytesWritten, mixin("t." ~ getSymbolsByUDA!(T, ToSerialize)[0].stringof));
        }
        else
        {
            // TODO: If no union member is tagged ToSerialize, search for the largest union member and serialize that one.
            static assert(0);
        }
    }
    else static if(is(T == struct))
    {
        static if (!hasUDA!(T, NoSerialize))
        {            
            static foreach(member; __traits(allMembers, typeof(t)))
            {{
                static if(!hasUDA!(__traits(getMember, t, member), NoSerialize))
                {
                    static if(isArray!(typeof(__traits(getMember, t, member))) && getUDAs!(__traits(getMember, t, member), ArrayLen).length == 1)
                    {
                        //pragma(msg, T.stringof ~ "." ~ member ~ " has custom ArrayLen");
                        
                        enum arrayLengthExpr = getUDAs!(__traits(getMember, t, member), ArrayLen)[0].expr;
                        bytesWritten += serialize(file, filePos+bytesWritten, mixin("t." ~ member ~ "[0 .. " ~ arrayLengthExpr ~ "]"));
                    }
                    else
                    {
                        bytesWritten += serialize(file, filePos+bytesWritten, __traits(getMember, t, member));                    
                    }
                }
                else
                {
                    //pragma(msg, T.stringof ~ "." ~ member ~ " is marked as NoSerialize");
                }
            }}        
        }
    }
    else static if (isArray!T)
    {   
        static if (__traits(isArithmetic, T[0]))
        {
            bytesWritten += writeFile(file, filePos+bytesWritten, t.ptr, t[0].sizeof * t.length); 
        }
        else
        {
            foreach(i; 0 .. t.length)
            {
                bytesWritten += serialize(file, filePos+bytesWritten, t[i]);
            }
        }
    }
    else static if (__traits(isArithmetic, T))
    {
        bytesWritten += writeFile(file, filePos+bytesWritten, &t, t.sizeof);        
    }
    else
    {
        pragma(msg, "ERR: Unable to serialize type " ~ T.stringof);
        static assert(0);
    }
    
    return bytesWritten;
}