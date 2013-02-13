package atregen 
{
	import com.bit101.components.CheckBox;
	import com.bit101.components.ComboBox;
	import com.bit101.components.HBox;
	import com.bit101.components.InputText;
	import com.bit101.components.Label;
	import com.bit101.components.NumericStepper;
	import com.bit101.components.PushButton;
	import com.bit101.components.VBox;
	import flash.display.Sprite;
	import flash.events.Event;
	/**
	 * App responsible for converting elevation map/island information into individual quad tree pages and accompanying detailed image data files.
	 * @author Glenn Ko
	 */
	public class ATreGen extends Sprite
	{
		
		private var uiHolder:VBox;
		private var optionsHolder:VBox;
		private var cbox_height:CheckBox;
		
		private var cbox_normal:CheckBox;
		private var cbox_diffuse:CheckBox;
		private var cbox_light:CheckBox;
		private var cbox_tiles:CheckBox;
		private var input_filename:InputText;
		
		public function ATreGen() 
		{
			uiHolder = new VBox(this, 0, 0);
			
			var hLayout:HBox = new HBox(uiHolder);
			var b:PushButton = new PushButton( hLayout, 0, 0, "Load single elevation map/island", uiLoadSingleClick);
			b.width = 200;
			
			
			b = new PushButton( hLayout, 0, 0, "Load multiple elevation maps/islands", uiLoadMultipleClick);
			b.width = 200;
			
		hLayout = new HBox(uiHolder);
			new Label(hLayout, 0, 0, "Grid x,y (columns, rows)"); 
			new NumericStepper(hLayout);
			new NumericStepper(hLayout);
				
			var optionsAllImages:Array = [".jpg", ".png", ".data"];
			
			optionsHolder = new VBox(uiHolder);
			
			
			new Label(optionsHolder, 0, 0, "OPTIONS:"); 
	
			
			hLayout = new HBox(optionsHolder);
			new Label(hLayout, 0, 0, "Page Size:     <-   Sample Size:"); 
			hLayout = new HBox(optionsHolder);
			new NumericStepper(hLayout, 0, 0);
			new NumericStepper(hLayout, 0, 0);
			
			hLayout = new HBox(optionsHolder);
			new Label(hLayout, 0, 0, "Save images as:"); 
			input_filename = new InputText(hLayout, 0, 0, "myterrain");
			hLayout = new HBox(optionsHolder);
			cbox_height = new CheckBox(hLayout, 0, 0, "Height Map", onOptionChecked); 
			new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages);
			hLayout = new HBox(optionsHolder);
			cbox_normal = new CheckBox(hLayout, 0, 0, "Normal Map", onOptionChecked);
			new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages);
			hLayout = new HBox(optionsHolder);
			cbox_diffuse = new CheckBox(hLayout, 0, 0, "Diffuse Map [biomediffuse]", onOptionChecked);
			new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages);
			hLayout = new HBox(optionsHolder);
			cbox_light = new CheckBox(hLayout, 0, 0, "Light Map [slopelighting]", onOptionChecked);
			new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages);
			hLayout = new HBox(optionsHolder);
			cbox_tiles = new CheckBox(hLayout, 0, 0, "Tile Map [biometiles]", onOptionChecked);
			//new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages);
			hLayout = new HBox(optionsHolder);
			new Label(optionsHolder, 0, 0, "Choose a save option:");
			b = new PushButton(optionsHolder, 0, 0, "Save for Sync (.tre/.tres and assets)", onSaveImagesClickSync);
			b.width = 200;
			b = new PushButton(optionsHolder, 0, 0, "Save for ASync (.tre and assets)", onSaveImagesClickASync);
			b.width = 200;
			
			
		}
		
		public function onSaveImagesClickSync(e:Event):void 
		{
			
		}
		public function onSaveImagesClickASync(e:Event):void 
		{
			
		}
		
		private function onOptionChecked(e:Event):void 
		{
			
		}
		
		private function uiLoadMultipleClick(e:Event):void 
		{
			
		}
		
		private function uiLoadSingleClick(e:Event):void 
		{
			
		}
		
	}

}