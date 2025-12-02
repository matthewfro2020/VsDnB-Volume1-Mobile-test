package thx;

@:forward
abstract ThxNil(Dynamic) from Dynamic to Dynamic
{
    public static var nil(default, null):ThxNil = cast {};

    @:from
    public static function fromDynamic(v:Dynamic):ThxNil
        return cast v;

    @:to
    public function toDynamic():Dynamic
        return this;
}
