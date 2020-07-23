#!/bin/bash

clang++ -c stb_image.cpp
dmd *.d  -i -I../../ stb_image.o -version=utils -version=opengl -version=testing
rm *.o