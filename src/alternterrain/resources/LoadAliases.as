package alternterrain.resources 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrain.core.QuadChunkCornerData;
	import alternterrain.core.QuadSquareChunk;
	import alternterrain.core.QuadTreePage;
	import alternterrain.util.Tuple3;
	import flash.net.FileReference;
	import flash.net.registerClassAlias;
	import flash.utils.ByteArray;

	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class LoadAliases 
	{
		
		public function LoadAliases() 
		{
			registerClassAlias("QuadSquareChunk", QuadSquareChunk);
			registerClassAlias("HeightMapInfo", HeightMapInfo);
			registerClassAlias("QuadTreePage", QuadTreePage);
			registerClassAlias("QuadChunkCornerData", QuadChunkCornerData);
			registerClassAlias("Tuple3", Tuple3);
			registerClassAlias("String", String);
		}
		
		public function savePage(page:QuadTreePage, compress:Boolean, defaultFileName:String=null):void {
			var fileRef:FileReference = new FileReference();
			fileRef.save( getByteArray(compress, page), defaultFileName );
		}
		
		public function getByteArray(compress:Boolean, page:QuadTreePage):ByteArray {
			var bytes:ByteArray = new ByteArray();
			
			bytes.writeObject(page);
			
			if (compress) bytes.compress();

			return bytes;
		}
	}

}