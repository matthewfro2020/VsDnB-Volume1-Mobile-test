package polymod.util;

// Removes thx.core dependency from polymod internals
class PolymodThunk {
    public static inline function tuple(a:Dynamic, b:Dynamic)
        return { _1: a, _2: b };
}
