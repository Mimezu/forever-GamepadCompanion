"""Find the WoW window and read the HelperLink strip from its client area's top-left corner.

GDI only: BitBlt from the screen DC into a memory DC, then one GetDIBits per read (no per-pixel
GetPixel). Copying from the screen (not the window DC) is what works for a DirectX game under the
desktop compositor; it needs windowed or borderless display mode (exclusive full screen is black).
"""
import ctypes
from ctypes import wintypes

from protocol import NCELLS, classify, classify_rgb, MARKERS

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

WOW_CLASSES = ("waxWindowClass", "GxWindowClass", "GxWindowClassD3d")
WOW_EXES = ("wow.exe", "wowclassic.exe", "wowt.exe", "wowb.exe")

SRCCOPY = 0x00CC0020
CAPTUREBLT = 0x40000000
DIB_RGB_COLORS = 0
BI_RGB = 0
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wintypes.LPARAM]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsIconic.argtypes = [wintypes.HWND]
user32.IsWindow.argtypes = [wintypes.HWND]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetClientRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.ClientToScreen.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetDC.argtypes = [wintypes.HWND]
user32.GetDC.restype = wintypes.HDC
user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
gdi32.CreateCompatibleDC.argtypes = [wintypes.HDC]
gdi32.CreateCompatibleDC.restype = wintypes.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wintypes.HBITMAP
gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
gdi32.SelectObject.restype = wintypes.HGDIOBJ
gdi32.BitBlt.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                         wintypes.HDC, ctypes.c_int, ctypes.c_int, wintypes.DWORD]
gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wintypes.HDC]
kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel32.OpenProcess.restype = wintypes.HANDLE
kernel32.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
                                                ctypes.POINTER(wintypes.DWORD)]
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG),
                ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
                ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
                ("biClrImportant", wintypes.DWORD)]


class BITMAPINFO(ctypes.Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", wintypes.DWORD * 3)]


gdi32.GetDIBits.argtypes = [wintypes.HDC, wintypes.HBITMAP, wintypes.UINT, wintypes.UINT, ctypes.c_void_p,
                            ctypes.POINTER(BITMAPINFO), wintypes.UINT]


def dpi_aware():
    """Physical pixel coordinates everywhere (per-monitor v2, else system aware)."""
    try:
        if user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4)):
            return
    except AttributeError:
        pass
    try:
        ctypes.WinDLL("shcore").SetProcessDpiAwareness(2)
    except (OSError, AttributeError):
        user32.SetProcessDPIAware()


def _class_name(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buf, 256)
    return buf.value


def window_title(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, buf, 256)
    return buf.value


def _exe_name(hwnd):
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid.value)
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(520)
        size = wintypes.DWORD(520)
        if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            return buf.value.rsplit("\\", 1)[-1].lower()
        return ""
    finally:
        kernel32.CloseHandle(h)


def find_wow_windows():
    """Visible top-level windows of the game: by class name or by Wow.exe."""
    found = []

    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            if _class_name(hwnd) in WOW_CLASSES or _exe_name(hwnd) in WOW_EXES:
                found.append(hwnd)
        return True

    user32.EnumWindows(WNDENUMPROC(cb), 0)
    return found


def find_window(use_foreground=False):
    wins = find_wow_windows()
    if wins:
        fg = user32.GetForegroundWindow()
        return fg if fg in wins else wins[0]
    if use_foreground:
        return user32.GetForegroundWindow() or None
    return None


def client_rect(hwnd):
    """(x, y, w, h) of the client area in screen pixels, or None (gone or minimised)."""
    if not hwnd or not user32.IsWindow(hwnd) or user32.IsIconic(hwnd):
        return None
    rc = wintypes.RECT()
    if not user32.GetClientRect(hwnd, ctypes.byref(rc)):
        return None
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y, rc.right - rc.left, rc.bottom - rc.top


