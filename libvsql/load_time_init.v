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
//
// The GC registers the thread that initializes it, which is the thread that
// loads the library, and that may be any thread of the program (such as a Java
// thread). A thread that the GC didn't start isn't unregistered when it exits,
// so the GC would keep trying to stop and scan it: on macOS the next collection
// aborts ("thread_suspend failed"), and a new thread that gets the same thread
// ID would be taken for it (with the old thread's stack), so the memory on the
// new thread's stack would be freed while it's still in use. So the thread is
// unregistered once the library is initialized, and like every other thread,
// it's only registered while it runs a routine (see enter).
fn C._vinit_caller()

@[_constructor; markused]
fn load_time_init() {
	C._vinit_caller()
	unregister_thread(true)
}
