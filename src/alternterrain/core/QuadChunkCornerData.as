package alternterrain.core 
{
	
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class QuadChunkCornerData
	{
	
		public var Parent:QuadChunkCornerData;
		public var Square:QuadSquareChunk; //	Square;
		public	var ChildIndex:int;
		public var	Level:int
		
		public	var xorg:int;
		public var zorg:int;
	
		public static var BUFFER:Vector.<QuadChunkCornerData> = new Vector.<QuadChunkCornerData>();
		public static var BI:int = 0;
		public static var BLEN:int = 0;
		
		public static function createFromCornerData(qd:QuadCornerData, square:QuadSquareChunk, parent:QuadChunkCornerData=null):QuadChunkCornerData {
			var me:QuadChunkCornerData = new QuadChunkCornerData();
			me.Parent = parent;
			me.Square = square;
			me.ChildIndex = qd.ChildIndex;
			me.xorg = qd.xorg;
			me.zorg = qd.zorg;
			me.Level = qd.Level;
			return me;
		}
	
		public static function create():QuadChunkCornerData {
			//return new QuadChunkCornerData();
			var result:QuadChunkCornerData;
			if (BI < BLEN) {
				result = BUFFER[BI];
			}
			else {
				result = new QuadChunkCornerData();
				BUFFER[BLEN++] = result ;
			}

			
			BI++;
			return result;
		}
		
		public static function setFixedBufferSize(size:int):void {
			//return;
			BUFFER.length = size;
			BUFFER.fixed = true;
			BLEN = size;
		}

		
		public function clone():QuadChunkCornerData {
		//	return this;
			var result:QuadChunkCornerData = new QuadChunkCornerData();
			result.Parent = Parent;
			result.Square = Square;
			result.xorg = xorg;
			result.zorg = zorg;
			result.Level = Level;
			result.ChildIndex = ChildIndex;
			return result;
		}


	
		
	}

}