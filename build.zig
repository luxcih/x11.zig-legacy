const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("x11", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    const example_names = [_][]const u8{
        "display",
        "setup",
        "window",
        "events",
        "gc",
        "draw",
        "redraw",
        "unix_socket",
    };

    const examples_step = b.step("examples", "Build all examples");
    const check_examples_step = b.step("check-examples", "Compile all examples");

    inline for (example_names) |name| {
        const source = b.fmt("examples/{s}.zig", .{name});
        const executable_name = b.fmt("example-{s}", .{name});

        const example_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = target,
            .optimize = optimize,
        });
        example_module.addImport("x11", module);

        const example = b.addExecutable(.{
            .name = executable_name,
            .root_module = example_module,
        });

        const run_example = b.addRunArtifact(example);

        const run_step_name = b.fmt("example-{s}", .{name});
        const run_step_description = b.fmt(
            "Run the {s} example",
            .{name},
        );
        const example_step = b.step(
            run_step_name,
            run_step_description,
        );
        example_step.dependOn(&run_example.step);

        examples_step.dependOn(&example.step);
        check_examples_step.dependOn(&example.step);
    }
}
