const std = @import("std");
const Io = std.Io;
const mt = @import("mt");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Stdout is buffered; remember to flush before returning.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    try stdout.print("mt {s} — minimalistic translator\n", .{mt.version});
    try stdout.flush();
}
