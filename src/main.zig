const std = @import("std");
const Cli = @import("Cli.zig");

const argsAlloc = std.process.argsAlloc;
const argsFree = std.process.argsFree;

const APP_NAME = "sew";
const APP_HELP =
    \\Manage your symlinks/shortcuts via a single file.
;

fn app_handler(context: *Cli.CliContext) void {
    std.debug.print("Args count: {d}\n", .{context.os_args.len});
    for (context.os_args) |arg| {
        std.debug.print("Arg {s}\n", .{arg});
    }
}

fn link_handler(context: *Cli.CliContext) void {
    std.debug.print("Link Args count: {d}\n", .{context.os_args.len});
    for (context.os_args) |arg| {
        std.debug.print("Arg {s}\n", .{arg});
    }
}

fn unlink_handler(context: *Cli.CliContext) void {
    std.debug.print("Unlink Args count: {d}\n", .{context.os_args.len});
    for (context.os_args) |arg| {
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

    const app = Cli.init(
        .{
            .name = APP_NAME,
            .help = APP_HELP,
            .handler = &app_handler,
            .sub_commands = &[_]Cli.Command{
                Cli.Command.init(.{
                    .name = "link",
                    .help = "Create symlinks relative to the current directory config",
                    .handler = &link_handler,
                }),
                Cli.Command.init(.{
                    .name = "unlink",
                    .help = "Removes symlinks relative to the current directory config",
                    .handler = &unlink_handler,
                }),
            },
        },
    );

    const allocator = gpa.allocator();

    var osArgs = try argsAlloc(allocator);
    defer argsFree(allocator, osArgs);

    var res = Cli.CliContext.init(osArgs[1..]);
    defer res.deinit();

    const stdout = std.io.getStdOut().writer();
    Cli.run(&app, &res) catch |e| switch (e) {
        error.InvalidCommand => {
            try std.fmt.format(stdout, "Invalid command\n\n", .{});
            try app.display_help(stdout);
        },

        else => try std.fmt.format(stdout, "Something went wrong: {s}", .{@errorName(e)}),
    };
}
