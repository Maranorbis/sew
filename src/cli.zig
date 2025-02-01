const std = @import("std");
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const LookupMap = std.StaticStringMap(usize);
pub const LookupMapEntry = struct { []const u8, usize };

pub fn Command(comptime T: type) type {
    return struct {
        name: T,
        handler: *const fn (Context(T)) void,
        commands: []const Command(T) = undefined,
        lookup_map: LookupMap = undefined,

        const Self = @This();

        pub fn init(
            comptime name: T,
            comptime handler: *const fn (Context(T)) void,
            comptime commands: anytype,
        ) Self {
            if (@typeInfo(T) != .Enum) {
                @compileError("Expected Command(T) to be an enum, got Command(" ++ @typeName(@TypeOf(T)) ++ ")");
            }

            const commands_type = @typeInfo(@TypeOf(commands));
            if (!commands_type.Struct.is_tuple) {
                @compileError("Expected commands to be of type tuple, got " ++ @typeName(@TypeOf(commands)));
            }

            const length = commands_type.Struct.fields.len;
            const cmd_arr = comptime blk: {
                var arr: [length]Command(T) = undefined;

                for (commands_type.Struct.fields, 0..) |sub, i| {
                    arr[i] = @field(commands, sub.name);
                }

                break :blk arr;
            };

            const cmd_entries = comptime blk: {
                var arr: [length]LookupMapEntry = undefined;

                for (cmd_arr, 0..) |cmd, i| {
                    const key = cmd.get_name() orelse
                        @compileError("Got null while converting enum to string, " ++ @typeInfo(@TypeOf(cmd)));

                    arr[i] = LookupMapEntry{ key, i };
                }

                break :blk arr;
            };

            return .{
                .name = name,
                .handler = handler,
                .commands = cmd_arr[0..],
                .lookup_map = LookupMap.initComptime(cmd_entries),
            };
        }

        pub fn run(self: *const Self, argIterator: *ArgIterator) !void {
            var cmd = self;

            while (argIterator.next()) |arg| {
                cmd = try cmd.get_command(arg);
            }

            cmd.handler(Context(T).init(cmd, &cmd.commands, &cmd.lookup_map));
        }

        pub fn get_name(self: *const Self) ?[]const u8 {
            return std.enums.tagName(T, self.name);
        }

        pub fn get_command(self: *const Self, cmd: []const u8) !*const Command(T) {
            if (!self.lookup_map.has(cmd)) {
                return error.CommandDoesNotExist;
            }

            const index = self.lookup_map.get(cmd).?;
            return &self.commands[index];
        }
    };
}

pub fn Context(comptime T: type) type {
    return struct {
        parent: *const Command(T),
        commands: *const []const Command(T),
        lookup_map: *const LookupMap,

        const Self = @This();

        pub fn init(
            parent: *const Command(T),
            commands: *const []const Command(T),
            lookup_map: *const LookupMap,
        ) Self {
            return .{
                .parent = parent,
                .commands = commands,
                .lookup_map = lookup_map,
            };
        }
    };
}
