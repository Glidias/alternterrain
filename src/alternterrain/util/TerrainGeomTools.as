package alternterrain.util 
{
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.resources.Geometry;
	import alternativa.engine3d.alternativa3d;
	import alternativa.protocol.codec.complex.ByteArrayCodec;
	import alternterrain.resources.GeometryFixed;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display3D.IndexBuffer3D;
	import flash.filters.BlurFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	use namespace alternativa3d;
	
	/**
	 * Generic methods useful for generating terrain LODs and such.
	 * @author Glenn Ko
	 */
	public class TerrainGeomTools 
	{
		
		public static function createPaddedProtoLODForMesh(patchesAcross:int = 32, patchSize:int = 256):GeometryResult {
			var result:GeometryResult = new GeometryResult();
			var vAcross:int = patchesAcross + 1  + 4;
			var geom:Geometry = new GeometryFixed(vAcross * vAcross);
			var attributes:Array = [
			  VertexAttributes.POSITION,
			  VertexAttributes.POSITION,
			  VertexAttributes.POSITION,
			  VertexAttributes.TEXCOORDS[0],
			  VertexAttributes.TEXCOORDS[0],
			   VertexAttributes.NORMAL,
			  VertexAttributes.NORMAL,
			  VertexAttributes.NORMAL,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4
			];
			geom.addVertexStream(attributes);
			var indices:Vector.<uint> = new Vector.<uint>();
			var vertices:ByteArray = new ByteArray();
			vertices.endian = Endian.LITTLE_ENDIAN;
			var x:int;
			var y:int;
			var segUVSize:Number = 1 / patchesAcross;
			
			var offsetAdditionalData:Number = 28;
			var vIndexLookup:Vector.<int> = new Vector.<int>(vAcross * vAcross, true);
			
			var count:int = 0;
			// Start set of vertices whose vertex normals won't change when LOD stitching between chunks occurs.
			
			// inner vertices (arranged in reading direction: left to right, top to bottom)
			for (y = 0; y < vAcross; y++) {
				for (x = 0; x < vAcross; x++) {
					writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData);
					vIndexLookup[y*vAcross + x] = count++;
				}
			}
			geom._attributesStreams[VertexAttributes.POSITION].data = vertices;
			result.geometry = geom;		
			result.indexLookup = vIndexLookup;
			return result;
		}
		
		public static function modifyGeometryByHeightData(geometry:Geometry, heightData:Vector.<int>, verticesAcross:int):void {
			var uvs:Vector.<Number> = geometry.getAttributeValues(VertexAttributes.TEXCOORDS[0]);
			var positions:Vector.<Number> =  geometry.getAttributeValues(VertexAttributes.POSITION);
			
			var vLen:int = geometry.numVertices;
			for (var i:int = 0; i < vLen; i++) {
				var x:int = uvs[i * 2] * (verticesAcross-1);
				var y:int = uvs[i * 2 + 1] * (verticesAcross-1);
				positions[i * 3 + 2] =  heightData[y*verticesAcross + x];
			
			}
			
			 geometry.setAttributeValues(VertexAttributes.POSITION, positions);
		}
		
		public static function createLODTerrainChunkForMesh(patchesAcross:int=32, patchSize:int=256):GeometryResult 
		{
			var vAcross:int = patchesAcross + 1;
			var i:int;
			
			// code similar to Mesh class in Alternativa3D
			var geom:Geometry = new Geometry(vAcross * vAcross);
			var attributes:Array = [
			  VertexAttributes.POSITION,
			  VertexAttributes.POSITION,
			  VertexAttributes.POSITION,
			  VertexAttributes.TEXCOORDS[0],
			  VertexAttributes.TEXCOORDS[0],
			   VertexAttributes.NORMAL,
			  VertexAttributes.NORMAL,
			  VertexAttributes.NORMAL,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4,
			  VertexAttributes.TANGENT4
			];
			geom.addVertexStream(attributes);
			var indices:Vector.<uint> = new Vector.<uint>();
			var vertices:ByteArray = new ByteArray();
			vertices.endian = Endian.LITTLE_ENDIAN;
			var x:int;
			var y:int;
			var segUVSize:Number = 1 / patchesAcross;
			
			var offsetAdditionalData:Number = 28;
			
			// vIndexLookup could be precomputed actually
			var vIndexLookup:Vector.<int> = new Vector.<int>(vAcross * vAcross, true);
			//i = vIndexLookup.length;
			//while (--i > -1) { vIndexLookup[i] = -1; }
			
			var count:int = 0;
			
			// Start set of vertices whose vertex normals won't change when LOD stitching between chunks occurs.
			
			// inner vertices (arranged in reading direction: left to right, top to bottom)
			for (y = 2; y < (vAcross-2); y++) {
				for (x = 2; x < (vAcross-2); x++) {
					writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData);
					vIndexLookup[y*vAcross + x] = count++;
				}
			}
			
			
			
			// diamond vertex normals don't change when LOD edges stitch, cross vertex normals do.
			// edge flow order: east, north, west, south (always edge update from previous vertex if available)
			
			// Each cardinal side has their own unique set of diamond vertices (ie. no sharing of vertices between sides, since they share no common corners), 
			// unlike cross vertices which share common corner vertices.
			
			//   even-indexed outerEdge vertices (inside) aka. Inner diamond vertices 
			x = vAcross -2;  // east inner diamond
			for (y = vAcross-3; y >= 2; y-=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 0!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y =  1;  // north  inner diamond
			for (x = vAcross -3; x >=2; x-=2) {  
				writeVertices(vertices, x, y, patchSize, segUVSize,offsetAdditionalData);  //if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 1!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			x = 1;   // west  inner diamond
			for (y = 2; y <= vAcross-3; y+=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize,offsetAdditionalData);  // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 2!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y = vAcross - 2;  // south  inner diamond
			for (x = 2; x <= vAcross-3; x+=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 3!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			
			//   odd-indexed outerEdge vertices (outside) aka. Outer diamond vertices.
			x = vAcross -1;  // east outer diamond
			for (y = vAcross-2; y >= 1; y-=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize,offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 4!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y = 0;
			for (x = vAcross-2; x >=1; x-=2) {    // north outer diamond
				writeVertices(vertices, x, y, patchSize, segUVSize,offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 5!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			x = 0;   // west  outer diamond
			for (y = 1; y <= vAcross-2; y+=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize,offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 6!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y = vAcross - 1;  // south outer diamond
			for (x = 1; x <= vAcross-2; x+=2) {
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 7!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			
			
			var noChangeVertexCount:int = count;
			
			// The vertex indices from here onwards indicates the close-to-edge vertices whose vertex normals can potentially change... (ie. they are cross vertices) as a result
			// of LOD stiching to neighbouring LOD chunks. We process each side's vertex order from the inside out in typical edge-flow order. 
			
			// Remember to skip starting vertex for subsequent sides due to shared corner vertex when flowing to a new side.
			
			// EAST
			x = vAcross -2; 
			for (y = vAcross-2; y >= 1; y-=2) {   // inner cross  (odd-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 8!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			x = vAcross - 1;  
			for (y = vAcross - 1; y >= 0; y-=2 ) { // outer cross  (even-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 9!");
				vIndexLookup[y*vAcross + x] = count++;
			} 
			
			// NORTH
			y = 1; 
			for (x = vAcross-4; x >= 1; x-=2) {   // inner cross  (odd-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 10!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y = 0;  
			for (x = vAcross - 3; x >= 0; x-=2 ) { // outer cross  (even-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData);  //if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 11!");
				vIndexLookup[y*vAcross + x] = count++;
			} 
			
			// WEST
			x = 1; 
			for (y = 3; y <= vAcross-2; y+=2) {   // inner cross  (odd-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData);  //if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 12!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			x = 0;  
			for (y = 2; y <= vAcross-1; y+=2 ) { // outer cross  (even-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData);  //if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 13!");
				vIndexLookup[y*vAcross + x] = count++;
			} 
			 
			// SOUTH     (remember to skip last vertex to avoid looping back to first vertex at east side)
			y = vAcross -2;
			for (x = 3; x <= vAcross - 4; x+=2) {   // inner cross  (odd-indexed vertices)
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 14!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			y = vAcross -1;
			for (x = 2; x <= vAcross - 3; x+=2) {   // outer cross  (even-indexed vertices) 
				writeVertices(vertices, x, y, patchSize, segUVSize, offsetAdditionalData); // if (vIndexLookup[y * vAcross + x] != -1) throw new Error("Vertex already found 15!");
				vIndexLookup[y*vAcross + x] = count++;
			}
			
				
				// Form up cross hatch index-buffer. 
				// Iterate through quads and form cross patches (4 patches).
				for (y = 0; y < patchesAcross; y += 2) {
					for (x = 0; x < patchesAcross; x += 2) {
						// ne
						createFace(indices, vertices, vIndexLookup[y*vAcross + x+2], vIndexLookup[y*vAcross + x+1], vIndexLookup[(y + 1)*vAcross + x + 1], vIndexLookup[(y+1)*vAcross + x + 2], 0, 0, 1, 1, 0, 0, -1, false);
						//nw
						createFace(indices, vertices, vIndexLookup[y * vAcross + x], vIndexLookup[(y + 1) * vAcross + x], vIndexLookup[(y + 1) * vAcross + x + 1], vIndexLookup[y * vAcross + x + 1], 0, 0, 1, 1, 0, 0, -1, false);
						// sw
						createFace(indices, vertices, vIndexLookup[(y+1) * vAcross + x+1], vIndexLookup[(y + 1) * vAcross + x], vIndexLookup[(y + 2) * vAcross + x], vIndexLookup[(y+2) * vAcross + x + 1], 0, 0, 1, 1, 0, 0, -1, false);
						// se
						createFace(indices, vertices, vIndexLookup[(y+1) * vAcross + x+1], vIndexLookup[(y + 2) * vAcross + x+1], vIndexLookup[(y + 2) * vAcross + x+2], vIndexLookup[(y+1) * vAcross + x + 2], 0, 0, 1, 1, 0, 0, -1, false);
					}
				}
				
				geom._vertexStreams[0].data = vertices;
				geom._indices = indices; 
		
				var result:GeometryResult = new GeometryResult();
				result.geometry = geom;
				result.edgeChangeVertexIndex = noChangeVertexCount;
				result.uvSeg = segUVSize;
				result.indexLookup  = vIndexLookup;
				result.verticesAcross = vAcross;
				result.patchSize = patchSize;
			return result;
		}
		
		public static const NORTH_EAST:int = 0;
		public static const NORTH_WEST:int = 1;
		public static const SOUTH_WEST:int = 2;
		public static const SOUTH_EAST:int = 3;
		
		public static const MASK_EAST:int = 1;
		public static const MASK_NORTH:int = 2;
		public static const MASK_WEST:int = 4;
		public static const MASK_SOUTH:int = 8;
		
		public static function writeEdgeVerticesToByteArray2(patchesAcross:int, vIndexLookup:Vector.<int>, byteArray:ByteArray, edgeMask:int):void {
			
			var x:int;
			var y:int;
			var vAcross:int = patchesAcross + 1;
			var count:int;
		//	/*
			// east
			x = vAcross - 5;
			
			count = 0;
			for (y = vAcross-7; y >= 4; y -= 2) {
				writeConditionalQuad(x, y, vAcross, byteArray, vIndexLookup, edgeMask & MASK_EAST); count++;
			}
			
			
			// north-east corner
			y = 2;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_NORTH | MASK_EAST) );
		//	*/
			// north
			count = 0;
			for (x = vAcross-7; x >= 4; x -= 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_NORTH);  count++; 
			}
	//		/*
			// north-west corner
			x = 2;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_NORTH | MASK_WEST ) );
			
			// west
			count = 0;
			for (y = 4; y <= vAcross-7; y += 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_WEST);  count++;
			}
			
			
			// south-west corner
			y = vAcross - 5;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_SOUTH | MASK_WEST) );

			
			//south
			count = 0;
			y = vAcross - 5;
			for (x = 4; x <= vAcross-7; x += 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_SOUTH );  count++;
			}

			// south-east corner
			x = vAcross - 5;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_SOUTH | MASK_EAST) );
//*/
		}
		
		public static function writeOuterFacesToByteArray(patchesAcross:int, vIndexLookup:Vector.<int>, byteArray:ByteArray):void {
			
			var x:int;
			var y:int;
			var vAcross:int = patchesAcross + 1;
			var count:int;
		//	/*
			// east
			x = vAcross - 3;
			var toggler:Boolean;
			
			count = 0;
			toggler = false;
			for (y = vAcross - 5; y >= 2; y -= 2) {
				writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup, toggler ?  NORTH_WEST : SOUTH_WEST);
				toggler = !toggler;
			}
			
			
			// north-east corner
			y = 0;
			writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup,  SOUTH_WEST);
		//	*/
			// north
			count = 0;
			toggler = false;
			for (x = vAcross-5; x >= 2; x -= 2) {
				writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup, toggler ?  SOUTH_WEST : SOUTH_EAST);
				toggler = !toggler;
			}
	//		/*
			// north-west corner
			x = 0;
			writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup,  SOUTH_EAST);
			
			// west
			count = 0;
			toggler = false;
			for (y = 2; y <= vAcross - 5; y += 2) {
				writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup, toggler ?  SOUTH_EAST : NORTH_EAST);
				
				toggler = !toggler;
			}
			
			
			// south-west corner
			y = vAcross - 3;
			writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup,  NORTH_EAST);

			
			//south
			count = 0;
			y = vAcross - 3;
			toggler = false;
			for (x = 2; x <= vAcross-5; x += 2) {
				writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup, toggler ?  NORTH_EAST : NORTH_WEST);
				toggler = !toggler;
			}

			// south-east corner
			x = vAcross - 3;
			writeSingleQuadPatchAt( x, y, vAcross, byteArray, vIndexLookup,  NORTH_WEST);

