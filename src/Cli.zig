const std = @import("std");
const log = std.log.scoped(.Cli);

const Allocator = std.mem.Allocator;

pub const OSArgs = []const [:0]u8;
pub const Handler = *const fn (*CliContext) void;

pub const FlagError = error{InvalidShortOrLongName};
pub const CommandError = error{InvalidName};
pub const CliError = CommandError || FlagError || error{
    FatalUnknown,
    OutOfMemory,
};

pub const CommandContext = struct {
    name: []const u8,
    help: []const u8,
    handler: Handler,
};

/// App is just a namespace and wrapper for `Command` struct.
///
/// `_internal` field represents the root command.
///
/// **Note**: **DO NOT** interact with the `_internal` field directly, instead use the provided builtin functions
/// for creating, managing and operating the instance of `App` struct.
pub const App = struct {
    _internal: Command,

    const Self = @This();

    pub fn init(comptime name: []const u8, comptime help: []const u8, comptime handler: Handler) Self {
        return .{
            ._internal = Command.init(.{
                .name = name,
                .help = help,
                .handler = handler,
            }),
        };
    }

    pub fn run(self: *const Self, cliContext: *CliContext) void {
        self._internal.run(cliContext);
    }

    pub fn display_help(self: *const Self, writer: anytype) void {
        self._internal.display_help(writer);
    }
};

pub const Command = struct {
    context: CommandContext,

    const Self = @This();

    pub fn init(comptime context: CommandContext) Self {
        return .{ .context = context };
    }

    pub fn run(self: *const Self, cliContext: *CliContext) void {
        self.context.handler(cliContext);
    }

    pub fn display_help(self: *const Self, writer: anytype) void {
        writer.writeAll(self.context.help ++ "\n");
    }
};

pub const CliContext = struct {
    osArgs: OSArgs,

    const Self = @This();

    pub fn init(osArgs: OSArgs) Self {
        return .{ .osArgs = osArgs };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
