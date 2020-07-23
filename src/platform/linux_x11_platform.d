// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module platform.linux_x11_platform;

version(linux):

@nogc nothrow:

public:

enum
{
    PLATFORM_FILE_MODE_READ  = 0x1,
    PLATFORM_FILE_MODE_WRITE = 0x2,
};

struct FileHandle
{
    bool error;
    
    private:
    int file;
}

void* allocMemory(size_t size, uint flags)
{
    import core.stdc.stdlib : calloc;
    // TODO: Exit application if alloc fails?
    return calloc(1, size);
}

void freeMemory(void* mem, size_t size)
{
    free(mem);
}

FileHandle* openFile(const char* fileName, uint mode)
{
    FileHandle* result = null;

    // TODO: Prepend the base path of the executable to the fileName?
    int oflags = 0;
    int permissions = S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH;
    if ((mode & PLATFORM_FILE_MODE_READ) && (mode & PLATFORM_FILE_MODE_WRITE))
    {
        oflags = O_RDWR|O_CREAT;
    }
    else if (mode & PLATFORM_FILE_MODE_READ)
    {
        oflags = O_RDONLY;
    }
    else if (mode & PLATFORM_FILE_MODE_WRITE)
    {
        oflags = O_WRONLY|O_CREAT;
    }
    
    int fd = open(fileName, oflags, permissions);
    if (fd != -1)
    {
        // TODO: Rather than allocate these this way, should we instead keep an expandable list
        // of them in the X11 state? This way we could close them all in one sweep when the game
        // closes. 
        result = cast(FileHandle*)allocMemory(FileHandle.sizeof, 0);
        result.file = fd;
    }

    return result;
}

void closeFile(FileHandle* fhandle)
{
    alias f = fhandle;
    
    close(f.file);
    free(f);
    f = null;
}

ulong writeFile(FileHandle* fhandle, ulong offset, const void* data, ulong length)
{
    alias f = fhandle;
    assert(!f.error);
    
    // TODO: Handle errors and cases where we return number doesn't match our length (which is appearently normal)
    // See here for som advice:
    // https://hero.handmade.network/forums/code-discussion/t/861-compiling_without_libc_on_linux
    pwrite(f.file, data, length, offset);
    
    // NOTE: We should return the length, even if the file was unable to write the entire length.
    // This is to make it easy to calculate the next read/write offset. RW error are reported through the file handle.
    return length; 
}

ulong readFile(FileHandle* fhandle, ulong offset, void* data, ulong length)
{
    alias f = fhandle;
    assert(!f.error);
    // TODO: Handle errors and cases where we return number doesn't match our length (which is appearently normal)
    // See here for som advice:
    // https://hero.handmade.network/forums/code-discussion/t/861-compiling_without_libc_on_linux
    pread(f.file, data, length, offset);
    
    // NOTE: We should return the length, even if the file was unable to write the entire length.
    // This is to make it easy to calculate the next read/write offset. RW error are reported through the file handle.
    return length;
}

char[] readEntireFile(FileHandle* file, MemoryArena* arena)
{
    // TODO: Error checking!
    stat_t s = void;
    fstat(file.file, &s);
    size_t size = s.st_size;
    
    auto result = allocArray!char(arena, size);
    readFile(file, 0, result.ptr, size);
    return result;
}

void getWindowSize(uint* w, uint* h)
{
    *w = global_xs.windowWidth;
    *h = global_xs.windowHeight;
}

char[] getAppFilePath()
{
    return global_xs.appFilePath[0 .. global_xs.appFilePathLength];
}

void setWindowAsTopmost(bool raise)
{
    // NOTE: Adapted from this source: https://stackoverflow.com/a/16235920
    enum _NET_WM_STATE_REMOVE = 0;
    enum _NET_WM_STATE_ADD    = 1;
    enum _NET_WM_STATE_TOGGLE = 2;
    
    Atom atomNetWMState = XInternAtom(global_xs.display, "_NET_WM_STATE", False);
    Atom atomNetWMStateAbove = XInternAtom(global_xs.display, "_NET_WM_STATE_ABOVE", False);
    
    if(atomNetWMState != None && atomNetWMStateAbove != None)
    {
        XClientMessageEvent clientMsg = void;
        clearToZero(&clientMsg);
        
        clientMsg.type = ClientMessage;
        clientMsg.window = global_xs.window;
        clientMsg.message_type = atomNetWMState;
        clientMsg.format = 32;
        clientMsg.data.l[0] = raise ? _NET_WM_STATE_ADD : _NET_WM_STATE_REMOVE;
        clientMsg.data.l[1] = atomNetWMStateAbove;
        
        XSendEvent(global_xs.display, XDefaultRootWindow(global_xs.display), False,
            SubstructureRedirectMask | SubstructureNotifyMask, cast(XEvent*)&clientMsg);
    }
}

