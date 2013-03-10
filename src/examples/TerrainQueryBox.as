package examples
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * Planning out terrain paging scheme across nested hierchical grids.
	 * 
	 * @author Glenn Ko
	 */
	public class TerrainQueryBox extends Sprite
	{
		public const BASE_PATCH:int = 4;  // increase this for more page loads from within the center
		public const QUERY_SIZE:int = 256;
		
		private var boundingSpace:Rectangle = new Rectangle(0, 0, 2048, 1024);
		private var boundingTiles:Rectangle = new Rectangle(boundingSpace.x/32, boundingSpace.y/32, boundingSpace.width / 32, boundingSpace.height / 32);
		private var offset6:Vector.<int>= new Vector.<int>(6*4, true);
		
		private var _lmx:int = -int.MAX_VALUE;
		private var _lmy:int = -int.MAX_VALUE;
		
		private var testLoadingLayer:Sprite = new Sprite();
		private var graphicsLayer:Sprite = new Sprite();
		override public function get graphics():Graphics {
			return graphicsLayer.graphics;
		}
		
		public static const STATE_EMPTY:int = 0;
		public static const STATE_PAUSED_PENDING_REMOVAL:int = 1;
		public static const STATE_DOWNLOADED_PENDING_REMOVAL:int = 2;
		public static const STATE_DOWNLOADING:int = 3; 
		public static const STATE_DOWNLOADED:int = 4;
		static private const ORIGIN:Point = new Point();
		
		private var levelPxOffsets:Vector.<int> = new Vector.<int>();
		
		
		
		
		private var gridLookup:BitmapData;
		
		private var stateLookup:BitmapData;
		private var lastStatelookup:BitmapData;
		
		private var previewChangeState:BitmapData;
		
		public function TerrainQueryBox() 
		{
			
			gridLookup = new BitmapData(boundingTiles.width, boundingTiles.height, false, 0);
			stateLookup = new BitmapData(boundingTiles.width*2, boundingTiles.height, false, 0);
			lastStatelookup = new BitmapData(stateLookup.width, stateLookup.height, false, 0);
			previewChangeState = new BitmapData(stateLookup.width, stateLookup.height, true, 0);
			///*
			offset6[0] = 0;  offset6[1] = 1;  // nw  (0)
			offset6[2] = 1;  offset6[3] = 1;
			offset6[4] = 1;  offset6[5] = 0;
			
			offset6[6] = -1;  offset6[7] = 0;  // ne  (0)
			offset6[8] = -1;  offset6[9] = 1;
			offset6[10] = 0;  offset6[11] = 1;
			
			offset6[12] =0;  offset6[13] = -1;  //   sw (|=2,)  10
			offset6[14] = 1;  offset6[15] = -1;
			offset6[16] = 1;  offset6[17] = 0;
			
			offset6[18] = -1;  offset6[19] = 0;   // se (|=2,|=1) 11
			offset6[20] = -1;  offset6[21] = -1;
			offset6[22] = 0;  offset6[23] = -1;
			//*/
			
			// bounding box query on level 1 grid - 32,  1
			// bounding box query on level 2 grid - 64  , 2
			// bounding box query on level 3 grid - 128, 4,
			// bounding box query on level 4 grid - 256, 8
			
			var qSize:uint = 32;
			levelPxOffsets.push(0);
			var count:int = 0;
			var level:int  = 0;
			var boundWidth:int = int(boundingSpace.width) / 32;
			while (qSize < QUERY_SIZE ) {
				
				qSize *= 2;
				levelPxOffsets.push(count += (boundWidth >> level) );
				level++;
			}
			 
			
			 stage.align = StageAlign.TOP_LEFT;
			 stage.scaleMode = StageScaleMode.NO_SCALE;
			 
			 addEventListener(Event.ENTER_FRAME, onEnterFrame);
			 
			 
			 scrollRect = new Rectangle(0, 0, 1680, 1024);
			 
			
			 addChild(testLoadingLayer);
			 addChild( graphicsLayer);
			 
			 addChild( new Bitmap(stateLookup));
			  addChild( new Bitmap(previewChangeState));
		}
		
		private static const START_ZOOM:int = 7;
		private static const START_X:int = 50;
		private static const START_Y:int = 7;
		
		//  http://mt0.google.com/vt/x=50&y=7&z=7
		
		public function getTileURLGoogle(x:int, y:int, zoom:int):String {
			return "http://mt0.google.com/vt/x="+x+"&y="+y+"&z="+zoom;
		}

		// if already downloading, get by grid id location
		// if not already downlaoding
		
		private function onEnterFrame(e:Event):void 
		{
			var mx:int = mouseX;
			var my:int = mouseY;
			var mix:int = Math.round(mouseX/32);
			var miy:int = Math.round(mouseY / 32);
			if (_lmx === mix && _lmy === miy) {
				return;
			}
			
			_lmx = mix;
			_lmy = miy;
			
			
			graphics.clear(); 
			gridLookup.fillRect(gridLookup.rect, 0xFF0000);
			lastStatelookup.copyPixels(stateLookup, stateLookup.rect, ORIGIN);
			previewChangeState.fillRect(previewChangeState.rect, 0);
			stateLookup.fillRect(stateLookup.rect, 0);
			
			var rect:Rectangle;
			
			
			rect = new Rectangle(mix * 32 - 32 * 4 * BASE_PATCH, miy * 32 - 32 * 4* BASE_PATCH, 32 * 8* BASE_PATCH, 32 * 8* BASE_PATCH);
			graphics.lineStyle(0, 0xFF0000, 1);
			
			graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
			
			graphics.lineStyle(0, 0, 1);
			
			var qSize:int;
			
			qSize = 32;
			

			rect.width = 32*4;
			rect.height = 32 * 4;
			rect.x = mix * 32 - 32 * 2
			rect.y = miy * 32 - 32 * 2
			var level:int = 0;
			drawOntoGrid(rect, qSize, level);
		
			while (qSize < QUERY_SIZE ) {
				rect.x -= rect.width*.5; rect.y -= rect.height*.5; rect.width *= 2, rect.height *= 2;
				drawOntoGrid(rect, qSize*=2, ++level);
			}
			
		
			
			
			// determine any change of state from last lookup
			level = 0;
			checkGrid(level);
			
			qSize = 32;
			while (qSize < QUERY_SIZE) {
				qSize *= 2;
				checkGrid(++level);
				
			}
			
			// go through pending removal list and add count, remove those items whose count has exceeded
			
		}
		
		private function checkGrid(level:int):void 
		{
			var xOffset:int = levelPxOffsets[level];
			var yLen:int = (boundingSpace.height / 32) >> level;
			var xLen:int = (boundingSpace.width / 32) >> level;
			for (var y:int = 0; y < yLen; y++) {
				for (var x:int = 0; x < xLen; x++) {
					var xer:int = xOffset + x;
					var last:Boolean = lastStatelookup.getPixel(xer, y) !=0; 
					var now:Boolean = stateLookup.getPixel(xer, y) != 0; 
					if (last != now) {
						resolveState(now, x,y, level);  // should resolve state index
					}
				}
			}
		}
		
		private function resolveState(doLoad:Boolean, x:int, y:int, level:int):void 
		{
			
			previewChangeState.setPixel32( levelPxOffsets[level] + x, y, 0xFF0000FF);
			//throw new Error("DIFFERENT:" + level + ","+[x+levelPxOffsets[level],y]);
			
			//if (!doLoad) throw new Error("TO UNLOAD!" + level + ","+[x+levelPxOffsets[level],y]);
			
		}
		
		private var rectFiller:Rectangle = new Rectangle();
		
		private function drawOntoGrid(sampleRegion:Rectangle, gridSize:int, level:int):void {
	
			var xLimit:int = Math.ceil( (sampleRegion.x+sampleRegion.width)  / gridSize );
			var yLimit:int = Math.ceil( (sampleRegion.y + sampleRegion.height)  / gridSize );
			var parentGridSize:int = gridSize * 2;
			if (xLimit > boundingTiles.x + boundingTiles.width) xLimit = boundingTiles.x + boundingTiles.width ;
			if (yLimit > boundingTiles.y + boundingTiles.height) yLimit = boundingTiles.y + boundingTiles.height ;
			var yStart:int = sampleRegion.y / gridSize;
			var xStart:int = sampleRegion.x / gridSize;
			if (xStart < boundingTiles.x) xStart = boundingTiles.x;
			if (yStart < boundingTiles.y) yStart = boundingTiles.y;
			
			rectFiller.width = gridSize / 32;
			rectFiller.height = gridSize / 32;
			
				var levelPxOffset:int = levelPxOffsets[level];
				
		
			var randColor:uint = 0xFF + (level + 1);// * (65535/8);
			
			var gotParent:Boolean = parentGridSize <= QUERY_SIZE;
			
			for (var yi:int =  yStart; yi < yLimit; yi++) {
					for (var xi:int = xStart; xi < xLimit; xi ++) {
						var xis:int;
						 var yis:int;
						rectFiller.x = xis =( xi - boundingTiles.x) * rectFiller.width;
						rectFiller.y = yis = (yi - boundingTiles.y) * rectFiller.height;
					
	
						if ( (gridLookup.getPixel(xis, yis) & 0xFFFF00) != 0xFF0000) {
							// this is already filled up by something
							//BitmapData().compare()
							continue;
						}
				
						if (gridSize == 32 ) graphics.lineStyle(2, 0xFF)
						else graphics.lineStyle(0, 0, 1);
						graphics.beginFill(0xFF0000, .4);
						graphics.drawRect(xi * gridSize, yi * gridSize, gridSize, gridSize);
						 gridLookup.fillRect(rectFiller, randColor);
							stateLookup.setPixel(xi+levelPxOffset, yi, 0xFF0000);
						
						if (gotParent) {
							if (gridSize == 32) graphics.lineStyle(1, 0xFF0000, 1)
							else graphics.lineStyle(0, 0, 1)
							
							var result:int = 0;
							// based on current region, which quadrant and I'm in?? draw rect on 3 other quadrants.
							var xii:int = xi*gridSize ;
							var yii:int = yi*gridSize;
						
							
							
							result|= ((xi*gridSize) % parentGridSize)  != 0 ? 1 : 0;
							result |= ((yi * gridSize) % parentGridSize) != 0 ? 2 : 0;
					
						
							
							//if (gridSize == 32 ) {
								//graphics.lineStyle(0, 0xFF, 1);
								
								result *= 6;
								
								rectFiller.x = (xis) + offset6[result]*rectFiller.width;
								rectFiller.y = (yis) + offset6[result + 1] * rectFiller.height;
								if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
									gridLookup.fillRect(rectFiller, randColor);
									graphics.beginFill(0xFF0000, .4);
									graphics.drawRect(xii+ offset6[result] * gridSize,
									yii+(offset6[result + 1]) * gridSize,
									gridSize, gridSize);
									stateLookup.setPixel(xi+ levelPxOffset+offset6[result], yi+ offset6[result+1], 0xFF0000);
								}
				
								rectFiller.x = (xis) + offset6[result+2]*rectFiller.width;
								rectFiller.y = (yis) + offset6[result+3]*rectFiller.height;
								if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
									gridLookup.fillRect(rectFiller, randColor);
									graphics.beginFill(0xFF0000, .4);
									graphics.drawRect(xii+ offset6[result + 2] * gridSize,
									yii+(offset6[result + 3]) * gridSize,
									gridSize, gridSize);
									stateLookup.setPixel(xi+ levelPxOffset+offset6[result+2], yi+ offset6[result+3], 0xFF0000);
								}
								
								rectFiller.x = (xis) + offset6[result+4]*rectFiller.width;
								rectFiller.y = (yis) + offset6[result + 5] * rectFiller.height;
								if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
									gridLookup.fillRect(rectFiller, randColor);
									graphics.beginFill(0xFF0000, .4);
									graphics.drawRect(xii+ offset6[result + 4] * gridSize,
									yii+offset6[result + 5] * gridSize,
									gridSize, gridSize);
									stateLookup.setPixel(xi+ levelPxOffset+offset6[result+4], yi+ offset6[result+5], 0xFF0000);
									
								}
								
							//}
							
						
						
						}
				}
			}
			
			
			
			
			
		
			
		}
		
	}

}