package terraingen.island 
{
	import flash.display.BitmapData;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public interface ITileAtlasPainter 
	{
		
		function isValidTileAtlas(acrossH:int, acrossV:int):Boolean;
		function getUint(ru:Number, rv:Number, gu:Number, gv:Number, bu:Number, bv:Number, ku:Number, kv:Number, ma:int, mb:int, mc:int, md:int):uint;
		function paintToTileMap(tileMap:Vector.<uint>, tilesAcross:int, tileIndex:uint, x:int, y:int):void;
		
		
	}

}