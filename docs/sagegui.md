# SageGUI Specification

> **Version:** 0.1.0 · **Component:** gui/ · **Related:** [architecture.md](architecture.md)

SageGUI is the native graphical environment of SagePocket: a desktop, window
manager, widget toolkit, and graphics library targeting the 172×320
ST7789V3 display. It is implemented in Sage and rendered through the
SageGraphics engine.

---

## 1. Display and Framebuffer

```text
Resolution:  172 × 320
Format:      RGB565
Full frame:  172 × 320 × 2 = 110,080 bytes ≈ 107.5 KiB
```

A full framebuffer is a significant fraction of the 520 KB SRAM. Rendering
modes:

```text
full framebuffer        optional
1/3 framebuffer         default GUI mode
small dirty rectangles  low-memory mode
```

Source layout:

```text
gui/
├── framebuffer.sage  Partial/tiled framebuffer management
├── graphics.sage     SageGraphics primitives
├── font.sage         Text rendering, .sfont assets
├── widgets.sage      Widget library
├── window.sage       Window management
├── menu.sage         Menus and popups
├── shell_ui.sage     Terminal-style UI views
└── desktop.sage      Desktop, taskbar, status bar
```

## 2. SageGraphics

Primitive set:

```text
pixel()
line()
rectangle()
fill_rectangle()
circle()
triangle()
bitmap()
sprite()
text()
image()
scroll()
```

Pixel formats:

```text
RGB565            primary display format
1-bit bitmap
4-bit indexed bitmap
8-bit indexed bitmap
```

Later: alpha blending, clipping, dirty rectangles, hardware-assisted
transfers, DMA.

## 3. Widget Library

```text
Window
Panel
Button
Label
TextBox
List
Menu
Dialog
Slider
ProgressBar
Icon
Canvas
StatusBar
Terminal
```

## 4. Desktop

Default screen:

```text
┌─────────────────────────────┐
│ SAGEOS              19:35   │
├─────────────────────────────┤
│                             │
│  [ Terminal ]  [ Files ]    │
│                             │
│  [ Monitor  ]  [ Apps  ]    │
│                             │
│  [ Games    ]  [ Settings ] │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│ CPU  12%  MEM 84K  SD 2GB   │
└─────────────────────────────┘
```

The status bar additionally shows temperature, task count, and VM state
as available.

## 5. GUI API

Applications interact with a declarative, event-driven API:

```text
window = gui.window("Calculator")

button = window.button("7")
button.on_click(...)
```

The API compiles to SageVM operations; widget events dispatch through the
VM syscall interface (`SYS_DISPLAY`, `SYS_INPUT`).

## 6. Windows and Menus

- Window stack with focus management
- Move, close, minimize (title-bar drag)
- Menus with keyboard and (future) touch input
- Dialogs for confirmations and file operations

## 7. Input Model

Initial input is limited (no touch controller on the base board):

```text
USB keyboard (HID)      primary
USB serial shell        text alternative
future touch adapter    via input abstraction
```

The input abstraction is designed so a touch layer can be added later
without changing widgets or the desktop.

## 8. Terminal Widget

The `Terminal` widget renders SageShell (see [sageos.md](sageos.md) §13 /
applications): command history, cursor navigation, scrollback, basic ANSI
escape sequences, colored text. Multiple virtual terminals are supported.

## 9. Assets

Sage-native asset formats (see [applications.md](applications.md) §8):

```text
.simg    image
.sfont   font
.sicon   icon
.sanim   animation
```

Host tools convert PNG → .simg, TTF → .sfont, SVG → .simg.

## 10. Performance

GUI target: **30+ FPS**.

Techniques:

- Partial/tiled rendering by default
- Dirty-rectangle invalidation in low-memory mode
- DMA transfers when available
- No full-framebuffer allocation unless memory profile proves it worthwhile

## 11. Definitions of Done

### SagePocket 0.5 milestone

- [ ] Desktop boots directly into a graphical environment
- [ ] Windows, widgets, menus, and icons functional
- [ ] File manager runs in GUI
- [ ] GUI target of 30+ FPS met on the board

Related docs: [architecture.md](architecture.md), [sageos.md](sageos.md),
[applications.md](applications.md), [drivers.md](drivers.md).