class Grabber:
    """A fixed-size region copied from the screen into memory: BGRA rows, top-down."""

    def __init__(self, width, height):
        self.w, self.h = width, height
        self.screen = user32.GetDC(None)
        self.mem = gdi32.CreateCompatibleDC(self.screen)
        self.bmp = gdi32.CreateCompatibleBitmap(self.screen, width, height)
        self.old = gdi32.SelectObject(self.mem, self.bmp)
        self.info = BITMAPINFO()
        hdr = self.info.bmiHeader
        hdr.biSize = ctypes.sizeof(BITMAPINFOHEADER)
        hdr.biWidth, hdr.biHeight = width, -height  # negative: top-down
        hdr.biPlanes, hdr.biBitCount, hdr.biCompression = 1, 32, BI_RGB
        self.buf = ctypes.create_string_buffer(width * height * 4)

    def grab(self, x, y):
        if not gdi32.BitBlt(self.mem, 0, 0, self.w, self.h, self.screen, x, y, SRCCOPY):
            return None
        if gdi32.GetDIBits(self.mem, self.bmp, 0, self.h, self.buf, ctypes.byref(self.info), DIB_RGB_COLORS) != self.h:
            return None
        return self.buf.raw

    def close(self):
        if self.mem:
            gdi32.SelectObject(self.mem, self.old)
            gdi32.DeleteObject(self.bmp)
            gdi32.DeleteDC(self.mem)
            user32.ReleaseDC(None, self.screen)
            self.mem = None


def _px(buf, w, x, y):
    i = (y * w + x) * 4
    return buf[i + 2], buf[i + 1], buf[i]  # BGRA -> RGB


def _is(buf, w, x, y, cell):
    return classify_rgb(*_px(buf, w, x, y)) == cell


def read_strip(buf, w, h, hint=None, max_cell=16):
    """Find the strip in a BGRA image and return (cells, (x, y, size)) or (None, reason).

    Looks for a magenta block (top-left corner: no magenta left of it or above it), measures its
    width (= the cell size), checks the green marker beside it, then samples every cell's centre.
    Tries the last position first (hint)."""
    def at(x, y):
        # top-left corner of the magenta block only (also for the hint: a hint one pixel inside
        # the block would sample every cell off-centre and fail every checksum)
        if (x > 0 and _is(buf, w, x - 1, y, MARKERS[0])) or (y > 0 and _is(buf, w, x, y - 1, MARKERS[0])):
            return None
        size = 0
        while x + size < w and _is(buf, w, x + size, y, MARKERS[0]):
            size += 1
        if size < 1 or size > max_cell or x + NCELLS * size > w or y + size > h:
            return None
        # magenta must be square-ish: as tall as it is wide
        if not _is(buf, w, x, y + size - 1, MARKERS[0]):
            return None
        half = size // 2
        cy = y + half
        cells = []
        for i in range(NCELLS):
            cells.append(classify_rgb(*_px(buf, w, x + i * size + half, cy)))
        if cells[1] != MARKERS[1]:
            return None
        return cells, (x, y, size)

    if hint:
        x, y, _ = hint
        if x < w and y < h:
            r = at(x, y)
            if r:
                return r
    for y in range(h):
        for x in range(w):
            if not _is(buf, w, x, y, MARKERS[0]):
                continue
            r = at(x, y)
            if r:
                return r
    return None, "no strip"


class StripReader:
    """Reads the strip from the game window's top-left corner (scans a small area)."""

    def __init__(self, area_w=320, area_h=40, use_foreground=False):
        self.area_w, self.area_h = area_w, area_h
        self.use_foreground = use_foreground
        self.grabber = Grabber(area_w, area_h)
        self.hint = None
        self.hwnd = None

    def window(self):
        if not self.hwnd or not user32.IsWindow(self.hwnd):
            self.hwnd = find_window(self.use_foreground)
        return self.hwnd

    def read(self):
        """-> (cells or None, info). cells may hold None entries (invalid channels)."""
        hwnd = self.window()
        if not hwnd:
            return None, "no window"
        rect = client_rect(hwnd)
        if not rect:
            self.hwnd = None
            return None, "window hidden"
        x, y, w, h = rect
        buf = self.grabber.grab(x, y)
        if buf is None:
            return None, "capture failed"
        cells, where = read_strip(buf, self.area_w, self.area_h, self.hint)
        if cells is None:
            return None, where
        self.hint = where
        return cells, where

    def forget(self):
        """Drop the last position (the frame there did not decode): scan afresh next read."""
        self.hint = None

    def close(self):
        self.grabber.close()
