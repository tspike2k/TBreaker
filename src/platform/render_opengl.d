// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module platform.render_opengl;

private:

string debugMessageCase(string strOut, GLenum err, string src)
{
    import std.conv;
    return "case " ~ to!string(err) ~ ": {" ~ strOut ~ " = \"" ~ src ~ "\";} break;";
}

@nogc nothrow:
public:

enum TARGET_GL_VERSION_MAJOR = 3;
enum TARGET_GL_VERSION_MINOR = 2;

enum
{
    RENDER_BATCH_RECT,
    RENDER_BATCH_CIRCLE,
    RENDER_BATCH_CIRCLE_GRADIENT,
    
    RENDER_BATCH_SPRITE,
    RENDER_BATCH_TEXT,
};

// TODO(tspike): Add blend mode defines!

struct VertexPrimitive
{
    Vect2 pos;
    Vect4 color;
};
static assert(isStructPacked!VertexPrimitive);

struct VertexTextured
{
    Vect2 pos;
    Vect2 texCoord;
    Vect4 color;
};
static assert(isStructPacked!VertexTextured);

struct VertexGradient
{
    Vect2 pos;
    Vect2 texCoord;
    Vect4 color;
    Vect4 colorAlt;
}
static assert(isStructPacked!VertexGradient);

struct RenderBatch
{
    Vect2 camera;
    float scale;
    //ui32 blendMode;
    
    // TODO: The following fields are exclusively used for specific render batch types. Should we place these inside a union?
    GameTexture* texture;
    GameFont* font;
    // TODO: Allow shader selection!
    
    // TODO(tspike): Decide if we should use depth testing over the painters algorithm. 
    // This seems to be an either/or case. It doesn't seem like we can use both at the
    // same time. We could fake it by secretly incrementing a depth value by a small 
    // decimal value (say 0.0001f) when the renderer creates a new batch.
    //f32 depth; // NOTE(tspike): This must be normalized in the range of 0 to 1.
    private:
    
    uint type;
    BatchData batchData;
    RenderBatch* nextBatch;
};

struct TextureID
{
    private:
    GLuint textureHandle; 
};

