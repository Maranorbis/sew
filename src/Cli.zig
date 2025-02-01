const std = @import("std");
const meta = std.meta;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const Handler = *const fn () void;
const HelpFunc = *const fn () void;

pub fn App(comptime T: type) type {
    return struct {
        name: []const u8,
        help: HelpFunc,
        handler: Handler,
        sub_commands: []const Command(T) = undefined,

        const Self = @This();

        pub fn init(
            comptime name: []const u8,
            comptime help: HelpFunc,
            comptime handler: Handler,
            comptime sub_commands: anytype,
        ) Self {
            if (@typeInfo(T) == .Void) {
                return .{
                    .name = name,
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

            const sub_commands_arr = comptime blk: {
                const length = sub_commands_type.Struct.fields.len;
                var cmd_arr: [length]Command(T) = undefined;

                for (sub_commands_type.Struct.fields, 0..) |sub, i| {
                    cmd_arr[i] = @field(sub_commands, sub.name);
                }

                break :blk cmd_arr;
            };

            return .{
                .name = name,
                .help = help,
                .handler = handler,
                .sub_commands = sub_commands_arr[0..],
            };
        }

        pub fn run(self: *const Self) void {
            self.handler();
        }
    };
}

pub fn Command(comptime T: type) type {
    return struct {
        name: T,
        help: HelpFunc,
        handler: Handler,
        sub_commands: []const Command(T) = undefined,

        const Self = @This();

        pub fn init(
            comptime name: T,
            comptime help: HelpFunc,
            comptime handler: Handler,
            comptime sub_commands: anytype,
        ) Self {
            if (@typeInfo(T) == .Void) {
                return .{
                    .name = name,
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

            const sub_commands_arr = comptime blk: {
                const length = sub_commands_type.Struct.fields.len;
                var cmd_arr: [length]Command(T) = undefined;

                for (sub_commands_type.Struct.fields, 0..) |sub, i| {
                    cmd_arr[i] = @field(sub_commands, sub.name);
                }

                break :blk cmd_arr;
            };

            return .{
                .name = name,
                .help = help,
                .handler = handler,
                .sub_commands = sub_commands_arr[0..],
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
