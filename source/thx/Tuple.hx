package thx;

@:keep
class Tuple0 {
    public function new() {}
}

@:keep
class Tuple1<T> {
    public var _1:T;
    public function new(v:T) this._1 = v;
}

@:keep
class Tuple2<A,B> {
    public var _1:A;
    public var _2:B;
    public function new(a:A,b:B) {
        _1 = a;
        _2 = b;
    }
}
