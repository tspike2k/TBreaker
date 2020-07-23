// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module platform.linux_x11;

version(linux):
extern (C) @nogc nothrow:

import core.stdc.config : c_ulong, c_long;

alias c_ulong Atom;
alias c_ulong XID;
alias c_ulong Time;
alias XID Window;
alias XID Drawable;
alias XID Font;
alias XID Pixmap;
alias XID Cursor;
alias XID Colormap;
alias XID GContext;
alias XID KeySym;
alias char* XPointer;
alias c_ulong VisualID;
alias XDisplay Display;

alias int Status;
alias int Bool;
enum True  = 1;
enum False = 0;

enum None = 0;	/* universal null resource or null atom */

alias int function(XDisplay*, XErrorEvent*) XErrorHandler; 	    /* WARNING, this type not in Xlib spec */

/* For CreateColormap */
enum
{
    AllocNone		= 0,	/* create map with no entries */
    AllocAll		= 1,	/* allocate entire map writeable */
}

/* Window classes used by CreateWindow */
/* Note that CopyFromParent is already defined as 0 above */
enum
{
    InputOutput	= 1,
    InputOnly   = 2,
}

/* Display classes  used in opening the connection 
 * Note that the statically allocated ones are even numbered and the
 * dynamically changeable ones are odd numbered */
enum
{
    StaticGray		= 0,
    GrayScale		= 1,
    StaticColor		= 2,
    PseudoColor		= 3,
    TrueColor		= 4,
    DirectColor		= 5,
}

/* Input Event Masks. Used as event-mask window attribute and as arguments
   to Grab requests.  Not to be confused with event names.  */
enum 
{
    NoEventMask			= 0,
    KeyPressMask			= 1<<0,  
    KeyReleaseMask			= 1<<1,  
    ButtonPressMask			= 1<<2,  
    ButtonReleaseMask		= 1<<3,  
    EnterWindowMask			= 1<<4,  
    LeaveWindowMask			= 1<<5,  
    PointerMotionMask		= 1<<6,  
    PointerMotionHintMask		= 1<<7,  
    Button1MotionMask		= 1<<8,  
    Button2MotionMask		= 1<<9,  
    Button3MotionMask		= 1<<10, 
    Button4MotionMask		= 1<<11, 
    Button5MotionMask		= 1<<12, 
    ButtonMotionMask		= 1<<13, 
    KeymapStateMask			= 1<<14,
    ExposureMask			= 1<<15, 
    VisibilityChangeMask		= 1<<16, 
    StructureNotifyMask		= 1<<17, 
    ResizeRedirectMask		= 1<<18, 
    SubstructureNotifyMask		= 1<<19, 
    SubstructureRedirectMask	= 1<<20, 
    FocusChangeMask			= 1<<21, 
    PropertyChangeMask		= 1<<22, 
    ColormapChangeMask		= 1<<23, 
    OwnerGrabButtonMask		= 1<<24, 
}

/* Window attributes for CreateWindow and ChangeWindowAttributes */
enum
{
    CWBackPixmap		= 1<<0,
    CWBackPixel		= 1<<1,
    CWBorderPixmap		= 1<<2,
    CWBorderPixel           = 1<<3,
    CWBitGravity		= 1<<4,
    CWWinGravity		= 1<<5,
    CWBackingStore          = 1<<6,
    CWBackingPlanes	        = 1<<7,
    CWBackingPixel	        = 1<<8,
    CWOverrideRedirect	= 1<<9,
    CWSaveUnder		= 1<<10,
    CWEventMask		= 1<<11,
    CWDontPropagate	        = 1<<12,
    CWColormap		= 1<<13,
    CWCursor	        = 1<<14,
}

enum
{
    QueuedAlready      = 0,
    QueuedAfterReading = 1,
    QueuedAfterFlush   = 2,
}

