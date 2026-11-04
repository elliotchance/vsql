module main

// V initializes its runtime and the GC in the first exported routine that's
// called, with a guard that isn't thread safe. So threads that make their first
// call at the same time could initialize it twice, or use it before it's
// ready, which the GC aborts on ("Threads explicit registering is not
// previously enabled").
//
// The library initializes itself while it's loaded instead, since no routine
// can be called until then, and later routines see that it's done. V's
// _vinit_caller is the constructor on every platform except Windows, where V
// generates it but doesn't run it. It's safe to call more than once.
//
// On Windows this runs with the loader lock held. The runtime doesn't wait for
// another thread to start while it initializes (the GC's parallel marking isn't
// enabled on Windows), but the init of V's net module does call WSAStartup,
// which Microsoft advises against in DllMain. The constructor needs GCC or Clang,
// which is what the Makefile and scripts/amalgamation.sh use on Windows.
fn C._vinit_caller()

@[_constructor; markused]
fn load_time_init() {
	C._vinit_caller()
}
