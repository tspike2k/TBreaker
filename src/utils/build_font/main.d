private nothrow @nogc:

import core.stdc.stdio;
import core.stdc.string;

import math;
import assets;

enum SRC_FONT_DIR = "./";
enum DEST_FONT_DIR = "../../../";

version = use_stb_truetype;

version(use_stb_truetype)
{
    extern(C)
    {
        struct stbtt__buf
        {
           ubyte *data;
           int cursor;
           int size;
        }

        struct stbtt_fontinfo
        {
           void*  userdata;
           ubyte* data;              // pointer to .ttf file
           int              fontstart;         // offset of start of font

           int numGlyphs;                     // number of glyphs, needed for range checking

           int loca,head,glyf,hhea,hmtx,kern,gpos; // table locations as offset from start of .ttf
           int index_map;                     // a cmap mapping for our chosen character encoding
           int indexToLocFormat;              // format needed to map from glyph index to glyph

           stbtt__buf cff;                    // cff font data
           stbtt__buf charstrings;            // the charstring index
           stbtt__buf gsubrs;                 // global charstring subroutines index
           stbtt__buf subrs;                  // private charstring subroutines index
           stbtt__buf fontdicts;              // array of font dicts
           stbtt__buf fdselect;               // map from glyph to fontdict
        }
        
        int stbtt_InitFont(stbtt_fontinfo *info, const(ubyte)* data, int offset);
        int stbtt_GetFontOffsetForIndex(const(ubyte)* data, int index);
        float stbtt_ScaleForPixelHeight(const(stbtt_fontinfo*) info, float pixels);
        void stbtt_GetCodepointHMetrics(const(stbtt_fontinfo*) info, int codepoint, int *advanceWidth, int *leftSideBearing);
        void stbtt_GetFontVMetrics(const(stbtt_fontinfo*) info, int *ascent, int *descent, int *lineGap);
        int stbtt_FindGlyphIndex(const(stbtt_fontinfo*) info, int unicode_codepoint);
        void stbtt_GetGlyphHMetrics(const(stbtt_fontinfo*) info, int glyph_index, int* advanceWidth, int* leftSideBearing);
        void stbtt_GetGlyphBitmapBox(const(stbtt_fontinfo*) font, int glyph, float scale_x, float scale_y, int* ix0, int* iy0, int* ix1, int* iy1);
        ubyte* stbtt_GetCodepointBitmap(const(stbtt_fontinfo*) info, float scale_x, float scale_y, int codepoint, int *width, int *height, int *xoff, int *yoff);
        void stbtt_FreeBitmap(ubyte* bitmap, void* userdata);
    }
}
else
{
    static assert(0, "Implement FreeType2 here!");
}

struct FontTableEntry
{
    uint height;
    string fileName;
}

immutable FontTableEntry[] fontTable =
[
    FontTableEntry(32, SRC_FONT_DIR ~ "LiberationSans-Bold.ttf"),
    FontTableEntry(40, SRC_FONT_DIR ~ "LiberationSans-Bold.ttf"),
];

struct PixelBuffer
{
    uint w, h;
    uint* pixels;
    uint pixelPadding;
    uint currentPixelX;
    uint currentPixelY;
};

__gshared char[2048] global_stringBuffer;

void saveToPPM(uint* pixels, uint imgWidth, uint imgHeight, const char* fileName)
{
    FILE* f = fopen(fileName, "w");
    if(f)
    {
        snprintf(global_stringBuffer.ptr, global_stringBuffer.length, "P6 %u %u 255 ", imgWidth, imgHeight);
        fwrite(global_stringBuffer.ptr, strlen(global_stringBuffer.ptr), 1, f);
        
        uint pixelsToWrite = imgWidth * imgHeight;
        uint pixelIndex = 0;
        while(pixelIndex < pixelsToWrite)
        {
            ubyte alpha = pixels[pixelIndex] >> 24;
            if (alpha == 0)
            {
                ubyte r = 255;
                ubyte g = 0;
                ubyte b = 255;
                fwrite(&r, ubyte.sizeof, 1, f);
                fwrite(&g, ubyte.sizeof, 1, f);
                fwrite(&b, ubyte.sizeof, 1, f);
            }
            else
            {
                ubyte r = alpha;
                ubyte g = alpha;
                ubyte b = alpha;
                fwrite(&r, ubyte.sizeof, 1, f);
                fwrite(&g, ubyte.sizeof, 1, f);
                fwrite(&b, ubyte.sizeof, 1, f);
            }
            
            pixelIndex++;
        }
            
        fclose(f);
    }
    else
    {
        printf("ERR: Unable to open %s file.\n", fileName);
    }
}