enum
{
    KeyPress		= 2,
    KeyRelease		= 3,
    ButtonPress		= 4,
    ButtonRelease		= 5,
    MotionNotify		= 6,
    EnterNotify		= 7,
    LeaveNotify		= 8,
    FocusIn			= 9,
    FocusOut		= 10,
    KeymapNotify		= 11,
    Expose			= 12,
    GraphicsExpose		= 13,
    NoExpose		= 14,
    VisibilityNotify	= 15,
    CreateNotify		= 16,
    DestroyNotify		= 17,
    UnmapNotify		= 18,
    MapNotify		= 19,
    MapRequest		= 20,
    ReparentNotify		= 21,
    ConfigureNotify		= 22,
    ConfigureRequest	= 23,
    GravityNotify		= 24,
    ResizeRequest		= 25,
    CirculateNotify		= 26,
    CirculateRequest	= 27,
    PropertyNotify		= 28,
    SelectionClear		= 29,
    SelectionRequest	= 30,
    SelectionNotify		= 31,
    ColormapNotify		= 32,
    ClientMessage		= 33,
    MappingNotify		= 34,
    GenericEvent		= 35,
    LASTEvent		= 36,	/* must be bigger than any event # */
}

enum
{
    ShiftMask		= (1<<0),
    LockMask		= (1<<1),
    ControlMask		= (1<<2),
    Mod1Mask		= (1<<3),
    Mod2Mask		= (1<<4),
    Mod3Mask		= (1<<5),
    Mod4Mask		= (1<<6),
    Mod5Mask		= (1<<7),
}

enum 
{
    XA_CARDINAL = cast(Atom)6,
}

enum
{
    IsUnmapped    = 0,
    IsUnviewable  = 1,
    IsViewable    = 2,
}


/* Property modes */
enum
{
    PropModeReplace         = 0,
    PropModePrepend         = 1,
    PropModeAppend          = 2,
}

enum
{
    // TODO: Get other useful keys from keysymdef.h
    XK_BackSpace                     = 0xff08,  /* Back space, back char */
    XK_Tab                           = 0xff09,
    XK_Linefeed                      = 0xff0a,  /* Linefeed, LF */
    XK_Clear                         = 0xff0b,
    XK_Return                        = 0xff0d,  /* Return, enter */
    XK_Pause                         = 0xff13,  /* Pause, hold */
    XK_Scroll_Lock                   = 0xff14,
    XK_Sys_Req                       = 0xff15,
    XK_Escape                        = 0xff1b,
    XK_Delete                        = 0xffff,  /* Delete, rubout */
    
    XK_Left                          = 0xff51,  /* Move left, left arrow */
    XK_Up                            = 0xff52,  /* Move up, up arrow */
    XK_Right                         = 0xff53,  /* Move right, right arrow */
    XK_Down                          = 0xff54,  /* Move down, down arrow */

    XK_a                             = 0x0061,  /* U+0061 LATIN SMALL LETTER A */
    XK_b                             = 0x0062,  /* U+0062 LATIN SMALL LETTER B */
    XK_c                             = 0x0063,  /* U+0063 LATIN SMALL LETTER C */
    XK_d                             = 0x0064,  /* U+0064 LATIN SMALL LETTER D */
    XK_e                             = 0x0065,  /* U+0065 LATIN SMALL LETTER E */
    XK_f                             = 0x0066,  /* U+0066 LATIN SMALL LETTER F */
    XK_g                             = 0x0067,  /* U+0067 LATIN SMALL LETTER G */
    XK_h                             = 0x0068,  /* U+0068 LATIN SMALL LETTER H */
    XK_i                             = 0x0069,  /* U+0069 LATIN SMALL LETTER I */
    XK_j                             = 0x006a,  /* U+006A LATIN SMALL LETTER J */
    XK_k                             = 0x006b,  /* U+006B LATIN SMALL LETTER K */
    XK_l                             = 0x006c,  /* U+006C LATIN SMALL LETTER L */
    XK_m                             = 0x006d,  /* U+006D LATIN SMALL LETTER M */
    XK_n                             = 0x006e,  /* U+006E LATIN SMALL LETTER N */
    XK_o                             = 0x006f,  /* U+006F LATIN SMALL LETTER O */
    XK_p                             = 0x0070,  /* U+0070 LATIN SMALL LETTER P */
    XK_q                             = 0x0071,  /* U+0071 LATIN SMALL LETTER Q */
    XK_r                             = 0x0072,  /* U+0072 LATIN SMALL LETTER R */
    XK_s                             = 0x0073,  /* U+0073 LATIN SMALL LETTER S */
    XK_t                             = 0x0074,  /* U+0074 LATIN SMALL LETTER T */
    XK_u                             = 0x0075,  /* U+0075 LATIN SMALL LETTER U */
    XK_v                             = 0x0076,  /* U+0076 LATIN SMALL LETTER V */
    XK_w                             = 0x0077,  /* U+0077 LATIN SMALL LETTER W */
    XK_x                             = 0x0078,  /* U+0078 LATIN SMALL LETTER X */
    XK_y                             = 0x0079,  /* U+0079 LATIN SMALL LETTER Y */
    XK_z                             = 0x007a,  /* U+007A LATIN SMALL LETTER Z */
}

