# LLVM-Makefiles

This is a set of GNU-makefiles for building LLVM / Clang on Windows
using either MSVC's `cl` or `clang-cl` itself (edit `Common.Windows`
and set `USE_CLANG_CL = 0` or `1`).

The reason I made these makefiles, was the utter slow build method the
*official* CMake based method provided. <br>
Using `cl -MP ...` to build is approximately 3 times faster than the
generated *Nmake* Makefiles.

Besides, I do not know Cmake that well (and feel little motivated to learn
that ugly syntax). Also, the obfuscated generated Makefiles Cmake generates
makes it really hard to understand how it builds things.

Using GNU-make in dry-run mode (`make -f Makefile.Windows -n`), it is clearer
what would be created without actually doing anything.

To use these Makefiles, select the **Download ZIP** button:
[![screenshot](LLVM-Makefiles_download.png?raw=true)](LLVM-Makefiles_download.png?raw=true)

E.g. if the downloaded files ends up in `c:\Users\John-Doe\Downloads`, do:
```
  cd /D c:\Users\John-Doe\Downloads
  unzip.exe LLVM-Makefiles-master.zip
```

Then move all of the extracted `LLVM-Makefiles-master\*.Windows` files
to your (for example) `c:\MyProjects\LLVM-Project` directory. And where you start GNU-make:
```
 c:\MyProjects\LLVM-Project> make -f Makefile.Windows
```