private:

import core.stdc.stdlib : free;
import core.sys.linux.time; // timspec, clock_gettime
import core.sys.posix.dlfcn;
import core.sys.linux.unistd;
import core.sys.linux.fcntl;
import core.stdc.config : c_ulong, c_long;
import core.sys.posix.sys.stat;

version(utils){}
else:

import memory;
import tbreaker;
import linux_x11;
import linux_glx;
import linux_x11_icon;
import glad;
import render_opengl;
import logging;
import strings;

__gshared X11State* global_xs;

struct X11State
{
    Display* display;
    Window window;
    XVisualInfo* visualInfo;
    int windowWidth;
    int windowHeight;
    
    GLXContext glContext;
    GLXFBConfig fbConfig;
    
    bool running;
    bool visible;
    
    Atom atom_WMState;
    Atom atom_WMStateFullscreen;
    Atom atom_WMDeleteWindow;
    Atom atom_WMIcon;
    
    char[4096] appFilePath;
    ulong appFilePathLength;
}

void setWindowBorder(X11State* xs, bool useBorder)
{
    // Adapted from this source:
    // https://stackoverflow.com/a/1909708
    enum
    {
        MWM_HINTS_FUNCTIONS = (1L << 0),
        MWM_HINTS_DECORATIONS =  (1L << 1),

        MWM_FUNC_ALL = (1L << 0),
        MWM_FUNC_RESIZE = (1L << 1),
        MWM_FUNC_MOVE = (1L << 2),
        MWM_FUNC_MINIMIZE = (1L << 3),
        MWM_FUNC_MAXIMIZE = (1L << 4),
        MWM_FUNC_CLOSE = (1L << 5)
    }

    struct MWMHints
    {
        c_ulong flags;
        c_ulong functions;
        c_ulong decorations;
        c_long  input_mode;
        c_ulong status;
    }
    
    Atom atomWMHints = XInternAtom(xs.display, "_MOTIF_WM_HINTS", False);
    if (atomWMHints != None)
    {
        MWMHints hints;
        hints.flags = MWM_HINTS_DECORATIONS;
        hints.decorations = useBorder;
        
        XChangeProperty(xs.display, xs.window, atomWMHints, atomWMHints, 32, PropModeReplace, cast(ubyte*)&hints, 5);
    }
    else
    {
        logWarn!("Unable to set window border.\n");
    }
}

void getDesktopWorkArea(X11State* xs, c_ulong* x, c_ulong* y, c_ulong* w, c_ulong* h)
{
    // TODO: This will likely not work when dealing with multi-monitor setups. Fix this.
    // https://stackoverflow.com/a/18678545
    Atom atomNetWorkarea = XInternAtom(xs.display, "_NET_WORKAREA", False);
    
    Atom realType;
    int realFormat;
    c_ulong propsLength;
    c_ulong* rawProps;
    c_ulong bytesAfterReturn;
    int result = XGetWindowProperty(xs.display, XDefaultRootWindow(xs.display), atomNetWorkarea, 0L, 4L, False,
                    XA_CARDINAL, &realType, &realFormat, &propsLength, &bytesAfterReturn, cast(ubyte**)&rawProps);
    scope(exit) XFree(rawProps);
                      
    c_ulong[] props = rawProps[0 .. propsLength];       
    if (result == Success)
    {
        *x = props[0];
        *y = props[1];
        *w = props[2];
        *h = props[3];
    }
    else
    {
        logWarn!("Unable to query desktop work area.\n");
    }
}

struct GLXExtensions
{
    glXCreateContextAttribsARBFunc CreateContextAttribsARB;
    glXSwapIntervalEXTFunc SwapIntervalEXT;
    glXSwapIntervalMESAFunc SwapIntervalMESA;
    glXSwapIntervalSGIFunc SwapIntervalSGI;
}

extern (C) int stubX11ErrorHandler(Display* display, XErrorEvent* ev)
{
    char[256] errorBuffer;
    //XGetErrorText(display, ev.error_code, errorBuffer, errorBuffer.length);
    
    //logErr("{0}", errorBuffer);
    return 0;
}

