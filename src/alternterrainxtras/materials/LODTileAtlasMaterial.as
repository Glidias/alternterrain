package alternterrainxtras.materials 
{
	import alternativa.engine3d.materials.Material;
	import alternativa.engine3d.materials.NormalMapSpace;
	import alternativa.engine3d.resources.BitmapTextureResource;
	import alternterrain.core.QuadChunkCornerData;
	import alternterrain.core.QuadTreePage;
	import alternterrain.materials.ILODTerrainMaterial;
	
	/**
	 * Extended TileAtlasMaterial to support ILODTerrainMaterial implementation
	 * @author Glenn Ko
	 */
	public class LODTileAtlasMaterial extends TileAtlasMaterial implements ILODTerrainMaterial
	{
		
		public var uvTilesAcrossShift:int = 5;  // 2^5 = 32 tiles across for each chunk
					
		public function LODTileAtlasMaterial(atlasSheet:BitmapTextureResource, blendAtlas:BitmapTextureResource, mipmapTable:BitmapTextureResource, mipmapUVCap:Number, tileIndexMaps:Vector.<BitmapTextureResource>, normalMaps:Vector.<BitmapTextureResource>, lightMaps:Vector.<BitmapTextureResource>, tileSizePx:int, tilePaddingPxH:int=0, tilePaddingPxV:int=-1) 
		{
			super(atlasSheet, blendAtlas, mipmapTable, mipmapUVCap, tileIndexMaps, normalMaps, lightMaps, tileSizePx, tilePaddingPxH, tilePaddingPxV);
			_normalMapSpace = NormalMapSpace.OBJECT;
		}
		
		
		/* INTERFACE utils.terrainlite.materials.ILODTerrainMaterial */
		
		public function visit(cd:QuadChunkCornerData, root:QuadTreePage, patchShift:int, lookupIndex:int):void 
		{
			_useWaterMode = _waterMode > 0 ? cd.Square.MinY < waterLevel ? _waterMode : 0 : 0;
			
			this.lookupIndex = lookupIndex;
			
			uvOffsetX = (cd.xorg - root.xorg) >> patchShift;
			uvOffsetY = (cd.zorg - root.zorg) >> patchShift;
		uvMultiplier = ( ((1 << cd.Level) << 1) >> patchShift ) >> uvTilesAcrossShift;  
	

		}
		
		override public function clone():Material {
                var res:LODTileAtlasMaterial = new LODTileAtlasMaterial(atlasSheet, blendAtlas, mipmapTable, mipmapUVCap, tileIndexMaps, normalMaps, lightMaps, tileSizePx, tilePaddingPxH, tilePaddingPxV);
                res.clonePropertiesFrom(this);
                return res;
            }
			
			 override protected function clonePropertiesFrom(source:Material):void {
                super.clonePropertiesFrom(source);
                var sMaterial:LODTileAtlasMaterial = LODTileAtlasMaterial(source);
				
            }
		
	}

}