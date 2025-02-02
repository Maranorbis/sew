const std = @import("std");
const fmt = std.fmt;
const process = std.process;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const LookupMap = std.StaticStringMap(usize);
pub const LookupMapEntry = struct { []const u8, usize };

pub const Set = std.StaticStringMap(void);
pub const SetEntry = struct { []const u8 };

pub const CommandError = error{DoesNotExist};

pub fn Command(comptime T: type) type {
    return struct {
        name: T,
        handler: *const fn (Context(T)) void,
        commands: []const Command(T) = undefined,
        lookup_map: LookupMap = undefined,
        options: []const u8 = "",
        flags: Set = undefined,

        const Self = @This();

        pub fn init(
            comptime name: T,
            comptime handler: *const fn (Context(T)) void,
            comptime options: []const u8,
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
            const cmd_arr, const cmd_entries = comptime blk: {
                var arr: [length]Command(T) = undefined;
                var entries: [length]LookupMapEntry = undefined;

                for (commands_type.Struct.fields, 0..) |sub, i| {
                    const cmd = @field(commands, sub.name);
                    arr[i] = cmd;

                    const key = cmd.get_name() orelse
                        @compileError("Got null while converting enum to string, " ++ @typeInfo(@TypeOf(cmd)));
                    entries[i] = LookupMapEntry{ key, i };
                }

                break :blk .{ arr, entries };
            };

            const set_entries = comptime blk: {
                const options_count = std.mem.count(u8, options, "\n");

                var arr: [options_count * 2]SetEntry = undefined;
                var index = 0;

                var lineIter = std.mem.splitScalar(u8, options, '\n');
                while (lineIter.next()) |line| {
                    if (line.len < 1) continue;

                    var tokenIter = std.mem.tokenizeScalar(u8, line, ' ');

                    var i = index;
                    while (tokenIter.next()) |token| : ({
                        i += 1;
                    }) {
                        if (i > 1) break;
                        arr[i] = .{token};
                    }

                    index += 2;
                }

                break :blk arr;
            };

            return .{
                .name = name,
                .handler = handler,
                .commands = cmd_arr[0..],
                .lookup_map = LookupMap.initComptime(cmd_entries),
                .options = options,
                .flags = Set.initComptime(set_entries),
            };
        }

        pub fn run(self: *const Self, argIterator: *ArgIterator, stderr: anytype) void {
            var cmd = self;

            while (argIterator.next()) |arg| {
                cmd = cmd.get_command(arg) catch |e| switch (e) {
                    error.DoesNotExist => {
                        fmt.format(stderr, "Command {s} does not exist.\n", .{arg}) catch |f| {
                            panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                        };
                        process.exit(1);
                    },
                };
            }

            cmd.handler(Context(T).init(cmd, &cmd.commands, &cmd.flags, &cmd.lookup_map));
        }

        pub fn get_name(self: *const Self) ?[]const u8 {
            return std.enums.tagName(T, self.name);
        }

        pub fn get_command(self: *const Self, cmd: []const u8) CommandError!*const Command(T) {
            if (!self.lookup_map.has(cmd)) {
                return error.DoesNotExist;
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
        flags: *const Set,
        lookup_map: *const LookupMap,

        const Self = @This();

        pub fn init(
            parent: *const Command(T),
            commands: *const []const Command(T),
            flags: *const Set,
            lookup_map: *const LookupMap,
        ) Self {
            return .{
                .parent = parent,
                .commands = commands,
                .flags = flags,
                .lookup_map = lookup_map,
            };
        }
    };
}
