package examples
{
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
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
		
		private var boundingSpace:Rectangle = new Rectangle(0, 0, 1024, 1024);
		private var offset6:Vector.<int>= new Vector.<int>(6*4, true);
		
		private var _lmx:int = -int.MAX_VALUE;
		private var _lmy:int = -int.MAX_VALUE;
		
		private var testLoadingLayer:Sprite = new Sprite();
		private var graphicsLayer:Sprite = new Sprite();
		override public function get graphics():Graphics {
			return graphicsLayer.graphics;
		}
		
		
		
		public function TerrainQueryBox() 
		{
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
			 
			
			 stage.align = StageAlign.TOP_LEFT;
			 stage.scaleMode = StageScaleMode.NO_SCALE;
			 
			 addEventListener(Event.ENTER_FRAME, onEnterFrame);
			 
			 
			 scrollRect = new Rectangle(0, 0, 1680, 1024);
			 
			
			 addChild(testLoadingLayer);
			 addChild( graphicsLayer);
		}
		
		private static const START_ZOOM:int = 7;
		private static const START_X:int = 50;
		private static const START_Y:int = 7;
		
		//  http://mt0.google.com/vt/x=50&y=7&z=7
		
		public function getTileURLGoogle(x:int, y:int, zoom:int):String {
			return "http://mt0.google.com/vt/x="+x+"&y="+y+"&z="+zoom;
		}

		
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
			
			var rect:Rectangle;
			
			rect = new Rectangle(mix * 32 - 32 * 4 * BASE_PATCH, miy * 32 - 32 * 4* BASE_PATCH, 32 * 8* BASE_PATCH, 32 * 8* BASE_PATCH);
			graphics.lineStyle(0, 0xFF0000, 1);
			graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
			
			graphics.lineStyle(0, 0, 1);
			
			var qSize:int = QUERY_SIZE;
			
			drawOntoGrid(rect, qSize);
			
			
			while(qSize > 32) {
				rect.x += rect.width * .25; rect.y += rect.height * .25; rect.width *= .5, rect.height *= .5;

				drawOntoGrid(rect, qSize*=.5);
		
			}
			
			// TODO: Actual quadtree traversal to get front-to-back order from top of tree;
			
			// leaf smallest node with smallest query square,   --- mark timestamp for any recursed in nodes to mark node as visited...
			// repeat leafing until largest node with largest query square, do not leaf any nodes on the target level where the nodes are deemed visited
			// with any leaf, check if already downloading via bit-vector, if not, than attempt download  // Mark bit flag once already downloaded, 
			
			//for any flushed downloaded content, uncheck bit flag. 
			// For any nodes that no longer exist, place in holding list for flushing, or bring back from holding list if received again.
			
			
		}
		
		
		private function drawOntoGrid(sampleRegion:Rectangle, gridSize:int):void {
	
			var xLimit:int = Math.ceil( (sampleRegion.x+sampleRegion.width)  / gridSize );
			var yLimit:int = Math.ceil( (sampleRegion.y + sampleRegion.height)  / gridSize );
			var parentGridSize:int = gridSize * 2;
		
	
			
			var gotParent:Boolean = parentGridSize <= QUERY_SIZE;
			for (var yi:int =  sampleRegion.y / gridSize; yi < yLimit; yi++) {
					for (var xi:int = sampleRegion.x / gridSize; xi < xLimit; xi ++) {
						
						graphics.lineStyle(0, 0, 1);
						
						if (gridSize == 32 ) graphics.lineStyle(2, 0xFF);
						graphics.drawRect(xi * gridSize, yi * gridSize, gridSize, gridSize);
				
			
					
						
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
								
								graphics.drawRect(xii+ offset6[result] * gridSize,
								yii+(offset6[result + 1]) * gridSize,
								gridSize, gridSize);
								
								graphics.drawRect(xii+ offset6[result + 2] * gridSize,
								yii+(offset6[result + 3]) * gridSize,
								gridSize, gridSize);
								
								graphics.drawRect(xii+ offset6[result + 4] * gridSize,
								yii+offset6[result + 5] * gridSize,
								gridSize, gridSize);
							//}
							
							// iterate through parent levels and unflag bits
						
						}
				}
			}
			
			
			
			
			
		
			
		}
		
	}

}