package play.dialogue;

import audio.GameSound;
import audio.SoundController;
import data.IRegistryEntry;
import data.animation.Animation;
import data.dialogue.SpeakerData;
import data.dialogue.SpeakerRegistry;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import scripting.IScriptedClass.IDialogueScriptedClass;
import scripting.events.ScriptEvent;

class Speaker extends FlxSprite implements IDialogueScriptedClass implements IRegistryEntry<SpeakerData>
{
	/**
	 * The id of this speaker from the registry.
	 */
	public final id:String;
    
    /**
     * The data for this Speaker retrieved from the registry.
     */
    var _data:SpeakerData;
    
    /**
     * The readable name of this speaker, from the data.
     */
    public var speakerName(get, never):String;

    function get_speakerName():String
    {
        return _data?.name ?? 'Unknown Speaker';
    }

    /**
     * Global position offsets that are used for this character on the dialogue box.
     */
    public var globalOffsets(get, never):Array<Float>;

    function get_globalOffsets():Array<Float>
    {
        return _data?.globalOffsets ?? [0, 0];
    }

    /**
     * The list of expressions that this speaker has available.
     */
    var expressions(get, never):Array<SpeakerExpressionData>;
    
    function get_expressions():Array<SpeakerExpressionData>
    {
        return _data?.expressions ?? [];
    }

    /**
     * A list of dialogue sounds this speaker has.
     * This is constructed on create for the dialogue to use when switching speakers, allowing for easy preloading.
     */
    public var dialogueSounds:Array<FlxSound> = [];

	public function new(id:String)
    {
        super();

		this.id = id;
        _data = fetchData(id);
	}
    
    public function onCreate(event:ScriptEvent):Void
    {
        if (dialogueSounds.length == 0 && ((_data?.sounds?.length > 0) ?? false))
        {
            // Speaker has dialogue sounds but they haven't been added yet.
            populateDialogueSounds();
        }
    }

    override function kill():Void
    {        
        clearDialogueSounds();

        super.kill();
    }
    
    public function onDestroy(event:ScriptEvent):Void
    {        
        // Remove dialogue sounds.
        clearDialogueSounds();
    }

    /**
     * Populates this speakers dialogue sound list by loading, and adding each sound.
     */
    public function populateDialogueSounds():Void
    {
        for (sound in _data.sounds)
        {
            var sound:FlxSound = constructDialogueSound(sound);
            dialogueSounds.push(sound);
        }
    }

    public function clearDialogueSounds():Void
    {
        for (sound in dialogueSounds)
        {
            if (sound != null)
            {
                SoundController.remove(cast sound);
                sound.stop();
                sound = null;
            }
            dialogueSounds.remove(sound);
        }
        dialogueSounds = [];
    }

    /**
     * Constructs a dialogue sound from the given asset path.
     * Scripts can use this if they want to further manipulate the sound such as the volume, etc.
     * @return GameSound
     */
    function constructDialogueSound(path:String):GameSound
    {
        var sound:GameSound = SoundController.load(Paths.sound(path));
        sound.volume = 0.8;

        return sound;
    }

    /**
     * Switches the speaker's expression to an new one given an id. 
     * @param expressionId The name of the expression.
     */
    public function switchToExpression(expressionId:String):Void
    {
        // Expression doesn't exist.
        if (!hasExpression(expressionId))
            return;

        var expressionData:SpeakerExpressionData = getExpressionData(expressionId);
        var assetPath:String = expressionData.assetPath;  

        if (expressionData.animation != null)
        {
            this.frames = Paths.getSparrowAtlas('ui/dialogue/portraits/$assetPath');
            Animation.addToSprite(this, expressionData.animation);

            this.animation.play(expressionData.animation.name, true);
        }
        else
        {
            loadGraphic(Paths.image('ui/dialogue/portraits/$assetPath'));
        }

        this.scale.set(expressionData.scale, expressionData.scale);
        this.updateHitbox();

        this.antialiasing = expressionData.antialiasing;

        // Apply position offsets.
        this.x += expressionData.offsets[0] ?? 0.0;
        this.y += expressionData.offsets[1] ?? 0.0;

        if (expressionData.animation != null)
        {
            // Apply animation offsets IN-CASE there's any provided.
            this.offset.x += expressionData.animation.offsets[0] ?? 0.0;
            this.offset.y += expressionData.animation.offsets[1] ?? 0.0;
        }
    }

    /**
     * Does this speaker have the given expression?
     * @param name The name of the expression.
     */
    public function hasExpression(name:String)
    {
        return getExpressionData(name) != null;
    }
    
    /**
     * Fetches the data of an expression given the name of it.
     * @param name The name of the expression.
     * @return A `SpeakerExpressionData` if one is found, else null.
     */
    function getExpressionData(name:String):SpeakerExpressionData
    {
        var expressions:Array<SpeakerExpressionData> = expressions.filter((data:SpeakerExpressionData) -> 
        {
            data.name == name;
        });

        // Return the first entry.
        if (expressions.length >= 1)
            return expressions[0];

        // No expression found.
        return null;
    }

    public function fetchData(id:String):SpeakerData
    {
        return SpeakerRegistry.instance.parseEntryDataWithMigration(id);
    }

    public function onUpdate(event:UpdateScriptEvent):Void {}

    public function onScriptEvent(event:ScriptEvent):Void {}

    public function onScriptEventPost(event:ScriptEvent):Void {}

    public function onPreferenceChanged(event:PreferenceScriptEvent):Void {}

    public function onDialogueStart(event:DialogueScriptEvent):Void {}

    public function onDialogueLine(event:DialogueScriptEvent):Void {}

    public function onDialogueLineComplete(event:DialogueScriptEvent):Void {}
    
    public function onDialogueEnd(event:DialogueScriptEvent):Void {}
    
    public function onDialogueSkip(event:DialogueScriptEvent):Void {}
}
