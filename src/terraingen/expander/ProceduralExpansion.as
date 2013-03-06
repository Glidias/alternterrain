package terraingen.expander 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrain.util.BitmapDataReadWrite;
	import alternterrainxtras.util.ITerrainProcess;
	import com.adobe.images.JPGEncoder;
	import com.bit101.components.CheckBox;
	import com.bit101.components.ComboBox;
	import com.bit101.components.HBox;
	import com.bit101.components.Label;
	import com.bit101.components.NumericStepper;
	import com.bit101.components.ProgressBar;
	import com.bit101.components.PushButton;
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
	import flash.events.IOErrorEvent;
	import flash.filters.BlurFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import jp.progression.commands.Func;
	import jp.progression.commands.lists.SerialList;
	import jp.progression.commands.Wait;
	import net.hires.debug.Stats;
	/**
	 * The utility is used for quickly creating expanded procedural terrain detail over small grayscaled heightmap image samples, and saving out full resolution heightmap(s) accordingly. 
	 * The problem with most grayscaled heightmaps is that they can potentially lack detail since the resolution is limited to 0-255 units (epsecially for larger worlds).
	 * Thus, this utility can be used to process low-detail heightmaps to produce more natural-looking (bumpier) terrains (by adding detail).
	 * 
	 * How it works (Approach #1):
	 * THis is a main document class to be compiled as a .swf. Make a copy of the .swf, paste it, and rename the file 
	 * to match the base name of all accompanying heightmap images in the same folder which uses the file convention:
	    name_0_0_heightmap.jpg. (Where 0_0 acts as the world page coordinate) or name_heightmap.jpg (for single loaded heightmap). Run the renamed .swf file under that specific folder location which contains a list of all accompanying elevation image maps. 
	 *  Create a .swf file called process.swf under the same folder to act as a runnable bridge program for executing the terrain process.  
	 * ( see examples.terrainprocessor.ExampleTerrainProcessor )
	 * Currently, this only supports executing 1 terrain filtering process for the entire world.
	 * 
	 * What results from the above approach? Automatically, each page's heightmap image is processed, and full resolution .hmi HeightMapInfo files are created 
	 * (or combine to single .hmi file if you wish).
	 * These can be loaded in Atregen to save out the .tre/.tres format.
	 * 
	 * @author Glenn Ko
	 */
	public class ProceduralExpansion extends Sprite
	{
		private var _cbFileExtension:ComboBox;
		private var _terrainProcessor:IHeightTerrainProcessor;
		private var _cbUseSingleHeightmap:CheckBox;
		private var uiLayout:VBox;
		private var _progressBar:ProgressBar;
		private var _progressLabel:Label;
		
		private var _numericPageAcrossX:NumericStepper;
		private var _numericPageAcrossY:NumericStepper;
		private var _pagesAcrossX:int;
		private var _pagesAcrossY:int;
		private var _pageSize:int;
		private var _worldOriginX:int;
		private var _worldOriginY:int;
		private var _numericHeightMult:NumericStepper;
		private var _numericPageSize:NumericStepper;
		
		private var _ext:String;
		private var _serialList:SerialList;
		private var _cbLoadSingleHeightmap:CheckBox;
		private var _cbBoxFilter:CheckBox;
		private var _cbPreviewNormalmap:CheckBox;
		private var _terrainName:String;
		
		private var _bitmapDataSamples:Vector.<BitmapData>;
		
		private static const LOAD_HM_DONE:String = "loadHMDone";
		static public const TILE_SIZE:Number = 256;
		
		private var _heightMap:HeightMapInfo;
		private var _heightMult:Number;
		private var _numericWorldTopLeftX:NumericStepper;
		private var _numericWorldTopLeftY:NumericStepper;
		private var _numericLowestHeight:NumericStepper;
		private var _lowestHeight:Number;
		
		private var _pageBmpdata:BitmapData;
		private var _sampleSize:int;
		private var _terrainProcesses:Vector.<ITerrainProcess>;
		private var _samplePhases:Vector.<SamplePhase>;
		
		private var _sample3x3:HeightMapInfo;
		private var _sample1x1:HeightMapInfo;
		private var _stats:Stats;
		private var _useBoxFilter:Boolean;
		private var _heightMapClone:HeightMapInfo;
	

		public function ProceduralExpansion() 
		{
			addChild( _stats = new Stats() );
			_stats.x = stage.stageWidth - _stats.width;
			
			
			uiLayout = new VBox(this);
			// Parameters:
			// image filename
			// .jpg/.png./.data (resulting filename convention)
			// page-samples across
			// expand sample to fit tiles across
			
			// marching 2x2 grid
			// for each iteration, 
			
			var hLayout:HBox;
			_terrainName = loaderInfo.url.split("/").pop().split(".").shift();
			
			
			new Label(uiLayout, 0, 0, "---- Welcome to ProceduralExpansion utility!  ----");
			
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "Grayscale heightmap file extension:");
			_cbFileExtension = new ComboBox(hLayout, 0, 0, "", [".jpg",".jpeg",".png",".data"]);
			_cbFileExtension.selectedIndex = 0;
			
			new Label(uiLayout, 0, 0, "");
			new Label(uiLayout, 0, 0, "(Please ensure height range is within int limits!)");
			
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "Lowest Height:")
			_numericLowestHeight = new NumericStepper(hLayout, 0, 0);
			_numericLowestHeight.value = 0;
			
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "Height Multiplier (height = lowestHeight + grayscaleColor * multiplier):")
			_numericHeightMult = new NumericStepper(hLayout, 0, 0);
			_numericHeightMult.value = 128;
			
			_cbBoxFilter = new CheckBox(uiLayout, 0, 0, "Box filter loaded heightmaps");
			_cbBoxFilter.selected = true;
			
			_cbPreviewNormalmap = new CheckBox(uiLayout, 0, 0, "Preview normal map after processing");
			
			
			new Label(uiLayout, 0, 0, "");
			
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "World top-left origin X/Y in tile coordinates:")
			_numericWorldTopLeftX = new NumericStepper(hLayout, 0, 0); 
			_numericWorldTopLeftY = new NumericStepper(hLayout, 0, 0);
			
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "Pages across x:");
			_numericPageAcrossX = new NumericStepper(hLayout, 0, 0);
			_numericPageAcrossX.value = 4;
			_numericPageAcrossX.minimum = 1;
			new Label(hLayout, 0, 0, "Pages across y:")
			_numericPageAcrossY = new NumericStepper(hLayout, 0, 0);
			_numericPageAcrossY.value = 4;
			_numericPageAcrossY.minimum = 1;
		
	
			hLayout = new HBox(uiLayout);
			new Label(hLayout, 0, 0, "Page size (please use a base2 value!!)")
			_numericPageSize = new NumericStepper(hLayout, 0, 0);
			_numericPageSize.value = 1024;


			
			
			_cbLoadSingleHeightmap = new CheckBox(uiLayout, 0, 0, "Load as single heightmap");
			_cbLoadSingleHeightmap.selected = true;
			
			// Depending on the world size, outputting a single .hmi file is viable rather than multiple
			_cbUseSingleHeightmap = new CheckBox(uiLayout, 0, 0, "Output single heightmap");
			_cbUseSingleHeightmap.selected = true;
			
			
			new PushButton(uiLayout, 0, 0, "Run!", onRunClick);
			
			
			
			// once all pages are loaded,
			//_cbFileExtension.d
		}
		
		private function onRunClick(e:Event):void 
		{
			uiLayout.visible = false;
			_ext = _cbFileExtension.selectedItem.toString();
			_pagesAcrossX = _numericPageAcrossX.value;
			_pagesAcrossY = _numericPageAcrossY.value;
			_pageSize = _numericPageSize.value;
			_heightMult = _numericHeightMult.value;
			_lowestHeight = _numericLowestHeight.value;
			_useBoxFilter = _cbBoxFilter.selected;
			
			
			var hLayout:HBox = new HBox(this);
			_progressBar = new ProgressBar(hLayout, 0, 0);
			_progressBar.width = 200;
			_progressLabel = new Label(hLayout, 0, 0, "Finding process.swf...");
			
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onProcessSWFLoadComplete);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onProcessSWFLoadFailed);
			loader.load( new URLRequest("process.swf"));
			
		}
		
		private function onProcessSWFLoadFailed(e:IOErrorEvent):void 
		{
			(e.currentTarget as IEventDispatcher).removeEventListener(e.type, onProcessSWFLoadComplete);
			_progressLabel.text = "Load of process.swf failed! Is the file there?";
		}
		
		private function onProcessSWFLoadComplete(e:Event):void 
		{
			(e.currentTarget as IEventDispatcher).removeEventListener(e.type, onProcessSWFLoadComplete);
			var content:DisplayObject = (e.currentTarget as LoaderInfo).content;
			_terrainProcessor = content as IHeightTerrainProcessor;
			if (_terrainProcessor == null) {
				_progressLabel.text = "Document class for process.swf doesn't implement IHeightTerrainProcessor (or cast to interface failed!)";
				return;
			}
			_progressLabel.text = "process.swf LOADED!";
			
			if (_cbLoadSingleHeightmap.selected) {
				loadSingleHeightMap();
			}
			else {
				begin();
			}
		
		}
		
		private function begin():void 
		{
			if (_cbUseSingleHeightmap.selected) {
				_heightMap = new HeightMapInfo();
				_heightMap.XSize = _pagesAcrossX * _pageSize + 1;
				_heightMap.ZSize = _pagesAcrossY * _pageSize + 1;
				_heightMap.RowWidth = _heightMap.XSize;
				_heightMap.Data = new Vector.<int>(_heightMap.XSize * _heightMap.ZSize, true);
				//_heightMap.fillDataWithValue( int.MIN_VALUE);
			
				_heightMap.XOrigin = _worldOriginX*TILE_SIZE;
				_heightMap.ZOrigin = _worldOriginY*TILE_SIZE;
				
			}
			
			
			setupSerialList();
			
			
			_serialList.execute();
		}
		
		private function loadSingleHeightMap():void 
		{
			var filename:String = _terrainName + "_heightmap" + _ext;
			_progressLabel.text = "Loading: " + filename;
			
			if (_ext === ".data") {
				var urlLoader:URLLoader = new URLLoader();
				urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
				urlLoader.addEventListener(Event.COMPLETE, onLoadSingleHeightmapDone);
				urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onLoadSingleHeightmapFailed);
				urlLoader.load( new URLRequest(filename) );
			}
			else {
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadSingleHeightmapDone);
				loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadSingleHeightmapFailed);
				loader.load( new URLRequest(filename) );
			}
			
		}
		
		private function onLoadSingleHeightmapFailed(e:Event):void {
			var filename:String = _terrainName + "_heightmap" + _ext;
			_progressLabel.text = "Single heightmap failed to load:" +filename;
		}
		
		private function onLoadSingleHeightmapDone(e:Event):void {
			_progressLabel.text = "Single heightmap loaded.";
			
			var loaderInfo:LoaderInfo =  (e.currentTarget as LoaderInfo);
			
			var bmpData:BitmapData = loaderInfo != null ? (loaderInfo.content as Bitmap).bitmapData : dataToBitmapdata( (e.currentTarget as URLLoader).data );
			_bitmapDataSamples = new Vector.<BitmapData>(_pagesAcrossX * _pagesAcrossY, true);
			
			var rect:Rectangle = new Rectangle(0,0, bmpData.width/ _pagesAcrossX, bmpData.height / _pagesAcrossY);
			var point:Point = new Point();
			var sampledData:BitmapData;
			for (var y:int = 0; y < _pagesAcrossY; y++) {
				for (var x:int = 0; x < _pagesAcrossX; x++) {
					_bitmapDataSamples[y * _pagesAcrossX + x] = sampledData = new BitmapData(rect.width, rect.height, false, 0);
					rect.x = rect.width * x;
					rect.y = rect.height * y;
					sampledData.copyPixels(bmpData, rect, point);
				}
			}
			
			bmpData.dispose();
			
			setTimeout(begin, 100);
		}
		
		private function dataToBitmapdata(data:ByteArray):BitmapData 
		{
			data.uncompress();
			return BitmapDataReadWrite.readSquareBmpDataGrayscale(data);
		}
		
		private function setupSerialList():void 
		{
			_pageBmpdata = new BitmapData(_pageSize, _pageSize, false, 0);
			
			_sampleSize = _terrainProcessor.sampleSize;
			_terrainProcesses = _terrainProcessor.getProcesses() || new Vector.<ITerrainProcess>();
			_samplePhases = getSamplePhases( _terrainProcessor.getSamplePhases() );
			
			_sample3x3 = new HeightMapInfo();
			_sample3x3.XSize = _sampleSize * 3;
			_sample3x3.ZSize = _sampleSize * 3;		
			_sample3x3.RowWidth = _sample3x3.XSize;		
			_sample3x3.XOrigin = 0;					
			_sample3x3.ZOrigin = 0;	
			_sample3x3.Data = new Vector.<int>(_sample3x3.XSize * _sample3x3.ZSize, true);
			
			 _sample1x1 = new HeightMapInfo();
			_sample1x1.XSize = _sampleSize;
			_sample1x1.ZSize = _sampleSize;		
			_sample1x1.RowWidth = _sample1x1.XSize;		
			_sample1x1.XOrigin = 0;					
			_sample1x1.ZOrigin = 0;		
			_sample1x1.Data = new Vector.<int>(_sample1x1.XSize * _sample1x1.ZSize, true);
			
			_progressLabel.text = "Processing terrain...";
			
			_serialList = new SerialList();
			_serialList.onPosition = onProgressSerialHandler;
		
			if (_heightMap != null  ) {  // Run output single heightmap branch
				
				if (_bitmapDataSamples != null) {  	// perform pushing of bitmapdata samples into single heightmap
					injectBitmapdataSamples(true);	
					_serialList.addCommand( new Func(disposeBitmapDataSamples) );
				}
				else {  // bitmapdata 
					throw new Error("Load multiple heightmaps not supported yet");
					// perform loading of each bitmapdata sample, to push into single heightmap
					_bitmapDataSamples = new Vector.<BitmapData>(_pagesAcrossX * _pagesAcrossY, true);
					
					_serialList.addCommand( new Func(injectBitmapdataSamples) );
					_serialList.addCommand( new Func(disposeBitmapDataSamples) );
					
				}
				if (_useBoxFilter) _serialList.addCommand( new Func(_heightMap.BoxFilterHeightMap), new Wait(.3) );
				
				injectSampleProcessesFromHeightmap();
				_serialList.addCommand( new Wait(.5), new Func(finaliseHeightMap) );
				
				// sample from heightmap and run terrain process on it
			}
			else {   // Run output multiple heightmaps approach. Prefably require a server (air APP) for this to help save files automatically!
				throw new Error("Output multiple heightmaps not supported yet");
			
				 // blast-load 3x3 heightmaps each. Fill into single heightmap buffer.
				 _heightMap = new HeightMapInfo();
				_heightMap.XSize = _pageSize * 3 + 1;
				_heightMap.ZSize = _pageSize * 3 + 1;		// Correct values below:
				_heightMap.RowWidth = _pageSize;		 // _heightMap.XSize; 
				_heightMap.XOrigin = 0;					// _worldOriginX * TILE_SIZE + ...;
				_heightMap.ZOrigin = 0;					// _worldOriginY * TILE_SIZE + ...;
				
				// sample new 1x1 heightmap from 3x3 heightmap blast
				
				// save out final 4or9 1x1 heightmaps with the correct values (hm values)
			}
			
		}
		
		private function onProgressSerialHandler():void 
		{
			_progressBar.value = (_serialList.position /  _serialList.numCommands);
			_progressLabel.text = "Processing terrain...( "+_serialList.position+" / "+ _serialList.numCommands+" )";
		}
		
		private function finaliseHeightMap():void 
		{
			///*
			if (_cbPreviewNormalmap.selected) {
				var normalMapper:PlanarDispToNormConverter = new PlanarDispToNormConverter();
				normalMapper.heightMap = _heightMap;
				//normalMapper.setDisplacementMapData(tempData);
				normalMapper.setDirection("z");
				//normalMapper.heightMapMultiplier = 1 / 128;
				normalMapper.setAmplitude(1);
				
			
				var normalMap:Bitmap = normalMapper.convertToNormalMap();
				//normalMap.bitmapData.applyFilter(normalMap.bitmapData, normalMap.bitmapData.rect, new Point(), new BlurFilter(3, 3, 4) );
				addChild(normalMap);
				
				new FileReference().save(new JPGEncoder(80).encode(normalMap.bitmapData) ,  "myterrain_normal.jpg");
				return;
			}
			//*/
			
			_progressLabel.text = "Preparing save file...Please wait...";
			_heightMap.paddEdgeDataValues();
			var byte:ByteArray = new ByteArray();
			_heightMap.writeExternal(byte);
			byte.compress();
			new FileReference().save(byte, _terrainName + ".hmi");
		}
		
		private function getSamplePhases(samplePhases:Vector.<Boolean>):Vector.<SamplePhase> 
		{
			
			if (samplePhases == null) {
				return new <SamplePhase>[
					new SamplePhase(true, 0), new SamplePhase(false,0)
				];
			}
			var result:Vector.<SamplePhase> = new Vector.<SamplePhase>();
			var count3:int = 0;
			var count:int = 0;
			for (var i:int = 0; i < samplePhases.length; i++) {
				var is3x3:Boolean = samplePhases[i];
				
				result.push(  new SamplePhase( is3x3, (is3x3 ? count3 : count) ) );
				
				if (is3x3) count3++
				else count++;
			}
			return result;
		}
		
		private function injectSampleProcessesFromHeightmap():void 
		{
			if (_sampleSize > _pageSize) throw new Error("Sorry, sample size is higher than page size! This isn't allowed (for now)! " +_sampleSize + "/"+_pageSize);
		
			var samplesAcrossX:int = (_heightMap.XSize - 1) / _sampleSize;
			var samplesAcrossY:int = (_heightMap.ZSize - 1) / _sampleSize;
			
			var uLen:int = _samplePhases.length;
			var pLen:int =  _terrainProcesses.length ;
			
			for ( var y:int = 0; y < samplesAcrossY; y++) {
				for (var x:int = 0; x < samplesAcrossX; x++) {
					//_sample3x3.copyData(x * _sampleSize, y * _sampleSize, _sample3x3.XSize, _sample3x3.ZSize, _heightMap.Data);
					//_sample1x1.copyData(x * _sampleSize, y * _sampleSize, _sample1x1.XSize, _sample1x1.ZSize, _heightMap.Data);
					
							
							
					for (var u:int = 0; u < uLen; u++) {
						var samplePhase:SamplePhase = _samplePhases[u];
					
						
						//if (pLen != 0) {
							_serialList.addCommand( new Func(setTerrainProcessesData , [x,y,samplePhase.is3x3 ? _sample3x3 : _sample1x1], null, "setTerrainProcessesData" ) );
						//}
						
						if (samplePhase.is3x3) {
							_serialList.addCommand(
								new Func(_sample3x3.copyData, [x * _sampleSize-_sampleSize, y * _sampleSize - _sampleSize, _sample3x3.XSize, _sample3x3.ZSize, _heightMap], null, "sample3x3.copyData" ),
								new Wait(.3),
								new Func( _terrainProcessor.process3By3Sample, [_sample3x3, samplePhase.phase], null, "process3By3Sample" ) ,
								new Wait(.3),
								new Func(copyBackSampledData3x3, [x,y,samplesAcrossX, samplesAcrossY], null, "copyBackSampledData3x3:"+x+","+y)
							);
						}
						else {
							_serialList.addCommand(
								new Func(_sample1x1.copyData, [x * _sampleSize, y * _sampleSize, _sample1x1.XSize, _sample1x1.ZSize, _heightMap], null, "sample1x1.copyData"),
							    new Wait(.3),
								new Func( _terrainProcessor.process1By1Sample, [_sample1x1, samplePhase.phase]) ,
								new Wait(.3),
								new Func(copyBackSampledData1x1, [x,y,samplesAcrossX, samplesAcrossY], null, "copyBackSampledData1x1:"+x+","+y)
							);
							
						}
						
					
					}
					//_serialList.addCommand( new Func(copyBackSampledData, [x,y,samplesAcrossX, samplesAcrossY], null, "copyBackSampledData:"+x+","+y) );
				}
			}
			
			_serialList.addCommand( new Func(cloneHeightmapForPreprocessing) );
			
			// 3x3 POST PROCESSING operations useful for smoothing operations. It supplies the 3x3 heightmap as input, but updates 1x1 in the middle only.
			for (  y = 0; y < samplesAcrossY; y++) {
				for ( x = 0; x < samplesAcrossX; x++) {
					
					//if (pLen != 0) {
						_serialList.addCommand( new Func(setTerrainProcessesData, [x,y, _sample3x3], null, "setTerrainProcessesData" ) );
					//	}
				
					_serialList.addCommand(
								new Func(copyDataForSample, [_sample3x3, x * _sampleSize-_sampleSize, y * _sampleSize - _sampleSize, _sample3x3.XSize, _sample3x3.ZSize, null, true], null, "sample3x3.copyData" ),
								new Wait(.3),
								new Func( _terrainProcessor.postProcess3By3Sample, [_sample3x3], null, "postProcess3By3Sample" ) ,
								new Wait(.3),
								new Func(copyBackSampledData1x1with3x3, [x,y,samplesAcrossX, samplesAcrossY], null, "postCopyBack:"+x+","+y)
							);
							
				}
			}
		}
		
		private function copyDataForSample(sample:HeightMapInfo, xStart:int, yStart:int, width:int, height:int, hm:HeightMapInfo, useClone:Boolean=false):void {
			hm = hm != null ? hm : !useClone ? _heightMap : _heightMapClone;
			sample.copyData(xStart, yStart, width, height, hm);
		}
		
		private function cloneHeightmapForPreprocessing():void {
			_heightMapClone = _heightMap.clone();
		}
		
		private function setTerrainProcessesData(x:int, y:int,heightmap:HeightMapInfo):void 
		{
			heightmap.XOrigin = x;
			heightmap.ZOrigin = y;
			var i:int = _terrainProcesses.length;
			while (--i > -1) {
				_terrainProcesses[i].setupHeights(heightmap.Data, heightmap.XSize, heightmap.ZSize);
			}
		
		}
		
		private function copyBackSampledData1x1(x:int, y:int, xSamplesAcross:int, ySamplesAcross:int):void 
		{

	
			_heightMap.copyData( 0, 0, _sampleSize, _sampleSize, _sample1x1, x * _sampleSize, y * _sampleSize );
			
			
		}
		
		private function copyBackSampledData1x1with3x3(x:int, y:int, xSamplesAcross:int, ySamplesAcross:int):void 
		{
		
			var dx:int = x == 0 ? 1 :0;  // destx
			var dy:int =  y == 0 ? 1 : 0;  // desty
			_heightMap.copyData( _sampleSize, _sampleSize, _sampleSize, _sampleSize, _sample3x3, x*_sampleSize , y*_sampleSize);
			
		}
		
		private function copyBackSampledData3x3(x:int, y:int, xSamplesAcross:int, ySamplesAcross:int):void 
		{

			
			
			// for 3x3 sample
			var dx:int = x == 0 ? 0 : x - 1;  // destx
			var dy:int =  y == 0 ? 0 : y-1;  // desty
			var dOffX:int =  x == 0 ? 1 : 0;
			var dOffY:int = y == 0 ? 1 :0;
			var dsX:int = x == 0 || x >= (xSamplesAcross -1)  ?  2 : 3;
			var dsY:int = y == 0 || y >= (ySamplesAcross -1) ?  2 : 3;

			_heightMap.copyData( dOffX*_sampleSize, dOffY*_sampleSize, _sampleSize*dsX,  _sampleSize*dsY, _sample3x3, dx*_sampleSize, dy*_sampleSize);
		}
		

		
		private function disposeBitmapDataSamples():void 
		{
			var i:int = _bitmapDataSamples.length;
			while (--i > -1) {
				_bitmapDataSamples[i].dispose();
			}
			_bitmapDataSamples.fixed = false;
			_bitmapDataSamples.length = 0;
			_bitmapDataSamples = null;  // remove off bitmapdata samples
			
			_pageBmpdata.dispose();
			_pageBmpdata = null;
		}
		
		private function copyPixelsFromBmpDataToHeightMap(xOrg:int, yOrg:int):void {
			for ( var y:int = yOrg; y < yOrg+_pageSize+1; y++) {
				for (var x:int =xOrg; x < xOrg+_pageSize+1 ; x++) {  // not sure why need to have a +1, but this is to avoid seeams
					_heightMap.Data[y * _heightMap.XSize + x] = _lowestHeight + (_pageBmpdata.getPixel(x - xOrg, y - yOrg) & 0xFF) * _heightMult;
				}
			}
		}
		
		
		private function injectBitmapdataSamples(sync:Boolean=false):void 
		{
			var scaleX:Number = _pageSize  / _bitmapDataSamples[0].width;
			var scaleY:Number = _pageSize / _bitmapDataSamples[0].height;
			var mat:Matrix = new Matrix(scaleX, 0, 0, scaleY);
			for ( var y:int = 0; y < _pagesAcrossY; y++) {
				for (var x:int = 0; x < _pagesAcrossX; x++) {
					var bmd:BitmapData = _bitmapDataSamples[y * _pagesAcrossX + x];
				//	_pageBmpdata.draw( bmd, mat, null, null, null, true);
					( sync ? _serialList.addCommand : _serialList.insertCommand )( new Func(_pageBmpdata.draw, [bmd, mat, null, null, null, true]),
										new Func( copyPixelsFromBmpDataToHeightMap, [x * _pageSize, y * _pageSize] ),
										new Wait(.3) );
					
				}
			}
		}
	}

}

class SamplePhase {
	public var is3x3:Boolean;
	public var phase:int;
	function SamplePhase(is3x3:Boolean, phase:int):void {
		this.phase = phase;
		this.is3x3 = is3x3;
		
	}
	
}