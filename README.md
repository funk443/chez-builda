---
Title: builda.ss
Description: A quick way to create a standalone executable for Chez Scheme.
---

I know [chez-exe](https://github.com/gwatt/chez-exe) exists, but it's just so
complicated, so I created this single-file solution, which can be used if you
have a C compiler and Chez Scheme itself installed.

# Requirements

To use this program, you'll need the following things:

- A C compiler
- Files from Chez Scheme, you should be able to find these files in your Chez
  Scheme installation directory, e. g., `/usr/local/lib/csv10.3.0/a6le`:
  - `scheme.h`
  - `libkernel.a`
  - `petite.boot`
  - `scheme.boot`
- liblz4
- zlib

# Usage

There is an Scheme program example in `s/`, you need to at least set up
`scheme-program` parameter in your program to somewhat like in `s/main.ss`.

Various config values can be found in the beginning of `builda.ss`, which you
can customize to fit your need.

After you've configed the desired values, just simply run:

```shell
$ scheme --program builda.ss
```

And you'll see the executable file at the place you have configured (via C
compiler flag `-o` in `builda.ss`). You should be able to just send this
executable (and the shared libraries, if they're used in your code) to any one
with the same platform, and they'll able to run it.

# How it works

This program literally embeds the boot file as byte array in a C file (C code
stole from [ids-chez-launcher](https://github.com/funk443/ids-chez-launcher)
btw), and uses the Chez Scheme function `Sregister_boot_file_bytes` to run the
encoded boot file.
