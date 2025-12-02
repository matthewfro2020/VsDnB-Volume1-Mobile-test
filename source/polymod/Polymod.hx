package polymod;

#if ios
@:keep
@:structAccess
#end
import haxe.Json;
import haxe.io.Bytes;
import polymod.backends.IBackend;
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets;
import polymod.format.JsonHelp;
import polymod.format.ParseRules;
import polymod.fs.PolymodFileSystem;
#if hscript
import polymod.hscript._internal.PolymodScriptClass;
#end
import polymod.util.DependencyUtil;
import polymod.util.VersionUtil;
import thx.semver.Version;
import thx.semver.VersionRule;

using StringTools;

#if firetongue
import firetongue.FireTongue;
#end

// ----------------------------------------------------------
//  iOS FIX: Remove ThxNil and curExpr
// ----------------------------------------------------------
#if ios
private typedef SafeDynamic = Null<Dynamic>;
#else
private typedef SafeDynamic = Dynamic;
#end

/**
 * Any framework-specific settings
 * Right now this is only used to specify asset library paths for the Lime/OpenFL framework but we'll add more framework-specific settings here as neeeded
 */
typedef FrameworkParams =
{
	/**
	 * (optional) if you're using Lime/OpenFL AND you're using custom or non-default asset libraries, then you must provide a key=>value store mapping the name of each asset library to a path prefix in your mod structure
	 */
	?assetLibraryPaths:Map<String, String>,

	/**
	 * (optional) specify this path to redirect core asset loading to a different path
	 * you can set this up to load core assets from a parent directory!
	 * Not applicable for file systems which don't use a directory obvs.
	 */
	 ?coreAssetRedirect:String
}

typedef ScanParams =
{
	?modRoot:String,
	?apiVersionRule:VersionRule,
	?errorCallback:PolymodError->Void,
	?fileSystem:IFileSystem
}

/**
 * The framework which your Haxe project is using to manage assets
 */
enum Framework
{
	CASTLE;
	NME;
	LIME;
	OPENFL;
	OPENFL_WITH_NODE;
	FLIXEL;
	HEAPS;
	KHA;
	CERAMIC;
	CUSTOM;
	UNKNOWN;
}


typedef ModDependencies = Map<String, VersionRule>;

/**
 * A type representing data about a mod, as retrieved from its metadata file.
 */
class ModMetadata
{
	/**
	 * The internal ID of the mod.
	 */
	public var id:String;

	/**
	 * The human-readable name of the mod.
	 */
	public var title:String;

	/**
	 * A short description of the mod.
	 */
	public var description:String;

	/**
	 * A link to the homepage for a mod.
	 * Should provide a URL where the mod can be downloaded from.
	 */
	public var homepage:String;

	/**
	 * A version number for the API used by the mod.
	 * Used to prevent compatibility issues with mods when the application changes.
	 */
	public var apiVersion:Version;

	/**
	 * A version number for the mod itself.
	 * Should be provided in the Semantic Versioning format.
	 */
	public var modVersion:Version;

	/**
	 * The name of a license determining the terms of use for the mod.
	 */
	public var license:String;

	/**
	 * Binary data containing information on the mod's icon file, if it exists.
	 * This is useful when you want to display the mod's icon in your application's mod menu.
	 */
	public var icon:Bytes = null;

	/**
	 * The path on the filesystem to the mod's icon file.
	 */
	public var iconPath:String;

	/**
	 * The path where this mod's files are stored, on the IFileSystem.
	 */
	public var modPath:String;

	/**
	 * `metadata` provides an optional list of keys.
	 * These can provide additional information about the mod, specific to your application.
	 */
	public var metadata:Map<String, String>;

	/**
	 * A list of dependencies.
	 * These other mods must be also be loaded in order for this mod to load,
	 * and this mod must be loaded after the dependencies.
	 */
	public var dependencies:ModDependencies;

	/**
	 * A list of dependencies.
	 * This mod must be loaded after the optional dependencies,
	 * but those mods do not necessarily need to be loaded.
	 */
	public var optionalDependencies:ModDependencies;

	/**
	 * A deprecated field representing the mod's author.
	 * Please use the `contributors` field instead.
	 */
	@:deprecated
	public var author(get, set):String;

	// author has been made a property so setting it internally doesn't throw deprecation warnings
	var _author:String;

	function get_author()
	{
		if (contributors.length > 0)
		{
			return contributors[0].name;
		}
		return _author;
	}

	function set_author(v):String
	{
		if (contributors.length == 0)
		{
			contributors.push({name: v});
		}
		else
		{
			contributors[0].name = v;
		}
		return v;
	}

	/**
	 * A list of contributors to the mod.
	 * Provides data about their roles as well as optional contact information.
	 */
	public var contributors:Array<ModContributor>;

	public function new()
	{
		// No-op constructor.
	}

	public function toJsonStr():String
	{
		var json = {};
		Reflect.setField(json, 'title', title);
		Reflect.setField(json, 'description', description);
		// Reflect.setField(json, 'author', _author);
		Reflect.setField(json, 'contributors', contributors);
		Reflect.setField(json, 'homepage', homepage);
		Reflect.setField(json, 'api_version', apiVersion.toString());
		Reflect.setField(json, 'mod_version', modVersion.toString());
		Reflect.setField(json, 'license', license);
		var meta = {};
		for (key in metadata.keys())
		{
			Reflect.setField(meta, key, metadata.get(key));
		}
		Reflect.setField(json, 'metadata', meta);
		return Json.stringify(json, null, '    ');
	}

