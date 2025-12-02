package thx;

// Fake minimal Nil that does NOT conflict with Obj-C "Nil"
@:keep
class Nil {
    public static final nil = new Nil();
    public function new() {}
    public function toString() return "nil";
}
