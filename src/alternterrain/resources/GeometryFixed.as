package alternterrain.resources 
{
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.core.VertexStream;
	import alternativa.engine3d.resources.Geometry;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import alternativa.engine3d.alternativa3d;
	use namespace alternativa3d;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class GeometryFixed extends Geometry
	{
		
		public function GeometryFixed(numVertices:int=0) 
		{
			super(numVertices);
		}
		
		override public function calculateNormals() : void {
			if (!hasAttribute(VertexAttributes.POSITION)) throw new Error("Vertices positions is required to calculate normals");
			var normals:Array = [];
			var positionsStream:VertexStream = _attributesStreams[VertexAttributes.POSITION];
			var positionsData:ByteArray = positionsStream.data;
			var positionsOffset:int = _attributesOffsets[VertexAttributes.POSITION]*4;
			var stride:int = positionsStream.attributes.length*4;
			var numIndices:int = _indices.length;
			var normal:Vector3D;
			var i:int;
			// Normals calculations
			for (i = 0; i < numIndices; i += 3) {
				var vertIndexA:int = _indices[i];
				var vertIndexB:int = _indices[i + 1];
				var vertIndexC:int = _indices[i + 2];
				// v1
				positionsData.position = vertIndexA*stride + positionsOffset;
				var ax:Number = positionsData.readFloat();
				var ay:Number = positionsData.readFloat();
				var az:Number = positionsData.readFloat();

				// v2
				positionsData.position = vertIndexB*stride + positionsOffset;
				var bx:Number = positionsData.readFloat();
				var by:Number = positionsData.readFloat();
				var bz:Number = positionsData.readFloat();

				// v3
				positionsData.position = vertIndexC*stride + positionsOffset;
				var cx:Number = positionsData.readFloat();
				var cy:Number = positionsData.readFloat();
				var cz:Number = positionsData.readFloat();

				// v2-v1
				var abx:Number = bx - ax;
				var aby:Number = by - ay;
				var abz:Number = bz - az;

				// v3-v1
				var acx:Number = cx - ax;
				var acy:Number = cy - ay;
				var acz:Number = cz - az;

				var normalX:Number = acz*aby - acy*abz;
				var normalY:Number = acx*abz - acz*abx;
				var normalZ:Number = acy*abx - acx*aby;

				var normalLen:Number = Math.sqrt(normalX*normalX + normalY*normalY + normalZ*normalZ);

				if (normalLen > 0) {
					normalX /= normalLen;
					normalY /= normalLen;
					normalZ /= normalLen;
				} else {
					trace("degenerated triangle", i/3);
				}

				// v1 normal
				normal = normals[vertIndexA];

				if (normal == null) {
					normals[vertIndexA] = new Vector3D(normalX, normalY, normalZ);
				} else {
					normal.x += normalX;
					normal.y += normalY;
					normal.z += normalZ;
				}

				// v2 normal
				normal = normals[vertIndexB];

				if (normal == null) {
					normals[vertIndexB] = new Vector3D(normalX, normalY, normalZ);
				} else {
					normal.x += normalX;
					normal.y += normalY;
					normal.z += normalZ;
				}

				// v3 normal
				normal = normals[vertIndexC];

				if (normal == null) {
					normals[vertIndexC] = new Vector3D(normalX, normalY, normalZ);
				} else {
					normal.x += normalX;
					normal.y += normalY;
					normal.z += normalZ;
				}
			}

			if (hasAttribute(VertexAttributes.NORMAL)) {

				var normalsOffset:int = _attributesOffsets[VertexAttributes.NORMAL]*4;
				var normalsStream:VertexStream = _attributesStreams[VertexAttributes.NORMAL];
				var normalsBuffer:ByteArray = normalsStream.data;
				var normalsBufferStride:uint = normalsStream.attributes.length*4;
				for (i = 0; i < _numVertices; i++) {
					normal = normals[i] || new Vector3D(0, 0, 1);
					normal.normalize();
					normalsBuffer.position = i*normalsBufferStride + normalsOffset;
					normalsBuffer.writeFloat(normal.x);
					normalsBuffer.writeFloat(normal.y);
					normalsBuffer.writeFloat(normal.z);
				}
			} else {
				throw new Error("Not supported for extended GeometryFixed unless you declare attribute streams first!")
				// Write normals to ByteArray
				var resultByteArray:ByteArray = new ByteArray();
				resultByteArray.endian = Endian.LITTLE_ENDIAN;
				for (i = 0; i < _numVertices; i++) {
					normal = normals[i] || new Vector3D(0, 0, 1);
					normal.normalize();
					resultByteArray.writeBytes(positionsData, i*stride, stride);
					resultByteArray.writeFloat(normal.x);
					resultByteArray.writeFloat(normal.y);
					resultByteArray.writeFloat(normal.z);
				}
				positionsStream.attributes.push(VertexAttributes.NORMAL);
				positionsStream.attributes.push(VertexAttributes.NORMAL);
				positionsStream.attributes.push(VertexAttributes.NORMAL);

				positionsStream.data = resultByteArray;
				positionsData.clear();

				_attributesOffsets[VertexAttributes.NORMAL] = stride/4;
				_attributesStreams[VertexAttributes.NORMAL] = positionsStream;
				//_attributesStrides[VertexAttributes.NORMAL] = 3;
			}

			
		}
		
		/**
		 * Calculation of tangents and bi-normals. Normals of geometry must be calculated.
		 */
		override public function calculateTangents(uvChannel:int):void {
			if (!hasAttribute(VertexAttributes.POSITION)) throw new Error("Vertices positions is required to calculate normals");
			if (!hasAttribute(VertexAttributes.NORMAL)) throw new Error("Vertices normals is required to calculate tangents, call calculateNormals first");
			if (!hasAttribute(VertexAttributes.TEXCOORDS[uvChannel])) throw new Error("Specified uv channel does not exist in geometry");

			var tangents:Array = [];

			var positionsStream:VertexStream = _attributesStreams[VertexAttributes.POSITION];
			var positionsData:ByteArray = positionsStream.data;
			var positionsOffset:int = _attributesOffsets[VertexAttributes.POSITION]*4;
			var positionsStride:int = positionsStream.attributes.length*4;

			var normalsStream:VertexStream = _attributesStreams[VertexAttributes.NORMAL];
			var normalsData:ByteArray = normalsStream.data;
			var normalsOffset:int = _attributesOffsets[VertexAttributes.NORMAL]*4;
			var normalsStride:int = normalsStream.attributes.length*4;

			var uvsStream:VertexStream = _attributesStreams[VertexAttributes.TEXCOORDS[uvChannel]];
			var uvsData:ByteArray = uvsStream.data;
			var uvsOffset:int = _attributesOffsets[VertexAttributes.TEXCOORDS[uvChannel]]*4;
			var uvsStride:int = uvsStream.attributes.length*4;

			var numIndices:int = _indices.length;
			var normal:Vector3D;
			var tangent:Vector3D;
			var i:int;

			for (i = 0; i < numIndices; i += 3) {
				var vertIndexA:int = _indices[i];
				var vertIndexB:int = _indices[i + 1];
				var vertIndexC:int = _indices[i + 2];

				// a.xyz
				positionsData.position = vertIndexA*positionsStride + positionsOffset;
				var ax:Number = positionsData.readFloat();
				var ay:Number = positionsData.readFloat();
				var az:Number = positionsData.readFloat();

				// b.xyz
				positionsData.position = vertIndexB*positionsStride + positionsOffset;
				var bx:Number = positionsData.readFloat();
				var by:Number = positionsData.readFloat();
				var bz:Number = positionsData.readFloat();

				// c.xyz
				positionsData.position = vertIndexC*positionsStride + positionsOffset;
				var cx:Number = positionsData.readFloat();
				var cy:Number = positionsData.readFloat();
				var cz:Number = positionsData.readFloat();

				// a.uv
				uvsData.position = vertIndexA*uvsStride + uvsOffset;
				var au:Number = uvsData.readFloat();
				var av:Number = uvsData.readFloat();

				// b.uv
				uvsData.position = vertIndexB*uvsStride + uvsOffset;
				var bu:Number = uvsData.readFloat();
				var bv:Number = uvsData.readFloat();

				// c.uv
				uvsData.position = vertIndexC*uvsStride + uvsOffset;
				var cu:Number = uvsData.readFloat();
				var cv:Number = uvsData.readFloat();

				// a.nrm
				normalsData.position = vertIndexA*normalsStride + normalsOffset;
				var anx:Number = normalsData.readFloat();
				var any:Number = normalsData.readFloat();
				var anz:Number = normalsData.readFloat();

				// b.nrm
				normalsData.position = vertIndexB*normalsStride + normalsOffset;
				var bnx:Number = normalsData.readFloat();
				var bny:Number = normalsData.readFloat();
				var bnz:Number = normalsData.readFloat();

				// c.nrm
				normalsData.position = vertIndexC*normalsStride + normalsOffset;
				var cnx:Number = normalsData.readFloat();
				var cny:Number = normalsData.readFloat();
				var cnz:Number = normalsData.readFloat();

				// v2-v1
				var abx:Number = bx - ax;
				var aby:Number = by - ay;
				var abz:Number = bz - az;

				// v3-v1
				var acx:Number = cx - ax;
				var acy:Number = cy - ay;
				var acz:Number = cz - az;

				var abu:Number = bu - au;
				var abv:Number = bv - av;

				var acu:Number = cu - au;
				var acv:Number = cv - av;

				var r:Number = 1/(abu*acv - acu*abv);

				var tangentX:Number = r*(acv*abx - acx*abv);
				var tangentY:Number = r*(acv*aby - abv*acy);
				var tangentZ:Number = r*(acv*abz - abv*acz);

				tangent = tangents[vertIndexA];

				if (tangent == null) {
					tangents[vertIndexA] = new Vector3D(
							tangentX - anx*(anx*tangentX + any*tangentY + anz*tangentZ),
							tangentY - any*(anx*tangentX + any*tangentY + anz*tangentZ),
							tangentZ - anz*(anx*tangentX + any*tangentY + anz*tangentZ));

				} else {
					tangent.x += tangentX - anx*(anx*tangentX + any*tangentY + anz*tangentZ);
					tangent.y += tangentY - any*(anx*tangentX + any*tangentY + anz*tangentZ);
					tangent.z += tangentZ - anz*(anx*tangentX + any*tangentY + anz*tangentZ);
				}

				tangent = tangents[vertIndexB];

				if (tangent == null) {
					tangents[vertIndexB] = new Vector3D(
							tangentX - bnx*(bnx*tangentX + bny*tangentY + bnz*tangentZ),
							tangentY - bny*(bnx*tangentX + bny*tangentY + bnz*tangentZ),
							tangentZ - bnz*(bnx*tangentX + bny*tangentY + bnz*tangentZ));

				} else {
					tangent.x += tangentX - bnx*(bnx*tangentX + bny*tangentY + bnz*tangentZ);
					tangent.y += tangentY - bny*(bnx*tangentX + bny*tangentY + bnz*tangentZ);
					tangent.z += tangentZ - bnz*(bnx*tangentX + bny*tangentY + bnz*tangentZ);
				}

				tangent = tangents[vertIndexC];

				if (tangent == null) {
					tangents[vertIndexC] = new Vector3D(
							tangentX - cnx*(cnx*tangentX + cny*tangentY + cnz*tangentZ),
							tangentY - cny*(cnx*tangentX + cny*tangentY + cnz*tangentZ),
							tangentZ - cnz*(cnx*tangentX + cny*tangentY + cnz*tangentZ));

				} else {
					tangent.x += tangentX - cnx*(cnx*tangentX + cny*tangentY + cnz*tangentZ);
					tangent.y += tangentY - cny*(cnx*tangentX + cny*tangentY + cnz*tangentZ);
					tangent.z += tangentZ - cnz*(cnx*tangentX + cny*tangentY + cnz*tangentZ);
				}

			}

			if (hasAttribute(VertexAttributes.TANGENT4)) {

				var tangentsOffset:int = _attributesOffsets[VertexAttributes.TANGENT4]*4;
				var tangentsStream:VertexStream = _attributesStreams[VertexAttributes.TANGENT4];
				var tangentsBuffer:ByteArray = tangentsStream.data;
				var tangentsBufferStride:uint = tangentsStream.attributes.length*4;
				for (i = 0; i < _numVertices; i++) {
					tangent = tangents[i]  || new Vector3D(1,0,0);
					tangent.normalize();
					tangentsBuffer.position = i*tangentsBufferStride + tangentsOffset;
					tangentsBuffer.writeFloat(tangent.x);
					tangentsBuffer.writeFloat(tangent.y);
					tangentsBuffer.writeFloat(tangent.z);
					tangentsBuffer.writeFloat(-1);
				}
			} else {
				// Write normals to ByteArray
				throw new Error("Not supported for extended GeometryFixed unless you declare attribute streams first!")
				var resultByteArray:ByteArray = new ByteArray();
				resultByteArray.endian = Endian.LITTLE_ENDIAN;
				for (i = 0; i < _numVertices; i++) {
					tangent = tangents[i] || new Vector3D(1,0,0);
					tangent.normalize();
					resultByteArray.writeBytes(positionsData, i*positionsStride, positionsStride);
					resultByteArray.writeFloat(tangent.x);
					resultByteArray.writeFloat(tangent.y);
					resultByteArray.writeFloat(tangent.z);
					resultByteArray.writeFloat(-1);
				}
				positionsStream.attributes.push(VertexAttributes.TANGENT4);
				positionsStream.attributes.push(VertexAttributes.TANGENT4);
				positionsStream.attributes.push(VertexAttributes.TANGENT4);
				positionsStream.attributes.push(VertexAttributes.TANGENT4);

				positionsStream.data = resultByteArray;
				positionsData.clear();

				_attributesOffsets[VertexAttributes.TANGENT4] = positionsStride/4;
				_attributesStreams[VertexAttributes.TANGENT4] = positionsStream;
			//	_attributesStrides[VertexAttributes.TANGENT4] = 4;
			}

		}
	}

}