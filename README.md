This is a Commodore 64 game browser for SD2IEC or Pi1541 devices.

Description

I wanted something like CBM-FileBrowser for my Commodore 64 game collection
but preferred to see full descriptions for the games rather than having to
hunt for cryptic file names in a large directory structure.  My game collection 
has meta data files that include attributes like year, genre, author, and full 
description of the game.

![alt text](https://raw.githubusercontent.com/randyrossi/c64-games-menu/master/sample.png)

I organized the collection under directories with names 'a'-'z' + '0' for 
games that start with a digit.  I then constructed my index files.  This 
program reads a custom index file format with each page containing 21
games, maximum 99 pages per letter. Pages are read into memory fairly quickly
so you can navigate to a game easily by pressing a letter, paging, scrolling
and hitting enter.  Once selected, the .d64 disk image is mounted and its
directory is loaded.  Pressing * instead of ENTER will also mount the disk
but issue a LOAD "*",8,1 instead of loading the directory.

You will have to make your own index files to use this. See menu.asm for the
expected format.  This obviously only works on SD2IEC or Pi1541 drives.

For now, only an alphabetical index is supported.

NOTE: Pi1541 doesn't support file browse mode with a fast loader yet.  So trying to
load anything from the Pi1541 in browse mode hangs.  Hopefully, this will be
fixed in the future.

Build

The Makefile uses acme cross compiler.  You should be able to use any.

Just type make to get 'menu'

Usage:

    LOAD "MENU",8
    RUN

    LEFT/RIGHT = MOVE TO NEXT/PREV LETTER
    UP/DOWN    = MOVE TO PREV/NEXT GAME
    SPACE      = NEXT PAGE
    <-         = PREV PAGE
    ENTER      = MOUNT THE .D64 IMAGE AND LOAD DIRECTORY
    ASTERISK   = MOUNT THE .D64 IMAGE AND LOAD "*",8,1
    COMMA      = INCREMEMT DRIVE NUMBER

I've included my index files (but obviously, not the games) as a
demonstration.  I didn't filter out the .p00 files so ignore those. This
only works with .d64 files.

