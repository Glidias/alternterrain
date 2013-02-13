package alternterrain.core 
{
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class Grid_QuadChunkCornerData 
	{
		public var vec:Vector.<QuadTreePage>;
		public var cols:int;

		public var originX:int = 0;
		public var originY:int = 0;
		
		public function Grid_QuadChunkCornerData() 
		{
			
		}
		
		
		
		/**
		 * Gets root chunk corner data at specific coordinates
		 * @param	x	World coordinates
		 * @param	y	World coordinates
		 * @param	level	Indicates the level which is the world size of a root chunk
		 * @return	A root QuadChunkCornerData.
		 */
		public function getCornerData(x:int, y:int, level:int):QuadChunkCornerData {
			level++;
			//if (x - originX < 0) throw new Error("WRONGx"+originX +", "+x);
			//if (y - originY < 0) throw new Error("WRONGy"+originY +", "+y);
			return vec[ ((y-originY) >> (level))*cols + ((x-originX)>>(level)) ]; 
		}
		
		
		
		
	}

}