	public static function fromJsonStr(str:String)
	{
		if (str == null || str == '')
		{
			Polymod.error(PARSE_MOD_META, 'Error parsing mod metadata file, was null or empty.');
			return null;
		}

		var json = null;
		try
		{
			json = haxe.Json.parse(str);
		}
		catch (msg:Dynamic)
		{
			Polymod.error(PARSE_MOD_META, 'Error parsing mod metadata file: (${msg})');
			return null;
		}

		var m = new ModMetadata();
		m.title = JsonHelp.str(json, 'title');
		m.description = JsonHelp.str(json, 'description');
		m._author = JsonHelp.str(json, 'author');
		m.contributors = JsonHelp.arrType(json, 'contributors');
		m.homepage = JsonHelp.str(json, 'homepage');
		var apiVersionStr = JsonHelp.str(json, 'api_version');
		var modVersionStr = JsonHelp.str(json, 'mod_version');
		try
		{
			m.apiVersion = apiVersionStr;
		}
		catch (msg:Dynamic)
		{
			Polymod.error(PARSE_MOD_API_VERSION, 'Error parsing API version: (${msg}) ${PolymodConfig.modMetadataFile} was ${str}');
			return null;
		}
		try
		{
			m.modVersion = modVersionStr;
		}
		catch (msg:Dynamic)
		{
			Polymod.error(PARSE_MOD_VERSION, 'Error parsing mod version: (${msg}) ${PolymodConfig.modMetadataFile} was ${str}');
			return null;
		}
		m.license = JsonHelp.str(json, 'license');
		m.metadata = JsonHelp.mapStr(json, 'metadata');

		m.dependencies = JsonHelp.mapVersionRule(json, 'dependencies');
		m.optionalDependencies = JsonHelp.mapVersionRule(json, 'optionalDependencies');

		return m;
	}
}

class Polymod
{
    public static var onError:PolymodError->Void = null;
    private static var assetLibrary:PolymodAssetLibrary = null;

    #if firetongue
    private static var tongue:FireTongue = null;
    #end

    private static var prevParams:PolymodParams = null;

    // ------------------------------------------------------
    // INIT
    // ------------------------------------------------------
    public static function init(params:PolymodParams):Array<ModMetadata>
    {
        if (params.errorCallback != null)
            onError = params.errorCallback;

        var modRoot = params.modRoot;
        if (modRoot == null)
        {
            if (params.fileSystemParams.modRoot != null)
                modRoot = params.fileSystemParams.modRoot;
            else
                modRoot = "./mods";
        }

        if (params.fileSystemParams == null)
            params.fileSystemParams = { modRoot: modRoot };
        if (params.fileSystemParams.modRoot == null)
            params.fileSystemParams.modRoot = modRoot;

        var fileSystem = PolymodFileSystem.makeFileSystem(params.customFilesystem, params.fileSystemParams);

        // Load metadata safely
        var mods = [];
        for (dir in (params.dirs == null ? [] : params.dirs))
        {
            var meta = fileSystem.getMetadata(dir);
            if (meta != null)
                mods.push(meta);
        }

        // Sort by dependencies
        var sorted = (params.skipDependencyChecks)
            ? mods
            : DependencyUtil.sortByDependencies(mods, params.skipDependencyErrors);

        var paths = sorted.map(m -> m.modPath);

        // Initialize library
        assetLibrary = PolymodAssets.init({
            framework: params.framework,
            dirs: paths,
            parseRules: params.parseRules,
            ignoredFiles: params.ignoredFiles,
            customBackend: params.customBackend,
            extensionMap: params.extensionMap,
            frameworkParams: params.frameworkParams,
            fileSystem: fileSystem,
            assetPrefix: params.assetPrefix,
            #if firetongue
            firetongue: params.firetongue,
            #end
        });

        prevParams = params;
        return sorted;
    }

    // ------------------------------------------------------
    // SAFE HScript Registration for iOS
    // ------------------------------------------------------
    public static function registerAllScriptClasses():Void
    {
        #if hscript
        var list = Polymod.assetLibrary.list(TEXT);
        for (p in list)
        {
            if (p.endsWith(".hxc"))
            {
                try {
                    PolymodScriptClass.registerScriptClassByPath(p);
                } catch (e) {
                    Polymod.error(SCRIPT_PARSE_ERROR, 'Failed to parse script: $p ($e)');
                }
            }
        }
        #end
    }

    // ------------------------------------------------------
    // Error helpers
    // ------------------------------------------------------
    public static function error(code:PolymodErrorCode, msg:String, ?o:PolymodErrorOrigin = UNKNOWN)
        if (onError != null) onError(new PolymodError(ERROR, code, msg, o));

    public static function warning(code:PolymodErrorCode, msg:String, ?o:PolymodErrorOrigin = UNKNOWN)
        if (onError != null) onError(new PolymodError(WARNING, code, msg, o));

    public static function notice(code:PolymodErrorCode, msg:String, ?o:PolymodErrorOrigin = UNKNOWN)
        if (onError != null) onError(new PolymodError(NOTICE, code, msg, o));
}