enum 
{
    AnyKey		     = 0L,	/* special Key Code, passed to GrabKey */
    AnyButton            = 0L,	/* special Button Code, passed to GrabButton */
    AllTemporary         = 0L,	/* special Resource ID passed to KillClient */
    CurrentTime          = 0L,	/* special Time */
    NoSymbol	     = 0L,	/* special KeySym */
}

enum
{
    Button1Mask		= (1<<8),
    Button2Mask		= (1<<9),
    Button3Mask		= (1<<10),
    Button4Mask		= (1<<11),
    Button5Mask		= (1<<12),
}

/* GrabPointer, GrabButton, GrabKeyboard, GrabKey Modes */
enum
{
    GrabModeSync		= 0,
    GrabModeAsync		= 1,
}

/* GrabPointer, GrabKeyboard reply status */
enum
{
    GrabSuccess		= 0,
    AlreadyGrabbed		= 1,
    GrabInvalidTime		= 2,
    GrabNotViewable		= 3,
    GrabFrozen		= 4,
}

/* Error codes */
enum
{
    Success		  =  0,	/* everything's okay */
    BadRequest	  =  1,	/* bad request code */
    BadValue	  =  2,	/* int parameter out of range */
    BadWindow	  =  3,	/* parameter not a Window */
    BadPixmap	  =  4,	/* parameter not a Pixmap */
    BadAtom		  =  5,	/* parameter not an Atom */
    BadCursor	  =  6,	/* parameter not a Cursor */
    BadFont		  =  7,	/* parameter not a Font */
    BadMatch	  =  8,	/* parameter mismatch */
    BadDrawable	  =  9,	/* parameter not a Pixmap or Window */
    BadAccess	  = 10,	/* depending on context:
                     - key/button already grabbed
                     - attempt to free an illegal
                       cmap entry
                    - attempt to store into a read-only
                       color map entry.
                    - attempt to modify the access control
                       list from other than the local host.
                    */
    BadAlloc	  = 11,	/* insufficient resources */
    BadColor	  = 12,	/* no such colormap */
    BadGC		  = 13,	/* parameter not a GC */
    BadIDChoice	  = 14,	/* choice not in range or already used */
    BadName		  = 15,	/* font or color name doesn't exist */
    BadLength	  = 16,	/* Request length incorrect */
    BadImplementation = 17,	/* server is defective */

    FirstExtensionError	= 128,
    LastExtensionError	= 255,

}

Window XDefaultRootWindow(XDisplay* display)
{
    return display.screens[display.default_screen].root;
}

Window XRootWindow(XDisplay* display, int screen)
{
    return display.screens[screen].root;
}

// TODO: Determine what integer sizes should be used as function parameters

