if [ ! -e build ]; then mkdir build; fi
gcc src/main.c -Isrc -Iinclude -Llib -lluajit_mingw -lraylib_mingw -lwinmm -lgdi32 -obuild/card.exe -Wl,--export-all-symbols
