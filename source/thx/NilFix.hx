package thx;

#if ios
// Avoid Objective-C `Nil` macro conflict by renaming the class.
typedef Nil = thx._NilCompat.NilCompat;
#else
typedef Nil = thx.Nil;
#end