XDisplay* XOpenDisplay(const(char)*);
int XCloseDisplay(XDisplay*);
Colormap XCreateColormap(XDisplay* display, Window window, Visual* visual, int alloc);
int XFreeColormap(XDisplay*, Colormap);
Status XMatchVisualInfo(XDisplay* display, int screen, int colorDepth, int c_class, XVisualInfo* result);
Window XCreateWindow(XDisplay* display, Window window, int x, int y, uint width, uint height, uint borderWidth, int colorDepth, uint c_class, Visual* visual, c_ulong	valueMask, XSetWindowAttributes* winAttributes);
int XDestroyWindow(XDisplay*, Window);
int XMapRaised(Display*, Window);
int XFlush(Display*);
int XEventsQueued(XDisplay* display, int mode);
int XNextEvent(Display*, XEvent*);
Atom XInternAtom(Display* display, const(char)* name, Bool ifExists);
Status XSetWMProtocols(Display* display, Window window, Atom* protocols, int count);
int XStoreName(Display*, Window, const(char)*);
int XFree(void*);
int XChangeProperty(XDisplay* display, Window w, Atom property, Atom type, int format, int mode, const(ubyte)* data, int nElements);
XErrorHandler XSetErrorHandler (XErrorHandler);
int XSync(XDisplay* display, Bool discard);
Pixmap XCreateBitmapFromData(Display*, Drawable, const (char)*, uint, uint);
int XFreePixmap(Display*, Pixmap);
Cursor XCreatePixmapCursor(Display*, Pixmap, Pixmap, XColor*, XColor*, uint, uint);
int XDefineCursor(Display*, Window, Cursor);
int XUndefineCursor(Display*, Window);
int XFreeCursor(Display*, Cursor);
Bool XGetEventData(Display*, XGenericEventCookie*);
void XFreeEventData(Display*, XGenericEventCookie*);
KeySym XLookupKeysym(XKeyEvent*, int);
int XPeekEvent(Display*, XEvent*);
Status XSendEvent(Display*, Window, Bool, long, XEvent*);
int XGrabPointer(Display*, Window, Bool, uint, int, int, Window, Cursor, Time);
int XUngrabPointer(Display*, Time);
Bool XQueryPointer(Display*, Window, Window*, Window*, int*, int*, int*, int*, uint*);
int XWarpPointer(Display*, Window, Window, int, int, uint, uint, int, int);
int XGetWindowProperty(Display*, Window, Atom, c_long, c_long, Bool, Atom, Atom*, int*, c_ulong*, c_ulong*, ubyte**);
Status XGetWindowAttributes(Display*, Window, XWindowAttributes*);
int XChangeWindowAttributes(Display*, Window, c_ulong, XSetWindowAttributes*);
int XMoveWindow(Display*, Window, int, int);
int XResizeWindow(Display*, Window, uint, uint);
int XRaiseWindow(Display*, Window);


Bool XQueryExtension(Display*, const(char)*, int*, int*, int*);

private struct _XPrivate;
private struct _XrmHashBucketRec;
struct Depth;
struct ScreenFormat;
struct XExtData;
struct Visual;

struct Screen
{
    XExtData *ext_data;	/* hook for extension to hang data */
    XDisplay *display;/* back pointer to display structure */
    Window root;		/* Root window id. */
    int width, height;	/* width and height of screen */
    int mwidth, mheight;	/* width and height of  in millimeters */
    int ndepths;		/* number of depths possible */
    Depth *depths;		/* list of allowable depths on the screen */
    int root_depth;		/* bits per pixel */
    Visual *root_visual;	/* root visual */
    GC default_gc;		/* GC for the root root visual */
    Colormap cmap;		/* default color map */
    c_ulong white_pixel;
    c_ulong black_pixel;	/* White and Black pixel values */
    int max_maps, min_maps;	/* max and min color maps */
    int backing_store;	/* Never, WhenMapped, Always */
    Bool save_unders;
    c_long root_input_mask;	/* initial root input mask */
}

struct XColor
{
    c_ulong pixel;
    ushort red, green, blue;
    char flags;  /* do_red, do_green, do_blue */
    char pad;
}

struct GC
{
    XExtData *ext_data;	/* hook for extension to hang data */
    GContext gid;	/* protocol ID for graphics context */
    /* there is more to this structure, but it is private to Xlib */
}

