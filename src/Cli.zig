const std = @import("std");
const log = std.log.scoped(.Cli);

const Allocator = std.mem.Allocator;

pub const OSArgs = []const [:0]u8;
pub const Handler = *const fn (*CliContext) void;

pub const FlagError = error{InvalidFlag};
pub const CommandError = error{InvalidCommand};
pub const CliError = CommandError || FlagError || error{
    FatalUnknown,
    OutOfMemory,
};

pub const CommandContext = struct {
    name: []const u8,
    help: []const u8,
    handler: Handler,
    sub_commands: []const Command = undefined,
};

pub fn init(comptime context: CommandContext) Command {
    return Command.init(context);
}

pub fn run(cmd: *const Command, cliContext: *CliContext) !void {
    const first_arg = cliContext.os_args[0];

    // If the first argument is a flag then hand of the `CliContext` to App `Handler`.
    //
    // If not, an assumption is made and the argument is considered a sub_command.
    if (Flag.arg_is_flag(first_arg)) {
        cmd.run(cliContext);
        return;
    } else {
        // Match the first_arg with sub_command names
        for (cmd.context.sub_commands) |sub| {
            if (std.mem.eql(u8, sub.context.name, first_arg)) {
                // Mark CliContext to be a sub_command
                cliContext.is_subcommand = true;
                sub.run(cliContext);
                return;
            }
        }

        return CliError.InvalidCommand;
    }
}

pub const Command = struct {
    context: CommandContext,

    const Self = @This();

    pub fn init(comptime context: CommandContext) Self {
        return .{ .context = context };
    }

    pub fn run(self: *const Self, cliContext: *CliContext) void {
        self.context.handler(cliContext);
    }

    pub fn display_help(self: *const Self, writer: anytype) !void {
        try std.fmt.format(writer, "{s}\n", .{self.context.help});
    }
};

pub const CliContext = struct {
    os_args: OSArgs,
    is_subcommand: bool = false,

    const Self = @This();

    pub fn init(osArgs: OSArgs) Self {
        return .{ .os_args = osArgs };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

pub const Flag = struct {
    const PREFIX = '-';
    const SEPARATOR = '=';

    pub fn arg_is_flag(arg: []const u8) bool {
        // Arg can be a short flag ie: -s, -t and etc
        if (arg.len < 3) {
            return arg[0] == PREFIX and std.ascii.isAlphabetic(arg[1]);
        }

        // We skip the check for 2nd character, because short flag is covered by our check above.
        //
        // if arg is not a short flag, we assume that it must be a long flag instead.
        // since long flags are prefix with two characters of special indentifiers, we check first and
        // third character to ensure that arg starts with the special identifier and third character
        // is an alphabet, which is the beginning of the actual flag key(property).
        return arg[0] == PREFIX and std.ascii.isAlphabetic(arg[3]);
    }
};
