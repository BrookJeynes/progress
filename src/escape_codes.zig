const std = @import("std");

const esc = "\x1B";
const csi = esc ++ "[";

pub fn clearCurrentLine(writer: anytype) !void {
    try writer.writeAll(csi ++ "2K");
}

pub fn hideCursor(writer: anytype) !void {
    try writer.writeAll(csi ++ "?25l");
}

pub fn setCursorColumn(writer: anytype, column: usize) !void {
    try writer.print(csi ++ "{d}G", .{column});
}

pub fn cursorForward(writer: anytype, columns: usize) !void {
    try writer.print(csi ++ "{d}C", .{columns});
}
