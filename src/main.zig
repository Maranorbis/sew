const std = @import("std");
const Cli = @import("Cli.zig");

const argsAlloc = std.process.argsAlloc;
const argsFree = std.process.argsFree;

const APP_NAME = "sew";
const APP_HELP =
    \\ Manage your symlinks/shortcuts via a single file.
;

fn app_handler(context: *Cli.CliContext) void {
    std.debug.print("Args count: {d}\n", .{context.osArgs.len});
    for (context.osArgs) |arg| {
        std.debug.print("Arg {s}\n", .{arg});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected");
        }
    }
    const app = Cli.App.init(APP_NAME, APP_HELP, &app_handler);
    const allocator = gpa.allocator();

    var osArgs = try argsAlloc(allocator);
    defer argsFree(allocator, osArgs);

    var res = Cli.CliContext.init(osArgs[1..]);
    defer res.deinit();

    app.run(&res);
}