//*/
		}
		
		
		public static function writeEdgeVerticesToByteArray(patchesAcross:int, vIndexLookup:Vector.<int>, byteArray:ByteArray, edgeMask:int):void {
			
			var x:int;
			var y:int;
			var vAcross:int = patchesAcross + 1;
			var count:int;
		//	/*
			// east
			x = vAcross - 3;
			
			count = 0;
			for (y = vAcross-5; y >= 2; y -= 2) {
				writeConditionalQuad(x, y, vAcross, byteArray, vIndexLookup, edgeMask & MASK_EAST); count++;
			}
			
			
			// north-east corner
			y = 0;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_NORTH | MASK_EAST) );
		//	*/
			// north
			count = 0;
			for (x = vAcross-5; x >= 2; x -= 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_NORTH);  count++; 
			}
	//		/*
			// north-west corner
			x = 0;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_NORTH | MASK_WEST ) );
			
			// west
			count = 0;
			for (y = 2; y <= vAcross-5; y += 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_WEST);  count++;
			}
			
			
			// south-west corner
			y = vAcross - 3;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_SOUTH | MASK_WEST) );

			
			//south
			count = 0;
			y = vAcross - 3;
			for (x = 2; x <= vAcross-5; x += 2) {
				writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & MASK_SOUTH );  count++;
			}

			// south-east corner
			x = vAcross - 3;
			writeConditionalQuad(x,y,vAcross,byteArray,vIndexLookup, edgeMask & (MASK_SOUTH | MASK_EAST) );
