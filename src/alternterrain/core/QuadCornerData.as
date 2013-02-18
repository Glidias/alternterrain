package alternterrain.core 
{
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.alternativa3d;
	import alternativa.engine3d.materials.FillMaterial;
	import alternativa.engine3d.primitives.Box;

	use namespace alternativa3d;

	/**
	 * 	A structure used during recursive traversal of the tree to hold
     * relevant but transitory data.
	 * @author Glenn Ko
	 */
	public class QuadCornerData
	{
	
		public var Parent:QuadCornerData;
		public var Square:QuadSquare; //	Square;
		public	var ChildIndex:int;
		public var	Level:int
		
		public	var xorg:int;
		public var zorg:int;
		
		public var Verts:Vector.<int> = new Vector.<int>(4);	//se,sw,nw,ne
		// ne, nw, sw, se [4]
		
		//public var vertexList:Vector.<Vertex>;
	
		public static var BUFFER:Vector.<QuadCornerData> = new Vector.<QuadCornerData>();
		public static var BI:int = 0;
		public static var BLEN:int = 0;
	
		public static function create():QuadCornerData {
			//return new QuadCornerData();
			var result:QuadCornerData;
			if (BI < BLEN) {
				result = BUFFER[BI];
			}
			else {
				result = new QuadCornerData();
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

		
		public function clone():QuadCornerData {
		//	return this;
			var result:QuadCornerData = new QuadCornerData();
			result.Parent = Parent;
			result.Square = Square;
			result.xorg = xorg;
			result.zorg = zorg;
			result.Level = Level;
			result.ChildIndex = ChildIndex;
			result.Verts[0] = Verts[0];
			result.Verts[1] = Verts[1];
			result.Verts[2] = Verts[2];
			result.Verts[3] = Verts[3];
			return result;
		}
		
	
		
		

		public static function createRoot(x:int, y:int, size:int, neighborTilable:Boolean=false):QuadCornerData {
			var quadRoot:QuadCornerData = neighborTilable ? new QuadCornerDataNeighbor() : new QuadCornerData();
			quadRoot.xorg = x;
			quadRoot.zorg = y;
			if (!isBase2(size)) throw new Error("Size isn't base 2!" + size);
			size >>= 1;
			quadRoot.Level = Math.round( Math.log(Number(size)) * Math.LOG2E);
			
			var sq:QuadSquare = new QuadSquare(quadRoot);
	
			return quadRoot;
		}
		
		public static function clearBuffer():void {
			
			
			var len:int = BUFFER.length;
			for (var i:int = 0; i < len; i++) {
				BUFFER[i].dispose();
			}
			
			BUFFER.length = 0;
			BI = 0;
			BLEN = 0;
		}
		
		public function dispose():void {
			Parent = null;
			Square = null;
			Verts  = null;	
		}
		public static function log2(input:Number):Number{
			if(input<=0){
				return NaN;
			}else if((input&(input-1))==0){
				var a:int=0;
				while(input>1){input>>=1; ++a;}
				return a;
			}else{
				return Math.round( Math.log(input) * Math.LOG2E);
			}
		}

				
		public static function isBase2(val:int):Boolean {
			return Math.pow(2, Math.round( Math.log(val) * Math.LOG2E) ) == val;
		}
		
		/*
		public final function setupForRendering(transform:Object3D):void { 
			
			var xorg:int = cd.xorg;
			var zorg:int = cd.zorg;
			var Verts:Vector.<Number> = cd.Verts;
			
			var vertexHeights:Vector.<Number> = cd.Square.Vertex;
		
			
			
			var x:Number, y:Number, z:Number;
			// init vertex list
			var v:Vertex = vertexList[0];
			var half:int = 1 << cd.Level;
			var whole:int = half << 1;
			

			
			v.x =  xorg + half;  v.z = vertexHeights[0];  v.y = zorg + half;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg + whole; v.z = vertexHeights[1]; v.y = zorg + half;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg + whole; v.z = Verts[0]; v.y =  zorg;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg + half; v.z =  vertexHeights[2]; v.y =  zorg;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg; v.z = Verts[1]; v.y = zorg;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg; v.z = vertexHeights[3]; v.y = zorg + half;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			
			v = v.next;
			v.x = xorg; v.z = Verts[2]; v.y = zorg + whole;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
		
			v.x = xorg + half; v.z = vertexHeights[4]; v.y = zorg + whole;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi*x + transform.mj*y + transform.mk*z + transform.ml;
			v = v.next;
			
			v.x = xorg + whole; v.z = Verts[3]; v.y = zorg + whole;
			x = v.x;
			y = v.y;
			z = v.z;
			v.cameraX = transform.ma*x + transform.mb*y + transform.mc*z + transform.md;
			v.cameraY = transform.me*x + transform.mf*y + transform.mg*z + transform.mh;
			v.cameraZ = transform.mi * x + transform.mj * y + transform.mk * z + transform.ml;

			
			// save out interplated clip average values
			var va:Vertex;
			var vb:Vertex;
			
			v = vertexList[1];
			v.value.x = v.x;
			v.value.y = v.y;
			v = v.value;
			va = vertexList[8];
			vb = vertexList[2];
			v.cameraX = va.cameraX + (vb.cameraX - va.cameraX)*.5;
			v.cameraY = va.cameraY + (vb.cameraY - va.cameraY)*.5;
			v.cameraZ = va.cameraZ + (vb.cameraZ - va.cameraZ)*.5; 
			v.z = va.z + (vb.z - va.z) * .5;
			
			v = vertexList[3];
			v.value.x = v.x;
			v.value.y = v.y;
			v = v.value;
			va = vertexList[2];
			vb = vertexList[4];
			v.cameraX = va.cameraX + (vb.cameraX - va.cameraX)*.5;
			v.cameraY = va.cameraY + (vb.cameraY - va.cameraY)*.5;
			v.cameraZ = va.cameraZ + (vb.cameraZ - va.cameraZ)*.5; 
			v.z = va.z + (vb.z - va.z) * .5;
			
			v = vertexList[5];
			v.value.x = v.x;
			v.value.y = v.y;
			v = v.value;
			va = vertexList[6];
			vb = vertexList[4];
			v.cameraX = va.cameraX + (vb.cameraX - va.cameraX)*.5;
			v.cameraY = va.cameraY + (vb.cameraY - va.cameraY)*.5;
			v.cameraZ = va.cameraZ + (vb.cameraZ - va.cameraZ)*.5; 
			v.z = va.z + (vb.z - va.z) * .5;
			
			v = vertexList[7];
			v.value.x = v.x;
			v.value.y = v.y;
			v = v.value;
			va = vertexList[8];
			vb = vertexList[6];					
			v.cameraX = va.cameraX + (vb.cameraX - va.cameraX)*.5;
			v.cameraY = va.cameraY + (vb.cameraY - va.cameraY)*.5;
			v.cameraZ = va.cameraZ + (vb.cameraZ - va.cameraZ)*.5; 
			v.z = va.z + (vb.z - va.z) * .5;
			
		}
		*/
		
	}

}