extern (C) int stubXExtErrorHandler(Display* display, const char* extensionName, const char* failureReason)
{
    logWarn!("{0}: {1}\n")(extensionName, failureReason);
    return 0;
}

void loadGLXExtensions(GLXExtensions* glxe, const(char)* extensionString)
{
    string loadGLXExtension(string funcName)
    {
        // NOTE(tspike): It seems as though we can rely on the GC at compile time for creating string mixins, and not pay any runtime cost. Sweet!
        assert(__ctfe);
        return `glxe.` ~ funcName ~ ` = cast(glX` ~ funcName ~ `Func) glXGetProcAddressARB(cast(ubyte*)"glX` ~ funcName ~ `".ptr);`;
    }

    // TODO: Return if CreateContextAttribsARB failed to load.
    import core.stdc.stdio;
    //logDebug!("GLX Extensions: {0}\n")(extensionString);
    char[] reader = cast(char[])extensionString[0..length(extensionString)];
        
    string token = advancePast(reader, ' ');
    while (reader.length > 0)
    {
        if (stringsMatch(token, "GLX_EXT_swap_control"))
        {
            mixin(loadGLXExtension("SwapIntervalEXT"));
        }
        else if (stringsMatch(token, "GLX_MESA_swap_control"))
        {
            mixin(loadGLXExtension("SwapIntervalMESA"));
        }
        else if (stringsMatch(token, "GLX_SGI_swap_control"))
        {
            mixin(loadGLXExtension("SwapIntervalSGI"));
        }
        else if (stringsMatch(token, "GLX_ARB_create_context") || stringsMatch(token, "GLX_ARB_create_context_profile"))
        {
            if (!glxe.CreateContextAttribsARB)
            {
                mixin(loadGLXExtension("CreateContextAttribsARB"));
            }
        }
        
        token = advancePast(reader, ' ');
    }
}

timespec getCurrentTime()
{
    timespec result;
    clock_gettime(CLOCK_MONOTONIC, &result);
    return result;
}

double getSecondsElapsed(timespec start, timespec end)
{
    return cast(double)(end.tv_sec - start.tv_sec) + cast(double)(end.tv_nsec - start.tv_nsec) / 1000000000.0;
}

static ulong
getMillisecondsElapsed(timespec start, timespec end)
{
    // TODO: Figure out how to handle this given the diffirent 
    ulong result = (end.tv_sec - start.tv_sec) * 1000 + (end.tv_nsec - start.tv_nsec) / 1000000;
    return result;
}

void handleEvents(XEvent *evt, X11State* xs)
{
    enum logEvents = false;

    switch (evt.type)
    {             
        case ClientMessage:
        {
            static if(logEvents) logDebug!"ClientMessage event\n";
            if (cast(uint)evt.xclient.data.l[0] == xs.atom_WMDeleteWindow)
            {
                xs.running = false;
            }
        } break;
        
        case FocusIn:
        {
            static if(logEvents) logDebug!"FocusIn event\n";

            xs.visible = true;     
        } break;
        
        case FocusOut:
        {
            static if(logEvents) logDebug!"FocusOut event\n";
            xs.visible = false;
        } break;
        
        case Expose:
        {
            static if(logEvents) logDebug!"Expose event\n";
        } break;
        
        case UnmapNotify:
        {
            static if(logEvents) logDebug!"UnmapNotify event\n";
            xs.visible = false;
        } break;
        
        case MapNotify:
        {
            static if(logEvents) logDebug!"MapNotify event\n";
            xs.visible = true;
        } break;
        
        default:
        {
            static if(logEvents) logDebug!"Unknown event: {0}\n"(evt.type);
        } break;
    }
}

