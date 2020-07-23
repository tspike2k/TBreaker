# TBreaker

Simple X11 application meant to remind users to take regular breaks from the computer.

## About

Sustained use of a desktop computer is strenuous on the human body so it's advisable to regularly step back and take breaks. This can be difficult to remember especially if you're using the computer to accomplish some sort of task that demands focus. This application is designed to remind you at regular intervals to take these breaks. It does this by having a small window displayed at the bottom of the screen that will raise above other windows when a break is scheduled.

## Installation

Clone the project and place the contents in whatever directory you wish to install the application. Build the application by running the included build.sh file. This will require the DMD D compiler to be installed. This should build both the executable (tbreaker-l64) and a utility (gen_shortcut) for generating a .desktop file in ~/.local/share/applications, allowing you to easily launch the application from the main panel menu.

## Configuration

By default, this application will remind the user to take a five minute break every thirty minutes, with no daily limit on computer use. This can be configured by editing the included config.txt file. The color of the background and text can also be configured.

## License

[Boost Software License 1.0](https://www.boost.org/LICENSE_1_0.txt)

## Acknowledgments

* Concept based on [Take a Break](https://launchpad.net/takeabreak) by Jacob Vlijm

* Icon based on [Stopwatch](https://openclipart.org/detail/185199/stopwatch) by ousia