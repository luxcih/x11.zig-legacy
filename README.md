# x11.zig

A native, low-level X11 client library written in Zig.

x11.zig provides direct access to the X11 protocol without depending on a C
X11 client library. The API stays explicit: construct protocol requests,
encode them, send them through a connection, and parse the server's responses
and events.

## Status

Early development. The public API is intentionally taking shape, and breaking
changes may still happen.

## Features

Currently implemented:

- Local X11 connections through Unix-domain sockets
- X11 setup handshake and server information parsing
- Display parsing
- XID resource allocation
- Window creation, configuration, mapping, and attributes
- Graphics contexts
- Drawing primitives, including lines, rectangles, arcs, filled shapes, and text
- Basic X11 event parsing
- Focused examples and a complete interactive demo

## Requirements

- Zig 0.16.0 or newer
- A running X11 server for the runtime examples

## Building

Run the library tests:

```sh
zig build test
```

Compile every example:

```sh
zig build check-examples
```

Build all examples:

```sh
zig build examples
```

Run the complete demo:

```sh
zig build example-demo
```

## Examples

The repository includes focused examples for individual parts of the library:

- `display` — parse X11 display names
- `setup` — connect and perform the X11 setup handshake
- `window` — create and configure a window
- `events` — receive and parse X11 events
- `gc` — create and modify graphics contexts
- `draw` — send drawing requests
- `redraw` — handle expose events and redraw content
- `demo` — a complete interactive example

## API

The public API is organized around the major parts of the X11 protocol:

```zig
const x11 = @import("x11");

const display = try x11.Display.parse(":0");

const setup = x11.Setup{};
const byte_order: x11.ByteOrder = setup.byte_order;
```

The main public namespaces include:

- `x11.Display`
- `x11.Connection`
- `x11.Setup`
- `x11.SetupResponse`
- `x11.SetupInfo`
- `x11.XidAllocator`
- `x11.Window`
- `x11.GC`
- `x11.Draw`
- `x11.Event`

## Goals

- Native Zig implementation
- Minimal dependencies
- Direct access to the X11 protocol
- Explicit, low-level abstractions
- A scalable architecture as more of the protocol is implemented

## Non-goals

At its current level, x11.zig is not intended to be a high-level GUI toolkit.
It does not try to hide the X11 protocol behind a widget or application
framework.

## License

A license has not been chosen yet.