struct XDisplay
{
    XExtData *ext_data;	/* hook for extension to hang data */
    _XPrivate *private1;
    int fd;			/* Network socket. */
    int private2;
    int proto_major_version;/* major version of server's X protocol */
    int proto_minor_version;/* minor version of servers X protocol */
    char *vendor;		/* vendor of the server hardware */
        XID private3;
    XID private4;
    XID private5;
    int private6;
    extern (C) nothrow @nogc XID function (XDisplay*) resource_alloc;	/* allocator function */
    int byte_order;		/* screen byte order, LSBFirst, MSBFirst */
    int bitmap_unit;	/* padding and data requirements */
    int bitmap_pad;		/* padding requirements on bitmaps */
    int bitmap_bit_order;	/* LeastSignificant or MostSignificant */
    int nformats;		/* number of pixmap formats in list */
    ScreenFormat *pixmap_format;	/* pixmap format list */
    int private8;
    int release;		/* release of the server */
    _XPrivate *private9;
    _XPrivate *private10;
    int qlen;		/* Length of input event queue */
    c_ulong last_request_read; /* seq number of last event read */
    c_ulong request;	/* sequence number of last request. */
    XPointer private11;
    XPointer private12;
    XPointer private13;
    XPointer private14;
    uint max_request_size; /* maximum number 32 bit words in request*/
    _XrmHashBucketRec *db;
    extern (C) nothrow @nogc int function(XDisplay*) private15;
    char* display_name;	/* "host:display" string used on this connect*/
    int default_screen;	/* default screen for operations */
    int nscreens;		/* number of screens on this server*/
    Screen* screens;	/* pointer to list of screens */
    c_ulong motion_buffer;	/* size of motion buffer */
    c_ulong private16;
    int min_keycode;	/* minimum defined keycode */
    int max_keycode;	/* maximum defined keycode */
    XPointer private17;
    XPointer private18;
    int private19;
    char *xdefaults;	/* contents of defaults from server */
    /* there is more to this structure, but it is private to Xlib */
}

struct XSetWindowAttributes
{
    Pixmap background_pixmap;	/* background or None or ParentRelative */
    c_ulong background_pixel;	/* background pixel */
    Pixmap border_pixmap;	/* border of the window */
    c_ulong border_pixel;	/* border pixel value */
    int bit_gravity;		/* one of bit gravity values */
    int win_gravity;		/* one of the window gravity values */
    int backing_store;		/* NotUseful, WhenMapped, Always */
    c_ulong backing_planes;/* planes to be preseved if possible */
    c_ulong backing_pixel;/* value to use in restoring planes */
    Bool save_under;		/* should bits under be saved? (popups) */
    c_long event_mask;		/* set of events that should be saved */
    c_long do_not_propagate_mask;	/* set of events that should not propagate */
    Bool override_redirect;	/* boolean value for override-redirect */
    Colormap colormap;		/* color map to be associated with window */
    Cursor cursor;		/* cursor to be displayed (or None) */
}

struct XVisualInfo
{
  Visual *visual;
  VisualID visualid;
  int screen;
  int depth;
  int c_class;
  c_ulong red_mask;
  c_ulong green_mask;
  c_ulong blue_mask;
  int colormap_size;
  int bits_per_rgb;
}

struct XKeyEvent 
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window it is reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    uint keycode;	/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XKeyEvent XKeyPressedEvent;
alias XKeyEvent XKeyReleasedEvent;

struct XButtonEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window it is reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    uint button;	/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XButtonEvent XButtonPressedEvent;
alias XButtonEvent XButtonReleasedEvent;

struct XMotionEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    uint state;	/* key or button mask */
    char is_hint;		/* detail */
    Bool same_screen;	/* same screen flag */
}
alias XMotionEvent XPointerMovedEvent;

struct XCrossingEvent
{
    int type;		/* of event */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;	        /* "event" window reported relative to */
    Window root;	        /* root window that the event occurred on */
    Window subwindow;	/* child window */
    Time time;		/* milliseconds */
    int x, y;		/* pointer x, y coordinates in event window */
    int x_root, y_root;	/* coordinates relative to root */
    int mode;		/* NotifyNormal, NotifyGrab, NotifyUngrab */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual
     */
    Bool same_screen;	/* same screen flag */
    Bool focus;		/* boolean focus */
    uint state;	/* key or button mask */
}
alias XCrossingEvent XEnterWindowEvent;
alias XCrossingEvent XLeaveWindowEvent;