void main()
{
    X11State xs;
    xs.windowWidth  = 640;
    xs.windowHeight = 240;
    
    global_xs = &xs;
    
    xs.appFilePathLength = readlink("/proc/self/exe", xs.appFilePath.ptr, xs.appFilePath.length);
    xs.appFilePath[xs.appFilePathLength] = '\0';
    foreach_reverse(i; 0 .. xs.appFilePath.length)
    {
        // NOTE: Chop off the executable name and final slash. We only want the directory name.
        if(xs.appFilePath[i] == '/')
        {
            xs.appFilePath[i] = '\0';
            xs.appFilePathLength = i;
            break;
        }
    }
    
    logDebug!"base file path: `{0}`\n"(xs.appFilePath[0 .. xs.appFilePathLength]);
    
    xs.display = XOpenDisplay(null);
    if (!xs.display)
    {
        logFatal!("Unable to open X11 display. Aborting.\n");
        return;
    }
    scope(exit){XCloseDisplay(xs.display);}
    
    // NOTE(tspike): This is based on the code found at the openGL tutorial found here:
    // https://www.khronos.org/opengl/wiki/Tutorial:_OpenGL_3.0_Context_Creation_(GLX)
    {
        int[23] targetFramebufferAttribs =
        [
            GLX_X_RENDERABLE    , True,
            GLX_DRAWABLE_TYPE   , GLX_WINDOW_BIT,
            GLX_RENDER_TYPE     , GLX_RGBA_BIT,
            GLX_X_VISUAL_TYPE   , GLX_TRUE_COLOR,
            GLX_RED_SIZE        , 8,
            GLX_GREEN_SIZE      , 8,
            GLX_BLUE_SIZE       , 8,
            GLX_ALPHA_SIZE      , 8,
            GLX_DEPTH_SIZE      , 24,
            GLX_STENCIL_SIZE    , 8,
            GLX_DOUBLEBUFFER    , True,
            //GLX_SAMPLE_BUFFERS  , 1,
            //GLX_SAMPLES         , 4,
            None
        ];
        
        int fbCount;
        GLXFBConfig* fbList = glXChooseFBConfig(xs.display, xs.display.default_screen, targetFramebufferAttribs.ptr, &fbCount);
        if (fbCount <= 0)
        {
            logFatal!("Unable to get list of adaquate OpenGL framebuffers for the screen using glXChooseFBConfig. Aborting.\n");
            return;
        }
        
        // TODO(tspike): Choose and store best visual/fbConfig
        xs.fbConfig = fbList[0];
        xs.visualInfo = glXGetVisualFromFBConfig(xs.display, xs.fbConfig);
        
        XFree(fbList);
    }
    scope(exit){XFree(xs.visualInfo);}
    
    XSetWindowAttributes winAttr = {};
    winAttr.event_mask = FocusChangeMask | ExposureMask | StructureNotifyMask;
    winAttr.colormap = XCreateColormap(xs.display, XRootWindow(xs.display, xs.visualInfo.screen), xs.visualInfo.visual, AllocNone);
    winAttr.background_pixel = 0;
    winAttr.border_pixel = 0;
    winAttr.background_pixmap = None;
    scope(exit){XFreeColormap(xs.display, winAttr.colormap);}
    
    xs.window = XCreateWindow(
        xs.display, XRootWindow(xs.display, xs.visualInfo.screen), 0, 0, xs.windowWidth, xs.windowHeight, 0,
        xs.visualInfo.depth, InputOutput, xs.visualInfo.visual, CWEventMask | CWBackPixel | CWColormap | CWBorderPixel, &winAttr
        );
    
    if (!xs.window)
    {
        logFatal!("Unable to create window. Aborting.\n");
        return;
    }
    scope(exit){XDestroyWindow(xs.display, xs.window);}
    
    xs.atom_WMState = XInternAtom(xs.display, "_NET_WM_STATE", False); 
    xs.atom_WMStateFullscreen = XInternAtom(xs.display, "_NET_WM_STATE_FULLSCREEN", False);
    xs.atom_WMDeleteWindow = XInternAtom(xs.display, "WM_DELETE_WINDOW", False);
    xs.atom_WMIcon = XInternAtom(xs.display, "_NET_WM_ICON", False);
    
    XSetWMProtocols(xs.display, xs.window, &xs.atom_WMDeleteWindow, 1);
    
    c_ulong screenX, screenY, screenW, screenH;
    setWindowBorder(&xs, false);
    getDesktopWorkArea(&xs, &screenX, &screenY, &screenW, &screenH);
    logDebug!("Usable screen size: {0}, {1}, {2}, {3}\n")(screenX, screenY, screenW, screenH);
    
    XStoreName(xs.display, xs.window, appTitle.ptr);
    
    GLXExtensions glxe = {};
    const(char)* glxExtensions = glXQueryExtensionsString(xs.display, xs.visualInfo.screen);
    loadGLXExtensions(&glxe, glxExtensions);
    
    XChangeProperty(xs.display, xs.window, xs.atom_WMIcon, XA_CARDINAL, 32, 
        PropModeReplace, cast(const ubyte*)x11IconData.ptr, cast(int)x11IconData.length
    );
    
    if (glxe.CreateContextAttribsARB)
    {
        // NOTE(tspike): Temporarily stub out the X11 error handler with our own in case context creation fails.
        XErrorHandler defaultX11ErrorHandler = XSetErrorHandler(&stubX11ErrorHandler);

        // NOTE(tspike): Setting GLX_CONTEXT_FLAGS_ARB to GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB
        // appears to be bad practice. The official OpenGL wiki states you should NEVER do it:
        // https://www.khronos.org/opengl/wiki/Creating_an_OpenGL_Context_(WGL)
version(testing)
{
        int[9] glxContextAttribs =
        [
            GLX_CONTEXT_MAJOR_VERSION_ARB, TARGET_GL_VERSION_MAJOR,
            GLX_CONTEXT_MINOR_VERSION_ARB, TARGET_GL_VERSION_MINOR,
            GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
            GLX_CONTEXT_FLAGS_ARB, GLX_CONTEXT_DEBUG_BIT_ARB,
            None
        ];
}
else
{
        int[7] glxContextAttribs =
        [
            GLX_CONTEXT_MAJOR_VERSION_ARB, TARGET_GL_VERSION_MAJOR,
            GLX_CONTEXT_MINOR_VERSION_ARB, TARGET_GL_VERSION_MINOR,
            GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
            None
        ];
}

        xs.glContext = glxe.CreateContextAttribsARB(xs.display, xs.fbConfig, null, True, glxContextAttribs.ptr);
        
        // NOTE(tspike): Call XSync to force X11 to process errors and send them to our error handler
        XSync(xs.display, False);
        XSetErrorHandler(defaultX11ErrorHandler);
    }    
    
    if (!xs.glContext)
    {
        logErr!("Unable to create OpenGL {0}.{1} context. Exiting.\n")(TARGET_GL_VERSION_MAJOR, TARGET_GL_VERSION_MINOR);
        return;
    }
    scope(exit){glXDestroyContext(xs.display, xs.glContext);}
    glXMakeCurrent(xs.display, xs.window, xs.glContext);
    
    // NOTE(tspike): We need to have a valid context active to do this!
    if (glxe.SwapIntervalEXT)
    {
        glxe.SwapIntervalEXT(xs.display, xs.window, 1);
        logInfo!("glXSwapIntervalEXT requested VSync.\n");
    }
    else if (glxe.SwapIntervalMESA)
    {
        glxe.SwapIntervalMESA(1);
        logInfo!("glXSwapIntervalMESA requested VSync.\n");
    }
    else if (glxe.SwapIntervalSGI)
    {
        // NOTE(tspike): glXSwapIntervalSGI CANNOT take a value of 0. See here for more info:
        // https://stackoverflow.com/a/38914829
        glxe.SwapIntervalSGI(1);
        logInfo!("glXSwapIntervalSGI requested VSync.\n");
    }
    else
    {
        logWarn!("Unable to request VSync.");
    }
    
    if (!gladLoadGL())
    {
        logFatal!("Failed to load OpenGL. Aborting.\n");
        return;
    }
    
    logInfo!("OpenGL context: {0}\n")(cast(const(char)*)glGetString(GL_VERSION));
    logInfo!("OpenGL shader version: {0}\n")(cast(const(char)*)glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    if(!renderInit())
    {
        logFatal!("Unable to initialize render state. Aborting.\n");
        return;
    }
  
    AppState app = void;
    if (!initApp(&app))
    {
        logFatal!("Unable to initialize app. Aborting.\n");
        return;
    }
  
    XMapRaised(xs.display, xs.window);    
    XMoveWindow(xs.display, xs.window, cast(int)screenX, cast(int)screenH - xs.windowHeight);
    XResizeWindow(xs.display, xs.window, cast(uint)screenW, xs.windowHeight);
    xs.windowWidth = cast(uint)screenW;
    XFlush(xs.display);
    
    timespec previousTime = getCurrentTime();
    timespec startTime = previousTime;
    
    XEvent evt;
    xs.running = true;
    while(xs.running)
    {
        while (XEventsQueued(xs.display, QueuedAlready))
        {
            XNextEvent(xs.display, &evt);
            handleEvents(&evt, &xs);
        }

        timespec currentTime = getCurrentTime();
        float dt = getSecondsElapsed(previousTime, currentTime);
        previousTime = currentTime;
        
        updateApp(&app, dt);
        
        renderGame(xs.windowWidth, xs.windowHeight, xs.windowWidth, xs.windowHeight);
        glXSwapBuffers(xs.display, xs.window);
        XFlush(xs.display);
        
        usleep(250000);
    }
}