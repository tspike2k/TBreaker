#!/bin/bash
cd src
dmd -of=../gen_shortcut -i gen_shortcut.d
dmd -of=../tbreaker-l64 -i tbreaker.d -Iplatform -version=opengl -version=testing -L-lGL -L-lX11
rm ../*.o