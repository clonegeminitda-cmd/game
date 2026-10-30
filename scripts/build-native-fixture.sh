#!/usr/bin/env bash
set -euo pipefail
: "${JAVA_HOME:?Set JAVA_HOME to a JDK containing include/jni.h}"
TASK_ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$TASK_ROOT/native-sample/src/main/jniLibs/x86_64"
# Minimal Linux x86_64 ELF, with no glibc dependency; Android's x86_64 linker can load it.
gcc -shared -nostdlib -fPIC -O2 -Wl,--hash-style=both -Wl,-z,max-page-size=16384 \
    -Wl,-soname,libnativefixture.so \
    -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/linux" \
    "$TASK_ROOT/native-sample/src/main/cpp/nativefixture.c" \
    -o "$TASK_ROOT/native-sample/src/main/jniLibs/x86_64/libnativefixture.so"
