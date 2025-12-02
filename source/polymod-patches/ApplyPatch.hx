package polymod.patches;

class ApplyPatch {
    macro public static function init() {
        return FixNil.apply();
    }
}
