"""DualSense adaptive triggers: effect bytes, output reports, and a tiny HID layer (ctypes).

Only the trigger part of the output report is ever set: valid_flag0 0x04 (right trigger) and 0x08
(left trigger) plus the two 11-byte effect blocks. Rumble flags (0x01, 0x02), valid_flag1 (LEDs,
light bar, mic LED, player LEDs) and valid_flag2 stay 0, so the game's rumble and light bar are
untouched (SDL's HIDAPI PS5 driver never sets the trigger bits: docs/ADAPTIVE-TRIGGERS.md).

Sources for the layouts:
- Output report, USB 0x02 / Bluetooth 0x31, the "common" block, trigger offsets, BT seq/tag and the
  CRC32 seeded with 0xA2: Linux hid-playstation.c (struct dualsense_output_report_common /
  _bt / _usb) and SDL's SDL_hidapi_ps5.c (DS5EffectsState_t: rgucRightTriggerEffect at common
  offset 10, rgucLeftTriggerEffect at 21).
- Effect formats: Nielk1's "TriggerEffectGenerator" (the reference most tools copy: 0x05 off,
  0x21 feedback, 0x25 weapon, 0x26 vibration, multi-position and slope feedback built on 0x21) and
  the older "simple" raw modes used by pydualsense / DualSenseX (0x01 feedback, 0x02 weapon/section,
  0x06 vibration).
UNCERTAIN (not checked against hardware yet): the simple modes' parameter order (marked below);
how Windows reports OutputReportByteLength over Bluetooth (we pad to whatever it says).
"""
import ctypes
import time
import zlib
from ctypes import wintypes

VID_SONY = 0x054C
PIDS = {0x0CE6: "DualSense", 0x0DF2: "DualSense Edge"}

FLAG0_RIGHT_TRIGGER = 0x04
FLAG0_LEFT_TRIGGER = 0x08
COMMON_LEN = 47          # dualsense_output_report_common
RIGHT_OFF, LEFT_OFF = 10, 21
USB_REPORT_ID, USB_LEN = 0x02, 64    # 1 + 47, padded to 64 (hid-playstation DS_OUTPUT_REPORT_USB_SIZE 63 + id)
BT_REPORT_ID, BT_LEN = 0x31, 78      # id, seq_tag, tag, common(47), reserved(24), crc32(4)
BT_TAG = 0x10

# --- Effects (11 bytes each) ----------------------------------------------------------

def _effect(*head):
    b = bytearray(11)
    b[:len(head)] = bytes(head)
    return bytes(b)


def effect_off():
    """0x05: off, the trigger returns to neutral (0x00 only 'clears' and can leave a stop)."""
    return _effect(0x05)


def effect_feedback(position, strength):
    """0x21 resistance from a zone on. position 0-9, strength 1-8 (Nielk1 Feedback)."""
    if not (0 <= position <= 9 and 1 <= strength <= 8):
        return effect_off()
    return effect_multi_feedback([0] * position + [strength] * (10 - position))


def effect_multi_feedback(strengths):
    """0x21 with a strength per zone: 10 values 0-8 (0 = no resistance in that zone)."""
    active, forces = 0, 0
    for i, s in enumerate(strengths[:10]):
        if s > 0:
            active |= 1 << i
            forces |= ((min(s, 8) - 1) & 7) << (3 * i)
    if not active:
        return effect_off()
    return _effect(0x21, active & 0xFF, (active >> 8) & 0xFF,
                   forces & 0xFF, (forces >> 8) & 0xFF, (forces >> 16) & 0xFF, (forces >> 24) & 0xFF)


def effect_slope(start, end, start_strength, end_strength):
    """Resistance rising from start to end (zones 0-9), then held (Nielk1 SlopeFeedback, on 0x21)."""
    if not (0 <= start < end <= 9):
        return effect_off()
    s = [0] * 10
    for i in range(start, 10):
        if i >= end:
            s[i] = end_strength
        else:
            s[i] = round(start_strength + (end_strength - start_strength) * (i - start) / (end - start))
    return effect_multi_feedback([max(1, min(8, v)) if i >= start else 0 for i, v in enumerate(s)])


def effect_weapon(start, end, strength):
    """0x25 a click between start (2-7) and end (start+1 - 8), strength 1-8 (Nielk1 Weapon)."""
    if not (2 <= start <= 7 and start < end <= 8 and 1 <= strength <= 8):
        return effect_off()
    zones = (1 << start) | (1 << end)
    return _effect(0x25, zones & 0xFF, (zones >> 8) & 0xFF, strength - 1)


