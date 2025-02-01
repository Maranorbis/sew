const std = @import("std");
const Cli = @import("Cli.zig");

fn app_handler(app: *const Cli.App(AppCommand), cmd: []const u8) void {
    const sub_cmd: AppCommand = std.meta.stringToEnum(AppCommand, cmd) orelse {
        std.fmt.format(std.io.getStdOut().writer(), "Command {s} does not exist.\n", .{cmd}) catch {
            std.process.exit(1);
        };
        app.help();
        std.process.exit(1);
    };

    switch (sub_cmd) {
        .link => app.execute(sub_cmd),
    }
}

fn app_help() void {
    std.io.getStdOut().writer().writeAll(
        \\Sew, manage your symlinks effortlessly
    ) catch return;
}

const AppCommand = enum {
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

    const app = Cli.App(AppCommand).init(&app_help, &app_handler, .{
        Cli.Command(AppCommand).init(.link, &app_help, &app_help),
    });

    var it = try std.process.argsWithAllocator(gpa.allocator());
    defer it.deinit();

    _ = it.skip();

    app.run(&it);
}
