package terraingen.island 
{
	import alternsector.utils.mapping.MarchingSquaresPackage;
	import com.bit101.components.ComboBox;
	import com.bit101.components.HBox;
	import com.bit101.components.InputText;
	import com.bit101.components.Label;
	import com.bit101.components.NumericStepper;
	import com.bit101.components.PushButton;
	import com.bit101.components.VBox;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class MapGen2Main extends MovieClip
	{
		private var uiInitial:VBox;
		private var cb:ComboBox;
		private var numStepper:NumericStepper;
		private var seedField:InputText;
		
		[SWF(width="800", height="600", frameRate=60)]
		public function MapGen2Main() 
		{
			MarchingSquaresPackage;
			haxe.init(this);
			
			uiInitial = new VBox(this, 0, 0);
			var hBox:HBox;
			
			hBox = new HBox(uiInitial, 0, 0);
			new Label(hBox, 0, 0, "Island seed initial");
			seedField = new InputText(hBox, 0, 0, "85882-1", onInputSeedChange );
			mapgen2.islandSeedInitial = seedField.text;
			hBox = new HBox(uiInitial, 0, 0);
			new Label(hBox, 0, 0, "Island Generate Size");
			mapgen2.EXPORT_SIZE = 512;
			mapgen2.SIZE = 512;
			var options:Array = ["Tiny (256x256)", "Small (512x512)", "Medium (1024x1024)", "Large (2048x2048)"];
			cb = new ComboBox(hBox, 0, 0, options[1], options);
			cb.width = 200;
			cb.addEventListener(Event.SELECT, onComboSelect);
			
			hBox = new HBox(uiInitial);
			numStepper = new NumericStepper(hBox,0,0, onNumericStepperChange);
			numStepper.value = Map.NUM_POINTS;
			
			new PushButton(uiInitial, 0, 0, "Start!", start);
		}
		
		private function onInputSeedChange(e:Event):void 
		{
			mapgen2.islandSeedInitial = seedField.text;
		}
		
		private function onNumericStepperChange(e:Event):void 
		{
			Map.NUM_POINTS = numStepper.value;
		}
		
		private function onComboSelect(e:Event):void 
		{
			var index:int = cb.selectedIndex;
			if (index === 0) {
				mapgen2.EXPORT_SIZE = 256;
				mapgen2.SIZE = 256;
			}
			else if (index === 1) {
				mapgen2.EXPORT_SIZE = 512;
				mapgen2.SIZE = 512;
			}
			else if (index === 2) {
				mapgen2.EXPORT_SIZE = 1024;
				mapgen2.SIZE = 1024;
			}
			else {
				mapgen2.EXPORT_SIZE = 2048;
				mapgen2.SIZE = 2048;
			}
		}
		
		public function start(e:Event=null):void 
		{
			removeChild(uiInitial);
			addChild( new mapgen2() );
		}
		
	}

}