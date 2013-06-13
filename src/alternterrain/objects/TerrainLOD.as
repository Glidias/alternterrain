package alternterrain.objects 
{
	import alternativa.engine3d.collisions.EllipsoidCollider;
	import alternativa.engine3d.core.BoundBox;
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.CullingPlane;
	import alternativa.engine3d.core.Light3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.RayIntersectionData;
	import alternativa.engine3d.core.Resource;
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.core.VertexStream;
	import alternativa.engine3d.materials.FillMaterial;
	import alternativa.engine3d.materials.Material;
	import alternativa.engine3d.materials.StandardMaterial;
	import alternativa.engine3d.materials.VertexLightTextureMaterial;
	import alternativa.engine3d.objects.Mesh;
	import alternativa.engine3d.objects.Surface;
	import alternativa.engine3d.objects.WireFrame;
	import alternativa.engine3d.primitives.Box;
	import alternativa.engine3d.resources.Geometry;
	import alternativa.types.Float;
	import alternterrain.materials.CheckboardFillMaterial;
	import alternterrain.materials.ILODTerrainMaterial;
	import alternterrain.util.GeometryResult;
	import alternterrain.util.TerrainGeomTools;
	import flash.display3D.Context3D;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Endian;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import alternterrain.core.*;


	import alternativa.engine3d.alternativa3d;
	use namespace alternativa3d;

	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class TerrainLOD extends Object3D implements ICuller
	{
		public static const PATCHES_ACROSS:int = 32;  // todo: we fix this for now, later we allow for customising this
		public static const NUM_VERTICES:int = (PATCHES_ACROSS+1)*(PATCHES_ACROSS+1); 
		public static const PATCHES_SHIFT:int = 5;
			
		// Requirement flags
		//public static const VERTEX_NORMALS:int = 1;
		//public static const VERTEX_TANGENTS:int = 2
		private static const VERTEX_INCLUDE_UVS:int = 4;
		
		//VERTEX_NO_XY;    
		//VERTEX_PREV_Z;
		
		//public var requireEdgeMask:int = VERTEX_NORMALS | VERTEX_TANGENTS;
		
		public static const UV_STEPWISE:int = 0;
		public static const UV_NORMALIZED:int = -1;
		
		
		public static var PROTO_32:GeometryResult;
		
		// pooled chunk state buffers
		private var chunkPool:TerrainChunkStateList = new TerrainChunkStateList();
		private var activeChunks:TerrainChunkStateList = new TerrainChunkStateList();
		private var drawnChunks:int = 0;
		private var lastDrawnChunks:int = 0;
		// lookup buffers
		private var tilingUVBuffers:Vector.<VertexBuffer3D>;
		alternativa3d var indexBuffers:Vector.<IndexBuffer3D>;
		
		private var _uvAttribOffset:int = 0;
		private var _defaultUVStream:VertexStream = null;  
		
		
		private var _cameraPos:Vector3D = new Vector3D();
		private var _lastUpdateCameraPos:Vector3D = new Vector3D();
		private var numTrianglesLookup:Vector.<int>;
		private var indexSideLookup:Vector.<int> = new Vector.<int>(16, true);
		private var cornerMask:Vector.<int>;
		
	//	public var _sampleRect:Rectangle = new Rectangle();
	
		
	
		private var tileSize:int;
		public var debug:Boolean = false;
		private var _debugStream:VertexStream;
		private var _lastDebugRun:Boolean = false;

		
		private var _frustum:CullingPlane;
		
		// used for drawing
		private var mySurface:Surface = new Surface();  
		private var myGeometry:Geometry = new Geometry();
		private var myLODMaterial:ILODTerrainMaterial = null;
		
		
		private var _currentPage:QuadTreePage;
		
		private var _vertexUpload:Vector.<Number>;  // alchemy version could use a multipurpose ByteArray for uploading and other calculations...
		private var _data32PerVertex:int;
		private var _debugMaterial:CheckboardFillMaterial = new CheckboardFillMaterial();
		
		
		// METHOD 1  
		// A grid of quad tree pages to render
		public var gridPagesVector:Vector.<QuadTreePage>;  // dense array method 
		private var _pagesAcross:int;
		
		
		private var _vOffsets:Vector.<int>;
		private var _vDistances:Vector.<int>;
		
		public var waterLevel:Number = -Number.MAX_VALUE;
		
		public var rayData:RayIntersectionData;
		
		private var _squaredDistUpdate:Number = 0;
		
		public function setUpdateRadius(val:Number):void {
			var a:Number = Math.sin(Math.PI * .125) * val;
			var b:Number = Math.cos(Math.PI * .125) * val;
			_squaredDistUpdate = a * a + b * b;
		}
		

		/**
		 * 
		 */
		public function loadGridOfPages(context3D:Context3D, pages:Vector.<QuadTreePage>, material:Material, uvTileSize:int=0, requirements:int=0, tileSize:int=256):void {
		
			setupPreliminaries(context3D, pages[0], requirements, tileSize, uvTileSize);
			
			var minZ:Number = Number.MAX_VALUE;
			var maxZ:Number = -Number.MAX_VALUE;
			_pagesAcross = Math.sqrt(pages.length);
			var len:int =  pages.length;
			for (var i:int = 0; i < len; i++) {
				var p:QuadTreePage = pages[i];
				p.uvTileSize = uvTileSize;
				p.material = material;
				p.requirements = requirements;
				if (p.Square.MinY < minZ) minZ = p.Square.MinY;
				if (p.Square.MaxY > maxZ) maxZ = p.Square.MaxY;
			}
			
			boundBox = new BoundBox();
			boundBox.minZ = minZ;
			boundBox.maxZ = maxZ;
			
			
			p = pages[0];
			boundBox.minX = p.xorg;
			boundBox.maxY = -p.zorg;
			
			p = pages[pages.length - 1];
			boundBox.maxX = p.xorg + ((1 << p.Level) << 1);
			boundBox.minY = -p.zorg - ((1 << p.Level) << 1);
			
			gridPagesVector = pages;
			///*
			QuadSquareChunk.QUADTREE_GRID = new Grid_QuadChunkCornerData();
			QuadSquareChunk.QUADTREE_GRID.vec = gridPagesVector;
		
			QuadSquareChunk.QUADTREE_GRID.cols = _pagesAcross;
			//*/
			setupPostliminaries(context3D, requirements, tileSize, uvTileSize, pages[0].Level);
			
			
			
		}
				
		// METHOD 3 (not yet available)
		public var gridPagesHash:Dictionary;  //  optional dictionary hash for larger worlds 
		
		
		
		// METHOD 3
		public var tree:QuadTreePage;
		
		public var detail:Number = 100;
		
		
		public function loadSinglePage(context3D:Context3D, page:QuadTreePage, material:Material, uvTileSize:int=0, requirements:int=-1, tileSize:int=256):void {
			
			runSinglePage(context3D, page.heightMap, page, material, requirements>=0 ? requirements : page.requirements,  uvTileSize != 0 ? uvTileSize : page.uvTileSize, tileSize);
		}
		
		// A single quad tree page to render
		/**
		 * Sets up a single quad tree page to render
		 * @param	context3D
		 * @param	heightMap
		 * @param	chunk
		 * @param	material
		 * @param	requirements
		 * @param	tileSize
		 * @param	uvTileSize
		 */
		public function runSinglePage(context3D:Context3D, heightMap:HeightMapInfo, quadCornerChunk:QuadTreePage, material:Material, requirements:int, uvTileSize:int = 0, tileSize:int = 256):void {
			
			
			
			setupPreliminaries(context3D, quadCornerChunk, requirements, tileSize, uvTileSize);
			
			
					
			var chunk:QuadSquareChunk  = quadCornerChunk.Square;

			var str:String;
			
			
			tree = new QuadTreePage();
			tree.heightMap = heightMap;
			tree.material = material;	
			tree.requirements = requirements;
			tree.uvTileSize = uvTileSize != 0 ? uvTileSize  : tree.uvTileSize;
			tree.Square = chunk;
			tree.Level = quadCornerChunk.Level;
			tree.xorg = quadCornerChunk.xorg;
			tree.zorg = quadCornerChunk.zorg;
			//tree.normals = quadCornerChunk.normals;
			//tree.Level =
	
			setupPostliminaries(context3D, requirements, tileSize, uvTileSize, tree.Level);
			
			
			// get bounds according to tree
			boundBox = new BoundBox();
			boundBox.minX = tree.xorg;
			boundBox.minY = -tree.zorg - ((1 << tree.Level) << 1); 
			//throw new Error( tree.Level);
			boundBox.maxX = tree.xorg + ((1 << tree.Level) << 1);
			boundBox.maxY = -tree.zorg;
			boundBox.maxZ = tree.Square.MaxY;
			boundBox.minZ = tree.Square.MinY;
			
			
		}
		
		private function setupPostliminaries(context3D:Context3D, requirements:int, tileSize:int, uvTileSize:int, rootLevel:int):void 
		{
				var injectUV:Boolean=false;
			var repeatUV:Boolean = false;
			if (uvTileSize > 0) {  // Got UVs
				
				
				if (uvTileSize <= tileSize * PATCHES_ACROSS) {  // repeatable texture coordinates per chunk level with same origin can be used
					 repeatUV = true;
					 
				}
				else {   // need to inject uv coordinates
						injectUV = true;
						requirements |= VERTEX_INCLUDE_UVS;
						
						if (tree != null) tree.requirements |= VERTEX_INCLUDE_UVS;
						if (gridPagesVector != null) {
							var i:int = gridPagesVector.length;
							while (--i > -1) {
								gridPagesVector[i].requirements |= VERTEX_INCLUDE_UVS;
							}
						}
				}
			}
			
			setupGeometry(requirements);  
			if (repeatUV) setupRepeatingUVs(context3D, uvTileSize, rootLevel);
			else if (injectUV) {
				setDefaultUVStream(myGeometry._attributesStreams[VertexAttributes.TEXCOORDS[0]], myGeometry._attributesOffsets[VertexAttributes.TEXCOORDS[0]] ); 
			}
			else if (uvTileSize === UV_STEPWISE) {
				setDefaultUVStream(  (_debugStream || (_debugStream = createDebugUVStream(context3D) )) , 0);
				
					_defaultUVStream.attributes = [VertexAttributes.TEXCOORDS[0], VertexAttributes.TEXCOORDS[0]];
			}
			else if (uvTileSize === UV_NORMALIZED) {
				setDefaultUVStream( getNormalizedUVStream(context3D), 0 );
					_defaultUVStream.attributes = [VertexAttributes.TEXCOORDS[0], VertexAttributes.TEXCOORDS[0]];
			}
			
			/*
			if ( (requirements & (VERTEX_NORMALS | VERTEX_TANGENTS)) ) {
				setupVOffsets(tree);
			}
			*/
		
			

			setupVertexUpload(requirements, tileSize);
		}
		
		private function setupPreliminaries(context3D:Context3D, quadCornerChunk:QuadTreePage, requirements:int, tileSize:int, uvTileSize:int):void 
		{
			if (!QuadCornerData.isBase2(tileSize)) throw new Error("tileSize must be base 2!");
			
			lodLvlMin = Math.round(Math.log(tileSize * PATCHES_ACROSS) * Math.LOG2E) - 1;

			//if (PROTO_32 == null) {
				setupPrototypes(context3D, tileSize);	
			//}
			
			/*
			if ((requirements & VERTEX_NORMALS) &&  (!quadCornerChunk.normals || !quadCornerChunk.normals.Normals || !quadCornerChunk.normals.Normals.length ) ) {
				throw new Error("No vertex normal data found in QuadTreePage");
			}
			if ((requirements & VERTEX_TANGENTS) &&  (!quadCornerChunk.normals || !quadCornerChunk.normals.Tangents || !quadCornerChunk.normals.Tangents.length) ) {
				throw new Error("No vertex tangent data found in QuadTreePage");
			}
			*/
			this.tileSize = tileSize;
			this.tileSizeInv = 1 / tileSize;
			this.tileShift = Math.round(Math.log(tileSize ) * Math.LOG2E);
			
			this.tileMod = tileSize  - 1;
			
			if ( uvTileSize > 0 && !QuadCornerData.isBase2(uvTileSize)) throw new Error("uvTileSize must be base 2!");
			
		}
		
		private function setupVOffsets(page:QuadTreePage):void 
		{
			var level:int = Math.round(Math.log(page.uvTileSize) * Math.LOG2E);
			var numLevels:int = (page.Level+1) - level + 1;
			_vOffsets = new Vector.<int>();
			TerrainGeomTools.calculateQuadTreeOffsetTable(_vOffsets, numLevels, 1, PATCHES_ACROSS);
			_vDistances = TerrainGeomTools.getQuadTreeDistanceTable(numLevels, 1, PATCHES_ACROSS);
		}
		
		private function setDefaultUVStream(object:VertexStream, attribOffset:int):void 
		{
			_defaultUVStream = object;
			
			validateExpandAttribIndex(VertexAttributes.TEXCOORDS[0]);
		
			_uvAttribOffset = attribOffset;
			myGeometry._attributesStreams[VertexAttributes.TEXCOORDS[0]] = object;
		}
		
		private function getNormalizedUVStream(context3D:Context3D):VertexStream {
			var vs:VertexStream = new VertexStream();
			vs.buffer = context3D.createVertexBuffer(NUM_VERTICES, 2);
			var values:Vector.<Number> = new Vector.<Number>(NUM_VERTICES * 2, true);
			TerrainGeomTools.writeNormalizedUVs(values, PROTO_32.indexLookup, PATCHES_ACROSS + 1);
			vs.buffer.uploadFromVector(values, 0, NUM_VERTICES);
			return vs;
		}
		
		private function setupRepeatingUVs(context3D:Context3D, uvTileSize:int, rootLevel:int):void 
		{
			_defaultUVStream = new VertexStream();
			_defaultUVStream.attributes = [VertexAttributes.TEXCOORDS[0], VertexAttributes.TEXCOORDS[0]]
			_uvAttribOffset = 0;
			validateExpandAttribIndex(VertexAttributes.TEXCOORDS[0]);
			myGeometry._attributesStreams[VertexAttributes.TEXCOORDS[0]] = _defaultUVStream;
			
			var level:int = Math.round(Math.log(uvTileSize ) * Math.LOG2E);
			var numLevels:int = (rootLevel+1) - level + 1;
			tilingUVBuffers = new Vector.<VertexBuffer3D>(numLevels, true);
			var count:int = 0;
			var indexLookup:Vector.<int> = PROTO_32.indexLookup;
			var vec:Vector.<Number> = new Vector.<Number>(NUM_VERTICES*2, true);
			numLevels += level;
			var vAcross:int = PATCHES_ACROSS + 1;
			
			
			if (level < lodLvlMin) {
				level = lodLvlMin;
			}
			if (level >= numLevels) {
				throw new Error("Unable to find number of levels for repeating UVs! ::"+ level + "/" + numLevels);
			}
			
			_repeatUVLowestLevel = level - 1;
			for (var i:int = level ; i < numLevels; i++) {
				var step:Number = ((1 << i) / uvTileSize) / PATCHES_ACROSS;
				var vBuffer:VertexBuffer3D = context3D.createVertexBuffer(NUM_VERTICES, 2);
				TerrainGeomTools.writeRepeatingTileUVs(vec, step, indexLookup, vAcross);
				vBuffer.uploadFromVector(vec, 0, NUM_VERTICES);
				tilingUVBuffers[count++] = vBuffer;
			}
			
			
		}
		
		private function setupGeometry(requirements:int):int 
		{
			var arr:Array = [VertexAttributes.POSITION,VertexAttributes.POSITION,VertexAttributes.POSITION];
			
			if (requirements & VERTEX_INCLUDE_UVS) { 
				arr.push(VertexAttributes.TEXCOORDS[0], VertexAttributes.TEXCOORDS[0]);	

			}
			/*
			if (requirements & VERTEX_NORMALS) {
				arr.push(VertexAttributes.NORMAL,VertexAttributes.NORMAL,VertexAttributes.NORMAL);
			}
			if (requirements & VERTEX_TANGENTS) {
				arr.push(VertexAttributes.TANGENT4,VertexAttributes.TANGENT4,VertexAttributes.TANGENT4,VertexAttributes.TANGENT4);
			}
			*/
			

			myGeometry.numVertices = NUM_VERTICES; 
			myGeometry.addVertexStream(arr);
			myGeometry._indices = PROTO_32.geometry.indices;
			
			return arr.length;
		}
		
		private function setupVertexUpload(requirements:int, tileSize:int):void 
		{
			
			var len:int;
			var i:int;
			var vAcross:int = PATCHES_ACROSS + 1;
			var stride:int = myGeometry._attributesStreams[1].attributes.length;

			_vertexUpload.length = len =  vAcross * vAcross * stride;  
			_vertexUpload.fixed = true;
		
			_data32PerVertex = stride;
			
			var indexLookup:Vector.<int> = PROTO_32.indexLookup;
			var pos:int;
			
			//this wouldn't work anyway because we re-uploading x,y later during sampleHeights
			for (var y:int = 0; y < vAcross; y++) {
				for (var x:int = 0; x < vAcross; x++) {
					pos = indexLookup[y * vAcross + x] * stride;
					_vertexUpload[pos] =  x * tileSize;
					_vertexUpload[pos+1] =  -y * tileSize;
				}
			}	
		}
		
		private function sampleHeights(requirements:int, heightMap:HeightMapInfo, square:QuadChunkCornerData ):void {
			
			var len:int;
			var i:int;
			
			var offset:int;
			var stride:int = _data32PerVertex;
			// based on requirements, could access a different vertex upload
			var heightData:Vector.<int> = heightMap.Data;
			var xorg:int = square.xorg;
			var zorg:int = square.zorg;
			var hXOrigin:int = heightMap.XOrigin;
			var hZOrigin:int = heightMap.ZOrigin;
			xorg -= hXOrigin;  // need to check if this is correct
			zorg -= hZOrigin;
			xorg /= tileSize;
			zorg /= tileSize;
			
			var limit:int = (((1 << square.Level) << 1) >> tileShift);  // numbr of tiles
			
			var vAcross:int = PATCHES_ACROSS + 1;
			var tStride:int = (limit >> PATCHES_SHIFT);  // divide by 32
			var yLimit:int = zorg + limit + 1;
			var xLimit:int = xorg + limit + 1;
			var RowWidth:int = heightMap.RowWidth;
			
			var indexLookup:Vector.<int> = PROTO_32.indexLookup;
			var pos:int;
			
			// NOTE: If all pages are using the same requirements, it's actually possible to hardcode all these below as an inline operation
			// within a single loop. 
			///*
			var xi:int;
			var yi:int;
			var y:int;
			var x:int;
			
			// We assume position offset is always zero and always made available!
			// TODO: consider Only Z case...
			yi = 0;
			for (y = zorg; y < yLimit; y+=tStride) {
				xi = 0;
				for (x = xorg; x < xLimit; x += tStride) {
					
					pos = indexLookup[yi * vAcross + xi] * stride;
					_vertexUpload[pos] = x * tileSize + hXOrigin;
					_vertexUpload[pos + 1] = y * -tileSize - hZOrigin;
					_vertexUpload[pos + 2] = heightData[y * RowWidth + x];
					xi++;
				}
				yi++;
			}
			
			//var vStream:VertexStream;
		
			var attribId:int;
			
			var divisor:Number;

			
			
			if ( (requirements & VERTEX_INCLUDE_UVS)) {  
		
				divisor = 1 / _currentPage.uvTileSize;
				attribId = VertexAttributes.TEXCOORDS[0];
				//vStream =  myGeometry._attributesStreams[attribId];
				offset =  3;// _defaultUVStream._attributesOffsets[attribId];
				
				yi = 0;
				for (y = zorg; y < yLimit; y+=tStride) {
					xi = 0;
					for (x = xorg; x < xLimit; x += tStride) {
						pos = indexLookup[yi * vAcross + xi] * stride + offset;
						_vertexUpload[pos] = x * tileSize*divisor;
						_vertexUpload[pos + 1] = y * tileSize*divisor;
						xi++;
					}
					yi++;
				}
			}
			
		
			//*/
		}
		
		private function updateEdges(requirements:int, cd:QuadChunkCornerData, oldEdgeState:int, newEdgeState:int):void {
			var attribId:int;
			var offset:int;
			
			
		}
		
		
		private function setupPrototypes(context3D:Context3D, patchSize:int ):void 
		{
			if (PROTO_32 == null) PROTO_32 = TerrainGeomTools.createLODTerrainChunkForMesh(PATCHES_ACROSS, patchSize);
			//var indexLookup:Vector.<int>
			setupIndexBuffers(context3D, PROTO_32.indexLookup, PATCHES_ACROSS);
		
			_vertexUpload = new Vector.<Number>();
			
		}
		
	
		
	
		public static function installQuadChunkFromHeightmap(heightMap:HeightMapInfo, offsetX:int=0, offsetY:int=0, tileSize:int=256, sampleSize:int=0):QuadChunkCornerData {
			var rootData:QuadCornerData = QuadCornerData.createRoot(offsetX, offsetY, sampleSize == 0 ? (tileSize * (heightMap.XSize-1)) : sampleSize, false); 
			rootData.Square.AddHeightMap(rootData, heightMap);

			var cd:QuadChunkCornerData = new QuadChunkCornerData();
			cd.Level = rootData.Level;
			cd.xorg = rootData.xorg;
			cd.zorg = rootData.zorg;
			cd.Square =  rootData.Square.GetQuadSquareChunk( rootData, rootData.Square.RecomputeErrorAndLighting(rootData)  ); 
			return cd; 
		}
		
		private var _setupContext:Context3D;
		private function setupIndexBuffers(context3D:Context3D, indexLookup:Vector.<int>, patchesAcross:int):void 
		{
			_setupContext = context3D;
			
			indexBuffers = new Vector.<IndexBuffer3D>(9, true);
			numTrianglesLookup = new Vector.<int>(9, true);
			var buffer:IndexBuffer3D;
			
			var count:int = 0;
			var byteArray:ByteArray = new ByteArray();
			byteArray.endian = Endian.LITTLE_ENDIAN;
			TerrainGeomTools.writeInnerIndicesToByteArray(patchesAcross, indexLookup, byteArray);
			var startEdgesPosition:int = byteArray.position;
			
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, 0);  
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3; 
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1); 
			indexSideLookup[0xF] = count;
			count++;
			
			
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_EAST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[(~TerrainGeomTools.MASK_EAST) & 0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_NORTH );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[(~TerrainGeomTools.MASK_NORTH)&0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_WEST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[(~TerrainGeomTools.MASK_WEST)&0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_SOUTH );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[(~TerrainGeomTools.MASK_SOUTH)&0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_EAST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[~(TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_EAST)&0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_WEST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[~(TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_WEST)&0xF] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_WEST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[ ~(TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_WEST)&0xF ] = count;
			count++;
			
			byteArray.position = byteArray.length = startEdgesPosition;
			TerrainGeomTools.writeEdgeVerticesToByteArray(patchesAcross, indexLookup, byteArray, TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_EAST );
			buffer = context3D.createIndexBuffer( byteArray.length >> 1 );
			indexBuffers[count] = buffer;
			numTrianglesLookup[count] = (byteArray.length >> 1) / 3;
			buffer.uploadFromByteArray(byteArray, 0, 0, byteArray.length >> 1);
			indexSideLookup[ ~(TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_EAST)&0xF ] = count;
			count++;

		}
		

		/**
		 * Constructor
		 */
		public function TerrainLOD() 
		{
			rayData = new RayIntersectionData();
			rayData.object = this;
			rayData.point = new Vector3D();
			
			waterRayData = new RayIntersectionData();
			waterRayData.object = this;
			waterRayData.point = new Vector3D();
			
			_patchHeights[0] = 0;  // nw
			_patchHeights[1] = 0;
			_patchHeights[3] = 1;  // ne
			_patchHeights[4] = 0;
			_patchHeights[6] = 0;  // sw
			_patchHeights[7] = 1;
			_patchHeights[9] = 1;  // se
			_patchHeights[10] = 1;
			
			_lastUpdateCameraPos.x = -1e22;
			_lastUpdateCameraPos.y = -1e22;
			_lastUpdateCameraPos.z = -1e22;
			
			mySurface.object = this;
			mySurface.indexBegin = 0;
			cornerMask = new Vector.<int>(4, true);
			cornerMask[0] = ~(TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_EAST) & 0xF;
			cornerMask[1] = ~(TerrainGeomTools.MASK_NORTH | TerrainGeomTools.MASK_WEST) & 0xF;
			cornerMask[2] = ~(TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_WEST) & 0xF;
			cornerMask[3] = ~(TerrainGeomTools.MASK_SOUTH | TerrainGeomTools.MASK_EAST) & 0xF;
			//mySurface.numTriangles = PATCHES_ACROSS * 2;
		}
		
		
		
		private static const QUAD_ORDER:Vector.<Vector.<int>> = createQuadOrderIndiceTable(false);  // back to front
		private static const QUAD_ORDER2:Vector.<Vector.<int>> = createQuadOrderIndiceTable(true);  // front to back
		private static const QUAD_OFFSETS:Vector.<int> = createQuadOffsetTable();
		private static function createQuadOrderIndiceTable(reversed:Boolean):Vector.<Vector.<int>> {
			// quad z order
			var result:Vector.<Vector.<int>> = new Vector.<Vector.<int>>(4, true);
			result[0] = !reversed ? new <int>[3,2,0,1] : new <int>[1,0,2,3];
			result[0].fixed = true;
			result[1] = !reversed ? new <int>[2,3,1,0] : new <int>[0,1,3,2];
			result[1].fixed = true;
			result[2] = !reversed ? new <int>[0,1,3,2] : new <int>[2,3,1,0];
			result[2].fixed = true;
			result[3] = !reversed ? new <int>[1,2,0,3] : new <int>[3,0,2,1];
			result[3].fixed = true;
			return result;
		}
		private static function createQuadOffsetTable():Vector.<int> {
			var result:Vector.<int> = new Vector.<int>(4, true);
			result[0] = 1;
			result[1] = 0;
			result[2] = 2;
			result[3] = 3;
			return result;
		}
		
		
		/* INTERFACE utils.terrain.ICuller */
		
		public function cullingInFrustum(culling:int, minX:Number, minY:Number, minZ:Number, maxX:Number, maxY:Number, maxZ:Number):int 
		{
			
				if (maxZ < waterLevel) return -1;		
				
				var frustum:CullingPlane = _frustum;
				var temp:Number = minY;
				minY = -maxY;
				maxY = -temp;
				
				
				
				var side:int = 1;
				for (var plane:CullingPlane = frustum; plane != null; plane = plane.next) {
				if (culling & side) {
				if (plane.x >= 0)
				if (plane.y >= 0)
				if (plane.z >= 0) {
				if (maxX*plane.x + maxY*plane.y + maxZ*plane.z <= plane.offset) return -1;
				if (minX*plane.x + minY*plane.y + minZ*plane.z > plane.offset) culling &= (63 & ~side);
				} else {
				if (maxX*plane.x + maxY*plane.y + minZ*plane.z <= plane.offset) return -1;
				if (minX*plane.x + minY*plane.y + maxZ*plane.z > plane.offset) culling &= (63 & ~side);
				}
				else
				if (plane.z >= 0) {
				if (maxX*plane.x + minY*plane.y + maxZ*plane.z <= plane.offset) return -1;
				if (minX*plane.x + maxY*plane.y + minZ*plane.z > plane.offset) culling &= (63 & ~side);
				} else {
				if (maxX*plane.x + minY*plane.y + minZ*plane.z <= plane.offset) return -1;
				if (minX*plane.x + maxY*plane.y + maxZ*plane.z > plane.offset) culling &= (63 & ~side);
				}
				else if (plane.y >= 0)
				if (plane.z >= 0) {
				if (minX*plane.x + maxY*plane.y + maxZ*plane.z <= plane.offset) return -1;
				if (maxX*plane.x + minY*plane.y + minZ*plane.z > plane.offset) culling &= (63 & ~side);
				} else {
				if (minX*plane.x + maxY*plane.y + minZ*plane.z <= plane.offset) return -1;
				if (maxX*plane.x + minY*plane.y + maxZ*plane.z > plane.offset) culling &= (63 & ~side);
				}
				else if (plane.z >= 0) {
				if (minX*plane.x + minY*plane.y + maxZ*plane.z <= plane.offset) return -1;
				if (maxX*plane.x + maxY*plane.y + minZ*plane.z > plane.offset) culling &= (63 & ~side);
				} else {
				if (minX*plane.x + minY*plane.y + minZ*plane.z <= plane.offset) return -1;
				if (maxX*plane.x + maxY*plane.y + maxZ*plane.z > plane.offset) culling &= (63 & ~side);
				}
				}
				side <<= 1;
				}
				return culling;
		}
		
		override alternativa3d function get useLights():Boolean {
			return useLighting;
		}
		
	
		
		override alternativa3d function collectDraws(camera:Camera3D, lights:Vector.<Light3D>, lightsLength:int, useShadow:Boolean):void {
				
				drawnChunks = 0;
				
				var i:int;
			
				QuadSquareChunk.LOD_LVL_MIN = lodLvlMin;
				
				quadOrderTable = QUAD_ORDER2;
				
				
				var tz:Number;
				
				_cameraPos.x = cameraToLocalTransform.d;
				_cameraPos.y = -cameraToLocalTransform.h;
				_cameraPos.z = cameraToLocalTransform.l;
				
				tx = _cameraPos.x - _lastUpdateCameraPos.x;
				ty = _cameraPos.y - _lastUpdateCameraPos.y;
				tz = _cameraPos.z - _lastUpdateCameraPos.z;
				
				var doUpdate:Boolean = false;
				if (tx * tx + ty * ty + tz * tz > _squaredDistUpdate) {
					_lastUpdateCameraPos.x = _cameraPos.x;
					_lastUpdateCameraPos.y = _cameraPos.y;
					_lastUpdateCameraPos.z = _cameraPos.z;
					doUpdate = true;
				}
				
				camera.calculateFrustum(cameraToLocalTransform);
				_frustum = camera.frustum;
				
				
				if (debug) {
					if (!_lastDebugRun) runDebugBuffer(camera.context3D);
				}
				else if (_lastDebugRun) {
					removeDebugBuffer();
				}
				
				if (tree != null) {  // Draw tree
					mySurface.material = !debug ? tree.material : _debugMaterial;
					myLODMaterial = mySurface.material as ILODTerrainMaterial;
					_currentPage = tree;
					if (doUpdate) {
						QuadChunkCornerData.BI = 0;
						 tree.Square.Update(tree, _cameraPos, detail, this , culling);  
						QuadChunkCornerData.BI = 0;
					}
					drawQuad(tree, camera, lights, lightsLength, useShadow, culling);
					QuadChunkCornerData.BI = 0;
				}
				
				if (gridPagesVector != null) {  // draw grid of pages 
					
					cd = gridPagesVector[0];
					var half:int = (1 << cd.Level);
					var full:int = ( half << 1);
					
					
					// Get 8 frustum corners clamped to terrain bounds in 2 dimensions for iterating throuhg a limited set of quad-trees on the grid (note, some flickering issues atm.)
					///*
					var minX:Number = Number.MAX_VALUE;
					var minY:Number = Number.MAX_VALUE;
					var maxX:Number = -Number.MAX_VALUE;
					var maxY:Number = -Number.MAX_VALUE;
					var tx:Number;
					var ty:Number;
					tx = cameraToLocalTransform.a * -1 + cameraToLocalTransform.b * -1 + cameraToLocalTransform.c*camera.farClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * -1 + cameraToLocalTransform.f * -1 + cameraToLocalTransform.g * camera.farClipping + cameraToLocalTransform.h; //ty *= -1;
					tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;
					tx = cameraToLocalTransform.a * -1 + cameraToLocalTransform.b * 1 + cameraToLocalTransform.c*camera.farClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * -1 + cameraToLocalTransform.f * 1 + cameraToLocalTransform.g * camera.farClipping + cameraToLocalTransform.h;// ty *= -1;
										tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;					
					tx = cameraToLocalTransform.a * 1 + cameraToLocalTransform.b * 1 + cameraToLocalTransform.c*camera.farClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * 1 + cameraToLocalTransform.f * 1 + cameraToLocalTransform.g * camera.farClipping + cameraToLocalTransform.h; //ty *= -1;
										tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;					
					tx =cameraToLocalTransform.a * 1 + cameraToLocalTransform.b * -1 + cameraToLocalTransform.c*camera.farClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * 1 + cameraToLocalTransform.f * -1 + cameraToLocalTransform.g * camera.farClipping + cameraToLocalTransform.h; //ty *= -1;
										tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;
					
					tx = cameraToLocalTransform.a * -1 + cameraToLocalTransform.b * -1 + cameraToLocalTransform.c*camera.nearClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * -1 + cameraToLocalTransform.f * -1 + cameraToLocalTransform.g * camera.nearClipping + cameraToLocalTransform.h; //ty *= -1;
										tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;
					tx = cameraToLocalTransform.a * -1 + cameraToLocalTransform.b * 1 + cameraToLocalTransform.c*camera.nearClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * -1 + cameraToLocalTransform.f * 1 + cameraToLocalTransform.g * camera.nearClipping + cameraToLocalTransform.h;// ty *= -1;
					tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;					
					tx = cameraToLocalTransform.a * 1 + cameraToLocalTransform.b * 1 + cameraToLocalTransform.c*camera.nearClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * 1 + cameraToLocalTransform.f * 1 + cameraToLocalTransform.g * camera.nearClipping + cameraToLocalTransform.h; //ty *= -1;
										tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;					
					tx = cameraToLocalTransform.a * 1 + cameraToLocalTransform.b * -1 + cameraToLocalTransform.c*camera.nearClipping + cameraToLocalTransform.d;
					ty = cameraToLocalTransform.e * 1 + cameraToLocalTransform.f * -1 + cameraToLocalTransform.g * camera.nearClipping + cameraToLocalTransform.h; //ty *= -1;
					tx = tx < boundBox.minX ? boundBox.minX : tx > boundBox.maxX ? boundBox.maxX : tx;
					ty = ty < boundBox.minY ? boundBox.minY : ty > boundBox.maxY ? boundBox.maxY : ty;
					if (tx < minX) minX = tx;
					if (tx > maxX) maxX = tx;
					if (ty < minY) minY = ty;
					if (ty > maxY) maxY = ty;
					
					// Ensure some drawing still occurs even if camera is outside bounds of terrain
					if (maxX == minX) maxX += .01;
					if (minY == maxY) minY -= .01;
					
					var mxTo:int = Math.ceil(maxX / full); //throw new Error(new Point(minX/full, -maxY/full) );
					var myTo:int =  Math.ceil( -minY / full);
			
					for (var yi:int = Math.floor(-maxY/full); yi < myTo; yi++) {
						for (var xi:int = Math.floor(minX/full); xi < mxTo; xi++) {
							var cd:QuadTreePage;
							_currentPage = cd = gridPagesVector[yi*_pagesAcross + xi];
							var c:QuadSquareChunk = cd.Square;
							var curCulling:int;
							if  ( (curCulling > 0 ? (curCulling = cullingInFrustum(culling, cd.xorg , cd.zorg, c.MinY, cd.xorg + full, cd.zorg + full, c.MaxY)) : 0) >=0 ) {
								
								mySurface.material = !debug ? cd.material : _debugMaterial;
								myLODMaterial = mySurface.material as ILODTerrainMaterial;
								if (doUpdate) {
									QuadChunkCornerData.BI = 0;
									c.Update(cd, _cameraPos, detail, this , curCulling); 
									QuadChunkCornerData.BI = 0;
								}
								drawQuad(cd, camera, lights, lightsLength, useShadow, curCulling);
							}
						}
					}
					//*/
					
					/*  // Blindly iterate through all quad tree pages in grid
					i = gridPagesVector.length;
					while ( --i > -1) {
						var cd:QuadTreePage;
						_currentPage = cd = gridPagesVector[i];
						var c:QuadSquareChunk = cd.Square;
						var curCulling:int;
						if  ( (curCulling > 0 ? (curCulling = cullingInFrustum(culling, cd.xorg , cd.zorg, c.MinY, cd.xorg + full, cd.zorg + full, c.MaxY)) : 0) >=0 ) {
							
							mySurface.material = !debug ? cd.material : _debugMaterial;
							myLODMaterial = mySurface.material as ILODTerrainMaterial;
							QuadChunkCornerData.BI = 0;
							c.Update(cd, _cameraPos, detail, this , curCulling); 
							QuadChunkCornerData.BI = 0;
							drawQuad(cd, camera, lights, lightsLength, useShadow, curCulling);
						}
					}
					*/
					
					QuadChunkCornerData.BI = 0;
				}
				
				// Append unused chunks back to pool for potential re-using
				i = drawnChunks - lastDrawnChunks;
				var head:TerrainChunkState;
				var h:TerrainChunkState = head = activeChunks.head;
				var lastH:TerrainChunkState;
				
				// iterate through the last of all chunks which are no longer active
				while (--i > -1) {
					if (h == null) break;
					lastH = h;
					h = h.next;
				}
				if (lastH != null) {     // unhook from active chunks
					if (lastH.next) { 
						lastH.next.prev = null;
						activeChunks.head = lastH.next;
						lastH.next = null;
						
					}
					else {
						activeChunks.head = null;
						activeChunks.tail = null;
					}
					
					if (chunkPool.tail) {  // append to pooled chunks
						head.prev = chunkPool.tail;
						chunkPool.tail.next = head;
					}
					else {
						chunkPool.head = head;
						chunkPool.tail = head;
					}
				}		
				lastDrawnChunks = drawnChunks;	
		}
		

		
		private function removeDebugBuffer():void {
			_lastDebugRun = false;
			var expandIndex:int = VertexAttributes.TEXCOORDS[0];
			myGeometry._attributesOffsets[expandIndex] = _uvAttribOffset;  
			myGeometry._attributesStreams[expandIndex] = _defaultUVStream;
			
		}
		
		private function validateExpandAttribIndex(expandIndex:int):void {
			if (myGeometry._attributesStreams.length <= expandIndex) {
				
				myGeometry._attributesStreams.fixed = false;
				myGeometry._attributesStreams.length = expandIndex+1;
				myGeometry._attributesStreams.fixed = true;
			}
			if (myGeometry._attributesOffsets.length <= expandIndex) {
				
				myGeometry._attributesOffsets.fixed = false;
				myGeometry._attributesOffsets.length = expandIndex+1;
				myGeometry._attributesOffsets.fixed = true;
			}
		}
	
		private function runDebugBuffer(context3D:Context3D):void 
		{	
			_lastDebugRun = true;
			var expandIndex:int = VertexAttributes.TEXCOORDS[0];
			
			validateExpandAttribIndex(expandIndex);
			
			var vStream:VertexStream = myGeometry._attributesStreams[expandIndex]; 
			if (_debugStream == null) _debugStream = createDebugUVStream(context3D);
			if (vStream != _debugStream) {
				myGeometry._attributesStreams[expandIndex] = vStream = _debugStream;
			}
			
			myGeometry._attributesOffsets[expandIndex] = 0; 
		}
		
		private function createDebugUVStream(context3D:Context3D):VertexStream {
			var vStream:VertexStream = new VertexStream();
			vStream.attributes =  [VertexAttributes.TEXCOORDS[0], VertexAttributes.TEXCOORDS[0]];
			var vBuffer:VertexBuffer3D = context3D.createVertexBuffer(NUM_VERTICES, 2);
			var vec:Vector.<Number> = new Vector.<Number>(NUM_VERTICES*2, true);
			TerrainGeomTools.writeDebugUVs(vec, PROTO_32.indexLookup, PATCHES_ACROSS+1);
			vBuffer.uploadFromVector(vec, 0, NUM_VERTICES);
			vStream.buffer = vBuffer;
			return vStream;
		}
		
		private static var COLORS:Vector.<uint> = getRandomColors();
		private var quadOrderTable:Vector.<Vector.<int>>;
		private var _repeatUVLowestLevel:int;
		private var lodLvlMin:int = 12;
		private var currentLookupIndex:int=0;
		private var tileShift:int;
		private var tileMod:int;
		public var useLighting:Boolean = true;
	
		
		private static function getRandomColors():Vector.<uint> {
			var vec:Vector.<uint> = new Vector.<uint>();
			for (var i:int = 0; i < 30; i++ ) {
				vec[i] = int(Math.random()*255);
			}
			vec[14] = 0xFF0000;
			vec[13] = 0xAAFF00;
			vec[12] = 0x00FF00;
			return vec;
		}
		
		private function getNewChunkState(context3D:Context3D):TerrainChunkState {
		
			var state:TerrainChunkState = new TerrainChunkState();
			
			state.vertexBuffer = context3D.createVertexBuffer(NUM_VERTICES, _data32PerVertex);
		
			return state;
		}
		
		
			alternativa3d override function fillResources(resources:Dictionary, hierarchy:Boolean = false, resourceType:Class = null):void {
				if (tree != null) {
					tree.material.fillResources(resources, resourceType);
				}
				
				if (gridPagesVector != null) {
					var i:int = gridPagesVector.length;
					while (--i > -1) {
						gridPagesVector[i].material.fillResources(resources, resourceType);
					}
				}
				super.fillResources(resources, hierarchy, resourceType);
			}
			
			
			override alternativa3d function collectGeometry(collider:EllipsoidCollider, excludedObjects:Dictionary):void {
				throw new Error("Not supported! Use setupCollisionGeometry() approach instead!");
			}
			
			public var numCollisionTriangles:int = 0;
			
	
			
			
			// TODO: collects all dynamic geometry on-the-fly within a bounding sphere radius! Sphere is assumed to be in local coordinate space
			public function setupCollisionGeometry(sphere:Vector3D, vertices:Vector.<Number>, indices:Vector.<uint>, vi:int = 0, ii:int = 0):void {
				numCollisionTriangles = 0;

				if (tree != null && boundIntersectSphere(sphere, tree.xorg, -tree.xorg - ((1 << tree.Level) << 1), tree.Square.MinY,  tree.zorg, tree.zorg + ((1 << tree.Level) << 1), tree.Square.MaxY )) {
						_currentPage = tree;
						collectTrisForTree2D(tree, sphere, vertices, indices, vi, ii);			
					}
					
					if ( gridPagesVector != null) {
						// TODO: for multiple pages case
					}
			}
			
			private function boundIntersectSphere(sphere:Vector3D, minX:Number, minY:Number, minZ:Number, maxX:Number, maxY:Number, maxZ:Number):Boolean {
				return sphere.x + sphere.w > minX && sphere.x - sphere.w < maxX && sphere.y + sphere.w > minY && sphere.y - sphere.w < maxY && sphere.z + sphere.w > minZ && sphere.z - sphere.w < maxZ;
			}
			
		
			
			override protected function clonePropertiesFrom(source:Object3D):void {
				super.clonePropertiesFrom(source);


			}
			
			private function boundIntersectRay(origin:Vector3D, direction:Vector3D, minX:Number, minY:Number, minZ:Number, maxX:Number, maxY:Number, maxZ:Number):Boolean {
				
				var temp:Number = minY;
				minY = -maxY;
				maxY = -temp;
				
				if (origin.x >= minX && origin.x <= maxX && origin.y >= minY && origin.y <= maxY && origin.z >= minZ && origin.z <= maxZ) return true;
				if (origin.x < minX && direction.x <= 0) return false;
				if (origin.x > maxX && direction.x >= 0) return false;
				if (origin.y < minY && direction.y <= 0) return false;
				if (origin.y > maxY && direction.y >= 0) return false;
				if (origin.z < minZ && direction.z <= 0) return false;
				if (origin.z > maxZ && direction.z >= 0) return false;
				var a:Number;
				var b:Number;
				var c:Number;
				var d:Number;
				var threshold:Number = 0.000001;
				// Intersection of X and Y projection
				if (direction.x > threshold) {
					a = (minX - origin.x) / direction.x;
					b = (maxX - origin.x) / direction.x;
				} else if (direction.x < -threshold) {
					a = (maxX - origin.x) / direction.x;
					b = (minX - origin.x) / direction.x;
				} else {
					a = -1e+22;
					b = 1e+22;
				}
				if (direction.y > threshold) {
					c = (minY - origin.y) / direction.y;
					d = (maxY - origin.y) / direction.y;
				} else if (direction.y < -threshold) {
					c = (maxY - origin.y) / direction.y;
					d = (minY - origin.y) / direction.y;
				} else {
					c = -1e+22;
					d = 1e+22;
				}
				if (c >= b || d <= a) return false;
				if (c < a) {
					if (d < b) b = d;
				} else {
					a = c;
					if (d < b) b = d;
				}
				// Intersection of XY and Z projections
				if (direction.z > threshold) {
					c = (minZ - origin.z) / direction.z;
					d = (maxZ - origin.z) / direction.z;
				} else if (direction.z < -threshold) {
					c = (maxZ - origin.z) / direction.z;
					d = (minZ - origin.z) / direction.z;
				} else {
					c = -1e+22;
					d = 1e+22;
				}
				
				c = c > a ? c : a;  // added to ensure reference is correct!
				d = d < b ? d : b;
				//if (c === Infinity) throw new Error("LOWER ZERO C!");
	
				if (direction.w > 0 && c >= direction.w) return false;
				
				if (c >= b || d <= a) return false;
				return true;
			}
			
			public function calcBoundIntersection(point:Vector3D, origin:Vector3D, direction:Vector3D, minX:Number, minY:Number, minZ:Number, maxX:Number, maxY:Number, maxZ:Number):Number {
		
			//	minZ = -Number.MAX_VALUE * .5
			//	maxZ = Number.MAX_VALUE * .5;
				var temp:Number = minY;
				minY = -maxY;
				maxY = -temp;
				
				if (origin.x >= minX && origin.x <= maxX && origin.y >= minY && origin.y <= maxY && origin.z >= minZ && origin.z <= maxZ) return 0;  // true
				
				if (origin.x < minX && direction.x <= 0) return -1;
				if (origin.x > maxX && direction.x >= 0) return -1;
				if (origin.y < minY && direction.y <= 0) return -1;
				if (origin.y > maxY && direction.y >= 0) return -1;
				if (origin.z < minZ && direction.z <= 0) return -1;
				if (origin.z > maxZ && direction.z >= 0) return -1;
				var a:Number;
				var b:Number;
				var c:Number;
				var d:Number;
				var threshold:Number = 0.000001;
				// Intersection of X and Y projection
				if (direction.x > threshold) {
					a = (minX - origin.x) / direction.x;
					b = (maxX - origin.x) / direction.x;
				} else if (direction.x < -threshold) {
					a = (maxX - origin.x) / direction.x;
					b = (minX - origin.x) / direction.x;
				} else {
					a = -1e+22;
					b = 1e+22;
				}
				if (direction.y > threshold) {
					c = (minY - origin.y) / direction.y;
					d = (maxY - origin.y) / direction.y;
				} else if (direction.y < -threshold) {
					c = (maxY - origin.y) / direction.y;
					d = (minY - origin.y) / direction.y;
				} else {
					c = -1e+22;
					d = 1e+22;
				}
				if (c >= b || d <= a) return -1;
				if (c < a) {
					if (d < b) b = d;
				} else {
					a = c;
					if (d < b) b = d;
				}
				// Intersection of XY and Z projections
				if (direction.z > threshold) {
					c = (minZ - origin.z) / direction.z;
					d = (maxZ - origin.z) / direction.z;
				} else if (direction.z < -threshold) {
					c = (maxZ - origin.z) / direction.z;
					d = (minZ - origin.z)  / direction.z;
				} else {
					c = -1e+22;
					d = 1e+22;
				}
				
				c = c > a ? c : a;  // added to ensure reference is correct!
				d = d < b ? d : b;
	
				if (c >= b || d <= a) return -1;
	 
				point.x = origin.x + direction.x * c;
				point.y = origin.y + direction.y * c;
				point.z = origin.z + direction.z * c;
				
				//if (c < 0) throw new Error("WRONG DIRECTION!");
				
				return c;
			}
			
			private var waterRayData:RayIntersectionData;
			
			public function intersectRayWater(origin:Vector3D, direction:Vector3D):RayIntersectionData {
				if (direction.z >= 0 || origin.z <= waterLevel) return null;
				var result:RayIntersectionData = waterRayData;
				var t:Number =  (origin.z - waterLevel) / direction.z;
				
				t = t < 0 ? -t : t;
		
				if (t >= (direction.w > 0 ? direction.w : 1e22)) return null;
				
				result.time = t;
				result.point.x = origin.x + t * direction.x;
				result.point.y = origin.y + t * direction.y;
				result.point.z = origin.z + t* direction.z;
				return result;
			}
			
			// Public Raycasting methods (origin,  direction (normalized vector with positive w value to indicate specific range or w value of 0 or less for infinite range)
			
			// Both methods performs per-polygon accruate raycasting on terrain at highest level of detail!
			
			// If the range of the ray is short, this approach is often better, immediately calculating DDA from current position since worse-case scenerio would not happen
			public function intersectRayDDA(origin:Vector3D, direction:Vector3D):RayIntersectionData {
				if ( (tree == null && gridPagesVector == null) || (boundBox != null && !boundBox.intersectRay(origin, direction)) ) return null;
				var data:RayIntersectionData = null;
			
					var minTime:Number = 1e22;
					rayData.time = 1e22;
					_boundRayTime = 0;
					
					if (tree != null && boundIntersectRay(origin, direction, tree.xorg, tree.zorg, tree.Square.MinY, tree.xorg + ((1 << tree.Level) << 1), tree.zorg + ((1 << tree.Level) << 1), tree.Square.MaxY )) {
						_currentPage = tree;
			
						if (calculateDDAIntersect(rayData, tree.heightMap, tree, origin, direction)) return rayData;
					}
					
					if ( gridPagesVector != null) {
						// TODO: perform DDA for grid of pages!
					}
				
				return null;
			}
		
			// Performs raycasting through the quad tree bounds first and into each chunk for DDA (Could later provide support for LOD-based raycasting as well)
			override public function intersectRay(origin:Vector3D, direction:Vector3D):RayIntersectionData {
					if ( (tree == null && gridPagesVector == null) || (boundBox != null && !boundBox.intersectRay(origin, direction)) ) return null;
					var data:RayIntersectionData = null;
					var result:RayIntersectionData = null;
					var minTime:Number = 1e22;
					rayData.time = 1e22;
					_boundRayTime = 0;
					//tracedTiles.length = 0;
					
					///*
					
					//*/
					//var test:RayIntersectionData = new RayIntersectionData();
					
					
					if (tree != null && boundIntersectRay(origin, direction, tree.xorg, tree.zorg, tree.Square.MinY, tree.xorg + ((1 << tree.Level) << 1), tree.zorg + ((1 << tree.Level) << 1), tree.Square.MaxY )) {
						_currentPage = tree;
			//	throw new Error("A");
						data = intersectRayQuad(tree, origin, direction);
						
						if (data != null && data.time < minTime) {
							minTime = data.time;
							result = data;
						}
					}
					
					if ( gridPagesVector != null) {
						// TODO: perform DDA for grid of pages!
					}
					
					return result;
				}
				

				
				
				// Step-wise DDA raycasting for a chunk  
				private function calculateDDAIntersect(result:RayIntersectionData, hm:HeightMapInfo, cd:QuadChunkCornerData, origin:Vector3D, direction:Vector3D):Boolean {
					var dx:Number = direction.x;
					var dy:Number = -direction.y;
					
					var xt:Number; // time until the next x-intersection
					var dxt:Number; // time between x-intersections
					var yt:Number; // time until the next y-intersection
					var dyt:Number; // time between y-intersections
					var dxi:int; // direction of the x-intersection
					var dyi:int; // direction of the y-intersection
					var t:Number;
					
					var xorg:Number = _currentPage.xorg - hm.XOrigin;
					var zorg:Number = _currentPage.zorg - hm.ZOrigin;
	
					var fullC:int = (1 << cd.Level) << 1;
					var P_ACROSS:int = fullC >> tileShift;
					
					// If point isn't inside chunk, find starting intersection point of ray against bound of QuadChunkCornerData square
					var px:Number = origin.x;
					var py:Number = -origin.y;
					var zValStart:Number = origin.z;
					var xi:int;
					var yi:int;
					if (px < cd.xorg || px >= cd.xorg + fullC || py < cd.zorg || py >= cd.zorg + fullC) {
						if ( (t = calcBoundIntersection( result.point, origin, direction, cd.xorg, cd.zorg, cd.Square.MinY, cd.xorg + fullC, cd.zorg + fullC, cd.Square.MaxY  )) > 0 ) {
							if (t > (direction.w > 0 ? direction.w : 1e22) ) return false;
							px = result.point.x;
							py = -result.point.y;
							
							py -= dy<0 ? 1 : -1;
							px -= dx < 0 ? 1 : -1;
							zValStart = result.point.z;
							_boundRayTime = t;
							
							
							//result.time = 0;
				
							xi = int(px - xorg) >> tileShift;	
							yi = int(py - zorg) >> tileShift;
							//if (dx < 0) xi -= 1;
							//if (dy < 0 ) yi -= 1; 
						}
						else throw new Error("Should always have a positive intersection t:"+t)
					}
					else {
						xi = int(px - xorg) >> tileShift;	
						yi = int(py - zorg) >> tileShift;	
					}
					
					// with starting point, check if there's a hit, otherwise continue with DDA process!
					
					var minxi:int = (cd.xorg-xorg) >> tileShift;
					var minyi:int = (cd.zorg-zorg) >> tileShift;
					var maxxi:int = minxi +  P_ACROSS ;
					var maxyi:int = minyi + P_ACROSS ;

	
					var xoff:Number = px / tileSize;  // integer modulus + floating point
					xoff -= int(xoff);
					var yoff:Number = py / tileSize;  // integer modulus + floating point
					yoff -= int(yoff);
					
			
					
					var maxt:Number = direction.w > 0 ? (direction.w - _boundRayTime ) * tileSizeInv : 1e22;  
					
					 t = 0;
					//if (t > maxt) throw new Error("SHould not be! maxt should be positive:!"+maxt + ", "+_boundRayTime);
					 
					if (dx < 0) {
						xt = -xoff / dx;
						dxt = -1 / dx;
						dxi = -1;
					} else {
						xt = (1 - xoff) / dx;
						dxt = 1 / dx;
						dxi = 1;
					}
					if (dy < 0) {
						yt = -yoff / dy;
						dyt = -1 / dy;
						dyi = -1;
					} else {
						yt = (1 - yoff) / dy;
						dyt = 1 / dy;
						dyi = 1;
					}
				
					
						/*
					offsetOriginX = px;
					offsetOriginY = -py;
					offsetOriginZ = zValStart;
					*/
		
					if ( xi < minxi || xi >= maxxi || yi < minyi || yi >= maxyi) {
						return false;
						throw new Error("Should not be:" + minxi + "/"+ xi + "/" + maxxi + ", "+ minyi+"/"+ yi + "/" + maxyi);
					}
					
					
					if ( checkHitPatch(result, hm, xi, yi, direction.z < 0 ? xt < yt ? zValStart+xt*direction.z*tileSize : zValStart+yt*direction.z*tileSize : zValStart+t*direction.z*tileSize, origin, direction) ) return true;
		
				
					while (true) {
						if (xt < yt) {
							xi += dxi;
							t = xt;  
							xt += dxt;
							
							
						} else {
							yi += dyi;
							t = yt; 
							yt += dyt;
						}
						
						//if (t < 0) throw new Error("Negative t! Should not be!");
						
								if ( t >= maxt || xi < minxi || xi >= maxxi || yi < minyi || yi >= maxyi) return false;
							if (  checkHitPatch(result, hm, xi, yi, direction.z < 0 ? xt < yt ? zValStart+xt*direction.z*tileSize : zValStart+yt*direction.z*tileSize : zValStart+t*direction.z*tileSize, origin, direction) ) return true;   

					}
					
					return false;
				}
				

				
				private var _patchHeights:Vector.<int> = new Vector.<int>(4*3, true);
				private static const TRI_ORDER_TRUE:Vector.<int> =  createTriOrderIndiceTable(true); // forward slash tri-patch
				private static const TRI_ORDER_FALSE:Vector.<int> =  createTriOrderIndiceTable(false); // back slash tri-patch
				
				private static function createTriOrderIndiceTable(positive:Boolean):Vector.<int> {  
					var indices:Vector.<int> = new Vector.<int>(6, true);
					if (positive) {
						//nw | se =  00 or 11   !=
						indices[0] = 0; indices[1] = 2; indices[2] = 1;
						indices[3] = 2; indices[4] = 3; indices[5] = 1;
					}
					else {
						// ne | sw - 01 or 10   ==
						indices[0] = 0; indices[1] = 3; indices[2] = 1;
						indices[3] = 0; indices[4] = 2; indices[5] = 3;
					}
					return indices;
				}
				
				private function intersectRayTri(result:RayIntersectionData, ox:Number, oy:Number, oz:Number, dx:Number, dy:Number, dz:Number, ax:Number, ay:Number, az:Number, bx:Number, by:Number, bz:Number, cx:Number, cy:Number, cz:Number):Boolean 
				{
					var point:Vector3D = result.point;
					var abx:Number = bx - ax;
					var aby:Number = by - ay;
					var abz:Number = bz - az;
					var acx:Number = cx - ax;
					var acy:Number = cy - ay;
					var acz:Number = cz - az;
					var normalX:Number = acz*aby - acy*abz;
					var normalY:Number = acx*abz - acz*abx;
					var normalZ:Number = acy*abx - acx*aby;
					var len:Number = normalX*normalX + normalY*normalY + normalZ*normalZ;
					if (len > 0.001) {
						len = 1/Math.sqrt(len);
						normalX *= len;
						normalY *= len;
						normalZ *= len;
					}
					var dot:Number = dx*normalX + dy*normalY + dz*normalZ;
					if (dot < 0) {
						var offset:Number = ox*normalX + oy*normalY + oz*normalZ - (ax*normalX + ay*normalY + az*normalZ);
						if (offset > 0) {
						var time:Number = -offset/dot;
						
							var rx:Number = ox + dx*time;
							var ry:Number = oy + dy*time;
							var rz:Number = oz + dz*time;
							abx = bx - ax;
							aby = by - ay;
							abz = bz - az;
							acx = rx - ax;
							acy = ry - ay;
							acz = rz - az;
							if ((acz*aby - acy*abz)*normalX + (acx*abz - acz*abx)*normalY + (acy*abx - acx*aby)*normalZ >= 0) {
								abx = cx - bx;
								aby = cy - by;
								abz = cz - bz;
								acx = rx - bx;
								acy = ry - by;
								acz = rz - bz;
								if ((acz*aby - acy*abz)*normalX + (acx*abz - acz*abx)*normalY + (acy*abx - acx*aby)*normalZ >= 0) {
									abx = ax - cx;
									aby = ay - cy;
									abz = az - cz;
									acx = rx - cx;
									acy = ry - cy;
									acz = rz - cz;
									if ((acz*aby - acy*abz)*normalX + (acx*abz - acz*abx)*normalY + (acy*abx - acx*aby)*normalZ >= 0) {
										//if (time < minTime) {
											result.time = time + _boundRayTime;
											point.x = rx;
											point.y = ry;
											point.z = rz;
											return true;
											
												//	}
												}
											}
										}
									}
									
									
								}
								
								return false;
				}
				
				// remove once doen testing
				/*
				public var tracedTiles:Vector.<Vector3D> = new Vector.<Vector3D>();
				private var offsetOriginX:Number;
				private var offsetOriginY:Number;
				private var offsetOriginZ:Number;
				*/
				
				private function checkHitPatch(result:RayIntersectionData, hm:HeightMapInfo, xi:int, yi:int, zVal:Number, origin:Vector3D, direction:Vector3D):Boolean 
				{
					// highestPoint bound early reject
					var highestPoint:Number = hm.Data[xi + yi * hm.RowWidth]; // nw
				
					var cxorg:Number = _currentPage.xorg;
					var czorg:Number = _currentPage.zorg;
					
					var hp:Number;
					_patchHeights[2] = highestPoint;   // 0*3+2
					hp =   hm.Data[(xi + 1) + (yi) * hm.RowWidth];  // ne
					if (hp > highestPoint) highestPoint = hp;
					_patchHeights[5] = hp;  // 1*3+2
					hp = hm.Data[xi + (yi+1) * hm.RowWidth]; //sw
					if (hp > highestPoint) highestPoint = hp;
					_patchHeights[8] = hp;  // 2*3+2
					hp = hm.Data[(xi+1) + (yi + 1) * hm.RowWidth];  // se
					if (hp > highestPoint) highestPoint = hp;
					_patchHeights[11] = hp; // 3*3+2
					
					if (zVal > highestPoint) return false;
					
					// test for hit on 2 triangles
					var whichFan:Vector.<int>  = (xi & 1) != (yi & 1) ? TRI_ORDER_TRUE : TRI_ORDER_FALSE;
					
					var ax:Number; 
					var ay:Number; 
					var az:Number; 
					
					var bx:Number; 
					var by:Number; 
					var bz:Number;
					
					var cx:Number; 
					var cy:Number; 
					var cz:Number;
				
					
					ax = (_patchHeights[whichFan[0] * 3] + xi) *tileSize + cxorg;
					ay = (_patchHeights[whichFan[0] * 3 + 1] + yi) * tileSize + czorg; 
					ay *= -1;
					az = _patchHeights[whichFan[0] * 3 + 2];
					
					 
					bx=  (_patchHeights[whichFan[1] * 3] + xi) * tileSize+ cxorg; 
					by = (_patchHeights[whichFan[1] * 3 + 1] + yi) * tileSize+ czorg;  
					by *= -1;
					bz=_patchHeights[whichFan[1] * 3 + 2];
					   
					cx= (_patchHeights[whichFan[2] * 3] + xi) *tileSize + cxorg;
					cy =	(_patchHeights[whichFan[2] * 3 + 1] + yi) * tileSize+ czorg;  
					cy *= -1;
					cz = _patchHeights[whichFan[2] * 3 + 2];
					
					if (intersectRayTri(result, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, ax, ay, az, bx, by, bz, cx, cy, cz) ) return true;
					
					ax = (_patchHeights[whichFan[3] * 3] + xi) *tileSize + cxorg;
					ay = (_patchHeights[whichFan[3] * 3 + 1] + yi) * tileSize + czorg; 
					ay *= -1;
					az= _patchHeights[whichFan[3] * 3 + 2];
					 
					bx=  (_patchHeights[whichFan[4] * 3] + xi) * tileSize + cxorg;
					by = (_patchHeights[whichFan[4] * 3 + 1] + yi) * tileSize+ czorg; 
					by *= -1;
					bz=_patchHeights[whichFan[4] * 3 + 2];
					   
					cx= (_patchHeights[whichFan[5] * 3] + xi) *tileSize + cxorg;
					cy =	(_patchHeights[whichFan[5] * 3 + 1] + yi) * tileSize+ czorg;  
					cy *= -1;
					cz = _patchHeights[whichFan[5] * 3 + 2];

					if (intersectRayTri(result, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, ax, ay, az, bx, by, bz, cx, cy, cz) ) return true;
					
					return false;
				}
				
			private function collectTrisForTree2D(tree:QuadTreePage, sphere:Vector3D, vertices:Vector.<Number>, indices:Vector.<uint>, vi:int, ii:int):void {
				var hm:HeightMapInfo = tree.heightMap;
				var xi:int = (sphere.x - sphere.w - tree.xorg -hm.XOrigin ) * tileSizeInv;
				var yi:int = ( -sphere.y + sphere.y - tree.zorg - hm.ZOrigin) * tileSizeInv;
				var data:Vector.<int> = hm.Data;
				var len:int = sphere.w * 2 * tileSizeInv;
				var xtmax:int = xi + len;
				var ytmax:int = yi + len;
					var whichFan:Vector.<int>;
					var RowWidth:int = hm.RowWidth;
					var cxorg:Number = _currentPage.xorg;
					var czorg:Number = _currentPage.zorg;
					
					var ax:Number; 
					var ay:Number; 
					var az:Number; 
					
					var bx:Number; 
					var by:Number; 
					var bz:Number;
					
					var cx:Number; 
					var cy:Number; 
					var cz:Number;
					
					var vMult:Number = 1 / 3;
					
				for (yi; yi < ytmax; yi++) {
					for (xi; xi < xtmax; xi++) {

					_patchHeights[2] = data[xi + yi * RowWidth];   // nw
					_patchHeights[5] =  data[(xi + 1) + (yi) * RowWidth];  // ne
					_patchHeights[8] =  data[xi + (yi+1) * RowWidth]; //sw
					_patchHeights[11] =  data[(xi + 1) + (yi + 1) * RowWidth];  // se
					
					whichFan = (xi & 1) != (yi & 1) ? TRI_ORDER_TRUE : TRI_ORDER_FALSE;
					
					ax = (_patchHeights[whichFan[0] * 3] + xi) *tileSize + cxorg;
					ay = (_patchHeights[whichFan[0] * 3 + 1] + yi) * tileSize + czorg; 
					ay *= -1;
					az = _patchHeights[whichFan[0] * 3 + 2];
					
					 
					bx=  (_patchHeights[whichFan[1] * 3] + xi) * tileSize+ cxorg; 
					by = (_patchHeights[whichFan[1] * 3 + 1] + yi) * tileSize+ czorg;  
					by *= -1;
					bz=_patchHeights[whichFan[1] * 3 + 2];
					   
					cx= (_patchHeights[whichFan[2] * 3] + xi) *tileSize + cxorg;
					cy =	(_patchHeights[whichFan[2] * 3 + 1] + yi) * tileSize+ czorg;  
					cy *= -1;
					cz = _patchHeights[whichFan[2] * 3 + 2];
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = ax;
					vertices[vi++] = ay;
					vertices[vi++] = az;
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = bx;
					vertices[vi++] = by;
					vertices[vi++] = bz;
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = cx;
					vertices[vi++] = cy;
					vertices[vi++] = cz;
						
					numCollisionTriangles++;
					
					
					ax = (_patchHeights[whichFan[3] * 3] + xi) *tileSize + cxorg;
					ay = (_patchHeights[whichFan[3] * 3 + 1] + yi) * tileSize + czorg; 
					ay *= -1;
					az= _patchHeights[whichFan[3] * 3 + 2];
					 
					bx=  (_patchHeights[whichFan[4] * 3] + xi) * tileSize + cxorg;
					by = (_patchHeights[whichFan[4] * 3 + 1] + yi) * tileSize+ czorg; 
					by *= -1;
					bz=_patchHeights[whichFan[4] * 3 + 2];
					   
					cx= (_patchHeights[whichFan[5] * 3] + xi) *tileSize + cxorg;
					cy =	(_patchHeights[whichFan[5] * 3 + 1] + yi) * tileSize+ czorg;  
					cy *= -1;
					cz = _patchHeights[whichFan[5] * 3 + 2];
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = ax;
					vertices[vi++] = ay;
					vertices[vi++] = az;
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = bx;
					vertices[vi++] = by;
					vertices[vi++] = bz;
					
					indices[ii++] = vi * vMult;
					vertices[vi++] = cx;
					vertices[vi++] = cy;
					vertices[vi++] = cz;
					
					numCollisionTriangles++;
						
					}
				}
			}
			
			
			/*  // This approach checks bounds recursively by goging down quad-tree. Imo, not necessary and overkill unless perhaps if using airborne fast-flying objects.
			private function collectTrisForTree3D(tree:QuadTreePage, sphere:Vector3D, vertices:Vector.<Number>, indices:Vector.<uint>, vi:int, ii:int):void {
			
			var sq:QuadSquareChunk;
			
			const stackStart:int =  QuadChunkCornerData.BI;

			
			var cd:QuadChunkCornerData = tree;
			var buffer:Vector.<QuadChunkCornerData> =  QD_STACK;
			sq = cd.Square;
			var childList:Vector.<QuadSquareChunk> = sq.Child;
			var child:QuadSquareChunk;
			var half:int = 1 << cd.Level;
			var full:int = half << 1;
			var newCD:QuadChunkCornerData;
			
			
			
				
			var hm:HeightMapInfo = tree.heightMap;
			
			var bi:int = 1;
		
			
				
			while (bi > 0) {
				cd = buffer[--bi];
	
				sq = cd.Square;
				childList = sq.Child;
				half =  1 << cd.Level;
				full = half << 1;
				
				if (childList[0] == null) {
				//	vertices[vi++] = tree.xorg
				}
				
				
				child = childList[0];
				if ( boundIntersectSphere(sphere,  cd.xorg + half, -cd.zorg - half, child.MinY, cd.xorg + full, -cd.zorg, child.MaxY)) {	
					
					sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, 0);
					buffer[bi++] = newCD;
				}
				child = childList[1];
					if (boundIntersectSphere(sphere, cd.xorg, -cd.zorg - half , child.MinY, cd.xorg + half, -cd.zorg , child.MaxY) ) {
					sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, 1);
					buffer[bi++] = newCD;
				}
				child = childList[2];
				if (boundIntersectSphere(sphere, cd.xorg, -cd.zorg - full, child.MinY, cd.xorg + half, -cd.zorg - half , child.MaxY)) {
						
					sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, 2);
					buffer[bi++] = newCD;
				}
				child = childList[3];
				if (boundIntersectSphere(sphere, cd.xorg + half, -cd.zorg -+ full, child.MinY, cd.xorg + full, -cd.zorg - half , child.MaxY)) {
					sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, 3);
					buffer[bi++] = newCD;
				}
			}
			

		
			QuadChunkCornerData.BI = stackStart;

			
		}
		*/
				
				
				
				
				// Brute force raycasting by using entire chunk geometry  
				private function calculateRayIntersectGeom(result:RayIntersectionData, hm:HeightMapInfo, cd:QuadChunkCornerData, origin:Vector3D, direction:Vector3D):Boolean {
					sampleHeights(0, _currentPage.heightMap, cd);
					var mockGeom:Geometry = PROTO_32.geometry;
					mockGeom.setAttributeValues(VertexAttributes.POSITION, _vertexUpload);
					var test:RayIntersectionData = mockGeom.intersectRay(origin, direction, 0, mockGeom.numTriangles);
					if (test != null) {
						result.point = test.point;
						result.surface = test.surface;
						result.uv = test.uv;
						result.time = test.time;
						return true;
					}
					return false;
				}
				
				private static const QD_STACK:Vector.<QuadChunkCornerData> = new Vector.<QuadChunkCornerData>();
				private var tileSizeInv:Number;
				private var _boundRayTime:Number;
				
				private function intersectRayQuad(cd:QuadChunkCornerData, origin:Vector3D, direction:Vector3D):RayIntersectionData  // determine nearest ray hit from front-to-back
				{
					var sq:QuadSquareChunk;
					var result:RayIntersectionData = rayData;
					result.uv = null;
					result.surface = null;
					result.time = 1e22;
					//result.object  = this;
					
					const stackStart:int =  QuadChunkCornerData.BI;
					var index:int;
					
					var buffer:Vector.<QuadChunkCornerData> =  QD_STACK;
					sq = cd.Square;
					var childList:Vector.<QuadSquareChunk> = sq.Child;
					var c:QuadSquareChunk;
					var half:int = 1 << cd.Level;
					var full:int = half << 1;
					var newCD:QuadChunkCornerData;
					var orderedIndices:Vector.<int>;
					var quadOrderTable:Vector.<Vector.<int>> = QUAD_ORDER2;
					var quadOffsets:Vector.<int> = QUAD_OFFSETS;
					var o:int;
					
				
					var bi:int = 1;
					buffer[0] = cd;
						
					while (bi > 0) {
						cd = buffer[--bi];
			
						sq = cd.Square;
						childList = sq.Child;
						half =  1 << cd.Level;
						full = half << 1;
			
						
						if (childList[0] == null) {  // start tracing out through tile-based DDA
						//	throw new Error("current chunk coordinate:"+ int(cd.xorg / ((1<<cd.Level)*2) ) + ', ' + int(cd.zorg/ ((1<<cd.Level)*2)) );
							if (  calculateDDAIntersect(result, _currentPage.heightMap, cd, origin, direction) ) { 
								return result;
							};
							
							continue;
						}
						
						var halfX:int = cd.xorg + half;
						var halfY:int = cd.zorg + half;
						index = 0;
						index |= origin.x < halfX ? 1 : 0; 
						index |= -origin.y < halfY ? 2 : 0; 
						orderedIndices = quadOrderTable[index]; 
						
						index = orderedIndices[0];
						c = childList[index]; 
						o =  quadOffsets[index];
						if ( boundIntersectRay(origin, direction,  cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY)) {	
						
							sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, index);
							buffer[bi++] = newCD;
						}
						index = orderedIndices[1];
						c = childList[index]; 
						o =  quadOffsets[index];
						if (boundIntersectRay(origin, direction, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY) ) {
							sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, index);
							buffer[bi++] = newCD;
						}
						index = orderedIndices[2];
						c = childList[index]; 
						o =  quadOffsets[index];
						if (boundIntersectRay(origin, direction, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY)) {
								
							sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, index);
							buffer[bi++] = newCD;
						}
						index = orderedIndices[3];
						c = childList[index]; 
						o =  quadOffsets[index];
						if (boundIntersectRay(origin, direction, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY)) {
					
							sq.SetupCornerData( newCD = QuadChunkCornerData.create(), cd, index);
							buffer[bi++] = newCD;
						}
					}
				
					QuadChunkCornerData.BI = stackStart;		
	
					return null;
				}
				
				public function compare2Vectors(a:Vector.<Number>, b:Vector.<Number>):Boolean {
					var len:int = a.length;
					for (var i:int = 0; i < len; i++) {
						if (a[i] != b[i]) return false;
					}
					
					return true;
				}

				
				private function drawLeaf(cd:QuadChunkCornerData, s:QuadSquareChunk, camera:Camera3D, lights:Vector.<Light3D>, lightsLength:int, useShadow:Boolean):void {
					var state:TerrainChunkState;   
					if (!debug && tilingUVBuffers != null) myGeometry._attributesStreams[VertexAttributes.TEXCOORDS[0]].buffer = tilingUVBuffers[cd.Level-_repeatUVLowestLevel];
					if (myLODMaterial != null) myLODMaterial.visit(cd, _currentPage, tileShift, currentLookupIndex);
					
					var id:int = cd.Parent != null ? indexSideLookup[((cd.Parent.Square.EnabledFlags & 0xF) | cornerMask[cd.ChildIndex])]  : 0;
						state = s.state;   
					if (state == null) {
						 state =  chunkPool.getAvailable() || getNewChunkState(camera.context3D);
						 if (state.square != null)  state.square.state = null;  // this means that the square is from pool!
						 state.square = s;
						 s.state = state;
						state.enabledFlags = s.EnabledFlags;
						sampleHeights(_currentPage.requirements, _currentPage.heightMap, cd);
						state.vertexBuffer.uploadFromVector(_vertexUpload, 0, NUM_VERTICES);
					}
					/*
					else if ( state.enabledFlags != s.EnabledFlags ) {  
						if (_currentPage.requirements & requireEdgeMask) updateEdges(_currentPage.requirements, cd, state.enabledFlags, s.EnabledFlags);
						state.enabledFlags = s.EnabledFlags;
					}
					*/
					state.enabledFlags = s.EnabledFlags;
					mySurface.numTriangles = numTrianglesLookup[id]; 
					//myGeometry._indexBuffer = indexBuffers[0];
					myGeometry._indexBuffer = indexBuffers[id];
					
					
					myGeometry._attributesStreams[1].buffer = s.state.vertexBuffer;  
					mySurface.material.collectDraws( camera, mySurface, myGeometry, lights, lightsLength, useShadow);
		
					if (state.parent) state.parent.remove(state);
					activeChunks.append(state);
					
					drawnChunks++;
				}
				
		
		private function drawQuad(cd:QuadChunkCornerData, camera:Camera3D, lights:Vector.<Light3D>, lightsLength:int, useShadow:Boolean, culling:int):void 
		{
			var q:QuadChunkCornerData;
			var s:QuadSquareChunk = cd.Square;
			var c:QuadSquareChunk;
			var index:int;
			var half:int;
			var full:int;
			var cCulling:int;
			var state:TerrainChunkState;
			var orderedIndices:Vector.<int>;
		
			
			if ( cd.Level <= lodLvlMin) {  
				// draw single chunk!
				drawLeaf(cd, s, camera, lights, lightsLength, useShadow);
				return;
			}
			
			if (  (s.EnabledFlags & 0xF) ) { 
				
				half = (1 << cd.Level);
				full = (half << 1);
				var halfX:int = cd.xorg + half;
				var halfY:int = cd.zorg + half;
				index = 0;
				index |= _cameraPos.x < halfX ? 1 : 0; 
				index |= _cameraPos.y < halfY ? 2 : 0; 
				orderedIndices = quadOrderTable[index]; 
				var o:int;
				
				index = orderedIndices[0];
				o =  QUAD_OFFSETS[index];
				c = s.Child[index];  
				if (s.EnabledFlags & (16 << index) ) {
					cCulling = culling == 0 ? 0 :  cullingInFrustum(culling, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY);		
					if (cCulling >= 0) {
						q = QuadChunkCornerData.create();  
						s.SetupCornerData(q, cd, index);
						drawQuad(q, camera, lights, lightsLength, useShadow, cCulling);
					}
				}
				else {
					q = QuadChunkCornerData.create();  
					s.SetupCornerData(q, cd, index);
					drawLeaf(q, c, camera, lights, lightsLength, useShadow);
				}
				
				index = orderedIndices[1];
				o =  QUAD_OFFSETS[index];
				c = s.Child[index];
				if (s.EnabledFlags & (16 << index) ) {
					cCulling = culling == 0 ? 0 : cullingInFrustum(culling, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY);		
					if (cCulling >= 0) {
						q = QuadChunkCornerData.create(); 
						s.SetupCornerData(q, cd, index);
						drawQuad(q, camera, lights, lightsLength, useShadow, cCulling);
					}
				}
				else {
						q = QuadChunkCornerData.create();  
						s.SetupCornerData(q, cd, index);
					drawLeaf(q, c, camera, lights, lightsLength, useShadow);
				}
				
				index = orderedIndices[2];
				o =  QUAD_OFFSETS[index];
				c = s.Child[index];
				if (s.EnabledFlags & (16 << index) ) {
					cCulling = culling == 0 ? 0 :  cullingInFrustum(culling, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY);		
					if (cCulling >= 0) {
						q = QuadChunkCornerData.create();  
						s.SetupCornerData(q, cd, index);
						drawQuad(q, camera, lights, lightsLength, useShadow, cCulling);
					}
				}
				else {
						q = QuadChunkCornerData.create();  
						s.SetupCornerData(q, cd, index);
					drawLeaf(q, c, camera, lights, lightsLength, useShadow);
				}
				
				index = orderedIndices[3];
				o =  QUAD_OFFSETS[index];
				c = s.Child[index];
				if (s.EnabledFlags & (16 << index) ) {
					
					cCulling = culling == 0 ? 0 :  cullingInFrustum(culling, cd.xorg + ((o & 1) ? half : 0), cd.zorg + ((o & 2) ? half : 0), c.MinY, cd.xorg + ((o & 1) ? full : half), cd.zorg + ((o & 2) ? full : half), c.MaxY);		
					if (cCulling >= 0) {
						q = QuadChunkCornerData.create(); 
						s.SetupCornerData(q, cd, index);
						drawQuad(q, camera, lights, lightsLength, useShadow, cCulling);
					}
				}
				else {
						q = QuadChunkCornerData.create();  
						s.SetupCornerData(q, cd, index);
					drawLeaf(q, c, camera, lights, lightsLength, useShadow);
				}
			}
			else {
				drawLeaf(cd, s, camera, lights, lightsLength, useShadow);
			}
		}
		
	}

}