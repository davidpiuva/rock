import os/Time

/**
 * Contain the online (rather inline) help of the ooc compiler
 * 
 * @author Amos Wenger
 */
Help: class {

    /**
     * Print a helpful help message that helps 
     */
    printHelp: static func {

        println("Usage: ooc [options] files\n")
        /*
        println(
"-v, -verbose                    verbose
-g, -debug                      compile with debug information
-noclean                        don't delete any temporary file produced by
                                the backend
-backend=[c,json]               choose the rock backend (default=c)
-gcc,-tcc,-icc,-clang,-onlygen  choose the compiler backend (default=gcc)
-onlygen doesn't launch any C compiler, and implies -noclean
-gc=[dynamic,static,off]        link dynamically, link statically, or doesn't
                                link with the Boehm GC at all.
-driver=[combine,sequence]      choose the driver to use. combine does all in one,
                                sequence does all the .c one after the other.
-sourcepath=output/path/        location of your source files
-outpath                        where to output the  c/ h files
-Ipath, -incpath=path           where to find C headers
-Lpath, -libpath=path           where to find libraries to link with
-lmylib                         link with library 'mylib'
-timing                         print how much time it took to compile
-r, -run                        runs the executable after compilation
\nFor help about the backend options, run 'ooc -help-backends'"
        )
        */
        
    }

    /**
     * Print a helpful help message that helps about backends 
     */
    printHelpBackends: static func {
        /*
        println(
"The available backends are: [none,gcc,make] and the default is gcc 
none             just outputs the  c/ h files (be sure to have a main func)
gcc              call the GNU C compiler with appropriate options
make             generate a Makefile in the default output directory (ooc_tmp)
\nFor help about a specific backend, run 'ooc -help-gcc' for example"
        )
        */
    }
    
    /**
     * Print a helpful help message that helps about gcc 
     */
    printHelpGcc: static func {
        /*
        println(
"gcc backend options:
-clean=[yes,no]        delete (or not) temporary files  default: yes 
                       overriden by the global option -noclean
-verbose=[yes,no]      print the gcc command lines called from the backend 
                       overriden by the global options -v, -verbose
-shout=[yes,no], -s    prints a big fat [ OK ] at the end of the compilation
                       if it was successful (in green, on Linux platforms)
any other option       passed to gcc\n"
        )
        */
    }
    
    /**
     * Print a helpful help message that helps about make 
     */
    printHelpMake: static func {
        /*
        println(
"make backend options:
-cc=[gcc,icl]        write a Makefile to be compatible with the said compiler
-link=libname a      link with the static library libname a
any other option     passed to the compiler\n"
        )
        */
    }
    
    /**
     * Print a helpful help message that helps about none 
     */
    printHelpNone: static func {
        srand(Time microsec())
        
        /*
        text : UInt32[] = [
0x20202020, 0x20202020, 0x2b202020, 0x684e4e28, 0x73684242, 0x20272b73, 
0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x272b7e20, 0x424e7328, 
0x7e3d444e, 0x2020202e, 0x20202020, 0x200a2020, 0x20202020, 0x20202020, 
0x282d2020, 0x68444e3d, 0x3d2b4e4e, 0x20273d2b, 0x2020202e, 0x2e20202e, 
0x20202020, 0x2b2e202e, 0x7e2b273d, 0x444e4e44, 0x202e3d2b, 0x20202020, 
0x20202020, 0x20200a20, 0x20202020, 0x20202020, 0x2d2b2e20, 0x44444244, 
0x44282b68, 0x20273c2d, 0x20202020, 0x2e2e2e20, 0x20202e2e, 0x202b3c2d, 
0x447e3d28, 0x3c2b684e, 0x20202028, 0x20202020, 0x20202020, 0x2020200a, 
0x20202020, 0x20202020, 0x3c2b2720, 0x424e4e4e, 0x7a3d7e3d, 0x2d3c282d, 
0x2b283c3c, 0x272d2728, 0x3d3c3c7e, 0x2b2e202d, 0x4e427327, 0x202b7e68, 
0x20202020, 0x20202020, 0xa202020,  0x20202020, 0x20202020, 0x20202020, 
0x3d7e2820, 0x444e4e4e, 0x42443d2b, 0x2e2d287e, 0x20202020, 0x202e202e, 
0x2e202020, 0x3d282e2e, 0x2b424e42, 0x202d2d73, 0x20202020, 0x4c4c4120, 
0x554f5920, 0x200a2052, 0x20202020, 0x20202020, 0x20202020, 0x3d2d3d2e, 
0x7a444244, 0x2e7e272d, 0x20202e20, 0x272e2e20, 0x2e2e202e, 0x27202e2e, 
0x7e272020, 0x733c3c73, 0x2e3c687a, 0x20202020, 0x20202020, 0x20200a20, 
0x20202020, 0x20202020, 0x20202020, 0x7e283c20, 0x2e202e27, 0x202e2020, 
0x732e2e20, 0x2d273d44, 0x272d277e, 0x7344442d, 0x2e202e2e, 0x737e2e20, 
0x20202844, 0x43202020, 0x4245444f, 0x20455341, 0x20200a20, 0x20202020, 
0x20202020, 0x202e2020, 0x20272b7e, 0x20202720, 0x2d282d2e, 0x42732e2e, 
0x287e424e, 0x3d2b7e7e, 0x4e4e4e68, 0x3c3c277a, 0x2d273d7a, 0x2020287a, 
0x20202020, 0x20202020, 0x20202020, 0x20200a20, 0x20202020, 0x20202020, 
0x2e202e20, 0x2d202e3d, 0x3c7a4444, 0x207e737e, 0x4e422720, 0x7e3d4e4e, 
0x68733c2b, 0x4e4e4e4e, 0x4e732844, 0x7e684e4e, 0x20202b28, 0x52412020, 
0x45422045, 0x474e4f4c, 0x2020200a, 0x20202020, 0x20202020, 0x3c3d2e20, 
0x4e4e282e, 0x44444e4e, 0x28202e73, 0x2b736868, 0x683d733d, 0x4e4e444e, 
0x42424e42, 0x4e423c73, 0x3c3c444e, 0x20202e3d, 0x20202020, 0x20202020, 
0xa202020,  0x20202020, 0x20202020, 0x20202020, 0x272d272e, 0x4e4e737e, 
0x2d282873, 0x27272e20, 0x2027202e, 0x4e4e7e2d, 0x282b7a44, 0x2d2d7e28, 
0x42737e2d, 0x2727273c, 0x2020202e, 0x4f542020, 0x21535520, 0x2020200a, 
0x20202020, 0x20202020, 0x20202020, 0x283d2720, 0x2d282b2b, 0x20202e2e, 
0x2e2e202e, 0x2b7e2d2e, 0x2e277e42, 0x272e2e2e, 0x2d27272e, 0x2020282b, 
0x2e202020, 0x20202020, 0x20202020, 0x20202020, 0x20200a20, 0x20202020, 
0x20202020, 0x20202020, 0x3d2d2020, 0x273c3c7a, 0x2e202e2e, 0x2e2e2d27, 
0x7e2d272e, 0x2d7e7a68, 0x27272e27, 0x7e2d2727, 0x203d3c2d, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x2020200a, 0x20202020, 
0x20202020, 0x20202020, 0x7e2e2020, 0x7e737e2b, 0x7a7e2020, 0x2d277e3c, 
0x682d2d27, 0x287e3d4e, 0x2d277e28, 0x7e282d2d, 0x207e7a7e, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0xa202020,  0x20202020, 0x20202020, 
0x20202020, 0x20202020, 0x28202020, 0x2e2d3c2b, 0x273d2b27, 0x7e272727, 
0x423d2b28, 0x7e2d2d7a, 0x3d282828, 0x7e2b732b, 0x20207328, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0xa202020,  0x54492020, 0x4f205327, 
0x20524556, 0x20202020, 0x27202e20, 0x2e2e2d2b, 0x2d2d3c7e, 0x2d7e2d2d, 
0x4273282b, 0x7a2b684e, 0x424e4e42, 0x3c2b684e, 0x2020277a, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0xa202020,  0x20202020, 0x20202020, 
0x20202020, 0x20202020, 0x2e202020, 0x2d272d3c, 0x2827272d, 0x423d7e3c, 
0x4444683d, 0x3c3c3d44, 0x3d2b2b3c, 0x3d3c2b2b, 0x2020202e, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0x3920200a, 0x20303030, 0x53475542, 
0x20202021, 0x2e2e2020, 0x2e7e7320, 0x3d68272e, 0x73732b2b, 0x3c3c443d, 
0x28422b7e, 0x3c2b283c, 0x3d7a4e3d, 0x2020202b, 0x20202020, 0x20202020, 
0x20202020, 0x20202020, 0x200a2020, 0x20202020, 0x20202020, 0x20202020, 
0x20202020, 0x2b202020, 0x27272e27, 0x444e4e2b, 0x7a2b284e, 0x73282828, 
0x28283c42, 0x4e682b73, 0x202b3c68, 0x20202020, 0x20202020, 0x20202020, 
0x2020200a, 0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x2d203d2e, 
0x287e287e, 0x7a4e447a, 0x7a2b7a2b, 0x7a444e68, 0x687a733d, 0x2b7a4268, 
0x20202e2b, 0x20202020, 0x44414d20, 0x5353454e, 0x2020203f, 0x20202020, 
0x20200a20, 0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x2e2b2720, 
0x3c737320, 0x4e3d7e27, 0x42424e42, 0x7a427a44, 0x44687368, 0x3c2b3d44, 
0x20202d3c, 0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x20200a20, 
0x20202020, 0x20202020, 0x20202020, 0x20202020, 0x203d2d20, 0x732b202e, 
0x2b282d7e, 0x68683d3d, 0x424e4244, 0x3d734444, 0x2b7a683d, 0x2020203c, 
0x48542020, 0x20215349, 0x20215349, 0x4d414c4c, 0x200a2141, 0x20202020, 
0x20202020, 0x20202020, 0x20202020, 0x2d3c2827, 0x202e2020, 0x287e7e27, 
0x3d3c2b3c, 0x7a733c2b, 0x73732b3d, 0x28737a68, 0x20202e2e, 0x20202020, 
0x20202020, 0x20202020, 0x20200a20, 0x20202020, 0x20202020, 0x20202020, 
0x2b2e2020, 0x20202e3c, 0x28272020, 0x287e2d27, 0x28282828, 0x282b2b3c, 
0x28283c3c, 0x202e203d, 0x20202020, 0x20202020, 0x20202020, 0x20202020, 
0x2020200a, 0x20202020, 0x20202020, 0x20202020, 0x2d2e2020, 0x202e2e2d, 
0x2e2e2e2e, 0x2e272e27, 0x2e272e27, 0x2e27272e, 0x2e2d272e, 0x2020202e, 
0x20202020, 0x20202020, 0x20202020, 0xa202020,  0xa202020
    ]

        printf("\033[0;32;%dm                    SOMEBODY SET US UP THE BOMB!\n\033[m\n%s", ((rand() % 6) + 31), text as String)
    */
    }
    
}