def effect_vibration(position, amplitude, frequency):
    """0x26 vibration from a zone on: position 0-9, amplitude 1-8, frequency 1-255 Hz (Nielk1 Vibration).
    Bytes: id, active zones (2), amplitude zones 3 bits each (4), 0, 0, frequency, 0."""
    if not (0 <= position <= 9 and 1 <= amplitude <= 8 and 1 <= frequency <= 255):
        return effect_off()
    active, amps = 0, 0
    for i in range(position, 10):
        active |= 1 << i
        amps |= (amplitude - 1) << (3 * i)
    return _effect(0x26, active & 0xFF, (active >> 8) & 0xFF,
                   amps & 0xFF, (amps >> 8) & 0xFF, (amps >> 16) & 0xFF, (amps >> 24) & 0xFF, 0, 0, frequency)


# Older "simple" raw modes (pydualsense / DualSenseX). UNCERTAIN: parameter order from community
# notes (Nielk1 Simple_Feedback: start, strength; Simple_Weapon: start, end, strength;
# Simple_Vibration: frequency, amplitude, start), values 0-255. Only used with --legacy-triggers.
def legacy_resistance(start, force):
    return _effect(0x01, start & 0xFF, force & 0xFF)


def legacy_section(start, end, force):
    return _effect(0x02, start & 0xFF, end & 0xFF, force & 0xFF)


def legacy_vibration(frequency, amplitude, start):
    return _effect(0x06, frequency & 0xFF, amplitude & 0xFF, start & 0xFF)


# --- Protocol trigger (4-bit values) -> effect --------------------------------------------

VIB_FREQS = (5, 8, 10, 13, 16, 20, 25, 30, 35, 40, 50, 60, 80, 100, 150, 200)  # force 0-15 -> Hz


def _zone(v):          # 0-15 -> zone 0-9
    return round(v * 9 / 15)


def _strength(v):      # 0-15 -> 1-8
    return 1 + round(v * 7 / 15)


def trigger_effect(t, legacy=False):
    """protocol.Trigger -> 11 effect bytes. Modes: docs/HELPER.md."""
    m = t.mode
    if m == 0:
        return effect_off()
    if legacy:
        b = lambda v: min(255, v * 17)  # noqa: E731  (0-15 -> 0-255)
        if m in (1, 5):
            return legacy_resistance(b(t.start), b(t.force))
        if m in (2, 3):
            return legacy_section(b(t.start), b(max(t.start, t.finish)), b(t.force))
        if m == 4:
            return legacy_vibration(VIB_FREQS[t.force], b(t.finish), b(t.start))
        return effect_off()
    if m == 1:
        return effect_feedback(_zone(t.start), _strength(t.force))
    if m == 2:
        a, z = sorted((_zone(t.start), _zone(t.finish)))
        return effect_multi_feedback([_strength(t.force) if a <= i <= z else 0 for i in range(10)])
    if m == 3:
        start = 2 + round(t.start * 5 / 15)
        end = max(start + 1, min(8, 2 + round(t.finish * 6 / 15)))
        return effect_weapon(start, end, _strength(t.force))
    if m == 4:
        return effect_vibration(_zone(t.start), _strength(t.finish), VIB_FREQS[t.force])
    if m == 5:
        start = min(_zone(t.start), 8)
        end = max(start + 1, _zone(t.finish))
        return effect_slope(start, end, 1, _strength(t.force))
    return effect_off()


# --- Output reports ---------------------------------------------------------------------------

def common_block(right=None, left=None):
    """The 47-byte common block: trigger bits and bytes only (None = leave that trigger alone)."""
    c = bytearray(COMMON_LEN)
    if right is not None:
        c[0] |= FLAG0_RIGHT_TRIGGER
        c[RIGHT_OFF:RIGHT_OFF + 11] = right
    if left is not None:
        c[0] |= FLAG0_LEFT_TRIGGER
        c[LEFT_OFF:LEFT_OFF + 11] = left
    return bytes(c)


def bt_crc(data):
    """CRC32 (zlib / IEEE) seeded with the 0xA2 'output' header byte (hid-playstation: crc32_le over
    the seed byte, then the report)."""
    return zlib.crc32(data, zlib.crc32(b"\xa2")) & 0xFFFFFFFF


def build_report(transport, right=None, left=None, seq=0, length=None):
    if transport == "usb":
        r = bytearray([USB_REPORT_ID]) + common_block(right, left)
        size = max(length or USB_LEN, len(r))
        return bytes(r + bytes(size - len(r)))
    r = bytearray(BT_LEN)
    r[0] = BT_REPORT_ID
    r[1] = (seq & 0x0F) << 4
    r[2] = BT_TAG
    r[3:3 + COMMON_LEN] = common_block(right, left)
    r[74:78] = bt_crc(bytes(r[:74])).to_bytes(4, "little")
    size = max(length or BT_LEN, BT_LEN)
    return bytes(r + bytes(size - BT_LEN))