void saveToTGA(uint* pixels, uint imgWidth, uint imgHeight, const char* fileName)
{
    FILE* f = fopen(fileName, "w");
    if(f)
    {
        // NOTE: Write out the TGA header. Here's some useful websites on the subject:
        // https://stackoverflow.com/questions/16636311/what-is-the-simplest-rgb-image-format
        // http://paulbourke.net/dataformats/tga/
        // http://www.dca.fee.unicamp.br/~martino/disciplinas/ea978/tgaffs.pdf
        // https://en.wikipedia.org/wiki/Truevision_TGA
        ubyte[18] header = 0; // TODO: Make sure this clears all elements to zero. It should, if I remember the language docs correctly.
        header[2] = 2; // True-color image
        header[12] = imgWidth & 0xFF;
        header[13] = (imgWidth >> 8) & 0xFF;
        header[14] = imgHeight & 0xFF;
        header[15] = (imgHeight >> 8) & 0xFF;
        header[16] = 32; // Bits per pixel
        header[17] = 0x20; // ?
        
        fwrite(&header, header.sizeof, 1, f);

        uint pixelsToWrite = imgWidth * imgHeight;
        for(uint pixelIndex = 0; pixelIndex < pixelsToWrite; pixelIndex++)
        {
            uint pixel = pixels[pixelIndex];
            ubyte r = cast(ubyte)(pixel >> 0);
            ubyte g = cast(ubyte)(pixel >> 8);
            ubyte b = cast(ubyte)(pixel >> 16);
            ubyte a = cast(ubyte)(pixel >> 24);
            fwrite(&r, r.sizeof, 1, f);
            fwrite(&g, g.sizeof, 1, f);
            fwrite(&b, b.sizeof, 1, f);
            fwrite(&a, a.sizeof, 1, f);
        }
            
        fclose(f);
    }
    else
    {
        printf("ERR: Unable to open %s file.\n", fileName);
    }
}

