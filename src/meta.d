// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module meta;

public import std.traits;

bool isStructPacked(T)()
if(is(T == struct))
{
    size_t membersSize;   
    static foreach(member; __traits(allMembers, T))
    {
        membersSize += mixin("T." ~ member ~ ".sizeof");
    }
 
    return membersSize == T.sizeof;
}

version(none)
{
    bool testFunc(int a, int b);

    // NOTE: Incomplete function signature extractor. This is as far as I got.
    // See here for explination on how this template works:
    // https://forum.dlang.org/post/qdasbrihugkvpjpywhhg@forum.dlang.org
    template getFuncSig(alias f, string name)
    {
        import std.traits;
        enum getFuncSig = (ReturnType!f).stringof ~ " " ~ name ~ (Parameters!f).stringof;
    }
}

string enumString(T)(T t)
if(is(T == enum))
{
    import std.traits : EnumMembers;
    static foreach (i, member; EnumMembers!T)
    {
        if (t == member)
        {
            return __traits(identifier, EnumMembers!T[i]);
        }
    }
    assert(0, "ERR: Unable to find enum member for type " ~ T.stringof ~ ".");
}