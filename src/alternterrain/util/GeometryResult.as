package alternterrain.util 
{
	/**
	 * ...
	 * @author Glenn Ko
	 */
		import alternativa.engine3d.resources.Geometry;


		public class GeometryResult {
			
			public var geometry:Geometry;
			public var indexLookup:Vector.<int>;
			public var uvSeg:Number;
			public var edgeChangeVertexIndex:int;
			public var verticesAcross:int;
			public var patchSize:int;
			
			public function getIndexAtUV(u:Number, v:Number):int {

				return indexLookup[ int(v / uvSeg) * verticesAcross + int(u/uvSeg) ];
			}
			public function getIndex(x:int, y:int):int {

				return indexLookup[ y* verticesAcross + x ];
			}
			
		}

}