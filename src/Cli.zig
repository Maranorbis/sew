const std = @import("std");
const meta = std.meta;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const HelpFunc = *const fn () void;
pub const CmdFunc = *const fn () void;
pub const LookupMap = std.StaticStringMap(usize);
pub const LookupMapEntry = struct { []const u8, usize };

pub fn App(comptime T: type) type {
    return struct {
        help: HelpFunc,
        handler: *const fn (*const @This(), []const u8) void,
        commands: []const Command(T) = undefined,
        _cmd_lookup_map: LookupMap = undefined,

        const Self = @This();

        pub fn init(
            comptime help: HelpFunc,
            comptime handler: *const fn (*const @This(), []const u8) void,
            comptime sub_commands: anytype,
        ) Self {
            if (@typeInfo(T) == .Void) {
                return .{
                    .help = help,
                    .handler = handler,
                };
            }

            if (@typeInfo(T) != .Enum) {
                @compileError("Expected App(T) to be an enum, got App(" ++ @typeName(@TypeOf(T)) ++ ")");
            }

            const sub_commands_type = @typeInfo(@TypeOf(sub_commands));
            if (!sub_commands_type.Struct.is_tuple) {
                @compileError("Expected subcommands to be of type tuple, got " ++ @typeName(@TypeOf(sub_commands)));
            }

            const length = sub_commands_type.Struct.fields.len;
            const cmd_arr = comptime blk: {
                var arr: [length]Command(T) = undefined;

                for (sub_commands_type.Struct.fields, 0..) |sub, i| {
                    arr[i] = @field(sub_commands, sub.name);
                }

                break :blk arr;
            };

            const cmd_entries = comptime blk: {
                var arr: [length]LookupMapEntry = undefined;

                for (cmd_arr, 0..) |cmd, i| {
                    const key = std.enums.tagName(T, cmd.name);
                    if (key == null) {
                        @compileError("Got null while converting enum to string, " ++ @typeInfo(@TypeOf(cmd)));
                    }

                    arr[i] = LookupMapEntry{ key.?, i };
                }

                break :blk arr;
            };

            return .{
                .help = help,
                .handler = handler,
                .commands = cmd_arr[0..],
                ._cmd_lookup_map = LookupMap.initComptime(cmd_entries),
            };
        }

        pub fn execute(self: *const Self, cmd: T) void {
            const key = std.enums.tagName(T, cmd).?;

            self.get_command(key).handler();
        }

        pub fn get_command(self: *const Self, name: []const u8) *const Command(T) {
            const index = self._cmd_lookup_map.get(name);
            if (index == null) {
                std.fmt.format(std.io.getStdOut().writer(), "Command {s} does not exist.\n", .{name}) catch {
                    std.process.exit(1);
                };
                std.process.exit(1);
            }

            return &self.commands[index.?];
        }

        pub fn run(self: *const Self, argIterator: *ArgIterator) void {
            const arg = argIterator.next() orelse {
                self.help();
                std.process.exit(1);
            };
            self.handler(self, arg);
        }
    };
}

pub fn Command(comptime T: type) type {
    return struct {
        name: T,
        help: HelpFunc,
        handler: CmdFunc,

        const Self = @This();

        pub fn init(
            comptime name: T,
            comptime help: HelpFunc,
            comptime handler: CmdFunc,
        ) Self {
            return .{
                .name = name,
                .help = help,
                .handler = handler,
            };
        }

        pub fn run(self: *const Self) void {
            self.handler();
        }

        pub fn get_name(self: *const Self) []const u8 {
            return std.enums.tagName(@TypeOf(self.name), self.name) orelse
                panic("Unable to get the tag name for command {any}, Command Enums should be exhaustive.\n", .{self.name});
        }
    };
}
