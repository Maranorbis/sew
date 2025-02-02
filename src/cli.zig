const std = @import("std");
const fmt = std.fmt;
const process = std.process;
const panic = std.debug.panic;

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const LookupMap = std.StaticStringMap(usize);
pub const LookupMapEntry = struct { []const u8, usize };

pub const FlagMap = std.StringHashMap([]const u8);
pub const FlagMapEntry = struct { []const u8, []const u8 };

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

                    entries[i] = LookupMapEntry{ cmd.get_name(), i };
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
                .options = options,
                .lookup_map = LookupMap.initComptime(cmd_entries),
                .flags = Set.initComptime(set_entries),
            };
        }

        pub fn get_name(self: *const Self) []const u8 {
            return std.enums.tagName(T, self.name).?;
        }

        pub fn get_command(self: *const Self, cmd: []const u8) CommandError!*const Command(T) {
            if (!self.lookup_map.has(cmd)) {
                return error.DoesNotExist;
            }

            const index = self.lookup_map.get(cmd).?;
            return &self.commands[index];
        }

        pub fn contains_flag(self: *const Self, name: []const u8) bool {
            return self.flags.has(name);
        }

        pub fn run(self: *const Self, allocator: Allocator, argIterator: *ArgIterator, stderr: anytype) void {
            var cmd = self;
            var parsed_flag_map = FlagMap.init(allocator);

            while (argIterator.next()) |arg| {
                if (arg_is_flag(arg)) {
                    const key, const value = blk: {
                        const separator_count = std.mem.count(u8, arg, Flag.SEPARATOR);
                        const prefix_count = std.mem.count(u8, arg, Flag.SHORT_PREFIX);

                        if (prefix_count < 1) {
                            fmt.format(
                                stderr,
                                "Malformed flag {s}, A flag should be prefixed with either `--` or `-`.\n",
                                .{arg},
                            ) catch |f| {
                                panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                            };
                            process.exit(1);
                        }

                        if (separator_count > 1) {
                            fmt.format(
                                stderr,
                                "Found `=` {d} times in {s}, A flag should only have at max a single separator.",
                                .{ separator_count, arg },
                            ) catch |f| {
                                panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                            };
                            process.exit(1);
                        }

                        var splitIter = std.mem.splitScalar(u8, arg, Flag.SEPARATOR[0]);
                        break :blk .{
                            splitIter.next().?,
                            splitIter.next() orelse "",
                        };
                    };

                    if (!self.contains_flag(key)) {
                        fmt.format(stderr, "Flag {s} does not exists for Command {s}", .{ key, self.get_name() }) catch |f| {
                            panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                        };
                        process.exit(1);
                    }

                    parsed_flag_map.put(key, value) catch {
                        fmt.format(stderr, "Allocator Error: Unable to parse provided flags.\n", .{}) catch |f| {
                            panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                        };
                        process.exit(1);
                    };
                } else {
                    if (parsed_flag_map.count() > 0) {
                        fmt.format(
                            stderr,
                            \\Invalid command format, flags and commands cannot be mixed in-between each other.
                            \\
                            \\Valid Usage:
                            \\
                            \\app cmd1 --foo=bar --bar=baz --baz=foo
                            \\app --foo=bar
                        ,
                            .{},
                        ) catch |f| {
                            panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                        };
                        process.exit(1);
                    }

                    cmd = cmd.get_command(arg) catch |e| switch (e) {
                        error.DoesNotExist => {
                            fmt.format(stderr, "Command {s} does not exist.\n", .{arg}) catch |f| {
                                panic("Something went wrong while writing to stderr.\nError: {s}\n", .{@errorName(f)});
                            };
                            process.exit(1);
                        },
                    };
                }
            }

            cmd.handler(Context(T).init(cmd, &cmd.commands, &parsed_flag_map, &cmd.lookup_map));
        }
    };
}

pub fn Context(comptime T: type) type {
    return struct {
        parent: *const Command(T),
        commands: *const []const Command(T),
        flags: *FlagMap,
        lookup_map: *const LookupMap,

        const Self = @This();

        pub fn init(
            parent: *const Command(T),
            commands: *const []const Command(T),
            flags: *FlagMap,
            lookup_map: *const LookupMap,
        ) Self {
            return .{
                .parent = parent,
                .commands = commands,
                .flags = flags,
                .lookup_map = lookup_map,
            };
        }

        pub fn deinit(self: *const Self) void {
            self.flags.deinit();
        }
    };
}

pub const Flag = struct {
    const SEPARATOR = "=";
    const LONG_PREFIX = "--";
    const SHORT_PREFIX = "-";
};

fn arg_is_flag(arg: []const u8) bool {
    return std.mem.startsWith(u8, arg, Flag.LONG_PREFIX) or std.mem.startsWith(u8, arg, Flag.SHORT_PREFIX);
}
