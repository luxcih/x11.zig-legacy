const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("x11", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = module,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    const example_module = b.createModule(.{
        .root_source_file = b.path("examples/display.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_module.addImport("x11", module);

    const example = b.addExecutable(.{
        .name = "example-display",
        .root_module = example_module,
    });

    const run_example = b.addRunArtifact(example);

    const example_step = b.step(
        "example-display",
        "Run the display example",
    );
    example_step.dependOn(&run_example.step);
    const unix_socket_module = b.createModule(.{
        .root_source_file = b.path("examples/unix_socket.zig"),
        .target = target,
        .optimize = optimize,
    });
    unix_socket_module.addImport("x11", module);

    const unix_socket_example = b.addExecutable(.{
        .name = "example-unix-socket",
        .root_module = unix_socket_module,
    });

    const run_unix_socket_example = b.addRunArtifact(unix_socket_example);

    const unix_socket_example_step = b.step(
        "example-unix-socket",
        "Run the Unix socket example",
    );
    unix_socket_example_step.dependOn(&run_unix_socket_example.step);

    const setup_example_module = b.createModule(.{
        .root_source_file = b.path("examples/setup.zig"),
        .target = target,
        .optimize = optimize,
    });
    setup_example_module.addImport("x11", module);

    const setup_example = b.addExecutable(.{
        .name = "example-setup",
        .root_module = setup_example_module,
    });

    const run_setup_example = b.addRunArtifact(setup_example);

    const setup_example_step = b.step(
        "example-setup",
        "Run the X11 setup example",
    );
    setup_example_step.dependOn(&run_setup_example.step);

}
