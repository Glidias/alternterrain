package atregen 
{
	import alternterrain.core.Grid_QuadChunkCornerData;
	import alternterrain.core.HeightMapInfo;
	import alternterrain.core.QuadCornerData;
	import atregen.util.QuadPageInstaller;
	import com.adobe.images.JPGEncoder;
	import com.adobe.images.PNGEncoder;
	import com.bit101.components.CheckBox;
	import com.bit101.components.ComboBox;
	import com.bit101.components.HBox;
	import com.bit101.components.HUISlider;
	import com.bit101.components.InputText;
	import com.bit101.components.Label;
	import com.bit101.components.NumericStepper;
	import com.bit101.components.ProgressBar;
	import com.bit101.components.PushButton;
	import com.bit101.components.Slider;
	import com.bit101.components.VBox;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import net.hires.debug.Stats;
	/**
	 * App responsible for converting elevation map/island information into individual quad tree pages and accompanying detailed image data files.
	 * This program is intended to support loading of 3d models to retrieve elevation data as well.
	 * 
	 * @author Glenn Ko
	 */
	public class ATreGen extends Sprite
	{
		static public const GENERATE_CHECK_COUNT:int = 2;
		static public const HEIGHT_MAP_DONE:String = "heightMapDone";
		
		private var uiHolder:VBox;
		private var optionsHolder:VBox;
		private var cbox_height:CheckBox;
		
		private var cbox_normal:CheckBox;
		private var cbox_diffuse:CheckBox;
		private var cbox_light:CheckBox;
		private var cbox_tiles:CheckBox;
		private var input_filename:InputText;
		private var imageFileExts:String = "*.jpg;*.jpeg;*.png;*.data";
		private var imageFileExtsDesc:String = "*.jpg;*.jpeg;*.png;*.data";
		
		// todo: provide support for models!
		private var elevFileExts:String = "*.jpg;*.jpeg;*.png;*.data;*.isl";
		private var elevFileExtsDesc:String = "*.jpg;*.jpeg;*.png;*.data;*.isl";
		
		private var _singleFileRef:FileReference;
		private var _stats:Stats;
		private var installer:QuadPageInstaller;
		private var _progressBar:ProgressBar;
		private var _progressLabel:Label;
		private var cbox_boxSmoothing:ComboBox;
		private var boxSmoothOptions:Array = ["None", "SmoothEdge", "NoSmoothEdge"];
		private var _heightMaps:Vector.<HeightMapInfo> = new Vector.<HeightMapInfo>();
		private var lbl_hmSize:Label;
		private var _numericAmpl:NumericStepper;
		private var _numericAmplAcross:NumericStepper;
		private var _numericPageSize:NumericStepper;
		private var _lblPageSize:Label;
		
		private var _fileReferences:Vector.<FileReference> = new Vector.<FileReference>(); 
		private var _fileRefDictIndex:Dictionary = new Dictionary();
		
		private var fileExportUIStuff:Array = [];
		
		public function ATreGen() 
		{
			addChild( _stats = new Stats() );
			alignStats();
			
			uiHolder = new VBox(this, 0, 0);
			
			var hLayout:HBox = new HBox(uiHolder);
			var b:PushButton = new PushButton( hLayout, 0, 0, "Load single elevation map/island", uiLoadSingleClick);
			_singleFileRef = new FileReference();
			_singleFileRef.addEventListener(Event.SELECT, onFileSelected);
			_singleFileRef.addEventListener(Event.COMPLETE, onSingleFileLoaded);
			
			b.width = 200;
			
			
		
			
			new Label(hLayout, 0, 0, "Box filter:");
			cbox_boxSmoothing = new ComboBox(hLayout, 0, 0, boxSmoothOptions[0], boxSmoothOptions);
			cbox_boxSmoothing.width = 60;
			new Label(hLayout, 0, 0, "Img255Amplitude:");
			_numericAmpl = new NumericStepper(hLayout, 0, 0, null);
			_numericAmpl.width = 80;
			_numericAmpl.value = 128;
			new Label(hLayout, 0, 0, "across:");
			_numericAmplAcross = new NumericStepper(hLayout, 0, 0, null);
			_numericAmplAcross.minimum = 0;
			_numericAmplAcross.value = 0;
			new Label(hLayout, 0, 0, "tiles.");
		//	cbox_boxSmoothing.width = 160;
			
			hLayout = new HBox(uiHolder);
		//	b = new PushButton( hLayout, 0, 0, "Load multiple elevation maps/islands", uiLoadMultipleClick);
			b.width = 200;
		
			hLayout = new HBox(uiHolder);
			_progressBar = new ProgressBar(hLayout, 0, 0);
			_progressBar.width = 200;
			_progressLabel = new Label(hLayout, 0, 0, "");
				
			var optionsAllImages:Array = ["*.jpg", "*.png", "*.data"];
			var optionsDataOnly:Array = ["*.data"];
			
			optionsHolder = new VBox(uiHolder);
			optionsHolder.visible = false;
			
			new Label(optionsHolder, 0, 0, "OPTIONS:"); 
	
			
			hLayout = new HBox(optionsHolder);
			new Label(hLayout, 0, 0, "Page Size: (2^n tiles) ="); 
			_lblPageSize = new Label(hLayout, 0, 0, "");
			
			hLayout = new HBox(optionsHolder);
			_numericPageSize = new NumericStepper(hLayout, 0, 0, onNumericPageSizeAdjust);
			_numericPageSize.minimum = 8;
			_numericPageSize.value = 99999;
			new Label(hLayout, 0, 0, "Heightmap Size:"); 
			lbl_hmSize = new Label(hLayout, 0, 0, ""); 
			
			hLayout = new HBox(optionsHolder);
			new Label(hLayout, 0, 0, "Save assets as:"); 
			input_filename = new InputText(hLayout, 0, 0, "myterrain");
			hLayout = new HBox(optionsHolder);
			
			var count:int = 0;
			
			fileExportUIStuff.push(
				cbox_height = new CheckBox(hLayout, 0, 0, "Generate height maps", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages),
				getJPEGSlider(hLayout),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_height.name = String(count++);
			
			hLayout = new HBox(optionsHolder);
			fileExportUIStuff.push(
				cbox_normal = new CheckBox(hLayout, 0, 0, "Generate normal maps", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages),
				getJPEGSlider(hLayout),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_normal.name = String(count++);
			
			hLayout = new HBox(optionsHolder);
			fileExportUIStuff.push(
				cbox_diffuse = new CheckBox(hLayout, 0, 0, "Diffuse Map [biomediffuse]", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages),
				getJPEGSlider(hLayout),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_diffuse.name = String(count++);
				
			hLayout = new HBox(optionsHolder);
			fileExportUIStuff.push(
				cbox_light = new CheckBox(hLayout, 0, 0, "Light Map [slopelighting]", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages),
				getJPEGSlider(hLayout),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_light.name = String(count++);
			
			hLayout = new HBox(optionsHolder);
			fileExportUIStuff.push(
				cbox_tiles = new CheckBox(hLayout, 0, 0, "Tile Map [biometiles]", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsDataOnly[0], optionsDataOnly),
				getJPEGSlider(null),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_tiles.name = String(count++);
			
			
			_fileReferences.length = count;
			
			hLayout = new HBox(optionsHolder);
			new Label(optionsHolder, 0, 0, "Choose a save option:");
			b = new PushButton(optionsHolder, 0, 0, "Save for Sync (.tre/.tres only)", onSaveImagesClickSync);
			b.name = "sync";
			b.width = 200;
			b = new PushButton(optionsHolder, 0, 0, "Save for Sync (.tre/.tres and checked maps)", onSaveImagesClickSync);
			b.name = "syncAll";
			b.width = 200;
			b = new PushButton(optionsHolder, 0, 0, "Save for ASync (.tre only)", onSaveImagesClickASync);
			b.name = "async";
			b.width = 200;
			b = new PushButton(optionsHolder, 0, 0, "Save for ASync (.tre and checked maps)", onSaveImagesClickASync);
			b.name = "asyncAll";
			b.width = 200;
			
			
			var len:int = fileExportUIStuff.length;
			for (var i:int = 0; i < len; i += 4) {
				(fileExportUIStuff[i + 1] as IEventDispatcher).addEventListener(Event.SELECT, onFileTypeSelect);
				(fileExportUIStuff[i + 3] as PushButton).visible = false;
			}
			
		}
		
		
		
	
		
		private function onFileTypeSelect(e:Event):void 
		{
			var comboBox:ComboBox = (e.currentTarget as ComboBox);
			var indexer:int = fileExportUIStuff.indexOf(comboBox) / 4;
			fileExportUIStuff[indexer * 4 + 2].visible = comboBox.selectedIndex == 0;
			
		}
		
		
		
		
		private function getJPEGSlider(hLayout:HBox):HUISlider 
		{
			var re:HUISlider =  new HUISlider(hLayout, 0, 0, "JPEG Quality");
			re.value = 80;
			re.minimum = 1;
			re.maximum = 100;
			return re;
		}
		
		private function onNumericPageSizeAdjust(e:Event):void 
		{
			setValPageSize(_numericPageSize.value);
		}
		
		private function setValPageSize(value:Number):void 
		{
			_lblPageSize.text = Math.pow(2, value) + " tiles across.";
		}
		
		private function alignStats():void 
		{
			_stats.x = stage.stageWidth - _stats.width;
		}
		

		
		public function onSaveImagesClickSync(e:Event):void   // will share heightmaps(s) per page,
		{
			var btn:PushButton = (e.currentTarget as PushButton);
			
			var len:int = _heightMaps.length;
			var i:int ;
			for (i= 0; i < len; i++) {
				// stich neighboring heightmaps
			}
			
			
			for (i = 0; i < len; i++) {  // todo: push  this to serial list
				installHeightMap(_heightMaps[i]);
			}
			

			
			if (btn.name === "syncAll") {  // include checked maps per page
				
			}
		}
		
		
		public function onSaveImagesClickASync(e:Event):void   // will always split heightmap(s) per page
		{
			var btn:PushButton = (e.currentTarget as PushButton);
			
			var len:int = _heightMaps.length;
			for (var i:int = 0; i < len; i++) {
				// stitch neighboring heightmaps
			}
			
			// split heightmaps if required to form new grid of heightmaps
			
			
			// install all heights that were splitted per page, each page contains their own unique heightMap reference.
			
			// according to heightmap grid, save out grid of quadtree pages 
			//Grid_QuadChunkCornerData
			
			
			
			if (btn.name === "asyncAll") {  // include checked maps per page
				
			}
		}
		
		
		// Individual saving of maps per page
		private function onAssetFileBtnSave(e:Event):void 
		{
			var btn:PushButton = (e.currentTarget as PushButton);
			var indexer:int = fileExportUIStuff.indexOf(btn) / 4;
			
			
			
		}
		
		
		
		private function onOptionChecked(e:Event):void 
		{
			var checkbox:CheckBox = (e.currentTarget as CheckBox);
			var index:int = int(checkbox.name);
			
			var fileRef:FileReference;
				
			if (checkbox.selected) {
				if (index < GENERATE_CHECK_COUNT ) {
					
					checkSaveBtnVis();
					return;
				
				}
				if (_fileReferences[index] == null) {
					_fileReferences[index] = fileRef = new FileReference();
					fileRef.addEventListener(Event.SELECT, onFileSelected);
					fileRef.addEventListener(Event.COMPLETE, onMapFileLoaded);
					_fileRefDictIndex[fileRef] = index;
					//fileRef.name
				}
				else fileRef = _fileReferences[index];	
				
				var fileTypes:String = (fileExportUIStuff[index * 4 + 1] as ComboBox).items.join(";");
				fileRef.browse([new FileFilter(fileTypes, fileTypes)]);
				
				checkbox.selected = false;
				
				
			}
			else {
				
				
			}
			
			checkSaveBtnVis();
		
			
			
		}
		
		private function onMapFileLoaded(e:Event):void 
		{
			_progressLabel.text = "Done.";
			var index:int = _fileRefDictIndex[e.currentTarget];
			fileExportUIStuff[index * 4].selected = true;
			checkSaveBtnVis();
		}
		
		private function checkSaveBtnVis():void 
		{
			var len:int = fileExportUIStuff.length;
			for (var i:int = 0; i < len; i+=4) {
				fileExportUIStuff[i + 3].visible = fileExportUIStuff[i].selected;
			}
		}
		
		private function uiLoadMultipleClick(e:Event):void 
		{
			
		}
		
		private function uiLoadSingleClick(e:Event):void 
		{
			
			_singleFileRef.browse( [new FileFilter(elevFileExtsDesc, elevFileExts)] );
		}
		
		private function onFileSelected(e:Event):void 
		{
			_progressLabel.text = "Please wait";
			(e.currentTarget as FileReference).load();
			
		}
		
		private function onSingleFileLoaded(e:Event):void 
		{
			
			var tilesAcross:int = 256;
			//var bitmapData:BitmapData = new BitmapData(tilesAcross+1, tilesAcross+1, false, 0);
			//bitmapData.perlinNoise(256, 256, 8, 211, false, true, 7, true);
	
			
		
		//	/*
		
			
			var bytes:ByteArray = _singleFileRef.data;
			tilesAcross = Math.sqrt(bytes.length);
			
			
			if ( !QuadCornerData.isBase2(tilesAcross)) {
				
				bytes.uncompress();
				tilesAcross = Math.sqrt(bytes.length);
				if (!QuadCornerData.isBase2(tilesAcross)) throw new Error("Failed to get base2 size of heightmap tiles:!");
			}
			
			lbl_hmSize.text = tilesAcross + " tiles across."
			var heightMap:HeightMapInfo = HeightMapInfo.createFromByteArray(bytes, tilesAcross, 0, 0, _numericAmpl.value * ( _numericAmplAcross.value != 0 ? tilesAcross/_numericAmplAcross.value : 0 ), 0);  // TODO: interface to adjust height multiplier

			//heightMap = HeightMapInfo.createFromBmpData( bitmapData, 0, 0, 128, 0);
			if (cbox_boxSmoothing.selectedIndex > 0) heightMap.BoxFilterHeightMap( cbox_boxSmoothing.selectedIndex < 2 );  
			
			///*
			
			_numericPageSize.maximum = Math.log( tilesAcross) * Math.LOG2E;
			setValPageSize(_numericPageSize.value);
			
			// TODO: support grids of multiple heightmaps
			_heightMaps[0] = heightMap;
			
			optionsHolder.visible = true;
			_progressLabel.text = "Done.";
			_progressBar.value = 1;
			
		}
		
		private function installHeightMap(heightMap:HeightMapInfo):void {
			installer = new QuadPageInstaller();
			installer.install(heightMap, 256, Math.pow(2, _numericPageSize.value), onInstallProgress);
			installer.addEventListener(Event.COMPLETE, onInstallerComplete);
		}
		
		private function onInstallerComplete(e:Event):void 
		{
			installer.removeEventListener(Event.COMPLETE, onInstallerComplete);
			_progressLabel.text = "Done."
			dispatchEvent( new Event(HEIGHT_MAP_DONE) );
			
			
		}
		
		private function onInstallProgress():void 
		{
			_progressBar.value = (installer.serialList.position /  installer.serialList.numCommands);
			_progressLabel.text = "Processing:" + installer.serialList.position + " / " + installer.serialList.numCommands + " of .tre file";
		}
		
	}

}