# --- HID (Windows) -------------------------------------------------------------------------

class GUID(ctypes.Structure):
    _fields_ = [("Data1", wintypes.DWORD), ("Data2", wintypes.WORD), ("Data3", wintypes.WORD),
                ("Data4", ctypes.c_ubyte * 8)]


class SP_DEVICE_INTERFACE_DATA(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.DWORD), ("InterfaceClassGuid", GUID), ("Flags", wintypes.DWORD),
                ("Reserved", ctypes.c_size_t)]


class HIDD_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("Size", wintypes.ULONG), ("VendorID", wintypes.USHORT), ("ProductID", wintypes.USHORT),
                ("VersionNumber", wintypes.USHORT)]


class HIDP_CAPS(ctypes.Structure):
    _fields_ = [("Usage", wintypes.USHORT), ("UsagePage", wintypes.USHORT),
                ("InputReportByteLength", wintypes.USHORT), ("OutputReportByteLength", wintypes.USHORT),
                ("FeatureReportByteLength", wintypes.USHORT), ("Reserved", wintypes.USHORT * 17),
                ("Counts", wintypes.USHORT * 10)]


DIGCF_PRESENT, DIGCF_DEVICEINTERFACE = 0x02, 0x10
GENERIC_READ, GENERIC_WRITE = 0x80000000, 0x40000000
FILE_SHARE_READ, FILE_SHARE_WRITE = 0x1, 0x2
OPEN_EXISTING = 3
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
HIDP_STATUS_SUCCESS = 0x00110000

_libs = None


def _load():
    global _libs
    if _libs:
        return _libs
    setupapi = ctypes.WinDLL("setupapi", use_last_error=True)
    hid = ctypes.WinDLL("hid", use_last_error=True)
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    setupapi.SetupDiGetClassDevsW.argtypes = [ctypes.POINTER(GUID), wintypes.LPCWSTR, wintypes.HWND, wintypes.DWORD]
    setupapi.SetupDiGetClassDevsW.restype = wintypes.HANDLE
    setupapi.SetupDiEnumDeviceInterfaces.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.POINTER(GUID),
                                                     wintypes.DWORD, ctypes.POINTER(SP_DEVICE_INTERFACE_DATA)]
    setupapi.SetupDiGetDeviceInterfaceDetailW.argtypes = [wintypes.HANDLE, ctypes.POINTER(SP_DEVICE_INTERFACE_DATA),
                                                          ctypes.c_void_p, wintypes.DWORD,
                                                          ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    setupapi.SetupDiDestroyDeviceInfoList.argtypes = [wintypes.HANDLE]
    hid.HidD_GetHidGuid.argtypes = [ctypes.POINTER(GUID)]
    hid.HidD_GetAttributes.argtypes = [wintypes.HANDLE, ctypes.POINTER(HIDD_ATTRIBUTES)]
    hid.HidD_GetPreparsedData.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_void_p)]
    hid.HidD_FreePreparsedData.argtypes = [ctypes.c_void_p]
    hid.HidP_GetCaps.argtypes = [ctypes.c_void_p, ctypes.POINTER(HIDP_CAPS)]
    hid.HidP_GetCaps.restype = ctypes.c_long
    hid.HidD_GetProductString.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.ULONG]
    k32.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
                                wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    k32.CreateFileW.restype = wintypes.HANDLE
    k32.WriteFile.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD),
                              ctypes.c_void_p]
    k32.CloseHandle.argtypes = [wintypes.HANDLE]
    _libs = (setupapi, hid, k32)
    return _libs


def _hid_paths():
    setupapi, hid, _ = _load()
    guid = GUID()
    hid.HidD_GetHidGuid(ctypes.byref(guid))
    devs = setupapi.SetupDiGetClassDevsW(ctypes.byref(guid), None, None, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE)
    if devs == INVALID_HANDLE_VALUE:
        return []
    paths = []
    try:
        i = 0
        while True:
            data = SP_DEVICE_INTERFACE_DATA()
            data.cbSize = ctypes.sizeof(SP_DEVICE_INTERFACE_DATA)
            if not setupapi.SetupDiEnumDeviceInterfaces(devs, None, ctypes.byref(guid), i, ctypes.byref(data)):
                break
            i += 1
            need = wintypes.DWORD()
            setupapi.SetupDiGetDeviceInterfaceDetailW(devs, ctypes.byref(data), None, 0, ctypes.byref(need), None)
            if not need.value:
                continue
            buf = ctypes.create_string_buffer(need.value)
            # SP_DEVICE_INTERFACE_DETAIL_DATA_W.cbSize: 8 on 64-bit, 6 on 32-bit (DWORD + one WCHAR, packed)
            ctypes.cast(buf, ctypes.POINTER(wintypes.DWORD))[0] = 8 if ctypes.sizeof(ctypes.c_void_p) == 8 else 6
            if setupapi.SetupDiGetDeviceInterfaceDetailW(devs, ctypes.byref(data), buf, need, None, None):
                paths.append(ctypes.wstring_at(ctypes.addressof(buf) + 4))
    finally:
        setupapi.SetupDiDestroyDeviceInfoList(devs)
    return paths