struct XFocusChangeEvent
{
    int type;		/* FocusIn or FocusOut */
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;		/* window of event */
    int mode;		/* NotifyNormal, NotifyWhileGrabbed,
                   NotifyGrab, NotifyUngrab */
    int detail;
    /*
     * NotifyAncestor, NotifyVirtual, NotifyInferior,
     * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
     * NotifyPointerRoot, NotifyDetailNone
     */
}
alias XFocusChangeEvent XFocusInEvent;
alias XFocusChangeEvent XFocusOutEvent;

/* generated on EnterWindow and FocusIn  when KeyMapState selected */
struct XKeymapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    char[32] key_vector;
}

struct XExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int x, y;
    int width, height;
    int count;		/* if non-zero, at least this many more */
}

struct XGraphicsExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Drawable drawable;
    int x, y;
    int width, height;
    int count;		/* if non-zero, at least this many more */
    int major_code;		/* core is CopyArea or CopyPlane */
    int minor_code;		/* not defined in the core */
}

struct XNoExposeEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Drawable drawable;
    int major_code;		/* core is CopyArea or CopyPlane */
    int minor_code;		/* not defined in the core */
}

struct  XVisibilityEvent {
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int state;		/* Visibility state */
}

struct XCreateWindowEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;		/* parent of the window */
    Window window;		/* window id of window created */
    int x, y;		/* window location */
    int width, height;	/* size of window */
    int border_width;	/* border width */
    Bool override_redirect;	/* creation should be overridden */
}

struct XDestroyWindowEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
}

struct XUnmapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Bool from_configure;
}

struct XMapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Bool override_redirect;	/* boolean, is override set... */
}

struct XMapRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
}

struct XReparentEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    Window parent;
    int x, y;
    Bool override_redirect;
}

struct XConfigureEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    Bool override_redirect;
}

struct XGravityEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int x, y;
}

struct XResizeRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    int width, height;
}

struct XConfigureRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    int detail;		/* Above, Below, TopIf, BottomIf, Opposite */
    c_ulong value_mask;
}

struct XCirculateEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window event;
    Window window;
    int place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XCirculateRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window parent;
    Window window;
    int place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XPropertyEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom atom;
    Time time;
    int state;		/* NewValue, Deleted */
}

struct XSelectionClearEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom selection;
    Time time;
}

struct XSelectionRequestEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window owner;
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;
    Time time;
};

struct XSelectionEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window requestor;
    Atom selection;
    Atom target;
    Atom property;		/* ATOM or None */
    Time time;
}

struct XColormapEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Colormap colormap;	/* COLORMAP or None */
    Bool c_new;		/* C++ */
    int state;		/* ColormapInstalled, ColormapUninstalled */
}

struct XClientMessageEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;
    Atom message_type;
    int format;
    union EvtData
    {
        char[20] b;
        short[10] s;
        c_long[5] l;
    } 
    EvtData data;
}

struct XMappingEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;	/* Display the event was read from */
    Window window;		/* unused */
    int request;		/* one of MappingModifier, MappingKeyboard,
                   MappingPointer */
    int first_keycode;	/* first keycode */
    int count;		/* defines range of change w. first_keycode*/
}

struct XErrorEvent
{
    int type;
    Display *display;	/* Display the event was read from */
    XID resourceid;		/* resource id */
    c_ulong serial;	/* serial number of failed request */
    ubyte error_code;	/* error code of failed request */
    ubyte request_code;	/* Major op-code of failed request */
    ubyte minor_code;	/* Minor op-code of failed request */
}

struct XAnyEvent
{
    int type;
    c_ulong serial;	/* # of last request processed by server */
    Bool send_event;	/* true if this came from a SendEvent request */
    Display *display;/* Display the event was read from */
    Window window;	/* window on which event was requested in event mask */
}


/***************************************************************
 *
 * GenericEvent.  This event is the standard event for all newer extensions.
 */

struct XGenericEvent
{
    int            type;         /* of event. Always GenericEvent */
    c_ulong  serial;       /* # of last request processed */
    Bool           send_event;   /* true if from SendEvent request */
    Display        *display;     /* Display the event was read from */
    int            extension;    /* major opcode of extension that caused the event */
    int            evtype;       /* actual event type. */
}

