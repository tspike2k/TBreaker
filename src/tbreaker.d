// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

private:

import memory;
import math;
import assets;
import logging;
import print;
import platform;
import core.stdc.stdlib : atol;

string readField(string field)
{
    return "filePos += readFile(file, filePos, &" ~ field ~ ", " ~ field ~ ".sizeof);";
}

nothrow @nogc:

public:

__gshared immutable string appVersionString = "1.0";
__gshared immutable string appTitle = "TBreaker ";

struct AppState
{
    Timer         workTimer;
    Timer         breakTimer;
    Timer         limitTimer;
    ScreenType    currentScreen;
    MemoryArena   tempMemory;
    
    Vect4         hudColor;
    Vect4         bgColor;
    GameFont      bigFont;
    GameFont      medFont;
}

public bool initApp(AppState* s)
{
    clearToZero(s);
    
    s.bgColor = Vect4(0.0f, 100.0f/255.0f, 200.0f/255.0f, 1.0f);
    s.hudColor = Vect4(1, 1, 1, 1);
    
    enum tempMemorySize = 2L * 1024L * 1024L;
    s.tempMemory.base = allocMemory(tempMemorySize, 0);
    s.tempMemory.length = tempMemorySize;
    
    import print;
     
    auto appFilePath = getAppFilePath();
    char[4096] pathBuffer = void;
    // TODO: Cross-platform asset loading (Slashes are an issue)
    auto fontFileName = format!"{0}/en.fnt"(pathBuffer, appFilePath); 
    
    if (!loadFonts(s, fontFileName.ptr)) return false;
    
    s.currentScreen = ScreenType.WORK;
    
    s.workTimer.sTarget  = 30.0f * 60.0f;
    s.breakTimer.sTarget = 5.0f  * 60.0f;
    s.limitTimer.sTarget = 4.0f * 60.0f * 60.0f;
    
    auto configFileName = format!"{0}/config.txt"(pathBuffer, appFilePath);
    auto configFile = openFile(configFileName.ptr, PLATFORM_FILE_MODE_READ);
    if(configFile)
    {
        scope(exit) closeFile(configFile);
        auto contents = readEntireFile(configFile, &s.tempMemory);
        //logDebug!"Config file contents: \n`{0}`\n"(contents);
        
        char[] reader = contents;
        auto word = nextWordOrNumber(reader);
        while(word.length > 0)
        {
            if(stringsMatch("work", word) || stringsMatch("break", word) || stringsMatch("limit", word))
            {
                auto timerName = word;
            
                long hr, min, sec;
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    hr = atol(word.ptr);                
                }
                
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    min = atol(word.ptr);                
                }
                
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    sec = atol(word.ptr);                
                }
                
                if(stringsMatch("work", timerName))
                {
                    logDebug!"work time: {0}:{1}:{2}\n"(hr, min, sec);
                    s.workTimer.sTarget = cast(float)(hr*60*60 + min*60 + sec);
                }
                else if(stringsMatch("break", timerName))
                {
                    logDebug!"break time: {0}:{1}:{2}\n"(hr, min, sec);
                    s.breakTimer.sTarget = cast(float)(hr*60*60 + min*60 + sec);
                }
                else if(stringsMatch("limit", timerName))
                {
                    logDebug!"limit time: {0}:{1}:{2}\n"(hr, min, sec);
                    s.limitTimer.sTarget = cast(float)(hr*60*60 + min*60 + sec);
                }
            }
            
            if(stringsMatch("bg", word) || stringsMatch("fg", word)) 
            {
                char[] colorName = word;
                
                long r, g, b;
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    r = atol(word.ptr);                
                }
                
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    g = atol(word.ptr);                
                }
                
                word = nextWordOrNumber(reader);
                if(word.length)
                {
                    b = atol(word.ptr);                
                }
                
                if(stringsMatch("bg", colorName))
                {
                    logDebug!"bg color: {0},{1},{2}\n"(r, g, b);
                    s.bgColor.r = r == 0 ? 0.0f: cast(float)r / 255.0f;
                    s.bgColor.g = g == 0 ? 0.0f: cast(float)g / 255.0f;
                    s.bgColor.b = b == 0 ? 0.0f: cast(float)b / 255.0f;
                }
                else if(stringsMatch("fg", colorName))
                {
                    logDebug!"fg color: {0},{1},{2}\n"(r, g, b);
                    s.hudColor.r = r == 0 ? 0.0f: cast(float)r / 255.0f;
                    s.hudColor.g = g == 0 ? 0.0f: cast(float)g / 255.0f;
                    s.hudColor.b = b == 0 ? 0.0f: cast(float)b / 255.0f;
                }   
            }
            
            word = nextWordOrNumber(reader);
        }
    }
    else
    {
        logWarn!"Unable to load file {0}. Using default settings.\n"(configFileName);
    }
       
    renderClearColor(s.bgColor.r, s.bgColor.g, s.bgColor.b, s.bgColor.a);
       
    return true;
}

