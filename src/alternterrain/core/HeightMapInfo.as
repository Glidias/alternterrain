package alternterrain.core 
{
	import flash.geom.Point;
	import flash.utils.IDataOutput;
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.IExternalizable;

	
	/**
	 * @author Thatcher Ulrich (tu@tulrich.com)
	 * @author Glenn Ko
	 */
	public class HeightMapInfo implements IExternalizable
	{
		
		public function HeightMapInfo() 
		{
			
		}
		
		//int16*	
		public var Data:Vector.<int>;
		public var	XOrigin:int;
		public var ZOrigin:int;
		public var	XSize:int, ZSize:int;
		public var	RowWidth:int;
		public var	Scale:int = 8;
		
		
		// Retreieve height data directly for writing into bytearray buffer!
		public function getData(ix:int, iz:int):int {
			return Data[ix + iz * RowWidth]; 
		}
		
		public function fillDataWithValue(val:int):void {
			var i:int = Data.length;
			while (--i > -1) Data[i] = val;
		}
		
		/*
		public function getShortData(ix:int, iz:int):int { 
			var i:int = (ix + iz * RowWidth) << 1;
			return ((ShortData[i] << 8) | ShortData[i + 1]);   
		}
		*/

		public function setFixed(val:Boolean):void {
			Data.fixed = val;
		}
		
		public function BoxFilterHeightMap(
                       smoothEdges:Boolean=true):void
{
  //     width: Width of the height map in bytes
  //    height: Height of the height map in bytes
  // heightMap: Pointer to your height map data
  
  // Temporary values for traversing single dimensional arrays
  var x:int = 0;
  var z:int = 0;
  var width:int = XSize;
  var height:int = width;
  
  var  widthClamp:int = (smoothEdges) ?  width : width  - 1;
  var heightClamp:int = (smoothEdges) ? height : height - 1;
  
  // [Optimization] Calculate bounds ahead of time
  var bounds:int = width * height;
  
  // Validate requirements
 
  
  // Allocate the result
  var result:Vector.<int> = new Vector.<int>();  // this should be a float
  var heightMap:Vector.<int> = Data;
  // Make sure memory was allocated
  if (!result)
    return;
  
  for (z = (smoothEdges) ? 0 : 1; z < heightClamp; ++z)
  {
    for (x = (smoothEdges) ? 0 : 1; x < widthClamp; ++x)
    {
      // Sample a 3x3 filtering grid based on surrounding neighbors
      
      var value:Number = 0.0;
      var cellAverage:Number = 1.0;
      
      // Sample top row
      
      if (((x - 1) + (z - 1) * width) >= 0 &&
          ((x - 1) + (z - 1) * width) < bounds)
      {
        value += heightMap[(x - 1) + (z - 1) * width];
        ++cellAverage;
      }
      
      if (((x - 0) + (z - 1) * width) >= 0 &&
          ((x - 0) + (z - 1) * width) < bounds)
      {
        value += heightMap[(x    ) + (z - 1) * width];
        ++cellAverage;
      }
      
      if (((x + 1) + (z - 1) * width) >= 0 &&
          ((x + 1) + (z - 1) * width) < bounds)
      {
        value += heightMap[(x + 1) + (z - 1) * width];
        ++cellAverage;
      }
      
      // Sample middle row
      
      if (((x - 1) + (z - 0) * width) >= 0 &&
          ((x - 1) + (z - 0) * width) < bounds)
      {
        value += heightMap[(x - 1) + (z    ) * width];
        ++cellAverage;
      }
      
      // Sample center point (will always be in bounds)
      value += heightMap[x + z * width];
      
      if (((x + 1) + (z - 0) * width) >= 0 &&
          ((x + 1) + (z - 0) * width) < bounds)
      {
        value += heightMap[(x + 1) + (z    ) * width];
        ++cellAverage;
      }
      
      // Sample bottom row
      
      if (((x - 1) + (z + 1) * width) >= 0 &&
          ((x - 1) + (z + 1) * width) < bounds)
      {
        value += heightMap[(x - 1) + (z + 1) * width];
        ++cellAverage;
      }
      
      if (((x - 0) + (z + 1) * width) >= 0 &&
          ((x - 0) + (z + 1) * width) < bounds)
      {
        value += heightMap[(x    ) + (z + 1) * width];
        ++cellAverage;
      }
      
      if (((x + 1) + (z + 1) * width) >= 0 &&
          ((x + 1) + (z + 1) * width) < bounds)
      {
        value += heightMap[(x + 1) + (z + 1) * width];
        ++cellAverage;
      }
      
      // Store the result
      result[x + z * width] = value / cellAverage;
    }
  }
  

  
  // Store the new one
  Data = result;
}

		public function	Sample(x:int,  z:int):int 

		// Returns the height (y-value) of a point in this heightmap.  The given (x,z) are in
		// world coordinates.  Heights outside this heightmap are considered to be 0.  Heights
		// between sample points are bilinearly interpolated from surrounding points.
		// xxx deal with edges: either force to 0 or over-size the query region....
		{
			// Break coordinates into grid-relative coords (ix,iz) and remainder (rx,rz).

			var	ix:int = (x - XOrigin) >> Scale;
			var	iz:int = (z - ZOrigin) >> Scale;
			
			
			var	mask:int = (1 << Scale) - 1;
			var	rx:int = (x - XOrigin) & mask;
			var	rz:int = (z - ZOrigin) & mask;
		
			

			if (ix < 0 || ix > XSize-1 || iz < 0 || iz > ZSize-1) {
				throw new Error("OUTSIDE!" + ix + "," + iz + ", " + XSize);
				if (ix < 0) ix  = 0;
				if (iz < 0 ) iz = 0;
				if (ix >= XSize ) ix = XSize - 1;
				if (iz >= ZSize) iz = ZSize -1;
				//return 0;	// Outside the grid.
			}
			
			

			var	fx:Number = rx / (mask + 1);
			var	fz:Number = rz / (mask + 1);

			var xSizeAdd:int = ix < XSize-1 ? 1 : 0;
			var zSizeAdd:int = iz < ZSize - 1 ? 1 : 0;  // clamp addition
			var	s00:Number = Data[ix + iz * RowWidth];
			var	s01:Number = Data[(ix+ xSizeAdd ) + iz * RowWidth];
			var	s10:Number = Data[ix + (iz+zSizeAdd) * RowWidth];
			var	s11:Number = Data[(ix+ xSizeAdd) + (iz+zSizeAdd) * RowWidth];

			return (s00 * (1-fx) + s01 * fx) * (1-fz) +
				(s10 * (1-fx) + s11 * fx) * fz;
		}
		
		public function clone():HeightMapInfo {
			var result:HeightMapInfo = new HeightMapInfo();
			
			result.XOrigin= XOrigin;
			result.ZOrigin= ZOrigin;
			result.XSize= XSize;
			result.ZSize= ZSize;
			result.RowWidth= RowWidth;
			result.Scale = Scale;
			result.Data = Data.concat();
			return result;
		}
		
		public function flatten(val:int = 0):void {
			var len:int = Data.length;
			for (var i:int = 0; i < len; i++) {
				Data[i] = val;
			}
		}
		
		public function getHighestLowestBounds():Vector.<Number> {
			var vec:Vector.<Number>  = new Vector.<Number>(2, true);
			var min:Number = Number.MAX_VALUE;
			var max:Number = -Number.MAX_VALUE;
			var i:int = Data.length;
			var h:Number;
			while (--i > -1) {
				h = Data[i];
				if (h < min) min = h;
				if (h > max) max = h;
			}
			vec[0] = min;
			vec[1] = max;
			return vec;
		}

		/*
		public function setFromMesh(mesh:Mesh, heightScale:Number=1, heightOffset:Number=0):void {
			mesh.calculateBounds();
			Scale = 8;
			
			XOrigin = mesh.boundMinX;
			ZOrigin = mesh.boundMinY;
			var vertsX:int = (int(mesh.boundMaxX - mesh.boundMinX) >> 8) + 1;
			var vertsY:int = (int(mesh.boundMaxY - mesh.boundMinY) >> 8) + 1;
			
			RowWidth = vertsX;
			XSize = RowWidth;
			ZSize = vertsY;
			
			var data:Vector.<int> =  new Vector.<int>( (vertsX+1) * (vertsY+1), true);
			for (var v:Vertex = mesh.vertexList; v != null; v = v.next) {
				data[(int(v.y-mesh.boundMinY) >> 8)*vertsX  +   (int(v.x-mesh.boundMinX) >> 8)] = v.z * heightScale + heightOffset;
			}
			Data = data;
		}
		*/
		
		public function copyData(xStart:int, yStart:int, width:int, height:int, hm:HeightMapInfo, destX:int = 0, destY:int = 0 ):void {
			var vec:Vector.<int> = hm.Data;
			var xEnd:int = xStart + width;
			var yEnd:int = yStart + height;
			for (var y:int = yStart; y < yEnd; y++) {
				for (var x:int = xStart; x < xEnd; x++ ) {
					var cx:int = x < 0 ? 0 : x >= hm.XSize ? hm.XSize - 1 : x;
					var cy:int = y < 0 ? 0 : y >= hm.ZSize ? hm.ZSize - 1 : y;
					Data[(y-yStart+destY) * XSize + x - xStart + destX] = vec[ cy * hm.XSize + cx ];
				}
			}
		}
		
		public static function isBase2(val:int):Boolean {
			return Math.pow(2, Math.round( Math.log(val) * Math.LOG2E) ) == val;
		}
		
		public function setFromByteArray(byteArray:ByteArray, heightMult:Number, patchesAcross:int, heightMin:int=0, tileSize:int=256):void 
		{
			if (!isBase2(tileSize)) throw new Error("Tile size isn't base 2!");
			Scale = Math.round( Math.log(Number(tileSize) ) * Math.LOG2E);
			var bWidth:int; var bHeight:int;
			var vertsX:int = bWidth = patchesAcross + 1;
			var vertsY:int = bHeight = patchesAcross + 1;
			
			RowWidth = vertsX;
			XSize = RowWidth;
			ZSize = vertsY;
			
			var data:Vector.<int> =  new Vector.<int>( vertsX*vertsX, true);
			var by:int = patchesAcross + 1;
	
			var lastValue:uint;
			
			for (var y:int = 0; y <  patchesAcross; y++ ) {
				for (var x:int = 0; x < patchesAcross; x++) {
					var xer:int = x < bWidth ? x : bWidth - 1;
					var yer:int = y < bHeight ? y : bHeight - 1;
					data[y * by  +  x] = heightMin + (lastValue = byteArray.readUnsignedByte()) * heightMult;
				}
				data[y * by + x] = heightMin + lastValue * heightMult;
			}
			for (x = 0; x < by; x++) {
				data[y * by + x] = data[(y - 1) * by + x];
			}
			Data = data;
		}
		
	
		
		public function setFromBmpData(bmpData:BitmapData, heightMult:Number, heightMin:int=0, tileSize:int=256):void 
		{
			if (!isBase2(tileSize)) throw new Error("Tile size isn't base 2!");
			Scale = Math.round( Math.log(Number(tileSize) ) * Math.LOG2E );
			var bWidth:int; var bHeight:int;
			var vertsX:int = bWidth = bmpData.width;
			var vertsY:int = bHeight = bmpData.height;
			if ( (vertsX & 1) != 1) {
				//throw new Error("Must be odd number of vertices along x dir!"); 
				vertsX += 1;
			}
			if ( (vertsY & 1) != 1) {
				//throw new Error("Must be odd number of vertices along y dir!"); 
				vertsY += 1;
			}
			
			RowWidth = vertsX;
			XSize = RowWidth;
			ZSize = vertsY;
			
			var data:Vector.<int> =  new Vector.<int>( (vertsX) * (vertsY), true);
			var by:int = vertsY;
			var bx:int = vertsX;
			
			for (var y:int = 0; y <  by; y++ ) {
				for (var x:int = 0; x < bx; x++) {
					var xer:int = x < bWidth ? x : bWidth - 1;
					var yer:int = y < bHeight ? y : bHeight - 1;
					data[y * by  +  x] = heightMin + (bmpData.getPixel(xer,yer) & 0x0000FF) * heightMult;
				}
			}
			Data = data;
		}
		
		
		
		/*
		public static function createFromMesh(mesh:Mesh, heightScale:Number=1, heightOffset:Number=0):HeightMapInfo {
			var result:HeightMapInfo = new HeightMapInfo();
			result.setFromMesh(mesh, heightScale, heightOffset);
			return result;
		}
		*/
		
		
		public static function createFromBmpData(bmpData:BitmapData, x:int = 0, y:int=0, heightMult:Number=16, heightMin:Number=0, tileSize:int=256):HeightMapInfo {
			var result:HeightMapInfo = new HeightMapInfo();
			result.XOrigin = x;
			result.ZOrigin = y;
			result.setFromBmpData(bmpData, heightMult, heightMin, tileSize);
			return result;
		}
		
		static public function createFromByteArray(bytes:ByteArray,patchesAcross:int, x:int = 0, y:int=0, heightMult:Number=16, heightMin:Number=0, tileSize:int=256):HeightMapInfo 
		{
			var result:HeightMapInfo = new HeightMapInfo();
			result.XOrigin = x;
			result.ZOrigin = y;
			result.setFromByteArray(bytes, heightMult, patchesAcross, heightMin, tileSize);
			return result;
		}
		
		/* INTERFACE flash.utils.IExternalizable */
		
		public function readExternal(byte:IDataInput):void 
		{
			XOrigin = byte.readInt();
			ZOrigin = byte.readInt();
			XSize = byte.readInt();
			ZSize = byte.readInt();
			RowWidth = byte.readInt();
			Scale = byte.readInt();
			
			Data = new Vector.<int>(byte.readUnsignedInt(), true);
			var len:uint = Data.length;
			for (var i:uint = 0; i <  len; i++) {
				Data[i] = byte.readShort();
			}
		}
		
		public function writeExternal(byte:IDataOutput):void 
		{
			byte.writeInt(XOrigin);
			byte.writeInt(ZOrigin);
			byte.writeInt(XSize);
			byte.writeInt(ZSize);
			byte.writeInt(RowWidth);
			byte.writeInt(Scale);
			
			//byte.writeObject(Data);
			var len:uint = Data.length;
			byte.writeUnsignedInt(Data.length);
			for (var i:uint = 0; i <  len; i++) {
				byte.writeShort(Data[i]);
			}
		}
		
		public function reset():void 
		{
			Data = new Vector.<int>(RowWidth*RowWidth, true);
		}
		
		public function paddEdgeDataValues():void 
		{
			var x:int; var y:int;
			
			var cap:int;
			
			x = XSize -1;
			cap = ZSize - 1;
			for (y = 0; y < cap; y++) {
				Data[y * RowWidth + x] = Data[y*RowWidth + x - 1];
			}
			
			y = ZSize - 1;
			cap = XSize - 1;
			for (x = 0; x < cap; x++) {
				Data[y * RowWidth + x] = Data[(y-1)*RowWidth + x ];
			}
			
			x = XSize -1;
			y = ZSize -1;
			Data[y * RowWidth + x] = Data[(y-1)*RowWidth + x - 1 ];
		}
		
	}
	
	
	

}