struct XGenericEventCookie
{
    int            type;         /* of event. Always GenericEvent */
    c_ulong  serial;       /* # of last request processed */
    Bool           send_event;   /* true if from SendEvent request */
    Display        *display;     /* Display the event was read from */
    int            extension;    /* major opcode of extension that caused the event */
    int            evtype;       /* actual event type. */
    uint   cookie;
    void           *data;
}

/*
 * this union is defined so Xlib can always use the same sized
 * event structure internally, to avoid memory fragmentation.
 */
union XEvent
{
    int type;		/* must not be changed; first element */
    XAnyEvent xany;
    XKeyEvent xkey;
    XButtonEvent xbutton;
    XMotionEvent xmotion;
    XCrossingEvent xcrossing;
    XFocusChangeEvent xfocus;
    XExposeEvent xexpose;
    XGraphicsExposeEvent xgraphicsexpose;
    XNoExposeEvent xnoexpose;
    XVisibilityEvent xvisibility;
    XCreateWindowEvent xcreatewindow;
    XDestroyWindowEvent xdestroywindow;
    XUnmapEvent xunmap;
    XMapEvent xmap;
    XMapRequestEvent xmaprequest;
    XReparentEvent xreparent;
    XConfigureEvent xconfigure;
    XGravityEvent xgravity;
    XResizeRequestEvent xresizerequest;
    XConfigureRequestEvent xconfigurerequest;
    XCirculateEvent xcirculate;
    XCirculateRequestEvent xcirculaterequest;
    XPropertyEvent xproperty;
    XSelectionClearEvent xselectionclear;
    XSelectionRequestEvent xselectionrequest;
    XSelectionEvent xselection;
    XColormapEvent xcolormap;
    XClientMessageEvent xclient;
    XMappingEvent xmapping;
    XErrorEvent xerror;
    XKeymapEvent xkeymap;
    XGenericEvent xgeneric;
    XGenericEventCookie xcookie;
    c_long[24] pad;
}

struct XWindowAttributes 
{
    int x, y;
    int width, height;
    int border_width;
    int depth;
    Visual *visual;
    Window root;
    int c_class;
    int bit_gravity;
    int win_gravity;
    int backing_store;
    c_ulong backing_planes;
    c_ulong backing_pixel;
    bool save_under;
    Colormap colormap;
    bool map_installed;
    int map_state;
    long all_event_masks;
    long your_event_mask;
    long do_not_propagate_mask;
    bool override_redirect;
    Screen *screen;
}

//
// XExt interface
//

alias int function(Display* display, const(char)* extensionName, const(char)* failureReason) XextErrorHandler;
alias XextErrorHandler function(XextErrorHandler handler) XSetExtensionErrorHandlerFunc;

//
// XInput 1/2 interface
//

/* Device types */
enum
{
    XIMasterPointer                         = 1,
    XIMasterKeyboard                        = 2,
    XISlavePointer                          = 3,
    XISlaveKeyboard                         = 4,
    XIFloatingSlave                         = 5,
}

enum
{
    XIAllDevices                            = 0,
    XIAllMasterDevices                      = 1,
}

struct XIAnyClassInfo;

struct XIEventMask
{
    int deviceid;
    int mask_len;
    ubyte* mask;
}

struct XIDeviceInfo
{
    int deviceid;
    char* name;
    int use;
    int attachment;
    Bool enabled;
    int num_classes;
    XIAnyClassInfo **classes;
}

alias int function(Display* display, Window window, XIEventMask* masks, int numMasks) XISelectEventsFunc;
alias Status function(Display* display, int* majorVersion, int* minorVersion) XIQueryVersionFunc;
alias XIDeviceInfo* function(Display* display, int deviceID, int* devicesReturnedNumber) XIQueryDeviceFunc;
alias void function(XIDeviceInfo* info) XIFreeDeviceInfoFunc;

void XISetMask(ubyte* ptr, int event)
{
    ptr[(event)>>3] |=  (1 << ((event) & 7));
}

struct XIValuatorState
{
    int           mask_len;
    ubyte         *mask;
    double        *values;
}

