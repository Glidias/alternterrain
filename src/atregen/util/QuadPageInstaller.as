package atregen.util 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrain.core.QuadCornerData;
	import alternterrain.core.QuadSquareChunk;
	import alternterrain.core.QuadTreePage;
	import alternterrain.resources.InstalledQuadTreePages;
	import alternterrain.resources.LoadAliases;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.FileReference;
	import flash.system.System;
	import flash.utils.ByteArray;
	import jp.progression.commands.Func;
	import jp.progression.commands.lists.SerialList;
	import jp.progression.commands.Wait;
	import jp.progression.events.ExecuteEvent;

	
	/**
	 * A utility class to help install multiple terrain quad-trees asynchrounously, using small sample
	 * sizes in a breath-first manner, and than building the list of quad-trees from the bottom-up rather than recursively 
	 * from the top-down.
	 * @author Glenn Ko
	 */
	public class QuadPageInstaller extends EventDispatcher
	{
		private var _currentGrid:Vector.<QuadSquareChunk>;
		private var _currentAcross:int;
		private var _nextGrid:Vector.<QuadSquareChunk>;
		
		public var pageGrid:Vector.<QuadTreePage>;
		public var totalPagesAcross:int;
		static public const EVENT_SAMPLE:String = "eventSample";
		
		private var _gatherCount:int;
		private var _serialList:SerialList;
		private var _patchesAcross:int;
		private var _count:int;
		private var _sampleSize:int;
		private var _heightMap:HeightMapInfo;

		public var filename:String = "pages.data";
		
		public function QuadPageInstaller() 
		{
			new LoadAliases();
		}
		
		public function install(heightMap:HeightMapInfo, sampleSize:int, pageSize:int, callbackProgress:Function=null):void {
			var fresh:Boolean = _serialList == null;
			_serialList = _serialList || new SerialList();
			
			var patchesAcross:int = heightMap.RowWidth - 1;
			this._patchesAcross = patchesAcross;
	

			if (!QuadCornerData.isBase2(patchesAcross)) {
				throw new Error("Heightmap dimension across patches isn't base-2age:"+patchesAcross ) ;
			}
			
			var pAcross:int = patchesAcross / sampleSize;
			_currentGrid = new Vector.<QuadSquareChunk>(pAcross * pAcross, true);
			_currentAcross = pAcross;
			_gatherCount = Math.log( pageSize / sampleSize ) * Math.LOG2E + 1;

			_sampleSize = sampleSize;
			_heightMap = heightMap;
			
			var i:int = _gatherCount;
			var count:int = 0;
			_count = 0;
			
			if (fresh) _serialList.addCommand( new Wait(.1) );
			while ( --i > -1) {
				if ( count != 0 )  addGridCombineProcess(heightMap, pAcross, sampleSize, count);
				else addGridProcess(heightMap, pAcross , sampleSize, count ) ;
				pAcross *= .5;
				count++;
			}
			
		
		if (fresh) {
				_serialList.onPosition = callbackProgress;
				_serialList.addCommand( new Wait(.2) );
				_serialList.addCommand( new Func(done) );
				_serialList.execute();
			}
			
		
			
		}
		
		private function addGridProcess(heightMap:HeightMapInfo, pAcross:int, sampleSize:int, count:int):void 
		{
			for (var y:int = 0; y < pAcross; y++) {
				for (var x:int = 0; x < pAcross; x++) {
					_serialList.addCommand( new Func(installQuadChunkFromHeightmap, [y*pAcross + x, heightMap, heightMap.XOrigin + ( ((x * sampleSize)*(1<<count)) << heightMap.Scale), heightMap.ZOrigin + ( ((y*sampleSize)*(1<<count)) << heightMap.Scale), (sampleSize << heightMap.Scale)*(1<<count)]) );
				
					_serialList.addCommand( new Wait(.3) );
						
				}
			}
			
			
			_serialList.addCommand( new Func(gridDone) );
			_serialList.addCommand( new Wait(.2) );
			
		}
		
	
		
		private function addGridCombineProcess(heightMap:HeightMapInfo, pAcross:int, sampleSize:int, count:int):void 
		{
			_serialList.addCommand( new Func(gridDone) );
			_serialList.addCommand( new Wait(.2) );
		}
		
		
		private function gridDone():void {
			_gatherCount--;
			
			
			if (_gatherCount > 0) {
				_count++;
				
				var curChunk:QuadSquareChunk;
				var upperRoot:QuadCornerData;
				var lastAcross:int = _currentAcross;
				var miny:Number;
				var maxy:Number;
				_currentAcross *= .5;
				_nextGrid = new Vector.<QuadSquareChunk>( _currentAcross * _currentAcross, true);
				for (var y:int = 0; y < _currentAcross; y++) {
					for (var x:int = 0; x < _currentAcross; x++) {
						var index:int = y * _currentAcross + x;
						var newChunk:QuadSquareChunk = new QuadSquareChunk();
						upperRoot = QuadCornerData.createRoot( _heightMap.XOrigin + ( ((x << _sampleSize) * (1<<_count)) << _heightMap.Scale), _heightMap.ZOrigin +  ( ((y << _sampleSize) * (1<<_count)) << _heightMap.Scale), (_sampleSize << _heightMap.Scale)* (1<<_count)); 
						upperRoot.Square.SampleFromHeightMap(upperRoot, _heightMap);
						var err:Number = upperRoot.Square.getHighestError(upperRoot);
						miny = Number.MAX_VALUE;
						maxy = -Number.MAX_VALUE;
						curChunk = _currentGrid[y * 2 * lastAcross + (x*2) ];  // top left
						newChunk.Child[1] = curChunk;
						if (curChunk.error > err) err = curChunk.error;
						if (curChunk.MinY < miny) miny = curChunk.MinY;
						if (curChunk.MaxY > maxy) maxy = curChunk.MaxY;
						curChunk = _currentGrid[y * 2 * lastAcross + 1 + (x*2)];  // top right
						newChunk.Child[0] = curChunk;
						if (curChunk.error > err) err = curChunk.error;
						if (curChunk.MinY < miny) miny = curChunk.MinY;
						if (curChunk.MaxY > maxy) maxy = curChunk.MaxY;
						curChunk = _currentGrid[ (y * 2 + 1) * lastAcross  + (x*2)];  // bottom left
						newChunk.Child[2] = curChunk;
						if (curChunk.error > err) err = curChunk.error;
						if (curChunk.MinY < miny) miny = curChunk.MinY;
						if (curChunk.MaxY > maxy) maxy = curChunk.MaxY;
						curChunk = _currentGrid[ (y * 2 + 1) * lastAcross + 1  + (x*2)];  // bottom right
						newChunk.Child[3] = curChunk;
						if (curChunk.error > err) err = curChunk.error;
						if (curChunk.MinY < miny) miny = curChunk.MinY;
						if (curChunk.MaxY > maxy) maxy = curChunk.MaxY;
						
						_nextGrid[index] = newChunk;
						newChunk.error = err;
						newChunk.MinY = miny;
						newChunk.MaxY = maxy;
		
					}
				}
				_currentGrid = _nextGrid;  
				_nextGrid = null;
				
			}
			else {  // gather pages
				
				totalPagesAcross = _currentAcross;
				gatherPages();
			}
		}
		
		private function gatherPages():void 
		{
			
			var across:int = totalPagesAcross;
			pageGrid = new Vector.<QuadTreePage>(across * across, true);
			var page:QuadTreePage;
			var square:QuadSquareChunk;
			
			for (var y:int = 0; y < across; y++) {
				for (var x:int = 0; x < across; x++) {
					page = QuadTreePage.create(( ((x * _sampleSize) * (1<<_count)) << _heightMap.Scale), ( ((y * _sampleSize) * (1<<_count)) << _heightMap.Scale), (_sampleSize << _heightMap.Scale) * (1<<_count));
					page.Square = _currentGrid[y * across + x];
					pageGrid[y * across + x] = page;
				}
			}
			
		}
		
		private function done():void {
			dispatchEvent( new Event(Event.COMPLETE) );
	
			// TODO:
			/*
			var installedPages:InstalledQuadTreePages = new InstalledQuadTreePages();
			installedPages.pageGrid = pageGrid;
			installedPages.heightMap = _heightMap;
			installedPages.totalPagesAcross = totalPagesAcross;
			var bArray:ByteArray = new ByteArray();
			installedPages.writeExternal(bArray);
			bArray.compress();
			*/
			
			//new FileReference().save(bArray, filename);
			
			_serialList = null;
			_heightMap = null;
			_currentGrid = null;
			_nextGrid = null;
		}
		
		private function installQuadChunkFromHeightmap(index:int, heightMap:HeightMapInfo, offsetX:int, offsetY:int,  sampleSize:int):void {
		
			var rootData:QuadCornerData = QuadCornerData.createRoot(offsetX, offsetY, sampleSize, false); 
			rootData.Square.AddHeightMap(rootData, heightMap);
		
			_currentGrid[index] =  rootData.Square.GetQuadSquareChunk( rootData, rootData.Square.RecomputeErrorAndLighting(rootData)  ); 

		}
		
		public function get serialList():SerialList 
		{
			return _serialList;
		}
		
	}

}