def _open(path, access):
    _, _, k32 = _load()
    h = k32.CreateFileW(path, access, FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING, 0, None)
    return None if h in (None, INVALID_HANDLE_VALUE) else h


def find_dualsenses():
    """[{path, name, vid, pid, transport, out_len, in_len}] without writing anything (opened with no access)."""
    _, hid, k32 = _load()
    found = []
    for path in _hid_paths():
        low = path.lower()
        if "054c" not in low:   # Sony (USB: vid_054c, Bluetooth: vid&0002054c)
            continue
        h = _open(path, 0)
        if not h:
            continue
        try:
            attr = HIDD_ATTRIBUTES()
            attr.Size = ctypes.sizeof(HIDD_ATTRIBUTES)
            if not hid.HidD_GetAttributes(h, ctypes.byref(attr)):
                continue
            if attr.VendorID != VID_SONY or attr.ProductID not in PIDS:
                continue
            caps = HIDP_CAPS()
            pre = ctypes.c_void_p()
            if hid.HidD_GetPreparsedData(h, ctypes.byref(pre)):
                ok = hid.HidP_GetCaps(pre, ctypes.byref(caps)) == HIDP_STATUS_SUCCESS
                hid.HidD_FreePreparsedData(pre)
                if not ok:
                    continue
            if caps.UsagePage != 0x01 or caps.Usage != 0x05:   # the game pad collection only
                continue
            # USB: 64-byte output report (0x02). Bluetooth: larger (0x31, 78, or more on Windows).
            # UNCERTAIN: the exact Bluetooth length Windows reports; anything over 64 counts as Bluetooth.
            transport = "usb" if caps.OutputReportByteLength <= USB_LEN else "bt"
            found.append(dict(path=path, name=PIDS[attr.ProductID], vid=attr.VendorID, pid=attr.ProductID,
                              transport=transport, out_len=caps.OutputReportByteLength,
                              in_len=caps.InputReportByteLength))
        finally:
            k32.CloseHandle(h)
    return found


class Pad:
    """One DualSense opened shared read/write; writes trigger-only output reports."""

    def __init__(self, info, transport=None):
        self.info = info
        self.transport = transport or info["transport"]
        self.length = info["out_len"]
        self.seq = 0
        self.handle = _open(info["path"], GENERIC_READ | GENERIC_WRITE)
        if not self.handle:
            raise OSError(f"cannot open {info['path']} (error {ctypes.get_last_error()})")

    def send(self, right=None, left=None):
        _, _, k32 = _load()
        report = build_report(self.transport, right, left, self.seq, self.length)
        self.seq = (self.seq + 1) & 0x0F
        written = wintypes.DWORD()
        buf = ctypes.create_string_buffer(report, len(report))
        if not k32.WriteFile(self.handle, buf, len(report), ctypes.byref(written), None):
            raise OSError(f"write failed (error {ctypes.get_last_error()})")

    def close(self):
        if self.handle:
            _load()[2].CloseHandle(self.handle)
            self.handle = None


class TriggerOutput:
    """Holds the wanted effects; writes only on change and at most every `interval` seconds."""

    def __init__(self, pad, legacy=False, interval=0.020, log=None):
        self.pad, self.legacy, self.interval, self.log = pad, legacy, interval, log
        self.wanted = (effect_off(), effect_off())   # (left, right)
        self.sent = None
        self.last = float("-inf")

    def set(self, left, right):
        self.wanted = (trigger_effect(left, self.legacy), trigger_effect(right, self.legacy))

    def tick(self, now=None):
        now = time.perf_counter() if now is None else now
        if self.wanted == self.sent or now - self.last < self.interval:
            return False
        left, right = self.wanted
        if self.pad:
            self.pad.send(right=right, left=left)
        self.sent, self.last = self.wanted, now
        if self.log:
            self.log(f"triggers L {left.hex(' ')} | R {right.hex(' ')}")
        return True

    def reset(self):
        """Both triggers off (0x05), now."""
        wait = self.interval - (time.perf_counter() - self.last)
        if wait > 0:
            time.sleep(wait)
        self.wanted = (effect_off(), effect_off())
        self.sent = None
        self.last = float("-inf")
        self.tick()
