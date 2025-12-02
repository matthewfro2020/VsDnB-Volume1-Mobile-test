package polymod.patches;

/**
 * Replaces the thx.Nil type with a safe empty struct for iOS.
 * Ensures Apple Obj-C `Nil` macro never conflicts.
 */
@:keep
@:noCompletion
class FixNil {
    public static macro function apply() {
        // Disable all thx Nil classes
        haxe.macro.Context.addGlobalMetadata("thx.Nil", "@:remove");
        haxe.macro.Context.addGlobalMetadata("thx._Tuple.Tuple0_Impl_", "@:remove");

        return null;
    }
}