void addGlyph(PixelBuffer* buffer, GameFont* font, stbtt_fontinfo* fontInfo, uint charcode, float fontScale, int fontHeight, int baseline)
{
    //assert(font.glyphsCount < ARRAY_LENGTH(font.glyphs));
    GameFontGlyph* glyph = &font.glyphs[font.glyphsCount];
    font.glyphsCount++;
    
    glyph.codepoint = charcode;
    int glyphIndex = stbtt_FindGlyphIndex(fontInfo, charcode);

    int advanceWidth, leftSideBearing;
    stbtt_GetGlyphHMetrics(fontInfo, glyphIndex, &advanceWidth, &leftSideBearing);
    
    int x0, y0, x1, y1;
    stbtt_GetGlyphBitmapBox(fontInfo, glyphIndex, fontScale, fontScale, &x0, &y0, &x1, &y1);
    
    int glyphWidth = x1-x0;
    int glyphHeight = y1-y0;
    
    if (buffer.currentPixelX + glyphWidth + buffer.pixelPadding >= buffer.w)
    {
        assert(buffer.currentPixelY + fontHeight + buffer.pixelPadding < buffer.h);
        buffer.currentPixelY += fontHeight + buffer.pixelPadding;
        buffer.currentPixelX = buffer.pixelPadding;
    }
    
    int renderedFontW, renderedFontH, renderedFontXOffset, renderedFontYOffset;
    ubyte* renderedFontPixels = stbtt_GetCodepointBitmap(fontInfo, fontScale, fontScale, charcode, &renderedFontW, &renderedFontH, &renderedFontXOffset, &renderedFontYOffset);
    
    assert(renderedFontW == glyphWidth);
    assert(renderedFontH == glyphHeight);
    for(int y = 0; y < glyphHeight; ++y)
    {
        for(int x = 0; x < glyphWidth; ++x)
        {
            // TODO: Gamma corrected colors. See here for more information:
            // https://www.youtube.com/watch?v=fVyzTKCfchw&feature=youtu.be&t=3275
            ubyte sourceVal = renderedFontPixels[x + y * glyphWidth];
            
            version(none)
            {
                uint outColor = (sourceVal << 24) | (0xff << 16) | (0xff << 8) | (0xff << 0);            
            }
            else
            {
                // Formula for premultiply alpha found here:
                // https://developer.nvidia.com/content/alpha-blending-pre-or-not-pre
                // DestinationColor.rgb = (SourceColor.rgb * One) + (DestinationColor.rgb * (1 - SourceColor.a));
                
                uint outColor = (sourceVal << 24) | (sourceVal << 16) | (sourceVal << 8) | (sourceVal << 0);
            }
            
            buffer.pixels[buffer.currentPixelX + x + (buffer.currentPixelY + y) * buffer.w] = outColor;            
        }
    }
    
    stbtt_FreeBitmap(renderedFontPixels, null);
    
    glyph.codepoint = charcode;
    glyph.w = glyphWidth;
    glyph.h = glyphHeight;

    glyph.textureTop    = (cast(float)buffer.currentPixelY + 0.5f) / cast(float)buffer.h;
    glyph.textureBottom = (cast(float)(buffer.currentPixelY + glyphHeight) - 0.5f) / cast(float)buffer.h;
    glyph.textureLeft   = (cast(float)buffer.currentPixelX + 0.5f) / cast(float)buffer.w;
    glyph.textureRight  = (cast(float)(buffer.currentPixelX + glyphWidth) - 0.5f) / cast(float)buffer.w;

    glyph.origin.x = floor(fontScale * cast(float)leftSideBearing);
    glyph.origin.y = baseline + y0;
    glyph.advance = cast(uint)floor(fontScale * cast(float)advanceWidth);
    
    buffer.currentPixelX += glyphWidth + buffer.pixelPadding;
}

uint blendColors(uint source, uint dest)
{
    // NOTE: Blending code taken directly from Handmade Hero.

    float sa = cast(float)((source >> 24) & 0xff);
    float sr = cast(float)((source >> 16) & 0xff);
    float sg = cast(float)((source >> 8) & 0xff);
    float sb = cast(float)((source >> 0) & 0xff);
    float rsa = (sa / 255.0f);
    
    float da = cast(float)((dest >> 24) & 0xff);
    float dr = cast(float)((dest >> 16) & 0xff);
    float dg = cast(float)((dest >> 8) & 0xff);
    float db = cast(float)((dest >> 0) & 0xff);
    float rda = (da / 255.0f);
    
    float invRsa = (1.0f - rsa);
    version(none)
    {
        float a = 255.0f * (rsa + rda  - rsa * rda);
        float r = invRsa*dr + sr;
        float g = invRsa*dg + sg;
        float b = invRsa*db + sb;    
    }
    else
    {
        float a = sa / 255.0f;
        float r = a*dr;
        float g = a*dg;
        float b = a*db;
    }
    
    uint result = (cast(uint)(a + 0.5f) << 24) | 
        (cast(uint)(r + 0.5f) << 16) | 
        (cast(uint)(g + 0.5f) << 8) |
        (cast(uint)(b + 0.5f) << 0);
        
    return result;
}

