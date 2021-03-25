# Demo of Bazel's configuration transitions

## Configuration flags

Build and run the default configuration:

```
$ bazel run //app:bin
Using community edition
Data file: COMMUNITY
```

Specify the configuration on the command line:

```
$ bazel run //app:bin --//flag:edition=enterprise
Using enterprise edition
Data file: ENTERPRISE
```

## Configuration transitions

The following targets use configuration transitions to pin a particular
configuration regardless of any command line flags:

```
$ bazel run //app:bin-ce
Using community edition
Data file: COMMUNITY

$ bazel run //app:bin-ee
Using enterprise edition
Data file: ENTERPRISE
```

The following uses configuration transitions to generate a test-suite over all
configurations:

```
$ bazel test //app:test-all
//app:test-all_test_community    PASSED in 0.0s
//app:test-all_test_enterprise   PASSED in 0.0s
```

## Bundling multiple configurations

The following uses configuration transitions and careful combinations of the
`pkg_tar` rule to bundle multiple configurations into one artifact.

```
$ bazel build //app:bundle-all
Target //app:bundle-all up-to-date:
  bazel-bin/app/bundle-all.tar
$ tar tvf bazel-bin/app/bundle-all.tar
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./community/
-r-xr-xr-x 0/0          117016 2000-01-01 01:00 ./community/bin
-r-xr-xr-x 0/0              10 2000-01-01 01:00 ./community/data.txt
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./community/bin.runfiles/
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./community/bin.runfiles/transitions-demo/
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./community/bin.runfiles/transitions-demo/app/
lrwxr-xr-x 0/0               0 2000-01-01 01:00 ./community/bin.runfiles/transitions-demo/app/data.txt -> ../../../data.txt
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./enterprise/
-r-xr-xr-x 0/0          117024 2000-01-01 01:00 ./enterprise/bin
-r-xr-xr-x 0/0              11 2000-01-01 01:00 ./enterprise/data.txt
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./enterprise/bin.runfiles/
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./enterprise/bin.runfiles/transitions-demo/
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./enterprise/bin.runfiles/transitions-demo/app/
lrwxr-xr-x 0/0               0 2000-01-01 01:00 ./enterprise/bin.runfiles/transitions-demo/app/data.txt -> ../../../data.txt
```

## Gotchas

Combining different configurations of the same target requires some care. It is
possible to cause collisions when combining such targets in one rule.

```
$ bazel build //app:gotcha
INFO: From Writing: bazel-out/k8-fastbuild/bin/app/gotcha.tar:
Duplicate file in archive: ./bin, picking first occurrence
Duplicate file in archive: ./data.txt, picking first occurrence
Target //app:gotcha up-to-date:
  bazel-bin/app/gotcha.tar
$ tar tvf bazel-bin/app/gotcha.tar
drwxr-xr-x 0/0               0 2000-01-01 01:00 ./
-r-xr-xr-x 0/0          117016 2000-01-01 01:00 ./bin-ce
-r-xr-xr-x 0/0          117016 2000-01-01 01:00 ./bin
-r-xr-xr-x 0/0              10 2000-01-01 01:00 ./data.txt
-r-xr-xr-x 0/0          117024 2000-01-01 01:00 ./bin-ee
```

This caused a collision in the files `bin` and `data.txt`. The resulting
artifact will only contain one of the configurations.

## Build definitions

Take a look at [`app/BUILD.bazel`](./app/BUILD.bazel) to see the definitions of
the targets above. Take a look at [`flag/defs.bzl`](./flag/defs.bzl) for the
implementation.
