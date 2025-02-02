const std = @import("std");
const Cli = @import("Cli.zig");

const SubCommand = enum { sew, link, unlink, help };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected");
        }
    }

    const app = Cli.Command(SubCommand).init(.sew, &handler, .{
        Cli.Command(SubCommand).init(.link, &linkHandler, .{}),
        Cli.Command(SubCommand).init(.unlink, &unlinkHandler, .{}),
    });

    var it = try std.process.argsWithAllocator(gpa.allocator());
    _ = it.skip();

    const stderr = std.io.getStdErr().writer();
    app.run(&it, stderr);
}

fn handler(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from {s}", .{context.parent.get_name() orelse ""});
}

fn linkHandler(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from {s}", .{context.parent.get_name() orelse ""});
}

fn linkHelp(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from link {s}", .{context.parent.get_name() orelse ""});
}

fn unlinkHandler(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from {s}", .{context.parent.get_name() orelse ""});
}
