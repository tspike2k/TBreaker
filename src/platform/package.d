// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2019
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module platform;

version(linux) public import platform.linux_x11_platform;
version(opengl) public import platform.render_opengl;