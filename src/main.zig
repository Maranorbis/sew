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
    const allocator = gpa.allocator();

    const app = Cli.Command(SubCommand).init(.sew, &handler,
        \\--test   -t  example for testing flag support
        \\
    , .{
        Cli.Command(SubCommand).init(.link, &linkHandler, "", .{}),
        Cli.Command(SubCommand).init(.unlink, &unlinkHandler, "", .{}),
    });

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.skip();

    const stderr = std.io.getStdErr().writer();
    app.run(allocator, &it, stderr);
}

fn handler(context: Cli.Context(SubCommand)) void {
    defer context.deinit();
    std.debug.print("Hello from {s}\n", .{context.parent.get_name()});

    var it = context.flags.iterator();
    while (it.next()) |entry| {
        std.debug.print("Key: {s}, Value: {s}", .{
            entry.key_ptr.*,
            entry.value_ptr.*,
        });
    }
}

fn linkHandler(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from {s}", .{context.parent.get_name()});
}

fn linkHelp(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from link {s}", .{context.parent.get_name()});
}

fn unlinkHandler(context: Cli.Context(SubCommand)) void {
    std.debug.print("Hello from {s}", .{context.parent.get_name()});
}
