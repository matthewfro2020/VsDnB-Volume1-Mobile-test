package thx._NilCompat;

class FixNil {
    public static function run() {
        // Replace all references to thx.Nil with thx.NilFix
        haxe.macro.Context.addGlobalMetadata("thx.Nil",
            "@:build(thx._NilCompat.ReplaceNil.build())");
    }
}
