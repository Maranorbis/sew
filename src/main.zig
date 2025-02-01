const std = @import("std");
const Cli = @import("Cli.zig");

const argsAlloc = std.process.argsAlloc;
const argsFree = std.process.argsFree;

fn app_handler() void {
    std.io.getStdOut().writer().writeAll("Sew") catch return;
}

fn app_help() void {
    std.io.getStdOut().writer().writeAll(
        \\Sew, manage your symlinks effortlessly
    ) catch return;
}

const SubCommands = enum {
    link,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected");
        }
    }

    const app = Cli.App(SubCommands).init("sew", &app_help, &app_handler, .{
        Cli.Command(SubCommands).init(.link, &app_help, &app_handler),
    });

    app.run();
}
