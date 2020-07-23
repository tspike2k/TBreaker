// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module assets;

private string readField(string field)
{
    return "filePos += readFile(file, filePos, &" ~ field ~ ", " ~ field ~ ".sizeof);";
}

@nogc nothrow:
public:

import math: Vect2;

private {
    import platform;
    import logging;
}

struct GameTextureFrame
{
    uint w, h;
    Vect2 origin;

    float textureTop;
    float textureBottom;
    float textureLeft;
    float textureRight;
};

struct GameFontGlyph
{
    uint codepoint;
    uint w, h;
    Vect2 origin;
    uint advance;
    
    float textureTop;
    float textureBottom;
    float textureLeft;
    float textureRight;
};

struct GameTexture
{
    uint w, h;
    GameTextureFrame* frames;
    uint framesCount;
    
    TextureID textureID;
};

struct GameFont
{
    // TODO: Store/use kerning information!
    GameFontGlyph* glyphs;
    uint glyphsCount;
    
    // TODO: Allow for multiple ranges in order to support internationalization.
    uint codepointsMin;
    uint codepointsMax;
    GameTexture texture; 
    // GameTexture* texture;
    
    uint lineGap;
    uint spaceWidth;
    uint height;
    uint baseline;
};

//version(utils){}
//else:

struct AssetCache
{
    GameFont[32] fonts;
    uint fontsCount;
    
    GameTexture[512] sprites;
    uint spritesCount;
};

void loadFonts(AssetCache* cache, const char* pack)
{
    auto file = openFile(pack, PLATFORM_FILE_MODE_READ);
    if(file)
    {
        uint glyphsCount;
        ulong filePos = 0;
                
        // TODO: Error checking!
        ubyte fileVersion;
        filePos += readFile(file, filePos, &fileVersion, fileVersion.sizeof);
        assert(fileVersion == 0);
        uint totalFonts;
        filePos += readFile(file, filePos, &totalFonts, totalFonts.sizeof);
        assert(totalFonts < cache.fonts.length);
      
        logDebug!("Total fonts: {0}\n")(totalFonts);
      
        foreach(fontIndex; 0 .. totalFonts)
        {
            GameFont* font = &cache.fonts[cache.fontsCount++];
        
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
        }
        
        closeFile(file);    
    }
    else
    {
        // TODO: Propogate this error!
        assert(0);
    }
}

void loadSprites(AssetCache* cache, string packName)
{
    auto file = openFile(packName.ptr, PLATFORM_FILE_MODE_READ);
    if(file)
    {
        ulong filePos = 0;
                
        // TODO: Error checking!
        ubyte fileVersion;
        filePos += readFile(file, filePos, &fileVersion, fileVersion.sizeof);
        assert(fileVersion == 0);
        uint totalSprites;
        filePos += readFile(file, filePos, &totalSprites, totalSprites.sizeof);
        assert(totalSprites < cache.sprites.length - cache.spritesCount);
      
        logDebug!("Total sprites: {0}\n")(totalSprites);
      
        foreach(spriteIndex; 0 .. totalSprites)
        {        
            uint spriteWidth, spriteHeight;
            mixin(readField("spriteWidth"));
            mixin(readField("spriteHeight"));

            // TODO: Rather than allocMemory, use temp memory arena?
            ulong pixelsSize = spriteWidth*spriteHeight*uint.sizeof;
            ubyte* pixels = cast(ubyte*)allocMemory(pixelsSize, 0);
            filePos += readFile(file, filePos, pixels, spriteWidth * spriteHeight*uint.sizeof);
            
            assert(cache.spritesCount < cache.sprites.length);
            GameTexture* texture = &cache.sprites[cache.spritesCount++];
            *texture = GameTexture.init;
            texture.w = spriteWidth;
            texture.h = spriteHeight;
            texture.textureID = generateTextureIDFromPixels(pixels, spriteWidth, spriteHeight);
            freeMemory(pixels, pixelsSize);
            
            mixin(readField("texture.framesCount"));
            
            logDebug!(" {0} frames for sprite {0}\n")(texture.framesCount, spriteIndex);
            
            texture.frames = cast(GameTextureFrame*)allocMemory(GameTextureFrame.sizeof * texture.framesCount, 0);
            
            foreach(frameIndex; 0 .. texture.framesCount)
            {
                auto frame = &texture.frames[frameIndex];
                mixin(readField("frame.w"));
                mixin(readField("frame.h"));
                mixin(readField("frame.origin.x"));
                mixin(readField("frame.origin.y"));
                mixin(readField("frame.textureTop"));
                mixin(readField("frame.textureBottom"));
                mixin(readField("frame.textureLeft"));
                mixin(readField("frame.textureRight"));                
            }
        }
        
        closeFile(file);    
    }
    else
    {
        // TODO: Propogate this error!
        assert(0);
    }
}

GameTexture* getTexture(AssetCache* assetsCache, const(char)* name);