bool renderInit()
{
    enum useStraitAlpha = false;

    clearToZero(&global_glState);
    alias gls = global_glState;
    //glPixelStorei(GL_UNPACK_ALIGNMENT, 1); // NOTE: Allows unaligned pixel packing for use with single component textures (ex: fonts)
    glEnable(GL_BLEND);
    //glEnable(GL_DEPTH_TEST);
    
    version(testing)
    {
        glClearColor(1.0f, 0.0f, 1.0f, 1.0f);    
    }
    else
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);    
    }
    
    static if(useStraitAlpha)
    {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    else
    {
        // NOTE: Using premultiplied alpha
        //glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    
        
    version(testing)
    {
        glEnable(GL_DEBUG_OUTPUT);
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        assert(glDebugMessageCallback);
        glDebugMessageCallback(&openGLDebugMessageCallback, null);    
    }
    
    // NOTE(tspike): Previously we were checking to see that our attribute location bindings were successful by
    // comparing our attrib constants to the number returned by glVertexAttribPointer. Appearently, this
    // isn't guaranteed to work as the GLSL compiler may optimize them away. See here:
    // https://stackoverflow.com/a/15640156
    
    if (!initShader(&global_glState.shaderRect, VertexType.PRIMITIVE, global_rectVertexSource, global_rectFragmentSource))
    {
        return false;
    }
    
    if (!initShader(&global_glState.shaderSprite, VertexType.TEXTURED, global_spriteVertexSource, global_spriteFragmentSource))
    {
        return false;
    }
    
    if (!initShader(&global_glState.shaderCircle, VertexType.TEXTURED, global_circleVertexSource, global_circleFragmentSource))
    {
        return false;
    }
    
    if (!initShader(&global_glState.shaderCircleGradient, VertexType.GRADIENT, global_circleGradientVertexSource, global_circleGradientFragmentSource))
    {
        return false;
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glUseProgram(0);     
     
    gls.fallbackTexture.w = 4;
    gls.fallbackTexture.h = 4;
    gls.fallbackTexture.textureID = generateTextureIDFromPixels(cast(ubyte*)global_fallbackTexturePixels.ptr, gls.fallbackTexture.w, gls.fallbackTexture.h);
     
    return true;
}

void renderClearColor(float r, float g, float b, float a)
{
    glClearColor(r, g, b, a);
}

RenderBatch* nextRenderBatch(MemoryArena* arena, uint batchType, uint maxRenderItems)
{
    alias gls = global_glState;
    
    // TODO: For some reason, pushing a render batch onto temp memory when arena.used is a certain number (like 1, 2, 5, and 6)
    // cause the render data to not display correctly. My quess is this has something to do with the pointer not being aligned in
    // memory in a way that OpenGL likes?
    //
    // Quick searches brings up these sites which might or might not be relevant:
    // http://wiki.lwjgl.org/wiki/The_Quad_updating_a_VBO_with_BufferSubData.html
    // https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/TechniquesforWorkingwithVertexData/TechniquesforWorkingwithVertexData.html
    // https://gamedev.stackexchange.com/questions/54868/glbuffersubdata-and-offset-alignment/54876
    // https://stackoverflow.com/questions/23688434/sending-normalized-vertex-attribute-produces-garbage
    // https://github.com/KhronosGroup/WebGL/issues/914
    // https://beginnerwithopengl.blogspot.com/2016/09/define-glbuffersubdata.html
    // https://stackoverflow.com/questions/30623737/gldrawelementsinstanced-freezes-or-slow-down-at-18680-instances
    
    // HACK: Right now we're simply bumping the arena.used count up to the nearest multiple of four. This seems to work for now,
    // but we REALLY need to understand why this is happening and fix it correctly, probably forcing the pointer returned by
    // ARENA_PUSH_TYPE to be aligned correctly.
    ulong padding = arena.used % 4;
    if (padding > 0) allocRaw(arena, padding); // TODO: Once we add alignment as a parameter to allocType, this will no longer be needed.
 
    RenderBatch* result = allocType!RenderBatch(arena);
    //result.texture = &assetCache.textures[0];
    result.scale = 1.0f;
    
    if (!gls.firstRenderBatch)
    {
        gls.firstRenderBatch = result;
    }
    else
    {
        gls.lastRenderBatch.nextBatch = result;
    }
    gls.lastRenderBatch = result;
    
    result.type = batchType;
    result.texture = &gls.fallbackTexture;

    BatchData* batchData = &result.batchData;
    // TODO: The only diffirence between these cases seems to be the verteces per element count and the size of each element.
    // Cache these in the the renderBatch on shader init?
    switch(result.type)
    {        
        case RENDER_BATCH_RECT:
        {
            batchData.shader = &gls.shaderRect;
            batchData.vertexBufferLength = maxRenderItems*VERTICES_PER_SQUARE;
            batchData.vertexBuffer = allocArray!VertexPrimitive(arena, batchData.vertexBufferLength).ptr;
            batchData.vertexIndexBuffer = allocArray!GLuint(arena, maxRenderItems * VERTEX_INDECES_PER_SQUARE);
            batchData.vertexSize = VertexPrimitive.sizeof;
        } break;
        
        case RENDER_BATCH_SPRITE:
        {
            batchData.shader = &gls.shaderSprite;
            batchData.vertexBufferLength = maxRenderItems*VERTICES_PER_SQUARE;
            batchData.vertexBuffer = allocArray!VertexTextured(arena, batchData.vertexBufferLength).ptr;
            batchData.vertexIndexBuffer = allocArray!GLuint(arena, maxRenderItems * VERTEX_INDECES_PER_SQUARE);
            batchData.vertexSize = VertexTextured.sizeof;
        } break;

        case RENDER_BATCH_CIRCLE:
        {
            batchData.shader = &gls.shaderCircle;
            batchData.vertexBufferLength = maxRenderItems*VERTICES_PER_SQUARE;
            batchData.vertexBuffer = allocArray!VertexTextured(arena, batchData.vertexBufferLength).ptr;
            batchData.vertexIndexBuffer = allocArray!GLuint(arena, maxRenderItems * VERTEX_INDECES_PER_SQUARE);
            batchData.vertexSize = VertexTextured.sizeof;
        } break;
        
        case RENDER_BATCH_TEXT:
        {
            batchData.shader = &gls.shaderSprite;
            batchData.vertexBufferLength = maxRenderItems*VERTICES_PER_SQUARE;
            batchData.vertexBuffer = allocArray!VertexTextured(arena, batchData.vertexBufferLength).ptr;
            batchData.vertexIndexBuffer = allocArray!GLuint(arena, maxRenderItems * VERTEX_INDECES_PER_SQUARE);
            batchData.vertexSize = VertexTextured.sizeof;
        } break;
        
        case RENDER_BATCH_CIRCLE_GRADIENT:
        {
            batchData.shader = &gls.shaderCircleGradient;
            batchData.vertexBufferLength = maxRenderItems*VERTICES_PER_SQUARE;
            batchData.vertexBuffer = allocArray!VertexGradient(arena, batchData.vertexBufferLength).ptr;
            batchData.vertexIndexBuffer = allocArray!GLuint(arena, maxRenderItems * VERTEX_INDECES_PER_SQUARE);
            batchData.vertexSize = VertexGradient.sizeof;
        } break;
        
        default:
        {
            assert(!"Unsupported batch type!");
        } break;
    }
    
    return result;
}

void renderRect(RenderBatch* batch, float x, float y, float w, float h, Vect4 color)
{
    assert(batch.type == RENDER_BATCH_RECT);
    BatchData* batchData = &batch.batchData;
    VertexPrimitive[] vertexBuffer;
    {
        VertexPrimitive* temp = cast(VertexPrimitive*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    
    assert(batchData.itemsPushed*VERTICES_PER_SQUARE < vertexBuffer.length); 
    
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    VertexPrimitive[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
    
    v[0].pos.x = x;
    v[0].pos.y = y;
    v[0].color = color;
    
    v[1].pos.x = x + w;
    v[1].pos.y = y;
    v[1].color = color;
    
    v[2].pos.x = x + w;
    v[2].pos.y = y + h;
    v[2].color = color;
    
    v[3].pos.x = x;
    v[3].pos.y = y + h;
    v[3].color = color;
    
    size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
    GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
    
    GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
    vIndeces[0] = 0 + vIndexOffset;
    vIndeces[1] = 1 + vIndexOffset;
    vIndeces[2] = 2 + vIndexOffset;
    vIndeces[3] = 0 + vIndexOffset;
    vIndeces[4] = 3 + vIndexOffset;
    vIndeces[5] = 2 + vIndexOffset;
    
    batchData.itemsPushed++;
}

void renderLine(RenderBatch* batch, float x1, float y1, float x2, float y2, float thickness, Vect4 color)
{
    assert(batch.type == RENDER_BATCH_RECT);
    BatchData* batchData = &batch.batchData;
    VertexPrimitive[] vertexBuffer;
    {
        VertexPrimitive* temp = cast(VertexPrimitive*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    assert(batchData.itemsPushed * VERTICES_PER_SQUARE < vertexBuffer.length); 
    
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    VertexPrimitive[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
    
    Vect2 diff = Vect2(x1 - x2, y1 - y2);
    Vect2 normal = normalizeSafe(Vect2(-diff.y, diff.x));
    
    v[0].pos.x = x1 + thickness*0.5f*-normal.x;
    v[0].pos.y = y1 + thickness*0.5f*-normal.y;
    v[0].color = color;
    
    v[1].pos.x = x2 + thickness*0.5f*-normal.x;
    v[1].pos.y = y2 + thickness*0.5f*-normal.y;
    v[1].color = color;
    
    v[2].pos.x = x2 + thickness*0.5f*normal.x;
    v[2].pos.y = y2 + thickness*0.5f*normal.y;
    v[2].color = color;
    
    v[3].pos.x = x1 + thickness*0.5f*normal.x;
    v[3].pos.y = y1 + thickness*0.5f*normal.y;
    v[3].color = color;

    size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
    GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
    
    GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
    vIndeces[0] = 0 + vIndexOffset;
    vIndeces[1] = 1 + vIndexOffset;
    vIndeces[2] = 2 + vIndexOffset;
    vIndeces[3] = 0 + vIndexOffset;
    vIndeces[4] = 3 + vIndexOffset;
    vIndeces[5] = 2 + vIndexOffset;
    
    batchData.itemsPushed++;
}

void renderSprite(RenderBatch* batch, float x, float y, float w, float h, uint frame, Vect4 color)
{
    alias gls = global_glState;
    
    assert(batch.type == RENDER_BATCH_SPRITE);
    BatchData* batchData = &batch.batchData;
    VertexTextured[] vertexBuffer;
    {
        VertexTextured* temp = cast(VertexTextured*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    assert(batchData.itemsPushed*VERTICES_PER_SQUARE < vertexBuffer.length); 
    
    assert(batch.texture);
    GameTexture* texture = batch.texture;
    
    float frameTop = void;
    float frameBottom = void;
    float frameLeft = void;
    float frameRight = void;
    
    if(frame < texture.framesCount)
    {   
        GameTextureFrame* frameInfo = &texture.frames[frame];
        frameTop = frameInfo.textureTop;
        frameBottom = frameInfo.textureBottom;
        frameLeft = frameInfo.textureLeft;
        frameRight = frameInfo.textureRight;
    /*
        int frameX = frame % texture.framesPerRow;
        int frameY = frame / texture.framesPerRow;
        
        // NOTE: We add/subtract 0.5f from each texture coordinate so that we can sample from the center of a texel.
        // This appears to prevent seems from appearing between tiles. See these for details:
        // https://gamedev.stackexchange.com/a/49585
        // https://docs.microsoft.com/en-us/windows/desktop/direct3d9/directly-mapping-texels-to-pixels
        float frameTop = (float)(texture.frameHeight * frameY + 0.5f) / (float)texture.fullHeight;
        float frameBottom = (float)(texture.frameHeight * frameY + texture.frameHeight - 0.5f) / (float)texture.fullHeight;
        float frameLeft = (float)(texture.frameWidth * frameX + 0.5f) / (float)texture.fullWidth;
        float frameRight = (float)(texture.frameWidth * frameX + texture.frameWidth - 0.5f) / (float)texture.fullWidth;*/
    }
    else
    {
        frameTop = 0.0f;
        frameBottom = 1.0f;
        frameLeft = 0.0f;
        frameRight = 1.0f;
    }
    
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    VertexTextured[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
    
    v[0].pos.x = x;
    v[0].pos.y = y;
    v[0].color = color;
    v[0].texCoord = Vect2(frameLeft, frameTop);
    
    v[1].pos.x = x + w;
    v[1].pos.y = y;
    v[1].color = color;
    v[1].texCoord = Vect2(frameRight, frameTop);
    
    v[2].pos.x = x + w;
    v[2].pos.y = y + h;
    v[2].color = color;
    v[2].texCoord = Vect2(frameRight, frameBottom);
    
    v[3].pos.x = x;
    v[3].pos.y = y + h;
    v[3].color = color;
    v[3].texCoord = Vect2(frameLeft, frameBottom);

    size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
    GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
    
    GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
    vIndeces[0] = 0 + vIndexOffset;
    vIndeces[1] = 1 + vIndexOffset;
    vIndeces[2] = 2 + vIndexOffset;
    vIndeces[3] = 0 + vIndexOffset;
    vIndeces[4] = 3 + vIndexOffset;
    vIndeces[5] = 2 + vIndexOffset;
    
    batchData.itemsPushed++;
}

void renderCircle(RenderBatch* batch, float centerX, float centerY, float radius, Vect4 color)
{
    assert(batch.type == RENDER_BATCH_CIRCLE);
    BatchData* batchData = &batch.batchData;
    VertexTextured[] vertexBuffer;
    {
        VertexTextured* temp = cast(VertexTextured*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    assert(batchData.itemsPushed * VERTICES_PER_SQUARE < vertexBuffer.length); 
    
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    VertexTextured[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
    
    float x = centerX - radius;
    float y = centerY - radius;
    float w = radius*2.0f;
    float h = radius*2.0f;
    
    v[0].pos.x = x;
    v[0].pos.y = y;
    v[0].color = color;
    v[0].texCoord = Vect2(-1.0f, -1.0f);
    
    v[1].pos.x = x + w;
    v[1].pos.y = y;
    v[1].color = color;
    v[1].texCoord = Vect2(1.0f, -1.0f);
    
    v[2].pos.x = x + w;
    v[2].pos.y = y + h;
    v[2].color = color;
    v[2].texCoord = Vect2(1.0f, 1.0f);
    
    v[3].pos.x = x;
    v[3].pos.y = y + h;
    v[3].color = color;
    v[3].texCoord = Vect2(-1.0f, 1.0f);

    size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
    GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
    
    GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
    vIndeces[0] = 0 + vIndexOffset;
    vIndeces[1] = 1 + vIndexOffset;
    vIndeces[2] = 2 + vIndexOffset;
    vIndeces[3] = 0 + vIndexOffset;
    vIndeces[4] = 3 + vIndexOffset;
    vIndeces[5] = 2 + vIndexOffset;
    
    batchData.itemsPushed++;
}

void renderCircleGradient(RenderBatch* batch, float x, float y, float w, float h, Vect4 color, Vect4 colorAlt)
{
    assert(batch.type == RENDER_BATCH_CIRCLE_GRADIENT);
    BatchData* batchData = &batch.batchData;
    VertexGradient[] vertexBuffer;
    {
        VertexGradient* temp = cast(VertexGradient*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    assert(batchData.itemsPushed * VERTICES_PER_SQUARE < vertexBuffer.length); 
    
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    VertexGradient[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
    
    v[0].pos.x = x;
    v[0].pos.y = y;
    v[0].color = color;
    v[0].colorAlt = colorAlt;
    v[0].texCoord = Vect2(-1.0f, -1.0f);
    
    v[1].pos.x = x + w;
    v[1].pos.y = y;
    v[1].color = color;
    v[1].colorAlt = colorAlt;
    v[1].texCoord = Vect2(1.0f, -1.0f);
    
    v[2].pos.x = x + w;
    v[2].pos.y = y + h;
    v[2].color = color;
    v[2].colorAlt = colorAlt;
    v[2].texCoord = Vect2(1.0f, 1.0f);
    
    v[3].pos.x = x;
    v[3].pos.y = y + h;
    v[3].color = color;
    v[3].colorAlt = colorAlt;
    v[3].texCoord = Vect2(-1.0f, 1.0f);

    size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
    GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
    
    GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
    vIndeces[0] = 0 + vIndexOffset;
    vIndeces[1] = 1 + vIndexOffset;
    vIndeces[2] = 2 + vIndexOffset;
    vIndeces[3] = 0 + vIndexOffset;
    vIndeces[4] = 3 + vIndexOffset;
    vIndeces[5] = 2 + vIndexOffset;
    
    batchData.itemsPushed++;
}

void renderGetTextSize(GameFont* font, char[] text, uint* w, uint* h)
{
    *w = 0;
    *h = 0;
    uint currentWidth = 0;
    
    foreach(charIndex; 0 .. text.length)
    {
        if (text[charIndex] == ' ')
        {
            currentWidth += font.spaceWidth;
        }
        else if (text[charIndex] == '\n')
        {
            *w = max(*w, currentWidth);
            *h += font.lineGap;
        }
        else if (cast(uint)text[charIndex] >= font.codepointsMin && cast(uint)text[charIndex] <= font.codepointsMax)
        {
            uint glyphIndex = text[charIndex] - font.codepointsMin;
            GameFontGlyph* glyph = &font.glyphs[glyphIndex];
            if (glyph.codepoint == cast(uint)text[charIndex])
            {   
                currentWidth += glyph.advance;
            }
        }
    }
    
    *w = max(*w, currentWidth);
}

void renderText(RenderBatch* batch, float x, float y, char[] text, Vect4 color)
{
    alias gls = global_glState;
    
    assert(batch.type == RENDER_BATCH_TEXT);
    BatchData* batchData = &batch.batchData;
    VertexTextured[] vertexBuffer;
    {
        VertexTextured* temp = cast(VertexTextured*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }
    assert(batchData.itemsPushed * VERTICES_PER_SQUARE < vertexBuffer.length); 

    //assert(batch.font < assets.fontsCount);
    //GameFont* font = &assets.fonts[batch.font];
    GameFont* font = batch.font;
    
    //GameTexture* texture = &font.texture;
    //OpenGLTextureInfo* textureInfo = (OpenGLTextureInfo*)batch.texture.internal;
    
    float startX = x;
    foreach(charIndex; 0 .. text.length)
    {
        if (text[charIndex] == ' ')
        {
            x += font.spaceWidth;
        }
        else if (text[charIndex] == '\n')
        {
            x = startX;
            y += font.lineGap;
        }
        else if (cast(uint)text[charIndex] >= font.codepointsMin && cast(uint)text[charIndex] <= font.codepointsMax)
        {
            uint glyphIndex = text[charIndex] - font.codepointsMin;
            GameFontGlyph* glyph = &font.glyphs[glyphIndex];
            if (glyph.codepoint == cast(uint)text[charIndex])
            {
                size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
                VertexTextured[] v = vertexBuffer[firstVertex .. firstVertex + VERTICES_PER_SQUARE];
                
                float w = glyph.w;
                float h = glyph.h;
                float fontHeight = font.baseline;
                
                v[0].pos.x = x + glyph.origin.x;
                v[0].pos.y = y + glyph.origin.y - fontHeight;
                v[0].color = color;
                v[0].texCoord = Vect2(glyph.textureLeft, glyph.textureTop);
                
                v[1].pos.x = x + w + glyph.origin.x;
                v[1].pos.y = y + glyph.origin.y - fontHeight;
                v[1].color = color;
                v[1].texCoord = Vect2(glyph.textureRight, glyph.textureTop);
                
                v[2].pos.x = x + w + glyph.origin.x;
                v[2].pos.y = y + h + glyph.origin.y - fontHeight;
                v[2].color = color;
                v[2].texCoord = Vect2(glyph.textureRight, glyph.textureBottom);
                
                v[3].pos.x = x + glyph.origin.x;
                v[3].pos.y = y + h + glyph.origin.y - fontHeight;
                v[3].color = color;
                v[3].texCoord = Vect2(glyph.textureLeft, glyph.textureBottom);

                size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
                GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
                
                GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
                vIndeces[0] = 0 + vIndexOffset;
                vIndeces[1] = 1 + vIndexOffset;
                vIndeces[2] = 2 + vIndexOffset;
                vIndeces[3] = 0 + vIndexOffset;
                vIndeces[4] = 3 + vIndexOffset;
                vIndeces[5] = 2 + vIndexOffset;
                
                batchData.itemsPushed++;
                
                x += glyph.advance;
            }
        }
    }
}

void pushVertices(T)(RenderBatch* batch, T[] verts)
{
    static if(is(T == VertexPrimitive))
    {
        assert(batch.type == RENDER_BATCH_RECT);
    }
    else static if(is(T == VertexTextured))
    {
        assert(batch.type == RENDER_BATCH_CIRCLE
            || batch.type == RENDER_BATCH_SPRITE
            || batch.type == RENDER_BATCH_TEXT
        );
    }
    else static if(is(T == VertexGradient))
    {
        assert(batch.type == RENDER_BATCH_CIRCLE_GRADIENT);
    }
    else
    {
        pragma(msg, "ERR: Unhandled type passed to pushVertices: " ~ T.stringof);
        static assert(0);
    }
    
    BatchData* batchData = &batch.batchData;
    
    T[] vertexBuffer;
    {
        T* temp = cast(T*)batchData.vertexBuffer;
        vertexBuffer = temp[0 .. batchData.vertexBufferLength];
    }

    // TODO: Ensure that this is, in fact, a quad.
    // Perhaps we should instead have an integer for each batch that tells how many vertices
    // are expected for each element and then assert off that.
    assert(verts.length % VERTICES_PER_SQUARE == 0);
    size_t firstVertex = batchData.itemsPushed*VERTICES_PER_SQUARE;
    vertexBuffer[firstVertex .. firstVertex + verts.length] = verts[0 .. verts.length];
    
    auto itemsToPush = verts.length / VERTICES_PER_SQUARE;
    
    foreach(i; 0 .. itemsToPush)
    {
        size_t firstIndex = batchData.itemsPushed * VERTEX_INDECES_PER_SQUARE;
        GLuint[] vIndeces = batchData.vertexIndexBuffer[firstIndex .. firstIndex + VERTEX_INDECES_PER_SQUARE];
        
        GLuint vIndexOffset = cast(GLuint)(batchData.itemsPushed * VERTICES_PER_SQUARE);
        vIndeces[0] = 0 + vIndexOffset;
        vIndeces[1] = 1 + vIndexOffset;
        vIndeces[2] = 2 + vIndexOffset;
        vIndeces[3] = 0 + vIndexOffset;
        vIndeces[4] = 3 + vIndexOffset;
        vIndeces[5] = 2 + vIndexOffset;
        
        batchData.itemsPushed++;   
    }
}

void renderGame(int resX, int resY, int windowWidth, int windowHeight)
{
    alias gls = global_glState;

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearDepth(12.0f);
    
    // NOTE(tspike): Resolution independence code thanks to code snippet posted by kenmo here:
    // https://www.purebasic.fr/english/viewtopic.php?t=50500
    float targetRatio = cast(float)resX / cast(float)resY;
    
    // TODO(tspike) Investigate why there's a vertical strip of non-rendered pixels on the right side of the screen when
    // in fullcreen mode in X11 (on my laptop). Floating point precision issues?
    version(none)
    {
        float viewX, viewY, viewW;
        float viewH = cast(float)windowWidth / targetRatio;
        if (viewH > cast(float)windowHeight)
        {
            viewW = cast(float)windowHeight * targetRatio;
            viewH = cast(float)windowHeight;
            viewX = (cast(float)windowWidth - viewW) * 0.5f;
            viewY = 0.0f;
        }
        else
        {
            viewW = cast(float)windowWidth;
            viewX = 0.0f;
            viewY = (cast(float)windowHeight - viewH) * 0.5f;
        }
        
        glViewport(cast(int)viewX, cast(int)viewY, cast(int)viewW, cast(int)viewH);

    }
    else
    {
        glViewport(0, 0, resX, resY);    
    }
    
    //AssetCache* assets = gls.assetCache;
    RenderBatch* currentBatch = gls.firstRenderBatch;
    while (currentBatch)
    {
        BatchData* batchData = &currentBatch.batchData;
        OpenGLShader* shader = batchData.shader;
        glUseProgram(shader.handle);
        glBindVertexArray(shader.vao);
        glBindBuffer(GL_ARRAY_BUFFER, shader.vbo);

        // TODO: Cache these uniform locations when we first compile the shader?
        Mat4 projection = calcProjection(currentBatch.camera.x, currentBatch.camera.y, resX, resY);
        GLint projectionUniform = glGetUniformLocation(shader.handle, "uProjection");
        assert(projectionUniform != -1);
        glUniformMatrix4fv(projectionUniform, 1, GL_FALSE, &projection.c[0]);
        
        GLint scaleUniform = glGetUniformLocation(shader.handle, "uScale");
        assert(scaleUniform != -1);
        glUniform1f(scaleUniform, currentBatch.scale);
        
        switch(currentBatch.type)
        {
            case RENDER_BATCH_SPRITE:
            {
                auto textureID = currentBatch.texture.textureID;
                glBindTexture(GL_TEXTURE_2D, textureID.textureHandle);
            } break;
            
            case RENDER_BATCH_TEXT:
            {
                GameFont* font = currentBatch.font;
                auto textureID = font.texture.textureID;
                glBindTexture(GL_TEXTURE_2D, textureID.textureHandle);
            } break;
            
            default: break;
        }
                
        glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(batchData.itemsPushed*VERTICES_PER_SQUARE*batchData.vertexSize), batchData.vertexBuffer, GL_DYNAMIC_DRAW);
        glDrawElements(GL_TRIANGLES, cast(GLsizei)(batchData.itemsPushed*VERTEX_INDECES_PER_SQUARE), GL_UNSIGNED_INT, batchData.vertexIndexBuffer.ptr);
        
        currentBatch = currentBatch.nextBatch;
    }
    
    // NOTE: Render cleanup. This must be called before the next iteration of the game loop.
    gls.firstRenderBatch = null;
    gls.lastRenderBatch = null;
}

TextureID generateTextureIDFromPixels(ubyte* pixels, int width, int height)
{
    alias gls = global_glState;
    GLint internalFormat = GL_RGBA8;
    GLenum sourceFormat = GL_RGBA;
    
    // NOTE: Default textureID (0) is the fallback texture
    TextureID textureID = TextureID.init;
    glGenTextures(1, &textureID.textureHandle);
    if (textureID.textureHandle)
    {
        glBindTexture(GL_TEXTURE_2D, textureID.textureHandle);
        glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, width, height, 0, sourceFormat, GL_UNSIGNED_BYTE, pixels);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        
        version(testing)
        {
            glBindTexture(GL_TEXTURE_2D, 0);            
        }
    }
    else
    {
        logErr!("OpenGL failed to generate texture!\n");
    }

    return textureID;
}

void freeTextureIDIfGenerated(TextureID* textureID)
{
    if(textureID.textureHandle)
    {
        glDeleteTextures(1, &textureID.textureHandle);
        textureID.textureHandle = 0;    
    }
}

private:

__gshared OpenGLState global_glState;

immutable ubyte[] global_fallbackTexturePixels =
[
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
    0, 255, 255, 255,
];

version(linux)
{
    import platform.linux_x11_platform;
}

import glad;
import math;
import memory;
import assets;
import meta : isStructPacked;
import logging;

struct OpenGLShader
{
    GLuint handle;
    GLuint vao;
    GLuint vbo;
};

struct OpenGLState
{    
    union
    {
        OpenGLShader[4] shaders;
        struct
        {
            OpenGLShader shaderRect;
            OpenGLShader shaderCircle;
            OpenGLShader shaderSprite;
            OpenGLShader shaderCircleGradient;
        };
    };
    
    RenderBatch* firstRenderBatch;
    RenderBatch* lastRenderBatch;
    
    GameTexture fallbackTexture;
};

enum VertexType : uint
{
    PRIMITIVE,
    TEXTURED,
    GRADIENT,
};

struct BatchData
{
    OpenGLShader* shader;
    ulong itemsPushed;
    void* vertexBuffer;
    ulong vertexBufferLength;
    GLuint[] vertexIndexBuffer;
    size_t vertexSize;
};

enum 
{
    ATTRIB_POS,
    ATTRIB_COLOR,
    ATTRIB_COLOR_ALT,
    ATTRIB_TEX_COORD,
    
    ATTRIB_TOTAL,
};

enum ulong VERTICES_PER_TRIANGLE = 3;
enum ulong VERTICES_PER_SQUARE = 4;
enum ulong VERTEX_INDECES_PER_SQUARE = 6;

// NOTE(tspike): Shader #version 150 equates to OpenGL 3.2, our target version. See here:
// https://www.khronos.org/opengl/wiki/Core_Language_(GLSL)
immutable string global_rectVertexSource = `
    #version 150
    
    in vec2 vPos;
    in vec4 vColor;
    out vec4 fColor;
    
    uniform mat4 uProjection;
    uniform float uScale;
    
    void main()
    {
        fColor = vColor;
        gl_Position = uProjection * vec4(vPos*uScale, 0.0, 1.0);
        //gl_Position = uProjection * vec4(vPos, depth, 1.0);
    }
`;

immutable string global_rectFragmentSource = `
    #version 150
    
    in vec4 fColor;
    
    out vec4 color;
    
    void main()
    {
        //color = fColor;
        color = vec4(fColor.rgb*fColor.a, fColor.a);
    }
`;

// NOTE: Circle rendering techniques thanks to this source:
// https://www.reddit.com/r/opengl/comments/akghb2/creating_circle_from_square_with_fragment_shader/
immutable string global_circleVertexSource = `
    #version 150
    
    in vec2 vPos;
    in vec4 vColor;
    in vec2 vertexTexCoord;
    
    out vec4 fColor;
    out vec2 fragTexCoord;
    
    uniform mat4 uProjection;
    uniform float uScale;
    
    void main()
    {        
        fColor = vColor;
        gl_Position = uProjection * vec4(vPos*uScale, 0.0, 1.0);
        fragTexCoord = vertexTexCoord;
    }
`;

immutable string global_circleFragmentSource = `
    #version 150
    
    in vec4 fColor;
    in vec2 fragTexCoord;
    
    out vec4 color;
    
    void main()
    {
        if(dot(fragTexCoord, fragTexCoord) > 1.0)
        {
            //color = vec4(0.0f, 0.2, 0.0, 1.0);
            discard;
        }
        else
        {        
            color = fColor;
        }
    
    }
`;

immutable string global_spriteVertexSource = `
    #version 150
    
    in vec2 vPos;
    in vec4 vColor;
    in vec2 vertexTexCoord;
 
    out vec4 fColor;
    out vec2 fragTexCoord;
    
    uniform mat4 uProjection;
    uniform float depth;
    uniform float uScale;
     
    void main()
    {
        fColor = vColor;
        fragTexCoord = vec2(vertexTexCoord.x, vertexTexCoord.y);
        gl_Position = uProjection * vec4(vPos*uScale, 0.0, 1.0);
        //gl_Position = uProjection * vec4(vPos, depth, 1.0);
        
    }
`;

//(SourceColor.rgb * One) + (DestinationColor.rgb * (1 - SourceColor.a));
immutable string global_spriteFragmentSource = `
    #version 150
    
    in vec4 fColor;
    in vec2 fragTexCoord;
    
    out vec4 color;
    
    uniform sampler2D sprite;
    
    void main()
    {
        vec4 textureColor = texture(sprite, fragTexCoord);
        //color = textureColor*fColor;
        color = textureColor*vec4(fColor.rgb*fColor.a, fColor.a);
        //color = vec4(textureColor.rgb*(fColor.rgb*fColor.a), fColor.a);
    }
`;

immutable string global_circleGradientVertexSource = `
    #version 150
    
    in vec2 vPos;
    in vec4 vColor;
    in vec4 vColorAlt;
    in vec2 vTexCoord;
    
    out vec4 fColor;
    out vec4 fColorAlt;
    out vec2 fTexCoord;
    
    uniform mat4 uProjection;
    uniform float uScale;
    
    void main()
    {        
        fColor = vColor;
        fColorAlt = vColorAlt;
        gl_Position = uProjection * vec4(vPos*uScale, 0.0, 1.0);
        fTexCoord = vTexCoord;
    }
`;

immutable string global_circleGradientFragmentSource = `
    #version 150
    
    in vec4 fColor;
    in vec4 fColorAlt;
    in vec2 fTexCoord;
    
    out vec4 color;
    
    void main()
    {
        //color = mix(fColor, fColorAlt, min(0.98, dot(fTexCoord, fTexCoord)));    
        //color = mix(fColor, fColorAlt, dot(fTexCoord, fTexCoord));    
        
        if(dot(fTexCoord, fTexCoord) > 1.0)
        {
            //color = vec4(1.0f, 0.0, 0.0, 1.0);
            discard;
        }
        else
        {        
            color = mix(fColor, fColorAlt, dot(fTexCoord, fTexCoord));  
        }
        
    }
`;

version (testing)
{
    extern (C) void openGLDebugMessageCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const(GLchar)* message, void* userParam)
    {
        string typeStr;
        string severityStr;
        
        switch(type)
        {
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_ERROR, "Error"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR, "Deprecated behavior"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR, "Undefined behavior"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_PORTABILITY, "Portability"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_PERFORMANCE, "Performance"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_MARKER, "Marker"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_PUSH_GROUP, "Push group"));
            mixin(debugMessageCase("typeStr", GL_DEBUG_TYPE_OTHER, "Other"));
            default: {typeStr = "Unknown";} break;
        }
         
        switch (severity)
        {
            mixin(debugMessageCase("severityStr", GL_DEBUG_SEVERITY_HIGH, "High"));
            mixin(debugMessageCase("severityStr", GL_DEBUG_SEVERITY_MEDIUM, "Medium"));
            mixin(debugMessageCase("severityStr", GL_DEBUG_SEVERITY_LOW, "Low"));
            mixin(debugMessageCase("severityStr", GL_DEBUG_SEVERITY_NOTIFICATION, "Notification"));
            default: {severityStr = "Unknown";} break;
        }
        
        if (severity != GL_DEBUG_SEVERITY_NOTIFICATION && type != GL_DEBUG_TYPE_OTHER)
        {
            logDebug!("GL {0}/{1}: {2}\n")(severityStr.ptr, typeStr.ptr, message);
        }
    }
}

GLuint compileShaderFromString(GLenum shaderType, string shaderTypeDesc, string source)
{
    const(char*) sourcecstr = source.ptr;
    GLuint shader = glCreateShader(shaderType);
    glShaderSource(shader, 1, &sourcecstr, null);
    glCompileShader(shader);
    
    GLint compileStatus;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
    if (compileStatus == GL_FALSE)
    {        
        char[512] buffer;
        glGetShaderInfoLog(shader, buffer.length, null, buffer.ptr);
        logErr!("Unable to compile {0}:\n{1}\n{2}")(shaderTypeDesc.ptr, buffer.ptr, source.ptr);
        glDeleteShader(shader);
        shader = 0;
    }
    
    return shader;
}

GLuint
compileProgram(string vertexSource, string fragmentSource)
{
    GLuint program = glCreateProgram();
    if(!program)
    {
        // TODO(tspike): Get error string!
        logErr!("Unable to create shader program.");
        return 0;
    }
        
    glBindAttribLocation(program, ATTRIB_POS, "vPos");
    glBindAttribLocation(program, ATTRIB_COLOR, "vColor");
    glBindAttribLocation(program, ATTRIB_TEX_COORD, "vertexTexCoord");
    
    GLuint vertexShader = compileShaderFromString(GL_VERTEX_SHADER, "Vertex Shader", vertexSource);
    GLuint fragmentShader = compileShaderFromString(GL_FRAGMENT_SHADER, "Fragment Shader", fragmentSource);
        
    if (!fragmentShader || !vertexShader)
    {
        logErr!("Unable to compile shader source.");
        glDeleteProgram(program);
        return 0;
    }
    
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
                        
    glLinkProgram(program);
    
    GLuint linkStatus;
    glGetProgramiv(program, GL_LINK_STATUS, cast(GLint*)&linkStatus);
    if (linkStatus == GL_FALSE)
    {
        char[512] buffer;
        glGetProgramInfoLog(program, buffer.length, null, buffer.ptr);
        logErr!("Unable to link shader:\n{0}")(buffer.ptr);
    }
    
    glDetachShader(program, fragmentShader);
    glDetachShader(program, vertexShader);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    return program;
}

bool initShader(OpenGLShader* shader, VertexType vertexType, string vertexSource, string fragmentSource)
{
    shader.handle = compileProgram(vertexSource, fragmentSource);   
    if (!shader.handle) return false;
    
    glGenVertexArrays(1, &shader.vao);
    assert(shader.vao);
    glBindVertexArray(shader.vao);
    
    glGenBuffers(1, &shader.vbo);
    assert(shader.vbo);
    glBindBuffer(GL_ARRAY_BUFFER, shader.vbo);
    
    switch(vertexType)
    {
        case VertexType.PRIMITIVE:
        {
            int componentsPerVertex = 6;
            glEnableVertexAttribArray(ATTRIB_POS);
            glVertexAttribPointer(ATTRIB_POS, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexPrimitive.pos.offsetof);
            
            glEnableVertexAttribArray(ATTRIB_COLOR);
            glVertexAttribPointer(ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexPrimitive.color.offsetof);
        } break;
        
        case VertexType.TEXTURED:
        {
            int componentsPerVertex = 8;
            glEnableVertexAttribArray(ATTRIB_POS);
            glVertexAttribPointer(ATTRIB_POS, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexTextured.pos.offsetof);
            
            glEnableVertexAttribArray(ATTRIB_COLOR);
            glVertexAttribPointer(ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexTextured.color.offsetof);  
            
            glEnableVertexAttribArray(ATTRIB_TEX_COORD);
            glVertexAttribPointer(ATTRIB_TEX_COORD, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexTextured.texCoord.offsetof);
        } break;
        
        case VertexType.GRADIENT:
        {
            int componentsPerVertex = 12;
            glEnableVertexAttribArray(ATTRIB_POS);
            glVertexAttribPointer(ATTRIB_POS, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexGradient.pos.offsetof);
            
            glEnableVertexAttribArray(ATTRIB_COLOR);
            glVertexAttribPointer(ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexGradient.color.offsetof);
            
            glEnableVertexAttribArray(ATTRIB_COLOR_ALT);
            glVertexAttribPointer(ATTRIB_COLOR_ALT, 4, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexGradient.colorAlt.offsetof);
            
            glEnableVertexAttribArray(ATTRIB_TEX_COORD);
            glVertexAttribPointer(ATTRIB_TEX_COORD, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(componentsPerVertex*GLfloat.sizeof), cast(GLvoid*)VertexGradient.texCoord.offsetof);
        } break;
        
        default:
        {
            assert(0);
        } break;
    }
    
    return true;
}

Mat4 calcProjection(float cameraX, float cameraY, int resX, int resY)
{
    /*
        NOTE(tspike): This is the order of transformations we used in Carrier Pigeon:    
        al_translate_transform(&_transform, -_pos.x, -_pos.y);
        al_scale_transform(&_transform, (_zoom * depth), (_zoom *depth));
        al_rotate_transform(&_transform, _rotation * 3.1415 / 180);
        al_translate_transform(&_transform, _halfWidth, _halfHeight);
    */
    
    Mat4 identity = void;
    identity.c = [
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    ];
    
    Mat4 projection = identity;
    {
        // NOTE: Calculating orthographic projection.
        float left = 0.0f;
        float right = cast(float)resX;
        float bottom = cast(float)resY;
        float top = 0.0f;
        
        projection.c[0] = 2.0f / (right - left);
        projection.c[5] =  2.0f / (top - bottom);
        projection.c[10] = -1.0f;
        projection.c[12] = -( (right + left) / (right - left));
        projection.c[13] = -( (top + bottom) / (top - bottom));
    }

    {
        // NOTE: Translating projection matrix by the camera vector.
        float x = -cameraX;
        float y = -cameraY;
        float z = 0.0f;
        projection.c[12] = projection.c[0]*x + projection.c[4]*y + projection.c[8]*z + projection.c[12];
        projection.c[13] = projection.c[1]*x + projection.c[5]*y + projection.c[9]*z + projection.c[13];
        projection.c[14] = projection.c[2]*x + projection.c[6]*y + projection.c[10]*z + projection.c[14];
        projection.c[15] = projection.c[3]*x + projection.c[7]*y + projection.c[11]*z + projection.c[15];
    }
    
    return projection;
}