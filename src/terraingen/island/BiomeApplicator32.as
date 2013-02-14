package terraingen.island 
{
	import alternsector.utils.mapping.MarchingSquares;
	import alternsector.utils.mapping.MarchingSquaresUtil;
	import com.sakri.utils.BitmapDataUtil;
	import com.sakri.utils.BitmapShapeExtractor;
	import com.sakri.utils.ExtractedShapeCollection;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import jp.progression.commands.Func;
	import jp.progression.commands.lists.LoaderList;
	import jp.progression.commands.lists.SerialList;
	import jp.progression.commands.Wait;
	/**
	 * Applies biomes for tile index material, by tracing out edges and blending them accordingly with the correct bit arrangement.
	 * @author Glenn Ko
	 */
	public class BiomeApplicator32 extends EventDispatcher
	{
		public var tileBitMap:Vector.<uint>;  // state map
		
		public var tileMap:BitmapData; // Main src map used to isolate color reference., when process is complet,e this holds the result tileBitmap data
		public var extractedShapes:ExtractedShapeCollection;  // extracted shapes to perform marching squares algorithm
		public var painter:BiomePainter32;

		public var tilesAcross:int;
		
		// in order of priority of application (back to front), their atlas UV coordinates as well
		public var textureList:Array = [
			["d"], ["OCEAN"],
			//["a"]
			["d"],["RIVER","MARSH"], //d
			["f"],["SUBTROPICAL_DESERT"],   //f
			["h"],["TEMPERATE_DESERT"],  //h
			["q"],["SHRUBLAND","GRASSLAND"],  //q
			["n"],["TEMPERATE_RAIN_FOREST","TEMPERATE_DECIDUOUS_FOREST"],  //n
			["s"],["COAST","LAKESHORE","LAKE"],  //s
			["r"], ["LAVA","BEACH"],  // r
			["c"], ["TROPICAL_SEASONAL_FOREST","TROPICAL_RAIN_FOREST"],  // c
			["k"], ["TAIGA","SCORCHED"],   // lqrr
			["g"], ["BARE", "ROAD1", "ROAD2", "ROAD3", "BRIDGE"],  // g+
			["i"], ["SNOW","TUNDRA","ICE"]  // i
		
		];
		public var atlasReadString:String = "dfhqnsrckgi";
		public var atlasTilesAcrossH:int = 4;
		public var atlasTilesAcrossV:int = 4;
		

		
		private var textureDict:Dictionary;
		
		
		
		
		public static var LOOKUP_STRINGS:Vector.<String>;
		
		private var marchSquareUtil:MarchingSquaresUtil = new MarchingSquaresUtil();
		public function get marchingUtil():MarchingSquaresUtil {
			return marchSquareUtil;
		}
		
		private var marchingSquares:MarchingSquares;
		private var _serialList:SerialList;
		
		// 26 biomes altogetehr
		/*  // For reference
			static public var BIOME_LIST:Array = [
			  // Features
			  ["OCEAN"],
			  ["COAST"],
			  ["LAKESHORE"],
			  ["LAKE"],
			  ["RIVER"],
			  ["MARSH"],
			  ["ICE"],
			  ["BEACH"],
			  ["ROAD1"],
			  ["ROAD2"],
			  ["ROAD3"],
			  ["BRIDGE"],
			  ["LAVA"],
			  // Terrain
			  ["SNOW"],
			  ["TUNDRA"],
			  ["BARE"],
			  ["SCORCHED"],
			  ["TAIGA"],
			  ["SHRUBLAND"],
			  ["TEMPERATE_DESERT"],
			  ["TEMPERATE_RAIN_FOREST"],,
			  ["TEMPERATE_DECIDUOUS_FOREST"],
			  ["GRASSLAND"],
			  ["SUBTROPICAL_DESERT"],
			  ["TROPICAL_RAIN_FOREST"],
			  ["TROPICAL_SEASONAL_FOREST"]
			];
			*/
	
		public function BiomeApplicator32() 
		{
			marchingSquares = marchSquareUtil.squares;
			marchSquareUtil.setTimeInterval(30);
			marchSquareUtil.steps = 256;
			
			
			
			displayField.autoSize = "left";
		}
		
		private var counter:int = 0;
		private function getDummyColor(colorDebug:*):int {
			throw new Error("Texture not supported !"+colorDebug);
			var result:int = counter + 1;
			counter++;
			if (counter >= textureList.length) counter = 0;
			return result;
		}
		
		public function processBiomes(b:ByteArray, tilesAcross:int, testSpr:Sprite=null):void {
			initProcess(tilesAcross);
			tileBitMap = new Vector.<uint>(tilesAcross * tilesAcross);
			tileMap = new BitmapData(tilesAcross, tilesAcross, true, 0);
			testbitMap = new BitmapData(tilesAcross, tilesAcross, true, 0);
		//	var snowcount:int = 0;
			for (var y:int = 0; y < tilesAcross; y++) {
				for (var x:int = 0; x < tilesAcross; x++) {
					var color:uint = b.readUnsignedByte();
					
					var colorIndex:int =  textureDict[LOOKUP_STRINGS[color-1]] != null ? textureDict[LOOKUP_STRINGS[color-1]] : getDummyColor(LOOKUP_STRINGS[color-1]);
					var atlasIndex:int = textureList[(colorIndex-1)*2][0];
					tileBitMap[y * tilesAcross + x] = painter.getUintFromIndices(atlasIndex, atlasIndex, atlasIndex , 3, 1,0,0,1);  // |  TODO: set correct value
					tileMap.setPixel32(x, y, 0xFF000000 | colorIndex );
					if (colorIndex < 1 || colorIndex > textureList.length * .5) throw new Error("Invalid color index processed:" + colorIndex);
					
				}
			}
			
			
			_serialList = new SerialList();
			
			var len:uint = textureList.length / 2;
			
			_currentLayerIndex = 1;
			
			for (var i:uint = 1; i < len; i++) {
				_serialList.addCommand( new Func(runLayerProcess) );
				_serialList.addCommand( new Wait(.6) );
				_serialList.addCommand( new Func(completedLayer) );
				_serialList.addCommand( new Wait(.8) );
			}
			
			_serialList.addCommand( new Func(notifyComplete) );
			
			_serialList.execute();
		}
		
		private var _currentLayerIndex:int;
		
		public function runLayerProcess():void {
		
			extractedShapes = BitmapShapeExtractor.extractShapes2(tileMap, 0xFF000000 | (_currentLayerIndex+1));
				var positiveShapes:Vector.<BitmapData> = extractedShapes.shapes;
				var negativeShapes:Vector.<BitmapData> = extractedShapes.negative_shapes;
				var shape:BitmapData;
				var pt:Point;
		
				_serialList.insertCommand( new Func(setCallbackState, [true] ) );
				var haveShape:Boolean = false;
				
				for each(shape in positiveShapes) {  // reverse logic here sorry
					// marching squares and apply callback
					pt = BitmapDataUtil.getPointNotMatchingColor(shape, 0);
					if (pt == null) {
						throw new Error("Could not find starting point.");
						continue;
					}
					if (pt.x == 0 || pt.y == 0) {
						//if (i != 1 && i != 6) throw new Error("POSITIVE SHAPES CAn't have zero point!");
						continue; 
					}
					
					scanlineCheck(shape, pt.y);
					_serialList.insertCommand( new Func(runMarchingSquares, [shape, 0, pt.y, 0, _currentLayerIndex], marchSquareUtil, Event.COMPLETE ) );
					haveShape = true;
				}
				
				_serialList.insertCommand( new Func(setCallbackState, [false] ) );
				for each(shape in negativeShapes) {
					// marching squares and apply callback
					pt = BitmapDataUtil.getPointNotMatchingColor(shape, 0);
					if (pt == null) {
						throw new Error("Could not find starting point.");
						continue;
					}
					if (pt.x == 0 || pt.y == 0) continue;
					scanlineCheck(shape, pt.y);
					_serialList.insertCommand( new Func(runMarchingSquares, [shape, 0, pt.y, 0, _currentLayerIndex], marchSquareUtil, Event.COMPLETE ) );
				}
				
				if (haveShape) biomeCount++;
				
				
				
				
				_currentLayerIndex++;
			
		}
		
		private function completedLayer():void 
		{
			extractedShapes.dispose();
		}
		
		
		
		private function scanlineCheck(shape:BitmapData, y:int, colorDisc:uint = 0):Boolean {
			
			for (var x:int = 0; x < shape.width; x++) {
				if ( shape.getPixel(x, y) != colorDisc ) {
					if (shape.getPixel(shape.width - 1, y) != colorDisc) {
						throw new Error("FAILED2: Not empty at end of line!");
					}
					return true;
				}
			};
			throw new Error("FAILED");
			return false;
		}
		
		private function runMarchingSquares(shape:BitmapData, ptX:int, ptY:int, color:uint, colorIndex:int):void {
			testbitMap.fillRect(testbitMap.rect, 0);
			//throw new Error(shape.getVector(shape.rect));
	//	throw new Error("Drawing shape:" + shape.getVector(shape.rect));
			testbitMap.draw(shape, null, null, null, null, false);
			if (!marchSquareUtil.runMarchingSquares(shape, ptX, ptY, color)) {
				throw new Error("MARCH START FAILED!");
			}
			
			_serialColorIndex = colorIndex;
			_serialAtlasIndex = textureList[colorIndex * 2][0];
		}
		
	
		
		private function notifyComplete():void 
		{
			
			tileMap.setVector( tileMap.rect, tileBitMap);
			displayField.text = "Process complete:" +biomeCount + " biomes. "+painter.errorCount+" potential errors.";
			dispatchEvent( new Event(Event.COMPLETE) );
			
		}
		
		private function setCallbackState(val:Boolean):void {
			marchSquareUtil.callbackFunc = val ? callbackPositiveOutline : callbackNegativeOutline;
		}
		
		public var displayField:TextField = new TextField();
		public var biomeCount:int=0;
		
		private var count:int = 0;
		private var _serialColorIndex:int;
		private var _serialAtlasIndex:int;
		public var testbitMap:BitmapData;
		

		// adjust values in tileBitMap accordingly
		private function callbackPositiveOutline():void {
			//throw new Error("A");
			
		
			displayField.text = String(count++ +" | POSTIIVE:" + marchingSquares.x + ', ' +marchingSquares.y + "::");

			//tileBitMap[marchingSquares.y * tilesAcross + marchingSquares.x] = _serialAtlasIndex;
			//if (tileMap.getPixel32(marchingSquares.x, marchingSquares.y) == 0) throw new Error("No splash!");
			
			painter.paintToTileMap(tileBitMap, tilesAcross, _serialAtlasIndex, marchingSquares.x, marchingSquares.y);
			testbitMap.setPixel32(marchingSquares.x, marchingSquares.y, 0xFFFFFF40);
		
		
		}
		private function callbackNegativeOutline():void {
			displayField.text = String(count++ + "NEGATIVE:" + marchingSquares.x + ', ' +marchingSquares.y);
			//if (tileMap.getPixel32(marchingSquares.x, marchingSquares.y) == 0) throw new Error("No splash!");
			//tileBitMap[marchingSquares.y * tilesAcross + marchingSquares.x] = 0xFFFFFF40;
			
			painter.paintToTileMap(tileBitMap, tilesAcross, _serialAtlasIndex, marchingSquares.x, marchingSquares.y);
			testbitMap.setPixel32(marchingSquares.x, marchingSquares.y, 0xFFFFFF40);
		}
		
		

		
		
		private function initProcess(tilesAcross:int):void 
		{
			painter = new BiomePainter32(atlasTilesAcrossH, atlasTilesAcrossV);
			
			if (LOOKUP_STRINGS == null) LOOKUP_STRINGS = mapgen2.getExportIndexLookup();
			if (textureDict == null) calculateTextureDictionary();
			
			this.tilesAcross = tilesAcross;
		}
		
		public function getNewBitmapData():BitmapData {
			var bmpData:BitmapData = new BitmapData(tilesAcross, tilesAcross, false, 0);
			bmpData.setVector(bmpData.rect, tileBitMap);
			return bmpData;
		}
		
		public function calculateTextureDictionary():void 
		{
			textureDict = new Dictionary();
			var len:int = textureList.length;
			var count:int = 1;
			for (var i:int = 0; i < len; i+=2) {
				var keys:Array = textureList[i + 1];
				for each(var k:String in keys) {
					textureDict[k] =count; 
				}

				if (textureList[i][0] is String) {
					var atlasIndex:int = atlasReadString.indexOf( textureList[i][0] );
					if (atlasIndex < 0) throw new Error("Could not find atlas index from string under texture dictionary!");
					textureList[i][0] = atlasIndex;
				}
				
				count++;
			}
		}
		
		public function dispose():void 
		{
			tileMap.dispose();
			extractedShapes.dispose();
			
		}
		
		public function get serialList():SerialList 
		{
			return _serialList;
		}
	}

}