package atregen 
{
	import alternterrain.core.Grid_QuadChunkCornerData;
	import alternterrain.core.HeightMapInfo;
	import alternterrain.core.QuadCornerData;
	import alternterrain.resources.LoadAliases;
	import alternterrain.util.BitmapDataReadWrite;
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
	import com.tartiflop.PlanarDispToNormConverter;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.filters.BlurFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import jp.progression.commands.Func;
	import jp.progression.commands.lists.SerialList;
	import jp.progression.commands.Wait;
	import mx.graphics.codec.JPEGEncoder;
	import net.hires.debug.Stats;

	/**
	 * App responsible for converting elevation map/island information into individual quad tree pages and accompanying detailed image data files.
	 * This program is intended to support loading of 3d models to retrieve elevation data as well.
	 * 
	 * @author Glenn Ko
	 */
	public class ATreGen extends Sprite
	{
		static public const GENERATE_CHECK_COUNT:int = 1;
		static public const HEIGHT_MAP_DONE:String = "heightMapDone";
		static public const SUPPORTED_MAP_TYPES:Array = [
					"height",
					"normal",
					"diffuse",
					"light",
					"tile"	
		]
		public static const GRAY_SCALES:Array = [
			true,
			false,
			false,
			true,
			false
		]
		static private const MIN_HEIGHT:Number = -32768;
		static private const MAX_HEIGHT:Number = 32768;
		
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
		

		private var elevFileExts:String = "*.jpg;*.jpeg;*.png;*.data;*.hmi;";
		private var elevFileExtsDesc:String = "*.jpg;*.jpeg;*.png;*.data;*.hmi;";
		
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
		
	
		private var _toSaveFiles:Vector.<ByteArray> = new Vector.<ByteArray>();
		private var _toSaveFileNames:Vector.<String> = new Vector.<String>();
		
		private var _fileReferences:Vector.<FileReference> = new Vector.<FileReference>(); 
		private var _loadedImgReferences:Vector.<BitmapData> = new Vector.<BitmapData>();
		private var _fileRefDictIndex:Dictionary = new Dictionary();
		
		private var fileExportUIStuff:Array = [];
		private var _payload:SerialList;
		private var _splittedHeightMaps:Vector.<HeightMapInfo>;
		private var _splitSrcDatas:Array;
		private var _numericLowestHeight:NumericStepper;
		private var _highestPossibleHeight:Number = -Number.MAX_VALUE;
		private var _selectOffsetY:int=0;
		private var _selectOffsetX:int = 0;
		
		public function ATreGen() 
		{
			new LoadAliases();
			
		
			
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
			new Label(hLayout, 0, 0, "tiles. From altitude:");
			_numericLowestHeight = new NumericStepper(hLayout, 0, 0, null);
			_numericLowestHeight.minimum = MIN_HEIGHT;
			_numericLowestHeight.maximum = MAX_HEIGHT;
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
				cbox_normal = new CheckBox(hLayout, 0, 0, "Normal map (slopenormals)", onOptionChecked),
				new ComboBox(hLayout, 0, 0, optionsAllImages[0], optionsAllImages),
				getJPEGSlider(hLayout),
				new PushButton(hLayout, 0, 0, "Save maps", onAssetFileBtnSave)
			);
			cbox_normal.name = String(count++);
			cbox_normal.addEventListener(Event.CHANGE, onNormalBoxChanged);
			
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
			_loadedImgReferences.length = count;
			
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
				(fileExportUIStuff[i + 1] as ComboBox).selectedIndex = 0;
					(fileExportUIStuff[i + 1] as IEventDispatcher).addEventListener(Event.SELECT, onFileTypeSelect);
				(fileExportUIStuff[i + 3] as PushButton).visible = false;
			}
			
		}
		
		private function onNormalBoxChanged(e:Event):void 
		{
			if ( !cbox_normal.selected ) {
				_loadedImgReferences[1] = null;
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
			
			_payload = new SerialList();
			for (i = 0; i < len; i++) {  
				
				_payload.addCommand(
				
					new Func(installHeightMap, [_heightMaps[i]], this, HEIGHT_MAP_DONE, null),
					new Wait(.5)
				);
			}
		
			if (btn.name === "syncAll") {  // include checked maps per page
				pushAllMapAssetsPerPage();

			}
			
			_payload.addCommand( new Func(saveAllToSaveFiles) );
			
			_payload.execute();
		}
		
		private function pushAllMapAssetsPerPage():void 
		{
			var len:int = _heightMaps.length;
			var i:int ;
				if (cbox_height.selected) {
					for (i = 0; i < len; i++) {
						_payload.addCommand(
							new Func(generateHeightMaps, [_heightMaps[i]]),
							new Wait(.8)
						);
					}
				}
				
				if (cbox_normal.selected) {
					for (i = 0; i < len; i++) {
						_payload.addCommand(
							new Func(generateNormalMaps, [_heightMaps[i]]),
							new Wait(.7)
						);
					}
				}
				
				var types:Array = SUPPORTED_MAP_TYPES;
				var kLen:int = fileExportUIStuff.length/4;
				for (var k:int = 2; k < kLen; k++) {
					if (fileExportUIStuff[k*4].selected) {
						for (i = 0; i < len; i++) {
							_payload.addCommand(
								new Func(generateMapsOf, [k, types[k], _heightMaps[i]] ),
								new Wait(.7)
							);
						}
					}
				}
		}
		
		private function getFileNameAt(index:int, type:String, location:Point=null):String {
			var comboBox:ComboBox = fileExportUIStuff[index * 4 + 1];
			var fileExt:String = comboBox.selectedItem.toString().split(".").pop();

			return location == null ? input_filename.text + "_" + type + "." + fileExt : input_filename.text+"_"+type+"_"+location.x +"_"+location.y+"."+fileExt;
		}
		
		private function getQualityAt(index:int):Number 
		{
			var slider:HUISlider = fileExportUIStuff[index * 4 + 2];
			return slider.value;
		}
		
		private function pushNormMap(hm:HeightMapInfo, location:Point=null):void {
			
			//var tempData:BitmapData = getHeightBitmapData(hm);
			
			var normalMapper:PlanarDispToNormConverter = new PlanarDispToNormConverter();
			normalMapper.heightMap = hm;
			//normalMapper.setDisplacementMapData(tempData);
			normalMapper.setDirection("z");
			//normalMapper.heightMapMultiplier = 1 / 128;
			normalMapper.setAmplitude(1);
			
		
			var normalMap:Bitmap = normalMapper.convertToNormalMap();
			normalMap.bitmapData.applyFilter(normalMap.bitmapData, normalMap.bitmapData.rect, new Point(), new BlurFilter(3,3,4) );
			
			var filename:String = getFileNameAt(1, "normal", location);
			
			
			pushBitmapData(filename, normalMap.bitmapData, false);
			
			//tempData.dispose();
		}
		
		
		
		private function pushBitmapData(filename:String, bitmapData:BitmapData, grayscale:Boolean):void {
			
			var data:ByteArray;
			var ext:String = filename.split(".").pop();
			if ( ext === "jpg" || ext === "png" ) {
				if (ext === "jpg") {
					data = new JPGEncoder( getQualityAt(1) ).encode( bitmapData);
				}
				else {
					data = PNGEncoder.encode(bitmapData);
				}
				_toSaveFileNames.push(filename);
				_toSaveFiles.push(data);
				
				bitmapData.dispose();
			}
			else if (ext === "data") {
				if (!grayscale) {
					BitmapDataReadWrite.writeSquareBmpData( data = new ByteArray(), bitmapData);
				}
				else {
					BitmapDataReadWrite.writeSquareBmpDataGrayscale( data = new ByteArray(), bitmapData);
				}
				data.compress();
				_toSaveFileNames.push(filename);
				_toSaveFiles.push(data);
			}
		}
		
		private function getHeightBitmapData(hm:HeightMapInfo):BitmapData {  //  consider scaling down?
			var across:int = hm.RowWidth - 1;
			var vec:Vector.<uint> = new Vector.<uint>(across * across, true);
			for (var y:int = 0; y < across; y++ ) {
				for (var x:int = 0; x < across; x++) {
					var grayscale:uint = Math.round( (hm.Data[ hm.RowWidth * y + x] - _numericLowestHeight.value) / (_highestPossibleHeight- _numericLowestHeight.value) * 255 );
					vec[y * across + x] = (grayscale << 16) | (grayscale << 8) | grayscale;	
				}
			}
			var bmpData:BitmapData = new BitmapData(across, across, false, 0);
			bmpData.setVector(bmpData.rect, vec);
			return bmpData;
		}
		
		
		private function pushHeightMap(hm:HeightMapInfo, location:Point=null):void {
		
			var bitmapData:BitmapData = getHeightBitmapData(hm);
			
			var data:ByteArray;
			var filename:String = getFileNameAt(0, "height", location);
			pushBitmapData(filename, bitmapData, true);
			
		}
		
		private function splitSrcData(srcData:*, grayscale:Boolean = false):void {
			
			
			
			if (srcData is BitmapData) {
				_splitSrcDatas = splitBitmapdata(srcData as BitmapData);
			}
			else {  // assumed is ByteArray
				
				splitSrcBytes(srcData, grayscale);
				
			}
			
			
		}
		
		private function splitSrcBytes(srcData:ByteArray, grayscale:Boolean):void 
		{
			var divisorTiles:int = Math.pow(2, _numericPageSize.value);
			
			_splitSrcDatas = [];
			
			srcData.position = 0;
			
			var across:int = grayscale ? srcData.length : srcData.length / 3;
		
			across = Math.sqrt(across);
			
			var acrossDiv:int = across/divisorTiles;
			_splitSrcDatas.length = acrossDiv * acrossDiv;
			
			
			var limitX:int;
			var limitY:int;
			var startX:int;
			var startY:int;
			
		
			var yi:int;
			var xi:int;
			var data:ByteArray;
			
			if (!grayscale) {
				for (yi = 0; yi < acrossDiv; yi++) {
					for (xi = 0; xi < acrossDiv; xi++) {
						startX = xi * divisorTiles;
						startY = yi * divisorTiles;
						limitX = startX +  divisorTiles;
						limitY = startY +  divisorTiles;
						data = new ByteArray();
						

						for (y = startY; y < limitY; y++) {
							for (x = startX; x < limitX; x++) {
								srcData.position = (y * across + x) * 3;
								data.writeByte( srcData.readUnsignedByte() );
								data.writeByte( srcData.readUnsignedByte() );
								data.writeByte( srcData.readUnsignedByte() );
							}
						}
						data.compress();
						_splitSrcDatas[yi * acrossDiv + xi] = data;
					}
				}
			
			}
			else {
				for (yi = 0; yi < acrossDiv; yi++) {
					for (xi = 0; xi < acrossDiv; xi++) {
						startX = xi * divisorTiles;
						startY = yi * divisorTiles;
						limitX = startX +  divisorTiles;
						limitY = startY +  divisorTiles;
						data = new ByteArray();
						for (y = startY; y < limitY; y++) {
							for (x = startX; x < limitX; x++) {
								srcData.position = (y * across + x);
								data.writeByte( srcData.readUnsignedByte() );
							}
						}
						data.compress();
						_splitSrcDatas[yi * acrossDiv + xi] = data;
					}
				}
			}
			
			
		
			
			
			
			srcData.position = 0;
			
		}
		
		private function pushSplittedSrcData(index:int, type:String ):void {
			var len:int = _splitSrcDatas.length;
			var across:int = Math.sqrt(len);
			for (var y:int = 0; y < across; y++) {
				for (var x:int = 0; x < across; x++) {
					var data:* = _splitSrcDatas[y*across+ x];
					_payload.insertCommand( 
						new Func(pushSrcData, [data, index, type, new Point(_selectOffsetX + x, _selectOffsetY + y) ]),
						new Wait(.5)
					
					);
		
				}
			}
		}
	
		private function pushSrcData(srcData:*, index:int, type:String,  location:Point = null):void {
			var filename:String = getFileNameAt(index, type, location);
			if (srcData is BitmapData) {
				pushBitmapData(filename, srcData as BitmapData, GRAY_SCALES[index]); 
				
			}
			else { // assume bytearray
				_toSaveFileNames.push(filename);
				_toSaveFiles.push(srcData);
			}
		}
		
		private function generateMapsOf(index:int, type:String, heightMap:HeightMapInfo):void {
			var fileRef:FileReference = _fileReferences[index];
			var srcData:* = fileRef != null ? fileRef.data : null;
			
			if (srcData == null) throw new Error("srcData is null from FileReference!:" + fileRef);
			
			if ( _loadedImgReferences[1] != null) {
				srcData = _loadedImgReferences[1];
			}
			
			if ( (heightMap.RowWidth - 1) / (1 << int(_numericPageSize.value)) > 1 ) { 
				_progressLabel.text = "Processing "+type+" maps...";

				_payload.insertCommand( new Func(splitSrcData, [srcData, false] ), new Wait(.5), new Func(pushSplittedSrcData, [index, type]));

				
			}
			else {
				_progressLabel.text = "Processing "+type+" map.";
				_payload.insertCommand( new Func(pushSrcData, [srcData, index,type]) );
			}
		}
		
		private function generateNormalMaps(heightMap:HeightMapInfo):void {
			var fileRef:FileReference = _fileReferences[1];
			var srcData:* = fileRef != null ? fileRef.data : null;
			if (srcData != null && _loadedImgReferences[1] != null) {
				srcData = _loadedImgReferences[1];
			}
			
			
			if ( (heightMap.RowWidth - 1) / (1 << int(_numericPageSize.value)) > 1 ) { 
				_progressLabel.text = "Processing normal maps...";
				if (srcData == null) {
					_payload.insertCommand( 
						new Func(splitHeightMap, [heightMap]),
						new Wait(.5),
						new Func(generateNormalMapsFromHeightMaps)
					 );
					
				}
				else {
				
					_payload.insertCommand( new Func(splitSrcData, [srcData, false] ),  
						new Wait(.5), 
						new Func(pushSplittedSrcData, [1, "normal"])
						);

				}
			}
			else {
				_progressLabel.text = "Processing normal map.";
				if (srcData == null) {
					_payload.insertCommand( new Func(pushNormMap, [heightMap]) );
				}
				else {
					_payload.insertCommand( new Func(pushSrcData, [srcData, 1, "normal"]) );
				}
			}
		
		}
		
		private function generateNormalMapsFromHeightMaps():void 
		{
			
				
			var len:int = _splittedHeightMaps.length;
			var across:int = Math.sqrt(len);
			for (var y:int = 0; y < across; y++) {
				for (var x:int = 0; x < across; x++) {
					var hm:HeightMapInfo = _splittedHeightMaps[y*across + x];
					_payload.insertCommand( 
						new Func(pushNormMap, [hm, new Point(_selectOffsetX + x, _selectOffsetY + y) ]) ,
						new Wait(.5));
				
				}
			}
			
	
		}
		
		private function generateHeightMaps(heightMap:HeightMapInfo):void {
			if ( (heightMap.RowWidth - 1) / (1 << int(_numericPageSize.value)) > 1 ) { 
				_progressLabel.text = "Processing height maps...";
				_payload.insertCommand( new Func(splitHeightMap, [heightMap] ), new Wait(.5), new Func(generateHeightMapsFromHeightMaps) );

			}
			else {
				_progressLabel.text = "Processing height map.";
				_payload.insertCommand( new Func(pushHeightMap, [heightMap]) );
			}
		}
		
		private function generateHeightMapsFromHeightMaps():void 
		{
			var len:int = _splittedHeightMaps.length;
			var across:int = Math.sqrt(len);
			for (var y:int = 0; y < across; y++) {
				for (var x:int = 0; x < across; x++) {
					var hm:HeightMapInfo = _splittedHeightMaps[y*across+ x];
					_payload.insertCommand( 
					new Func(pushHeightMap, [hm, new Point(_selectOffsetX + x, _selectOffsetY + y) ]) ,
					new Wait(.5) );
					
				}
			}
		}
		
		
		private function saveAllToSaveFiles():void 
		{
			
			
			_progressLabel.text = "Done";
			
			if(_toSaveFiles.length > 0){
				saveTopmostFile();
			}
			
			
			_splittedHeightMaps = null;
			_splitSrcDatas = null;
			_payload.dispose();
			_payload = null;	
		}
		
		private function onFileSaved(e:Event):void
		{
			FileReference(e.currentTarget).removeEventListener(Event.COMPLETE, onFileSaved);
				
			_toSaveFiles.pop();
			_toSaveFileNames.pop();
			if(_toSaveFiles.length > 0){
				saveTopmostFile();
			}
		}
		
		private function saveTopmostFile():void 
		{
			var fileRef:FileReference = new FileReference();
			fileRef.addEventListener(Event.COMPLETE, onFileSaved);
			fileRef.save( _toSaveFiles[_toSaveFiles.length - 1], _toSaveFileNames[_toSaveFileNames.length - 1] );
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
				pushAllMapAssetsPerPage();
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
					//fileRef.addEventListener(Event.CANCEL, onFileCanceled);
					fileRef.addEventListener(Event.SELECT, onFileSelected);
					fileRef.addEventListener(Event.COMPLETE, onMapFileLoaded);
					_fileRefDictIndex[fileRef] = index;
					//fileRef.name
				}
				else fileRef = _fileReferences[index];	
				
				var fileTypes:String = (fileExportUIStuff[index * 4 + 1] as ComboBox).items.join(";");
				fileRef.browse([new FileFilter(fileTypes, fileTypes)]);
				
				if (checkbox != cbox_normal) checkbox.selected = false;
				
				
			}
			else {
				
				
			}
			
			checkSaveBtnVis();
		
			
			
		}
		
		/*
		private function onFileCanceled(e:Event):void 
		{
		
		}
		*/
		
		
		private function splitHeightMap(val:HeightMapInfo):void {
			var divisorTiles:int = Math.pow(2, _numericPageSize.value);
			var splitList:Vector.<HeightMapInfo> = new Vector.<HeightMapInfo>();
			

			var acrossDiv:int = (val.RowWidth - 1)/divisorTiles;
			splitList.length = acrossDiv * acrossDiv;
			var limitX:int;
			var limitY:int;
			var startX:int;
			var startY:int;
			
		
			
			for (var yi:int = 0; yi < acrossDiv; yi++) {
				for (var xi:int = 0; xi < acrossDiv; xi++) {
					startX = xi * divisorTiles;
					startY = yi * divisorTiles;
					limitX = startX +  divisorTiles + 1;
					limitY = startY +  divisorTiles + 1;
					var hm:HeightMapInfo = new HeightMapInfo();
					hm.Data = new Vector.<int>((divisorTiles + 1) * (divisorTiles + 1), true);
					hm.RowWidth = hm.XSize = hm.ZSize =  divisorTiles + 1;
					hm.XOrigin = val.XOrigin + startX;
					hm.ZOrigin = val.ZOrigin  +startY;


					for (y = startY; y < limitY; y++) {
						for (x = startX; x < limitX; x++) {
							hm.Data[ (y - startY) * hm.RowWidth + (x - startX) ] = val.Data[y*val.RowWidth + x];
						}
					}
					splitList[yi * acrossDiv + xi] = hm;
				}
			}
			
			
			
			_splittedHeightMaps = splitList;
			
		
		}
		
		
		private function splitBitmapdata(val:BitmapData):Array {
			var splitList:Array = [];
			var divisorTiles:int = Math.pow(2, _numericPageSize.value);
			var acrossDiv:int = val.width / divisorTiles;
			divisorTiles = val.width / acrossDiv;
			var rect:Rectangle = new Rectangle(0, 0, divisorTiles, divisorTiles);
			var pt:Point = new Point();
			
			var bmpData:BitmapData;
			for (var yi:int = 0; yi < acrossDiv; yi++) {
				for (var xi:int = 0; xi < acrossDiv; xi++) {
					bmpData = new BitmapData(divisorTiles, divisorTiles, false, 0);
					rect.x = xi * divisorTiles;
					rect.y = yi * divisorTiles;
					bmpData.copyPixels(val, rect, pt);
					splitList.push(bmpData);
				}
			}
			
			return splitList;
			
			
		}
		
		private var _syncMapLoadIndex:int = -1;
		private function onMapFileLoaded(e:Event):void 
		{
		
			var index:int = _fileRefDictIndex[e.currentTarget];
			_syncMapLoadIndex = index;
			
			// check format. convert to jpeg or png if required
			var fileRef:FileReference = _fileReferences[index];
			var ext:String = fileRef.name.split(".").pop();
			if (ext === "jpg" || ext === "jpeg" || ext ==="png" ) {
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
				loader.loadBytes(fileRef.data);
			}
			else if (ext === "data") {
				fileRef.data.uncompress();
				notifyMapLoadDone();
			}
			else {
				throw new Error("Could not resolve file extension type of file reference!:"+fileRef.name);
				fileRef.data = null;
			}
			
		
		}
		
		private function onLoadComplete(e:Event):void 
		{
			var loaderInfo:LoaderInfo = (e.currentTarget as LoaderInfo);
			loaderInfo.removeEventListener(e.type, onLoadComplete);
		//	_fileReferences[_syncMapLoadIndex].data = loaderInfo.content;
			_loadedImgReferences[_syncMapLoadIndex] = (loaderInfo.content as Bitmap).bitmapData;
			notifyMapLoadDone();
		}
		
		private function notifyMapLoadDone():void 
		{
			_progressLabel.text = "Done loading map.";
			fileExportUIStuff[_syncMapLoadIndex * 4].selected = true;
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
			//var bitmapData:BitmapData = new BitmapData(tilesAcross+1, tilesAcross+1, false, 0);
			//bitmapData.perlinNoise(256, 256, 8, 211, false, true, 7, true);
	
			// TODO: generate from bitmapData support as well
		
		//	/*
		
		
			var tilesAcross:int;
			var heightMap:HeightMapInfo;
			
			var bytes:ByteArray = _singleFileRef.data;
			var ext:String = _singleFileRef.name.split(".").pop();
			
			if (ext === "data") {
				var potentialMaxHeight:Number;
				tilesAcross = Math.sqrt(bytes.length);
				
				if ( !QuadCornerData.isBase2(tilesAcross)) {
					
					bytes.uncompress();
					tilesAcross = Math.sqrt(bytes.length);
					if (!QuadCornerData.isBase2(tilesAcross)) throw new Error("Failed to get base2 size of heightmap tiles:!");
				}
				
				var mult:Number = _numericAmpl.value * ( _numericAmplAcross.value != 0 ? tilesAcross / _numericAmplAcross.value : 1 );
				potentialMaxHeight =  _numericLowestHeight.value + mult * 255;
				if ( potentialMaxHeight > MAX_HEIGHT) {
					_progressLabel.text = "Heightmap loading potentially exceeds MAX_HEIGHT value of: " + MAX_HEIGHT + ". Please try again with different settings.";
					return;
				}
			
				if (potentialMaxHeight > _highestPossibleHeight) _highestPossibleHeight = potentialMaxHeight;
				// TODO: store lowestPossibleHeight as well
				
				lbl_hmSize.text = tilesAcross + " tiles across.";
		
				heightMap = HeightMapInfo.createFromByteArray(bytes, tilesAcross, 0, 0, mult, _numericLowestHeight.value); 
				
				finaliseHeightMap(heightMap);
			}
			else if (ext === "hmi") {
				bytes.uncompress();
				heightMap = new HeightMapInfo();
				heightMap.readExternal(bytes);
				
				tilesAcross = heightMap.RowWidth - 1;
				
				finaliseHeightMap(heightMap);
				
				
			}
			else {   // assume image
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onSingleFileImgLoaded);
			}
		
			
			
		}
		
		private function onSingleFileImgLoaded(e:Event):void 
		{
			
			(e.currentTarget as IEventDispatcher).removeEventListener(e.type, onSingleFileImgLoaded);
			var bmpData:BitmapData = ((e.currentTarget as LoaderInfo).content as Bitmap).bitmapData;
			
			var tilesAcross:int = bmpData.width;
			var mult:Number = _numericAmpl.value * ( _numericAmplAcross.value != 0 ? tilesAcross / _numericAmplAcross.value : 1 );
				var potentialMaxHeight:int =  _numericLowestHeight.value + mult * 255;
				if ( potentialMaxHeight > MAX_HEIGHT) {
					_progressLabel.text = "Heightmap loading potentially exceeds MAX_HEIGHT value of: " + MAX_HEIGHT + ". Please try again with different settings.";
					return;
				}
			
			var hm:HeightMapInfo = HeightMapInfo.createFromBmpData(bmpData, 0, 0, mult, _numericLowestHeight.value);
			
			finaliseHeightMap(hm);
		}
		
		private function finaliseHeightMap(heightmap:HeightMapInfo):void {
			_numericPageSize.maximum = Math.round( Math.log( heightmap.RowWidth-1) * Math.LOG2E );
			setValPageSize(_numericPageSize.value);
		
			// TODO: support grids of multiple heightmaps
			
			if (cbox_boxSmoothing.selectedIndex > 0) heightmap.BoxFilterHeightMap( cbox_boxSmoothing.selectedIndex < 2 );  
			_heightMaps[0] = heightmap;
			
			optionsHolder.visible = true;
			_progressLabel.text = "Done.";
			_progressBar.value = 1;
		}
		
	
		private function installHeightMap(heightMap:HeightMapInfo):void {
			installer = new QuadPageInstaller();
			_progressLabel.text = "Installing heightmap...";
			installer.install(heightMap, 256, Math.pow(2, _numericPageSize.value), onInstallProgress);
			installer.addEventListener(Event.COMPLETE, onInstallerComplete);
		}
		
		private function onInstallerComplete(e:Event):void 
		{
			installer.removeEventListener(Event.COMPLETE, onInstallerComplete);
			_progressLabel.text = "Done."
			
			var data:ByteArray = new ByteArray();
			var fileName:String = input_filename.text;
			if (installer.installedPages.totalPagesAcross == 1) {
				fileName += ".tre";
				installer.installedPages.pageGrid[0].heightMap = installer.installedPages.heightMap;
				
				
				installer.installedPages.pageGrid[0].writeExternal(data);
				
				data.compress();
				_toSaveFiles.push(data);
			}
			else {
				installer.installedPages.writeExternal(data);
				data.compress();
				_toSaveFiles.push(data);
				fileName += ".tres";
			}
			
			_toSaveFileNames.push(fileName );
			
			dispatchEvent( new Event(HEIGHT_MAP_DONE) );
		}
		
		private function onInstallProgress():void 
		{
			_progressBar.value = (installer.serialList.position /  installer.serialList.numCommands);
			_progressLabel.text = "Processing:" + installer.serialList.position + " / " + installer.serialList.numCommands + " of .tre file";
		}
		
	}

}