//*/
		}
		
		public static function getIndexFromShortBytes(byteArray:ByteArray, pos:int=0):Vector.<uint> {
			byteArray.position = pos;
			var vec:Vector.<uint> = new Vector.<uint>();
			for (var i:int = 0; i < byteArray.length; i += 2) {
				vec.push(byteArray.readShort());
			}
			return vec;
			
		}
		
		public static function writeRepeatingTileUVs(vec:Vector.<Number>, step:Number, vIndexLookup:Vector.<int>, vAcross:int ):void {
			var x:int;
			var y:int;
			for (y = 0; y <vAcross;y++) {
				for (x = 0; x < vAcross; x++ ) {
					var pos:int = vIndexLookup[y * vAcross + x] * 2;
					vec[pos] = x * step;
					vec[pos + 1] = y * step;
				}
			}
		}
		
		/**
		 * Based on the number of levels in a quad tree, calculates offset table and number of nodes/data in such a tree starting from lowest LOD.
		 * @param	result	A vector to store the offsets
		 * @param	_depth	The number of levels in a quad tree
		 * @param   padding	 Any amount of padding you wish to add along both x and y dimensions to assume more nodes for data. (eg. good for vertex count offset determination - use padding "1")
		 * @param   multiplier  Multipler along 1 dimension before adding padding
		 * @return	The total number of data in a quad tree
		 */
		public static function calculateQuadTreeOffsetTable(result:Vector.<int>, _depth:int, padding:int=0, multiplier:int=1):int {
			//compute total number of nodes,
			//from lowest -> highest resolution
			
		
			var i:int;
			result.fixed = false;
			result.length = _depth;
			result.fixed = true;
			
			//allocate nodes, from lowest -> highest resolution
			var offset:int = 0;
			for (i = 0; i < _depth; i++)
			{
				//write level offset
				result[i] = offset;
				var a:int = (1 << i)*multiplier  + padding;
				
				offset += a * a;
			}
			
			return offset;
		}
		
		public static function getQuadTreeDistanceTable(_depth:int, padding:int=0, multiplier:int=1):Vector.<int> {
			//compute total number of nodes,
			//from lowest -> highest resolution
			var result:Vector.<int> = new Vector.<int>(_depth, true);
			
			//allocate nodes, from lowest -> highest resolution
			var offset:int = 0;
			var i:int;
			for (i = 0; i < _depth; i++)
			{
				//write length along 1 dimension
				result[i] = (1 << i)*multiplier  + padding;
			
			}
			return result;
		}
		
		
		
		public static function getIndicesFromByteArray(byteArray:ByteArray, position:int=0):Vector.<uint> {
			var vec:Vector.<uint> = new Vector.<uint>();
			byteArray.position = position;
			var len:int = byteArray.length - position;
			for (var i:int = 0; i < len; i+=2) {
				vec.push( byteArray.readShort() );
			}
			return vec;
		}
			
		public static function writeInnerIndicesToByteArray(patchesAcross:int, vIndexLookup:Vector.<int>, byteArray:ByteArray, addInnerPadding:int=0):void {
			var x:int;
			var y:int;
			var count:int = 0;
			var vAcross:int = patchesAcross + 1;
			for (y = 2+addInnerPadding; y < patchesAcross-2-addInnerPadding; y += 2) {
				for (x = 2+addInnerPadding; x < patchesAcross-2-addInnerPadding; x += 2) {
					writeRegularQuad(x, y, vAcross, byteArray, vIndexLookup);
					count++;
				}
			}
		}
		
		static private function writeSingleQuadPatchAt(x:int, y:int, vAcross:int, byteArray:ByteArray, vIndexLookup:Vector.<int>, childIndex:int):void 
		{
			var a:int;
			var b:int;
			var c:int;
			var d:int;
					// ne
				if (childIndex === 0) {
					a = vIndexLookup[(y+2)* vAcross + x ];  b = vIndexLookup[(y+2)* vAcross + x + 2]; c =  vIndexLookup[(y) * vAcross + x + 2]; d=  vIndexLookup[(y) * vAcross + x];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
				}
				else if (childIndex === 1) {
					//nw
					a = vIndexLookup[(y+2) * vAcross + x+2]; b = vIndexLookup[(y ) * vAcross + x + 2]; c = vIndexLookup[(y) * vAcross + x ]; d= vIndexLookup[(y+2) * vAcross + x];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
				}
				else if (childIndex === 2) {
					// sw
					a = vIndexLookup[(y) * vAcross + x + 2]; b = vIndexLookup[(y) * vAcross + x]; c =  vIndexLookup[(y + 2) * vAcross + x]; d = vIndexLookup[(y + 2) * vAcross + x + 2];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
				}
				else {
					// se
					a = vIndexLookup[(y) * vAcross + x ]; b = vIndexLookup[(y + 2) * vAcross + x]; c = vIndexLookup[(y + 2) * vAcross + x + 2]; d= vIndexLookup[(y ) * vAcross + x + 2];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
				}
		}
		
	
		// cross-hatch quad
		static private function writeRegularQuad(x:int, y:int, vAcross:int, byteArray:ByteArray, vIndexLookup:Vector.<int>):void 
		{
			var a:int;
			var b:int;
			var c:int;
			var d:int;
					// ne
					a = vIndexLookup[y * vAcross + x + 2];  b = vIndexLookup[y * vAcross + x + 1]; c =  vIndexLookup[(y + 1) * vAcross + x + 1]; d=  vIndexLookup[(y + 1) * vAcross + x + 2];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					//nw
					a = vIndexLookup[y * vAcross + x]; b = vIndexLookup[(y + 1) * vAcross + x]; c = vIndexLookup[(y + 1) * vAcross + x + 1]; d= vIndexLookup[y * vAcross + x + 1];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					// sw
					a = vIndexLookup[(y + 1) * vAcross + x + 1]; b = vIndexLookup[(y + 1) * vAcross + x]; c =  vIndexLookup[(y + 2) * vAcross + x]; d = vIndexLookup[(y + 2) * vAcross + x + 1];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					// se
					a = vIndexLookup[(y + 1) * vAcross + x + 1]; b = vIndexLookup[(y + 2) * vAcross + x + 1]; c = vIndexLookup[(y + 2) * vAcross + x + 2]; d= vIndexLookup[(y + 1) * vAcross + x + 2];
					byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
		}
		

		static private function writeConditionalQuad(x:int, y:int, vAcross:int, byteArray:ByteArray, vIndexLookup:Vector.<int>, disabledEdgeVertices:int):void 
		{
			var a:int;
			var b:int;
			var c:int;
			var d:int;
					// ne
					a = vIndexLookup[y * vAcross + x + 2];  // tr
					b = vIndexLookup[y * vAcross + x + 1];  // tl
					c =  vIndexLookup[(y + 1) * vAcross + x + 1];  // bl
					d=  vIndexLookup[(y + 1) * vAcross + x + 2];  // br
					if ( (disabledEdgeVertices & (MASK_NORTH | MASK_EAST)  ) ) {
						if ( !(disabledEdgeVertices & MASK_NORTH) ) {
							byteArray.writeShort(c); byteArray.writeShort(a); byteArray.writeShort(b);
						}
						if ( !(disabledEdgeVertices & MASK_EAST) ) {
							byteArray.writeShort(c); byteArray.writeShort(d); byteArray.writeShort(a);
						}
					}
					else {
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					}
					
					//nw
					///*
					a = vIndexLookup[y * vAcross + x];    // tl
					b = vIndexLookup[(y + 1) * vAcross + x];   //bl
					c = vIndexLookup[(y + 1) * vAcross + x + 1];   //br
					d = vIndexLookup[y * vAcross + x + 1];  // tr
					if ( (disabledEdgeVertices & (MASK_NORTH | MASK_WEST)  ) ) {
						if ( !(disabledEdgeVertices & MASK_NORTH) ) {
							byteArray.writeShort(c); byteArray.writeShort(d); byteArray.writeShort(a);
						}
						if ( !(disabledEdgeVertices & MASK_WEST) ) {
							byteArray.writeShort(c); byteArray.writeShort(a); byteArray.writeShort(b);
						}
					}
					else {
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					}
					//*/
					
					// sw
					a = vIndexLookup[(y + 1) * vAcross + x + 1];  // tr
					b = vIndexLookup[(y + 1) * vAcross + x];   // tl
					c =  vIndexLookup[(y + 2) * vAcross + x];   // bl
					d = vIndexLookup[(y + 2) * vAcross + x + 1];  // br
					if ( (disabledEdgeVertices & (MASK_SOUTH | MASK_WEST)  ) ) {
						if ( !(disabledEdgeVertices & MASK_SOUTH) ) {
							byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
						}
						if ( !(disabledEdgeVertices & MASK_WEST) ) {
							byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						}
					}
					else {
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					}
					
					// se
					
					a = vIndexLookup[(y + 1) * vAcross + x + 1];   //tl
					b = vIndexLookup[(y + 2) * vAcross + x + 1];  // bl
					c = vIndexLookup[(y + 2) * vAcross + x + 2];   // br
					d = vIndexLookup[(y + 1) * vAcross + x + 2];  // tr
					if ( (disabledEdgeVertices & (MASK_SOUTH | MASK_EAST)  ) ) {
						if ( !(disabledEdgeVertices & MASK_SOUTH) ) {
							byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						}
						if ( !(disabledEdgeVertices & MASK_EAST) ) {
							byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
						}
					}
					else {
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
						byteArray.writeShort(a); byteArray.writeShort(c); byteArray.writeShort(d);
					}
				
					
					a = vIndexLookup[(y + 1) * vAcross + x + 1];
					if (disabledEdgeVertices & MASK_EAST)  {
						b = vIndexLookup[(y + 2) * vAcross + x + 2];
						c = vIndexLookup[y * vAcross + x + 2];
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					}
					if (disabledEdgeVertices & MASK_NORTH) {
						b = vIndexLookup[y * vAcross + x + 2]; 
						c = vIndexLookup[y * vAcross + x];
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					}
					if (disabledEdgeVertices & MASK_WEST) {
						b = vIndexLookup[y * vAcross + x];
						c = vIndexLookup[(y + 2) * vAcross + x];
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					}
					if (disabledEdgeVertices & MASK_SOUTH) {
						b = vIndexLookup[(y + 2) * vAcross + x];
						c = vIndexLookup[(y + 2) * vAcross + x + 2];
						byteArray.writeShort(a); byteArray.writeShort(b); byteArray.writeShort(c);
					}
		}
		
		public static function getBitmapDataHeights(bmpData:BitmapData, across:int, mult:Number, baseZ:int = 0):Vector.<int> {
		
			var heights:Vector.<int> = new Vector.<int>(across*across);
			for (var y:int = 0; y <  across; y++ ) {
				for (var x:int = 0; x < across; x++) {
					heights[y * across  +  x] = baseZ + (bmpData.getPixel(x,y) & 0x0000FF) * mult;
				}
			}
			
			return heights;
		}
		
		/**
		 * This method oesn't seem to work , but i copied it somewhere...
		 * @param	Passes
		 * @param	HeightData
		 * @param	MapWidth
		 */
		public static function smoothTerrain(Passes:int, HeightData:Vector.<int>, MapWidth:int):void
		{
		   var newHeightData:Vector.<int>;
			var MapHeight:int = MapWidth;
			
		   while (Passes > 0)
		   {
			   Passes--;

			   // Note: MapWidth and MapHeight should be equal and power-of-two values
			   newHeightData =   new Vector.<int>(MapWidth*MapWidth,true);

			   for (var x:int = 0; x < MapWidth; x++)
			   {
				  for (var y:int = 0; y < MapHeight; y++)
				  {
					  var adjacentSections:int = 0;
					  var sectionsTotal:Number = 0.0;

					  if ((x - 1) > 0) // Check to left
					  {
						 sectionsTotal += HeightData[(y)*MapWidth + x - 1];
						 adjacentSections++;

						 if ((y - 1) > 0) // Check up and to the left
						 {
							sectionsTotal += HeightData[(y-1)*MapWidth + x - 1];
							adjacentSections++;
						 }

						 if ((y + 1) < MapHeight) // Check down and to the left
						 {
							sectionsTotal += HeightData[(y+1)*MapWidth + x - 1];
							adjacentSections++;
						 }
					  }

					  if ((x + 1) < MapWidth) // Check to right
					  {
						 sectionsTotal += HeightData[(y)*MapWidth + x + 1];
						 adjacentSections++;

						 if ((y - 1) > 0) // Check up and to the right
						 {
							 sectionsTotal += HeightData[(y-1)*MapWidth + x+1];
							 adjacentSections++;
						 }

						 if ((y + 1) < MapHeight) // Check down and to the right
						 {
							 sectionsTotal += HeightData[(y+1)*MapWidth + x + 1];
							 adjacentSections++;
						 }
					  }

					  if ((y - 1) > 0) // Check above
					  {
						 sectionsTotal += HeightData[(y-1)*MapWidth + x];
						 adjacentSections++;
					  }

					  if ((y + 1) < MapHeight) // Check below
					  {
						 sectionsTotal += HeightData[(y + 1)*MapWidth + x];
						 adjacentSections++;
					  }

					  newHeightData[y*MapWidth + x] = (HeightData[y*MapWidth + x] + (sectionsTotal / adjacentSections)) * 0.5;
				   }
			   }

			  // Overwrite the HeightData info with our new smoothed info
			  for ( x = 0; x < MapWidth; x++)
			  {
				  for ( y = 0; y < MapHeight; y++)
				  {
					  HeightData[y*MapWidth + x] = newHeightData[y*MapWidth + x];
				  }
			  }
		   }
		}
		
	
		
		
		
		
		private static function writeVertices(vertices:ByteArray, x:int, y:int, patchSize:int, segUVSize:Number, offsetAdditionalData:int):void {
				vertices.writeFloat(x*patchSize);
				vertices.writeFloat(-y*patchSize);
				vertices.writeFloat(0);
				vertices.writeFloat(x*segUVSize);
				vertices.writeFloat(y*segUVSize);
				vertices.length = vertices.position += offsetAdditionalData;
		}
		
		// Creates a square patch in order of abc, acd
		private static function createFace(indices:Vector.<uint>, vertices:ByteArray, a:int, b:int, c:int, d:int, nx:Number, ny:Number, nz:Number, tx:Number, ty:Number, tz:Number, tw:Number, reverse:Boolean):void {
			var temp:int;
			if (reverse) {
				nx = -nx;
				ny = -ny;
				nz = -nz;
				tw = -tw;
				temp = a;
				a = d;
				d = temp;
				temp = b;
				b = c;
				c = temp;
			}
			indices.push(a);
			indices.push(b);
			indices.push(c);
			indices.push(a);
			indices.push(c);
			indices.push(d);
			vertices.position = a*48 + 20;
			vertices.writeFloat(nx);
			vertices.writeFloat(ny);
			vertices.writeFloat(nz);
			vertices.writeFloat(tx);
			vertices.writeFloat(ty);
			vertices.writeFloat(tz);
			vertices.writeFloat(tw);
			vertices.position = b*48 + 20;
			vertices.writeFloat(nx);
			vertices.writeFloat(ny);
			vertices.writeFloat(nz);
			vertices.writeFloat(tx);
			vertices.writeFloat(ty);
			vertices.writeFloat(tz);
			vertices.writeFloat(tw);
			vertices.position = c*48 + 20;
			vertices.writeFloat(nx);
			vertices.writeFloat(ny);
			vertices.writeFloat(nz);
			vertices.writeFloat(tx);
			vertices.writeFloat(ty);
			vertices.writeFloat(tz);
			vertices.writeFloat(tw);
			vertices.position = d*48 + 20;
			vertices.writeFloat(nx);
			vertices.writeFloat(ny);
			vertices.writeFloat(nz);
			vertices.writeFloat(tx);
			vertices.writeFloat(ty);
			vertices.writeFloat(tz);
			vertices.writeFloat(tw);
			}


		
		public static function stripUVForLODChunk(geom:Geometry):void {
			// create a new Geometry specifically without UV coordinates specifically LOD-terrain specific implementations using StandardMaterial
		}
		
		public static function stripUVNormalsAndTangents(geom:Geometry):void {
				// create a new Geometry specifically without UV coordinates, Normals and Tangents specifically LOD-terrain specific implementations that do not require StandardMaterial lighting (eg. LightMapMaterial, TextureMaterial)
				
		}
		
		
		
		static public function writeDebugUVs(vec:Vector.<Number>, indexLookup:Vector.<int>, vAcross:int):void 
		{
			for (var y:int = 0; y < vAcross; y++) {
				for (var x:int = 0; x < vAcross; x++) {
					var pos:int = indexLookup[vAcross * y + x] ;
					pos *= 2;
					vec[pos] =  x;
					vec[pos + 1] = y;
				}
			}
		}
		
		static public function writeNormalizedUVs(vec:Vector.<Number>, indexLookup:Vector.<int>, vAcross:int):void 
		{
			var mult:Number = 1 / (vAcross -1);
			for (var y:int = 0; y < vAcross; y++) {
				for (var x:int = 0; x < vAcross; x++) {
					var pos:int = indexLookup[vAcross * y + x] *2 ;
					vec[pos] =  x * mult;
					vec[pos + 1] = y *mult;
				}
			}
		}
		
	}

}
