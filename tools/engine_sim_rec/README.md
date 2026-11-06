# Engine Simulator recorder (headless, Linux)

Builds the simulation core of AngeTheGreat's Engine Simulator (github.com/ange-yaghi/engine-sim, MIT) without its
Windows front end, and records each engine held on the dynamometer at set rpms, full throttle (`_on`) and closed
throttle (`_off`), to 44.1 kHz WAVs. `tools/engine_loops.py` turns those into the game's seamless loops.

    git clone --depth 1 https://github.com/ange-yaghi/engine-sim engine-sim
    cd engine-sim && git submodule update --init --depth 1 dependencies/submodules/simple-2d-constraint-solver \
        dependencies/submodules/csv-io dependencies/submodules/piranha && cd ..
    # patches for clang on Linux (all in the clone):
    #  include/delta.h            -> empty (the core uses nothing from the delta graphics engine)
    #  include/gas_system.h       -> Mix struct hoisted out of the class (GasSystemMix), the `= {}` defaults turned into overloads
    #  scripting/include/object_reference_node.h -> inner template parameter renamed (shadowed `Type`)
    apt-get install flex libboost-filesystem-dev clang
    CXX=clang++ CC=clang cmake -B build . && cmake --build build -j
    # from a folder beside engine-sim/assets and engine-sim/es:
    ./build/es_rec ../assets/rec_v8_351.mr out/v8_351 700 800,1500,2500,3600,5000

Engines used: v8_351 = Chev 454 truck V8, i6_202 = BMW M52B28, i6_40 = 2JZ, i4_22r = Honda B18C5.
