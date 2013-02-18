package alternterrain.core 
{
	import alternativa.engine3d.alternativa3d;
	import alternativa.engine3d.materials.Material;
	import alternativa.engine3d.objects.Surface;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	import flash.utils.IExternalizable;

	import alternativa.engine3d.alternativa3d;

	use namespace alternativa3d;
	
	/**
	 * 
	 * @author Glenn Ko
	 */
	public class QuadTreePage extends QuadChunkCornerData implements IExternalizable
	{
		public var material:Material;
		
		public var requirements:int;
		public var heightMap:HeightMapInfo;  // highest detail heights
		//alternativa3d var _uvTileShift:int = 0;
		public var uvTileSize:int = 0;
		//public var normals:NormMapInfo;   // todo: depeciate!
		
		public function QuadTreePage() 
		{
			
		}
		
		/* INTERFACE flash.utils.IExternalizable */
		
		public function writeExternal(output:IDataOutput):void 
		{
			// todo: normalmap, uvTileSize
			
			output.writeShort(requirements);
			output.writeObject(heightMap);
			output.writeShort(Level);
			output.writeInt(xorg);
			output.writeInt(zorg);
			output.writeObject(Square);
			
			output.writeBoolean(false); // todo: depciate fully
			
			
		}
		
		public function readExternal(input:IDataInput):void 
		{
			requirements = input.readShort();
			//throw new Error((input as ByteArray).position + ", " + (input as ByteArray).length);
			heightMap = input.readObject();
			Level = input.readShort();
			xorg = input.readInt();
			zorg = input.readInt(); 
			Square = input.readObject();
			if (input.readBoolean()) {
				//normals = input.readObject();
			}
			
		}
		
		public static function create(x:int, y:int, size:int):QuadTreePage {
			var quadRoot:QuadTreePage = new QuadTreePage();
			quadRoot.xorg = x;
			quadRoot.zorg = y;
			if (!QuadCornerData.isBase2(size)) throw new Error("Size isn't base 2!" + size);
			size >>= 1;
			quadRoot.Level = Math.round( Math.log(Number(size)) * Math.LOG2E );
			
			return quadRoot;
		}
		
	
		
		
	}
}