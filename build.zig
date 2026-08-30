const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const x11 = b.addModule("x11", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = x11,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const example_names = [_][]const u8{
        "display",
        "setup",
        "window",
        "events",
        "get_geometry",
        "get_window_attributes",
        "query_tree",
        "get_input_focus",
        "query_pointer",
        "gc",
        "draw",
        "redraw",
        "demo",
        "list_properties",
        "intern_atom",
        "get_atom_name",
    };

    const check_examples = b.step(
        "check-examples",
        "Compile all examples",
    );

    for (example_names) |name| {
        addExample(
            b,
            x11,
            target,
            optimize,
            name,
            check_examples,
        );
    }

    const examples = b.step("examples", "Build all examples");
    examples.dependOn(check_examples);
}

fn addExample(
    b: *std.Build,
    x11: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    check_examples: *std.Build.Step,
) void {
    const source = b.fmt("examples/{s}.zig", .{name});
    const executable_name = b.fmt("example-{s}", .{name});

    const example_module = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
    });
    example_module.addImport("x11", x11);

    const example = b.addExecutable(.{
        .name = executable_name,
        .root_module = example_module,
    });

    const run_example = b.addRunArtifact(example);

    const run_step = b.step(
        b.fmt("example-{s}", .{name}),
        b.fmt("Run the {s} example", .{name}),
    );
    run_step.dependOn(&run_example.step);

    check_examples.dependOn(&example.step);
}
