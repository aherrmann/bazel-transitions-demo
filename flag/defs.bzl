load("@bazel_skylib//lib:paths.bzl", "paths")

EditionProvider = provider(fields = ["edition"])

editions = ["community", "enterprise"]

_unknown_edition_error = "--{label} expects values {expected} but was set to {actual}."

def _edition_flag_impl(ctx):
    value = ctx.build_setting_value
    if value not in editions:
        fail(_unknown_edition_error.format(
            label = str(ctx.label),
            expected = repr(editions),
            actual = repr(value),
        ))
    return EditionProvider(edition = value)

edition_flag = rule(
    implementation = _edition_flag_impl,
    build_setting = config.string(flag = True),
)

def _edition_transition_impl(settings, attr):
    edition = attr.edition
    return {"//flag:edition": edition}

edition_transition = transition(
    implementation = _edition_transition_impl,
    inputs = [],
    outputs = ["//flag:edition"],
)

def _editions_transition_impl(settings, attr):
    editions = attr.editions
    return [
        {"//flag:edition": edition}
        for edition in editions
    ]

editions_transition = transition(
    implementation = _editions_transition_impl,
    inputs = [],
    outputs = ["//flag:edition"],
)

def _edition_files_impl(ctx):
    files = ctx.files.srcs
    return [DefaultInfo(
        files = depset(direct = files),
    )]

edition_files = rule(
    _edition_files_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "edition": attr.string(),
        "srcs": attr.label_list(allow_files = True),
    },
    cfg = edition_transition,
)

def _editions_files_impl(ctx):
    files = ctx.files.srcs
    return [DefaultInfo(
        files = depset(direct = files),
    )]

editions_files = rule(
    _editions_files_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "editions": attr.string_list(),
        "srcs": attr.label_list(
            allow_files = True,
            cfg = editions_transition,
        ),
    },
)

def _edition_binary_impl(ctx):
    (_, extension) = paths.split_extension(ctx.executable.executable.path)
    executable = ctx.actions.declare_file(
        ctx.label.name + extension,
    )
    ctx.actions.symlink(
        output = executable,
        target_file = ctx.executable.executable,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [executable, ctx.executable.executable] + ctx.files.data)
    runfiles = runfiles.merge(ctx.attr.executable[DefaultInfo].default_runfiles)
    for data_dep in ctx.attr.data:
        runfiles = runfiles.merge(data_dep[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        executable = executable,
        files = depset(direct = [executable]),
        runfiles = runfiles,
    )]

edition_binary = rule(
    _edition_binary_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "data": attr.label_list(allow_files = True),
        "edition": attr.string(),
        "executable": attr.label(
            cfg = "target",
            executable = True,
        ),
    },
    cfg = edition_transition,
    executable = True,
)

TestAspectInfo = provider(fields = ["args", "env"])

def _test_aspect_impl(target, ctx):
    data = getattr(ctx.rule.attr, "data", [])
    args = getattr(ctx.rule.attr, "args", [])
    env = getattr(ctx.rule.attr, "env", [])
    args = [ctx.expand_location(arg, data) for arg in args]
    env = {k: ctx.expand_location(v, data) for (k, v) in env.items()}
    return [TestAspectInfo(
        args = args,
        env = env,
    )]

_test_aspect = aspect(_test_aspect_impl)

def _edition_test_impl(ctx):
    test_aspect_info = ctx.attr.test[TestAspectInfo]
    (_, extension) = paths.split_extension(ctx.executable.test.path)
    executable = ctx.actions.declare_file(
        ctx.label.name + extension,
    )
    ctx.actions.write(
        output = executable,
        content = """\
#!/usr/bin/env bash
set -euo pipefail
{commands}
""".format(
            commands = "\n".join([
                " \\\n".join([
                    '{}="{}"'.format(k, v)
                    for k, v in test_aspect_info.env.items()
                ] + [
                    ctx.executable.test.short_path,
                ] + test_aspect_info.args),
            ]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [executable, ctx.executable.test] + ctx.files.data)
    runfiles = runfiles.merge(ctx.attr.test[DefaultInfo].default_runfiles)
    for data_dep in ctx.attr.data:
        runfiles = runfiles.merge(data_dep[DefaultInfo].default_runfiles)

    return [DefaultInfo(
        executable = executable,
        files = depset(direct = [executable]),
        runfiles = runfiles,
    )]

edition_test = rule(
    _edition_test_impl,
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "data": attr.label_list(allow_files = True),
        "edition": attr.string(),
        "test": attr.label(
            aspects = [_test_aspect],
            cfg = "target",
            executable = True,
        ),
    },
    cfg = edition_transition,
    executable = True,
    test = True,
)

def editions_test_suite(name, tests = [], editions = editions, **kwargs):
    test_suite_tests = []
    for test in tests:
        if test.startswith(":") or test.startswith("//") or test.startswith("@"):
            test_name = Label(test).name
        else:
            test_name = test
        for edition in editions:
            edition_test_name = "{}_{}_{}".format(name, test_name, edition)
            test_suite_tests.append(edition_test_name)
            edition_test(
                name = edition_test_name,
                edition = edition,
                test = test,
            )
    native.test_suite(
        name = name,
        tests = test_suite_tests,
        **kwargs
    )
