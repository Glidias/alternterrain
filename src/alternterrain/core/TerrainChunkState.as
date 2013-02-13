package alternterrain.core 
{
	import alternativa.engine3d.resources.Geometry;
	import flash.display3D.VertexBuffer3D;


	/**
	 * Simple class to keep track of poolable chunk states between frames.
	 * 
	 * @author Glenn Ko
	 */
	public class TerrainChunkState 
	{
		public var vertexBuffer:VertexBuffer3D;
		public var enabledFlags:int;
		public var square:QuadSquareChunk;
		public var next:TerrainChunkState;
		public var prev:TerrainChunkState;
		public var parent:TerrainChunkStateList;
		
		
		public function TerrainChunkState() 
		{
		
			
		}
		
	
		
	}

}