package examples 
{
	import alternativa.engine3d.materials.StandardMaterial;
	import alternativa.engine3d.objects.Mesh;
	import alternativa.engine3d.objects.WireFrame;
	import alternativa.engine3d.primitives.Plane;
	import alternativa.engine3d.resources.BitmapTextureResource;
	import alternativa.engine3d.resources.Geometry;
	import alternterrain.core.HeightMapInfo;
	import alternterrain.util.TerrainGeomTools;
	import alternterrainxtras.msa.Perlin;
	import alternterrainxtras.util.TerrainProcesses;
	import com.tartiflop.PlanarDispToNormConverter;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.Event;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class TestTerrainFilters extends Template
	{
		
		public function TestTerrainFilters() 
		{
			settings.cameraSpeed = 600;
			settings.cameraSpeedMultiplier = 16;
			settings.viewBackgroundColor = 0x3BB9FF;
			
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		private function onAddedToStage(e:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			
			addEventListener(VIEW_CREATE, onViewCreate);
			//stage.addEventListener(KeyboardEvent.KEY_DOWN, onkeyDowN);
			
			init();
		}
		
		private function onViewCreate(e:Event):void 
		{
			runTest();
			//runTest2();
			startRendering();
		}
		
		private function runTest2():void 
		{
			var data:BitmapData = new BitmapData(1025, 1025, false, 0);
			var seed:int = 0;
			data.perlinNoise(32, 32, 4, seed, false, true, 7, true, [0, 0]);
			addChild( new Bitmap(data));
		}
	
		
		private var filterCircles:TerrainProcesses = new TerrainProcesses(); // will spill out of current heightmap location for splashed circle
		
		private var filterNoise:TerrainProcesses = new TerrainProcesses();  // frequency noise that can be seamless with shift x/y offsets
		
		private var filterFault:TerrainProcesses = new TerrainProcesses();  // can't seam this!
		
		private var filterSmooth:TerrainProcesses = new TerrainProcesses();
		
		private var filterPerlinNoise:TerrainProcesses = new TerrainProcesses();   // // FLash's perlinNoise noise that  can be seamless with shift x/y offsets
		
		//private var filter
		
		private function runTest():void 
		{
			var tilesAcross:int = 128;
			var vAcross:int = tilesAcross + 1;
			
			var data:Vector.<int> = new Vector.<int>(vAcross * vAcross, true);
			filterCircles.setupHeights(data, vAcross, vAcross);
			filterCircles.terrainCircleSize = 64*64;
			filterCircles.maxDisp = 900;
			filterCircles.minDisp = -900;
			filterCircles.terrainRandomSeed = Math.random() * 99999;
		//	filterCircles.terrainIterateCircles(32);
			
			filterFault.setupHeights(data, vAcross, vAcross);
			filterFault.maxDisp = 420;
			filterFault.minDisp = -420;
			filterFault.terrainWaveSize = 4;
			filterFault.terrainRandomSeed = Math.random() * 99999;
			filterFault.terrainFunction = TerrainProcesses.SIN;
		//	filterFault.terrainIterateFault(33);
			
			filterNoise.setupHeights(data, vAcross, vAcross);
			filterNoise.maxDisp = 600;
			filterNoise.minDisp = -600;
			filterNoise.terrainRandomSeed = Math.random() * 99999;
		//	filterNoise.terrainApplyNoise(20, 4, 3.4, .2);
			
		//	filterNoise.terrainApplyNoise(20, 4, 2.4, .4);
			
				filterNoise.maxDisp = 3200;
			filterNoise.minDisp = -3200;
			filterNoise.terrainRandomSeed = Math.random() * 99999;
			filterNoise.terrainApplyNoise(40, 4, 2.4, .4);
			//filterNoise.terrainApplyNoise(4, 512, 128);
			
			filterPerlinNoise.setupHeights(data, vAcross, vAcross);
			var perlinData:BitmapData = new BitmapData(129, 129, false, 0);
			var seed:int = 0;
			perlinData.perlinNoise(16, 16, 4, seed, false, true, 7, true, [62, 54]);
			filterPerlinNoise.maxDisp = 178;
			filterPerlinNoise.minDisp = -178;
			//filterPerlinNoise.terrainGrayscaleHeightMap(perlinData);
			//addChild( new Bitmap(data));
			
			//throw new Error(arr);
			
			filterSmooth.setupHeights(data, vAcross, vAcross);
			filterSmooth.terrainRandomSeed = Math.random() * 99999;
		//	filterSmooth.terrainSmooth(.15);
			
			
			var mesh:Mesh = new Mesh();
			if (tilesAcross <= 128) {
				var geo:Geometry = TerrainGeomTools.createLODTerrainChunkForMesh(tilesAcross, 512).geometry;
				TerrainGeomTools.modifyGeometryByHeightData(geo, data, vAcross);
				
				mesh.geometry = geo;
				mesh.calculateBoundBox();
			mesh.geometry.calculateNormals();
				mesh.geometry.calculateTangents(0);
				
				var testMat:StandardMaterial =  new StandardMaterial(new BitmapTextureResource(new BitmapData(4, 4, false, 0xBBBBBB)), new BitmapTextureResource(new BitmapData(4, 4, false, 0x0000FF) ) );
				testMat.glossiness = 0;
				testMat.specularPower = 0;
			//	mesh.scaleX = mesh.scaleY = 2;
				mesh.addSurface(testMat, 0, mesh.geometry.numTriangles );
			}
			//else {
				var hm:HeightMapInfo = new HeightMapInfo();
				hm.RowWidth = vAcross;
				hm.XSize = vAcross;
				hm.ZSize = vAcross;
				hm.Data = data;
				var normMap:PlanarDispToNormConverter = new PlanarDispToNormConverter();
				
				normMap.heightMap = hm;
				normMap.setAmplitude(1);
				normMap.setDirection("z");
				addChild( normMap.convertToNormalMap() );
				
		//	}
			
			scene.addChild(mesh);
			//var wireframe:WireFrame = WireFrame.createEdges(mesh, 0xFFFFFF, 1, 1);
		//	scene.addChild(wireframe);
		}
		
		
		
		override public function onRenderTick(e:Event):void {
	//	super.onRenderTick(e);
			cameraController.update();
			renderId++;
			camera.render(stage3D);
			//if (terrainLOD) _debugField.text = String( terrainLOD._sampleRect );
		}
		
	}

}