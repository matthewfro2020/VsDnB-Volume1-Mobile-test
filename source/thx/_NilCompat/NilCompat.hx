package thx._NilCompat;

@:final
class NilCompat {
    public static inline var nil:NilCompat = new NilCompat();

    public inline function new() {}

    public inline function toString()
        return "Nil";
}