void main()
{
    import core.stdc.stdlib;
/+
    // TODO: Determine a better size based on the number of characters we need and the chosen pixel height.
    PixelBuffer buffer;
    buffer.w = 2048;
    buffer.h = 2048;
    buffer.pixels = (uint*)calloc(1, buffer.w * buffer.h * sizeof(buffer.pixels[0]));
    DEFER(free(buffer.pixels););
    buffer.pixelPadding = 4;
    buffer.currentPixelX = buffer.pixelPadding;
    buffer.currentPixelY = buffer.pixelPadding;

    FT_Library libft;
    if (FT_Init_FreeType(&libft) != 0)
    {
        LOG_ERR("Unable to initialize libfreetype. Aborting...");
        return 1;
    }
    DEFER(FT_Done_FreeType(libft));
    
    FontTableEntry* fontDef = &fontTable[3];
    
    FT_Face face;
    if (FT_New_Face(libft, fontDef.fileName, 0, &face) != 0)
    {
        LOG_ERR("Unable to load font file. Aborting...");
        return 1;
    }
    
    assert(!FT_Set_Char_Size(face, 0, fontDef.height * 64, 96, 96));
    
    if (fontDef.stroke > 0)
    {
        // NOTE: Stroke rendering code thanks to the following sources:
        // https://stackoverflow.com/questions/20874056/draw-text-outline-with-freetype    
    
        FT_Stroker stroker;
        FT_Stroker_New(libft, &stroker);
        FT_Stroker_Set(stroker, fontDef.stroke * 64, FT_STROKER_LINECAP_ROUND, FT_STROKER_LINEJOIN_ROUND, 0);
    
        // generation of an outline for single glyph:
        auto glyphIndex = FT_Get_Char_Index(face, 'X');
        FT_Load_Glyph(face, glyphIndex, FT_LOAD_DEFAULT);
        FT_Glyph glyph;
        FT_Get_Glyph(face.glyph, &glyph);
        FT_Glyph_StrokeBorder(&glyph, stroker, false, true);
        FT_Glyph_To_Bitmap(&glyph, FT_RENDER_MODE_NORMAL, nullptr, true);
        FT_BitmapGlyph bitmapGlyph = reinterpret_cast<FT_BitmapGlyph>(glyph);
        
        FT_Bitmap* bitmap = &bitmapGlyph.bitmap;   
        
        uint glyphWidth = bitmap.width;
        uint glyphHeight = bitmap.rows;
        for(uint y = 0; y < glyphHeight; ++y)
        {
            for(uint x = 0; x < glyphWidth; ++x)
            {
                ArrayIndex destPixelIndex = buffer.currentPixelX + x + (buffer.currentPixelY + y) * buffer.w;
                // TODO: Gamma corrected colors. See here for more information:
                // https://www.youtube.com/watch?v=fVyzTKCfchw&feature=youtu.be&t=3275
                ubyte sourceVal = bitmap.buffer[x + y * glyphWidth];
                uint outColor = (sourceVal << 24) | (0x00 << 16) | (0x00 << 8) | (0x00 << 0);
                buffer.pixels[destPixelIndex] = blendColors(outColor, buffer.pixels[destPixelIndex]);            
            }
        }    
        
        FT_Stroker_Done(stroker);
        FT_Done_Glyph(glyph);
        // TODO: Cleanup
    }
    
    {
        FT_Stroker stroker;
        FT_Stroker_New(libft, &stroker);
        FT_Stroker_Set(stroker, fontDef.stroke * 64, FT_STROKER_LINECAP_ROUND, FT_STROKER_LINEJOIN_ROUND, 0);
    
        // generation of an outline for single glyph:
        auto glyphIndex = FT_Get_Char_Index(face, 'X');
        FT_Load_Glyph(face, glyphIndex, FT_LOAD_DEFAULT);
        FT_Glyph glyph;
        FT_Get_Glyph(face.glyph, &glyph);
        //FT_Glyph_StrokeBorder(&glyph, stroker, false, true);
        FT_Glyph_To_Bitmap(&glyph, FT_RENDER_MODE_NORMAL, nullptr, true);
        FT_BitmapGlyph bitmapGlyph = reinterpret_cast<FT_BitmapGlyph>(glyph);
        
        FT_Bitmap* bitmap = &bitmapGlyph.bitmap;
        
        // TODO: Correct offset. 
        uint offset = fontDef.stroke;
        uint glyphWidth = bitmap.width;
        uint glyphHeight = bitmap.rows;
        for(uint y = 0; y < glyphHeight; ++y)
        {
            for(uint x = 0; x < glyphWidth; ++x)
            {
                // TODO: Gamma corrected colors. See here for more information:
                // https://www.youtube.com/watch?v=fVyzTKCfchw&feature=youtu.be&t=3275
                ArrayIndex destPixelIndex = buffer.currentPixelX + x + offset + (buffer.currentPixelY + y + offset) * buffer.w;
                ubyte sourceVal = bitmap.buffer[x + y * glyphWidth];
                uint outColor = ((uint)sourceVal << 24) | (0x00 << 16) | (0xff << 8) | (0xff << 0);
                buffer.pixels[destPixelIndex] = blendColors(outColor, buffer.pixels[destPixelIndex]);  
            }
        }
        LOG_INFO("w: %u u: %u", glyphWidth, glyphHeight);
    }
    
    // TODO: Cleanup 
    
    
    saveToTGA(buffer.pixels, buffer.w, buffer.h, "test.tga");
    
/*
    if (argc < 1)
    {
        printf("ERR: Must supply a filename for the font file to generate.\n");
        return 1;
    }
    
    uint totalFonts = ARRAY_LENGTH(fontTable);
    
    const char* outputFileName = argv[1];
    FILE* out = fopen(outputFileName, "w");
    if (!out)
    {
        LOG_ERR("Unable to open output file %s. Aborting.", outputFileName);
        return 1;
    }
    DEFER(fclose(out));
    
    ubyte version = 0;            
    fwrite(&version, sizeof(version), 1, out);
    fwrite(&totalFonts, sizeof(totalFonts), 1, out);
    
    FORUINT(tableIndex, totalFonts)
    {
        const char* fontFileName = fontTable[tableIndex].fileName;
        FILE* fontFile = fopen(fontFileName, "r");
        if (fontFile)
        {
        
            
            fclose(fontFile);
        }
        else
        {
            LOG_ERR("Unable to open font file %s. Skipping.", fontFileName);
        }
    }*/
+/

    stbtt_fontinfo fontInfo;

    uint totalFonts = cast(uint)fontTable.length;
    
    enum outputFileName = DEST_FONT_DIR ~ "en.fnt";
    FILE* outFile = fopen(outputFileName.ptr, "w");
    if (!outFile)
    {
        printf("ERR: Unable to open output file %s. Aborting.\n", outputFileName.ptr);
        return;
    }
    
    ubyte fileVersion = 0;            
    fwrite(&fileVersion, fileVersion.sizeof, 1, outFile);
    fwrite(&totalFonts, totalFonts.sizeof, 1, outFile);
    
    foreach(tableIndex; 0 .. totalFonts)
    {
        const char* fontFileName = fontTable[tableIndex].fileName.ptr;
        FILE* file = fopen(fontFileName, "r");
        if (file)
        {
            fseek(file, 0, SEEK_END);
            size_t fileSize = ftell(file);
            fseek(file, 0, SEEK_SET);
            ubyte* fileMemory = cast(ubyte*)malloc(fileSize);
            fread(fileMemory, fileSize, 1, file);
            
            if (stbtt_InitFont(&fontInfo, fileMemory, stbtt_GetFontOffsetForIndex(fileMemory, 0)))
            {
                GameFont font = {};
                float fontScale = stbtt_ScaleForPixelHeight(&fontInfo, fontTable[tableIndex].height);                
                {
                    int advanceWidth, leftSideBearing;
                    stbtt_GetCodepointHMetrics(&fontInfo, ' ', &advanceWidth, &leftSideBearing);
                    
                    font.spaceWidth = cast(uint)(advanceWidth * fontScale);
                    
                    int ascent, descent, lineGap;
                    stbtt_GetFontVMetrics(&fontInfo, &ascent, &descent, &lineGap);
                    font.lineGap = cast(uint)(cast(float)(ascent - descent + lineGap) * fontScale);
                    font.baseline = cast(uint)(cast(float)(ascent) * fontScale);
                }
                
                // TODO: Determine a better size based on the number of characters we need and the chosen pixel height.
                PixelBuffer buffer;
                buffer.w = 2048;
                buffer.h = 2048;
                buffer.pixels = cast(uint*)calloc(1, buffer.w * buffer.h * buffer.pixels[0].sizeof);
                scope(exit) free(buffer.pixels);
                buffer.pixelPadding = 4;
                buffer.currentPixelX = buffer.pixelPadding;
                buffer.currentPixelY = buffer.pixelPadding;
                
                font.height = fontTable[tableIndex].height;
                font.codepointsMin = '!';
                font.codepointsMax = 'z';
                font.glyphs = cast(GameFontGlyph*)malloc(GameFontGlyph.sizeof * font.codepointsMax - font.codepointsMin);
                scope(exit) free(font.glyphs);
                
                for(uint codepoint = font.codepointsMin; codepoint <= font.codepointsMax; codepoint++)
                {   
                    addGlyph(&buffer, &font, &fontInfo, codepoint, fontScale, fontTable[tableIndex].height, font.baseline);
                }
                
                snprintf(global_stringBuffer.ptr, global_stringBuffer.length, "font_preview_%u.tga", tableIndex);
                //saveToPPM(&buffer, global_stringBuffer);
                saveToTGA(buffer.pixels, buffer.w, buffer.h, global_stringBuffer.ptr);
                version(none)
                {
                    printf("{\n");
                    for(uint y = 0; y < buffer.h; ++y)
                    {
                        for(uint x = 0; x < buffer.w; ++x)
                        {
                            ubyte alpha = cast(ubyte)buffer.pixels[x + y * buffer.w] & 0x000000FF;
                            printf("%02X, ", alpha);
                        }
                        printf("\n");
                    }
                    printf("}\n");
                }
                    
                fwrite(&buffer.w, buffer.w.sizeof, 1, outFile);
                fwrite(&buffer.h, buffer.h.sizeof, 1, outFile);
                fwrite(buffer.pixels, buffer.w*buffer.h*buffer.pixels[0].sizeof, 1, outFile);
                
                fwrite(&font.lineGap, font.lineGap.sizeof, 1, outFile);
                fwrite(&font.spaceWidth, font.spaceWidth.sizeof, 1, outFile);
                fwrite(&font.height, font.height.sizeof, 1, outFile);
                fwrite(&font.baseline, font.baseline.sizeof, 1, outFile);
                fwrite(&font.codepointsMin, font.codepointsMin.sizeof, 1, outFile);
                fwrite(&font.codepointsMax, font.codepointsMax.sizeof, 1, outFile);
                fwrite(&font.glyphsCount, font.glyphsCount.sizeof, 1, outFile);
                foreach(glyphIndex; 0 .. font.glyphsCount)
                {
                    GameFontGlyph* glyph = &font.glyphs[glyphIndex];                
                    fwrite(&glyph.codepoint, glyph.codepoint.sizeof, 1, outFile);
                    fwrite(&glyph.w, glyph.w.sizeof, 1, outFile);
                    fwrite(&glyph.h, glyph.h.sizeof, 1, outFile);
                    fwrite(&glyph.origin.x, glyph.origin.x.sizeof, 1, outFile);
                    fwrite(&glyph.origin.y, glyph.origin.y.sizeof, 1, outFile);
                    fwrite(&glyph.advance, glyph.advance.sizeof, 1, outFile);
                    fwrite(&glyph.textureTop, glyph.textureTop.sizeof, 1, outFile);
                    fwrite(&glyph.textureBottom, glyph.textureBottom.sizeof, 1, outFile);
                    fwrite(&glyph.textureLeft, glyph.textureLeft.sizeof, 1, outFile);
                    fwrite(&glyph.textureRight, glyph.textureRight.sizeof, 1, outFile);
                }        
            }
            else
            {
                printf("ERR: Unable to init font info for font file %s. Skipping.\n", fontFileName);
            }
            
            fclose(file);
        }
        else
        {
            printf("ERR: Unable to open font file %s. Skipping.\n", fontFileName);
        }
    }
}