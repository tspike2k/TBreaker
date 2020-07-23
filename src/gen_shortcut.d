// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

import core.stdc.stdio;
import core.stdc.stdlib : getenv;
import core.sys.linux.unistd;

nothrow @nogc:

char[2048] destFileName;
char[2048] appDirectory;

enum fileContents =
`[Desktop Entry]
Encoding=UTF-8
Exec=%s/tbreaker-l64
Path=%s/
Icon=%s/icon.png
Type=Application
Terminal=false
Comment=Break timer application
Name=TBreaker
GenericName=TBreaker1.0
StartupNotify=false
Categories=Accessories;
`;

int main()
{
    char* homeDir = getenv("HOME");
    
    if (!homeDir)
    {
        fprintf(stderr, "ERR: Unable to query HOME env. Aborting.");
        return 1;
    }
    
    snprintf(destFileName.ptr, destFileName.length, "%s/%s", homeDir, ".local/share/applications/tbreaker.desktop".ptr);
    
    auto linkLen = readlink("/proc/self/exe", appDirectory.ptr, appDirectory.length);
    appDirectory[linkLen] = '\0';
    foreach_reverse(i, _; appDirectory)
    {
        if(appDirectory[i] == '/')
        {
            appDirectory[i] = '\0';
            break;
        }
    }
    
    auto file = fopen(destFileName.ptr, "w");
    if(!file)
    {
        fprintf(stderr, "ERR: Unable to open file `%s`. Aborting.", destFileName.ptr);
        return 1;
    }
    scope(exit) fclose(file);
    
    fprintf(file, fileContents.ptr, appDirectory.ptr, appDirectory.ptr, appDirectory.ptr);
    
    return 0;
}