public void updateApp(AppState* s, float dt)
{
    reset(&s.tempMemory);
    
    auto lTextBatch = nextRenderBatch(&s.tempMemory, RENDER_BATCH_TEXT, 512);
    auto mTextBatch = nextRenderBatch(&s.tempMemory, RENDER_BATCH_TEXT, 512);
    lTextBatch.font = &s.bigFont;
    mTextBatch.font = &s.medFont;
    
    switch (s.currentScreen)
    {
        case ScreenType.WORK:
        {
            s.workTimer.sCurrent += dt;
            if (s.limitTimer.sTarget > 0.0f) s.limitTimer.sCurrent += dt;
         
            if (s.limitTimer.sCurrent > s.limitTimer.sTarget)
            {
                s.limitTimer.sCurrent = 0;
                s.currentScreen = ScreenType.LIMIT;
                s.limitTimer.sTarget = 45;
                setWindowAsTopmost(true);
            }
            else if (s.workTimer.sCurrent > s.workTimer.sTarget)
            {
                s.workTimer.sCurrent = 0;
                s.currentScreen = ScreenType.BREAK;
                setWindowAsTopmost(true);
            }
        } break;
        
        case ScreenType.BREAK:
        {
            s.breakTimer.sCurrent += dt;
            if (s.limitTimer.sTarget > 0.0f) s.limitTimer.sCurrent += dt;
        
            if (s.limitTimer.sCurrent > s.limitTimer.sTarget)
            {
                s.limitTimer.sCurrent = 0;
                s.currentScreen = ScreenType.LIMIT;
                s.limitTimer.sTarget = 45.0f;
                setWindowAsTopmost(true);
            }
            else if (s.breakTimer.sCurrent > s.breakTimer.sTarget)
            {
                s.breakTimer.sCurrent = 0;
                s.currentScreen = ScreenType.WORK;
                setWindowAsTopmost(false);
            }
        } break;
        
        case ScreenType.LIMIT:
        {

        } break;
    
        default: assert(0);
    }

    uint windowWidth, windowHeight;
    getWindowSize(&windowWidth, &windowHeight);
    switch (s.currentScreen)
    {    
        case ScreenType.WORK:
        {
            uint msgW, msgH;
            
            char[] workLabel = cast(char[])"Work Time";
            renderGetTextSize(lTextBatch.font, workLabel, &msgW, &msgH);
            renderText(lTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 4, workLabel, s.hudColor);
            
            auto workTime = secondsToTimeText(s.workTimer.sTarget - s.workTimer.sCurrent, &s.tempMemory);
            renderGetTextSize(mTextBatch.font, workTime, &msgW, &msgH);
            renderText(mTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 4 + lTextBatch.font.lineGap, workTime, s.hudColor);
            
            char[] limitLabel = cast(char[])"Daily Limit";
            renderGetTextSize(lTextBatch.font, limitLabel, &msgW, &msgH);
            renderText(lTextBatch, windowWidth / 2 - msgW / 2, windowHeight - windowHeight / 4, limitLabel, s.hudColor);
            
            auto limitTime = secondsToTimeText(s.limitTimer.sTarget - s.limitTimer.sCurrent, &s.tempMemory);
            renderGetTextSize(mTextBatch.font, limitTime, &msgW, &msgH);
            renderText(mTextBatch, windowWidth / 2 - msgW / 2, windowHeight - windowHeight / 4 + lTextBatch.font.lineGap, limitTime, s.hudColor);
        } break;
        
        case ScreenType.BREAK:
        {
            uint msgW, msgH;
            
            char[] breakLabel = cast(char[])"Time to take a break!";
            renderGetTextSize(lTextBatch.font, breakLabel, &msgW, &msgH);
            renderText(lTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 2, breakLabel, s.hudColor);
            
            auto breakTime = secondsToTimeText(s.breakTimer.sTarget - s.breakTimer.sCurrent, &s.tempMemory);
            renderGetTextSize(mTextBatch.font, breakTime, &msgW, &msgH);
            renderText(mTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 2 + lTextBatch.font.lineGap, breakTime, s.hudColor);
        } break;
        
        case ScreenType.LIMIT:
        {
            uint msgW, msgH;
            
            char[] limitLabel = cast(char[])"Daily limit reached";
            renderGetTextSize(lTextBatch.font, limitLabel, &msgW, &msgH);
            renderText(lTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 2, limitLabel, s.hudColor);

            char[] limitSub = cast(char[])"Time to turn off your computer";
            renderGetTextSize(mTextBatch.font, limitSub, &msgW, &msgH);
            renderText(mTextBatch, windowWidth / 2 - msgW / 2, windowHeight / 2 + lTextBatch.font.lineGap, limitSub, s.hudColor);
        } break;
    
        default: assert(0);
    }
}

private:

enum ScreenType : uint
{
    WORK,
    BREAK,
    LIMIT
}

