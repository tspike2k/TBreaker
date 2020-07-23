// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module strings;

@nogc nothrow:

ulong length(const(char)* s)
{
    ulong result = 0;
    while(s[result] != '\0')
    {
        result++;
    }
    
    return result;
}

bool stringsMatch(string a, string b)
{    
    if (a.length != b.length)
    {
        return false;
    }
    
    foreach(i, _; a)
    {
        if(a[i] != b[i]) return false;
    }
    
    return true;
}

string advancePast(ref char[] reader, char deliminator)
{    
    ulong place = 0; 
    while (place < reader.length && reader[place] != deliminator)
    {
        place++;
    }
    
    string subString = cast(string)reader[0..place];
    
    if (place + 1 < reader.length)
    {
        reader = reader[place + 1 .. reader.length];
    }
    else
    {
        reader = reader[reader.length..reader.length];
    }
    
    return subString;
}

version(none)
{
    // NOTE: Succeeded by the more powerful print/format functions.
    char[] bakeText(Args...)(ref char[] textBuffer, const char[] formatStr, Args args)
    {
        string snprintfWrapper(uint argsLength)
        {
            import std.conv;
            string result = `snprintf(textBuffer.ptr, textBuffer.length, formatStr.ptr`;
            foreach(argIndex; 0 .. argsLength)
            {
                result ~= `, _param_` ~ to!string(argIndex+2);
            }
            result ~= `);`;
            
            return result;
        }

        import core.stdc.stdio : snprintf;
        import strings : length;
        
        mixin(snprintfWrapper(Args.length));
        char[] result = textBuffer[0 .. length(textBuffer.ptr)];
        return result;
    }
}