struct XIRawEvent
{
    int           type;         /* GenericEvent */
    ulong serial;               /* # of last request processed by server */
    Bool          send_event;   /* true if this came from a SendEvent request */
    Display       *display;     /* Display the event was read from */
    int           extension;    /* XI extension offset */
    int           evtype;       /* XI_RawKeyPress, XI_RawKeyRelease, etc. */
    Time          time;
    int           deviceid;
    int           sourceid;     /* Bug: Always 0. https://bugs.freedesktop.org//show_bug.cgi?id=34240 */
    int           detail;
    int           flags;
    XIValuatorState valuators;
    double        *raw_values;
}

/* Event types */
enum XI_DeviceChanged                 = 1;
enum XI_KeyPress                      = 2;
enum XI_KeyRelease                    = 3;
enum XI_ButtonPress                   = 4;
enum XI_ButtonRelease                 = 5;
enum XI_Motion                        = 6;
enum XI_Enter                         = 7;
enum XI_Leave                         = 8;
enum XI_FocusIn                       = 9;
enum XI_FocusOut                      = 10;
enum XI_HierarchyChanged              = 11;
enum XI_PropertyEvent                 = 12;
enum XI_RawKeyPress                   = 13;
enum XI_RawKeyRelease                 = 14;
enum XI_RawButtonPress                = 15;
enum XI_RawButtonRelease              = 16;
enum XI_RawMotion                     = 17;
enum XI_TouchBegin                    = 18; /* XI 2.2 */
enum XI_TouchUpdate                   = 19;
enum XI_TouchEnd                      = 20;
enum XI_TouchOwnership                = 21;
enum XI_RawTouchBegin                 = 22;
enum XI_RawTouchUpdate                = 23;
enum XI_RawTouchEnd                   = 24;
enum XI_BarrierHit                    = 25; /* XI 2.3 */
enum XI_BarrierLeave                  = 26;
enum XI_LASTEVENT                     = XI_BarrierLeave;

bool XIMaskIsSet(ubyte* ptr, uint event) 
{
    //((unsigned char*)(ptr))[(event)>>3] &   (1 << ((event) & 7))
    return cast(bool)( (cast(ubyte*)(ptr))[(event)>>3] & (1 << ((event) & 7)));
}

/*
enum XI_DeviceChangedMask             = (1 << XI_DeviceChanged);
enum XI_KeyPressMask                  = (1 << XI_KeyPress);
enum XI_KeyReleaseMask                = (1 << XI_KeyRelease);
enum XI_ButtonPressMask               = (1 << XI_ButtonPress);
enum XI_ButtonReleaseMask             = (1 << XI_ButtonRelease);
enum XI_MotionMask                    = (1 << XI_Motion);
enum XI_EnterMask                     = (1 << XI_Enter);
enum XI_LeaveMask                     = (1 << XI_Leave);
enum XI_FocusInMask                   = (1 << XI_FocusIn);
enum XI_FocusOutMask                  = (1 << XI_FocusOut);
enum XI_HierarchyChangedMask          = (1 << XI_HierarchyChanged);
enum XI_PropertyEventMask             = (1 << XI_PropertyEvent);
enum XI_RawKeyPressMask               = (1 << XI_RawKeyPress);
enum XI_RawKeyReleaseMask             = (1 << XI_RawKeyRelease);
enum XI_RawButtonPressMask            = (1 << XI_RawButtonPress);
enum XI_RawButtonReleaseMask          = (1 << XI_RawButtonRelease);
enum XI_RawMotionMask                 = (1 << XI_RawMotion);
enum XI_TouchBeginMask                = (1 << XI_TouchBegin);
enum XI_TouchEndMask                  = (1 << XI_TouchEnd);
enum XI_TouchOwnershipChangedMask     = (1 << XI_TouchOwnership);
enum XI_TouchUpdateMask               = (1 << XI_TouchUpdate);
enum XI_RawTouchBeginMask             = (1 << XI_RawTouchBegin);
enum XI_RawTouchEndMask               = (1 << XI_RawTouchEnd);
enum XI_RawTouchUpdateMask            = (1 << XI_RawTouchUpdate);
enum XI_BarrierHitMask                = (1 << XI_BarrierHit);
enum XI_BarrierLeaveMask              = (1 << XI_BarrierLeave);*/