struct Timer
{
    float sCurrent;
    float sTarget;
}

bool loadFonts(AppState* s, const char* fileName)
{
    ulong readFont(FileHandle* file, GameFont* font, ulong filePos)
    {
        uint fontWidth, fontHeight;
        mixin(readField("fontWidth"));
        mixin(readField("fontHeight"));

        ulong pixelsSize = fontWidth*fontHeight*uint.sizeof;
        ubyte* pixels = cast(ubyte*)allocMemory(pixelsSize, 0);
        filePos += readFile(file, filePos, pixels, fontWidth * fontHeight*uint.sizeof);
        
        GameTexture* texture = &font.texture;
        *texture = GameTexture.init;
        texture.w = fontWidth;
        texture.h = fontHeight;
        texture.textureID = generateTextureIDFromPixels(pixels, fontWidth, fontHeight);
        freeMemory(pixels, pixelsSize);
        
        mixin(readField("font.lineGap"));
        mixin(readField("font.spaceWidth"));
        mixin(readField("font.height"));
        mixin(readField("font.baseline"));
        mixin(readField("font.codepointsMin"));
        mixin(readField("font.codepointsMax"));
        mixin(readField("font.glyphsCount"));
        
        // TODO: Allocate from main memory instead?
        font.glyphs = cast(GameFontGlyph*)allocMemory(GameFontGlyph.sizeof * font.glyphsCount, 0);
        foreach(glyphIndex; 0 .. font.glyphsCount)
        {
            GameFontGlyph* glyph = &font.glyphs[glyphIndex];
            mixin(readField("glyph.codepoint"));
            mixin(readField("glyph.w"));
            mixin(readField("glyph.h"));
            mixin(readField("glyph.origin.x"));
            mixin(readField("glyph.origin.y"));
            mixin(readField("glyph.advance"));
            mixin(readField("glyph.textureTop"));
            mixin(readField("glyph.textureBottom"));
            mixin(readField("glyph.textureLeft"));
            mixin(readField("glyph.textureRight"));
        }            
        
        return filePos;
    }

    auto file = openFile(fileName, PLATFORM_FILE_MODE_READ);
    if(file)
    {
        scope(exit) closeFile(file);
        
        ulong filePos = 0;
                
        // TODO: Error checking!
        ubyte fileVersion;
        filePos += readFile(file, filePos, &fileVersion, fileVersion.sizeof);
        assert(fileVersion == 0);
        uint totalFonts;
        filePos += readFile(file, filePos, &totalFonts, totalFonts.sizeof);
      
        logDebug!("Total fonts: {0}\n")(totalFonts);
        
        if(totalFonts < 2)
        {
            logFatal!"Font pack has too few fonts: expected >= 2 got {0}\n"(totalFonts);
            return false;
        }
      
        filePos = readFont(file, &s.medFont, filePos);
        filePos = readFont(file, &s.bigFont, filePos);
    }
    else
    {
        logFatal!"Unable to load font pack {0}.\n"(fileName);
        return false;
    }
    
    return true;
}

bool stringsMatch(const(char[]) a, const(char[]) b)
{    
    if (a.length != b.length)
    {
        return false;
    }
    
    foreach(i; 0 .. a.length)
    {
        if(a[i] != b[i]) return false;
    }
    
    return true;
}

char[] secondsToTimeText(float seconds, MemoryArena* arena)
{
    auto buffer = allocArray!(char)(arena, 256);
    uint h =  cast(uint)seconds / (60 * 60);
    uint m = (cast(uint)seconds - (h * 60 * 60)) / 60;
    uint s =  cast(uint)seconds - (h * 60 * 60) - (m * 60);
    
    return format!"{0}h {1}m {2}s"(buffer, h, m, s);
}

bool isAlphabetic(char c)
{
    return ((c >= 'a') && (c <= 'z')) || ((c >= 'A') && (c <= 'Z'));
}

bool isNumeric(char c)
{
    return (c >= '0') && (c <= '9');
}

char[] nextWordOrNumber(ref char[] reader)
{
    foreach(i; 0 .. reader.length)
    {
        if(isAlphabetic(reader[i]) || isNumeric(reader[i]) || i == reader.length - 1)
        {
            reader = reader[i .. reader.length];
            break;
        }
    }
    
    char[] result;
    if (isAlphabetic(reader[0]))
    {
        foreach(i; 0 .. reader.length)
        {
            if(!isAlphabetic(reader[i]) || i == reader.length - 1)
            {
                result = reader[0 .. i];
                reader = reader[i .. reader.length];
                break;
            }
        }
    }
    else if (isNumeric(reader[0]))
    {
        foreach(i; 0 .. reader.length)
        {
            if(!isNumeric(reader[i]) || i == reader.length - 1)
            {
                result = reader[0 .. i];
                reader = reader[i .. reader.length];
                break;
            }
        }
    }
   
    return result;
}