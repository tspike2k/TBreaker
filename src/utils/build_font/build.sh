#!/bin/bash

# TODO: We're pulling in opengl here just to make the few deps we have compile. Perhaps we should add a "headless mode" to the
# platform layer that would allow us to NOT include graphics. I don't know. Maybe make platform_linux_x11 work without OpenGL
# by having copius version(...) checks.
clang++ -c stb_truetype.cpp
dmd main.d -i -I../../ -version=utils -version=opengl stb_truetype.o -of=build_font
rm *.o