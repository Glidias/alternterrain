package alternterrain.materials 
{
	import alternterrain.core.QuadChunkCornerData;
	import alternterrain.core.QuadTreePage;

	
	/**
	 * Optional interface to pass 2 key references to a specific material for handling drawing of textures over a particular region.
	 * Often, this maens passing certain constants to the material (such as UV offsets/multipliers) to ensure the right texture colors are 
	 * sampled within an LOD quadtree, but you can use this for varied cases depending on your material's purpose.
	 * 
	 * @author Glenn Ko
	 */
	public interface ILODTerrainMaterial 
	{
		function visit(cd:QuadChunkCornerData, root:QuadTreePage, patchShift:int, lookupIndex:int):void;
	}
	
}