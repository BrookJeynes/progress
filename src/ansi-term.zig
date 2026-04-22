// MIT License
//
// Copyright (c) 2019 joachimschmidt557
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Repo: https://github.com/ziglibs/ansi-term

const std = @import("std");

pub const RGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Colour = union(enum) {
    Default,
    Black,
    White,
    Red,
    Green,
    Blue,
    Yellow,
    Magenta,
    Cyan,
    Fixed: u8,
    Grey: u8,
    RGB: RGB,
};

const esc = "\x1B";
const csi = esc ++ "[";
const reset = csi ++ "0m";

pub fn clearCurrentLine(writer: anytype) !void {
    try writer.writeAll(csi ++ "2K");
}

pub fn hideCursor(writer: anytype) !void {
    try writer.writeAll(csi ++ "?25l");
}

pub fn showCursor(writer: anytype) !void {
    try writer.writeAll(csi ++ "?25h");
}

pub fn setCursorColumn(writer: anytype, column: usize) !void {
    try writer.print(csi ++ "{d}G", .{column});
}

pub fn cursorForward(writer: anytype, columns: usize) !void {
    try writer.print(csi ++ "{d}C", .{columns});
}

pub fn writeColour(writer: anytype, colour: Colour) !void {
    try writer.writeAll(csi);
    switch (colour) {
        .Default => try writer.writeAll("39"),
        .Black => try writer.writeAll("30"),
        .Red => try writer.writeAll("31"),
        .Green => try writer.writeAll("32"),
        .Yellow => try writer.writeAll("33"),
        .Blue => try writer.writeAll("34"),
        .Magenta => try writer.writeAll("35"),
        .Cyan => try writer.writeAll("36"),
        .White => try writer.writeAll("37"),
        .Fixed => |fixed| try writer.print("48;5;{}", .{fixed}),
        .Grey => |grey| try writer.print("48;2;{};{};{}", .{ grey, grey, grey }),
        .RGB => |rgb| try writer.print("38;2;{};{};{}", .{ rgb.r, rgb.g, rgb.b }),
    }
    try writer.writeAll("m");
}

pub fn resetColour(writer: anytype) !void {
    try writer.writeAll(reset);
}
