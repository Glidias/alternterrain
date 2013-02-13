package examples
{
	import flash.display.Sprite;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class TestLODTerrain extends Sprite
	{
		
		public function TestLODTerrain() 
		{
			addChild( new MyTemplate( root.loaderInfo.url.slice(0, ("http://").length) === "http://" ) );
		}
		
	}
	

}


import alternativa.engine3d.core.Debug;
import alternativa.engine3d.core.VertexAttributes;
import alternativa.engine3d.lights.OmniLight;
import alternativa.engine3d.lights.SpotLight;
import alternativa.engine3d.materials.FillMaterial;
import alternativa.engine3d.materials.NormalMapSpace;
import alternativa.engine3d.materials.StandardMaterial;
import alternativa.engine3d.materials.TextureMaterial;
import alternativa.engine3d.materials.VertexLightTextureMaterial;
import alternativa.engine3d.objects.Mesh;
import alternativa.engine3d.objects.WireFrame;
import alternativa.engine3d.primitives.Box;
import alternativa.engine3d.resources.BitmapTextureResource;
import alternativa.engine3d.resources.Geometry;
import alternterrain.core.*;
import alternterrain.objects.*;
import alternterrain.resources.InstalledQuadTreePages;
import alternterrain.resources.LoadAliases;
import alternterrain.resources.QuadPageInstaller;
import alternterrain.util.*;
import alternterrainxtras.materials.LODTileAtlasMaterial;
import com.tartiflop.PlanarDispToNormConverter;
import examples.Template;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.filters.BlurFilter;
import flash.geom.Point;
import flash.net.URLLoader;
import flash.net.URLLoaderDataFormat;
import flash.net.URLRequest;
import flash.text.TextField;
import flash.ui.Keyboard;
import flash.utils.ByteArray;
import flash.utils.Endian;
import net.hires.debug.Stats;

import alternativa.engine3d.alternativa3d;
use namespace alternativa3d;


class MyTemplate extends Template {
	
	private var heightMapTest:HeightMapInfo;
	private var terrainLOD:TerrainLOD;
	private var _loadedPage:QuadTreePage;
	
	
	[Embed(source="hmtest2.bin", mimeType="application/octet-stream")]
	public var HM_TEST:Class;
	
	//[Embed(source="pages.data", mimeType="application/octet-stream")]
	public var HM_GRID_TEST:Class;
	

	[Embed(source = "elevation.data", mimeType = "application/octet-stream")]
	public var ELEVATION_BYTES:Class;
	
	
	
	public function MyTemplate(IS_ONLINE:Boolean=false) {
		super();
		
		var loadAliases:LoadAliases = new LoadAliases();
		settings.cameraSpeed = 600;
		settings.cameraSpeedMultiplier = 16;
		settings.viewBackgroundColor = 0x3BB9FF;
		

		
		var gotItem:Boolean = HM_GRID_TEST != null || HM_TEST != null;
		
		if (IS_ONLINE && !gotItem) {
			var urlLoader:URLLoader = new URLLoader( );
			urlLoader.addEventListener(Event.COMPLETE, onURLLoadDone);
			urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
			urlLoader.load( new URLRequest("hmtest.zip"));
		}
		else if (!gotItem) {
			
			addChild( new Stats() );
			var tilesAcross:int = 256;
			//var bitmapData:BitmapData = new BitmapData(tilesAcross+1, tilesAcross+1, false, 0);
			//bitmapData.perlinNoise(256, 256, 8, 211, false, true, 7, true);
	
			
		
			
			var heightMap:HeightMapInfo;
			
			var bytes:ByteArray = new ELEVATION_BYTES();
			tilesAcross = Math.sqrt(bytes.length);
			
			if ( !QuadCornerData.isBase2(tilesAcross)) {
				;
				bytes.uncompress();
				tilesAcross = Math.sqrt(bytes.length);
				if (!QuadCornerData.isBase2(tilesAcross)) throw new Error("Failed to get base2 size of heightmap tiles:!");
			}
			
			heightMap = HeightMapInfo.createFromByteArray(bytes, tilesAcross, 0, 0, 128, 0);

			//heightMap = HeightMapInfo.createFromBmpData( bitmapData, 0, 0, 128, 0);
			heightMap.BoxFilterHeightMap();
			installer = new QuadPageInstaller();
			
			installerField = new TextField();
			installerField.autoSize = "left";
			installerField.x = 144;
			addChild(installerField);
			installer.install(heightMap, 256, 1024, onInstallProgress);
			
			//installer.addEventListener
			return;
			var array:ByteArray = new ByteArray();
			
			
			var tree:QuadTreePage = new QuadTreePage();
			var sample:QuadChunkCornerData = TerrainLOD.installQuadChunkFromHeightmap(heightMap);
			tree.Square = sample.Square;
			tree.requirements  = 0;
			tree.heightMap = heightMap;
			tree.xorg = sample.xorg;
			tree.zorg = sample.zorg;
			tree.Level = sample.Level;
			
	//		var calcNormals:TerrainNormalCalculator = new TerrainNormalCalculator();
	//	calcNormals.initPageInfo(tree);
	//calcNormals.runPageRecursive(tree);
	//throw new Error( tree.normals.getNormalAt(7) );
//throw new Error(tree.normals.Normals);
	
		
			loadAliases.savePage(tree, true, "hmtest1.bin");
			
			
		}
		else if (HM_TEST != null) {
			var bArray:ByteArray = (new HM_TEST() as ByteArray);
			bArray.uncompress();
			 var page:QuadTreePage = bArray.readObject();
			 _loadedPage = page;
		
				addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		}
		else if (HM_GRID_TEST != null) {
			bArray = (new HM_GRID_TEST() as ByteArray);
			bArray.uncompress();
			_installedPages = new InstalledQuadTreePages();
			
			_installedPages.readExternal(bArray);
			//throw new Error(_installedPages.heightMap.Data);

				addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		}
		
		
	}
	
	private function onInstallProgress():void 
	{
		installerField.text = installer.serialList.position + " / " + installer.serialList.numCommands;
	}
	
	private function onURLLoadDone(e:Event):void 
	{
		var data:ByteArray = (e.currentTarget as URLLoader).data;
		data.uncompress();
		_loadedPage = data.readObject();
		addedToStage();
	}
	
	private function addedToStage(e:Event=null):void 
	{
		removeEventListener(Event.ADDED_TO_STAGE, addedToStage);
		addEventListener(VIEW_CREATE, onViewCreate);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onkeyDowN);
		
		init();
	}
	
	private function onkeyDowN(e:KeyboardEvent):void 
	{
		var code:uint = e.keyCode;
		if (code === Keyboard.F11) {
			save();
		}
		else if (code === Keyboard.TAB) {
			if (terrainLOD) {
				terrainLOD.debug = !terrainLOD.debug;
			}
		}
	}
	
	private function save():void 
	{
			var load:LoadAliases = new LoadAliases();
			load.savePage(terrainLOD.tree, true,  "hmtest.bin");
	}
	
	private function onViewCreate(e:Event):void 
	{

		if (_installedPages != null) presetup_installedPages();
		else presetup();
		
		//testsetup();
		//testsetup2();
		//testsetup3();
		startRendering();
	}
	

	


	
	
	
	
	//[Embed(source="../../../bin/simpletest/texture0.jpg")]
	[Embed(source="GROUND.jpg")]
	private static var TEXTURE:Class;
	private var omniLight:OmniLight;
	private var installer:QuadPageInstaller;
	private var installerField:TextField;
	private var _installedPages:InstalledQuadTreePages;
	
	private function presetup_installedPages():void {
		camera.z = 32*255;
		//	throw new Error(geom.indices.length + ", "+plane.geometry.indices.length);
		camera.rotationZ = -Math.PI * .8;
		cameraController.updateObjectTransform();
		
		
		terrainLOD = new TerrainLOD();
		terrainLOD.detail = 4;
		//_loadedPage.heightMap.BoxFilterHeightMap();
		var textureBmpData:BitmapData = TEXTURE == null ? new BitmapData(2, 2, false, 0x808080) :  new TEXTURE().bitmapData;
		var textureMat:TextureMaterial = new TextureMaterial( new BitmapTextureResource(textureBmpData)  );
		
		terrainLOD.loadGridOfPages(stage3D.context3D, _installedPages.pageGrid, textureMat, 256 );
		camera.farClipping = 256 * 1024;// 900000;
		camera.debug = true;
		camera.addToDebug(Debug.BOUNDS, terrainLOD);


		scene.addChild(terrainLOD);
	}
	
	
	private function presetup():void 
	{
		
		camera.z = 32*255;
		//	throw new Error(geom.indices.length + ", "+plane.geometry.indices.length);
		camera.rotationZ = -Math.PI * .8;
		cameraController.updateObjectTransform();
		
		
		terrainLOD = new TerrainLOD();
		terrainLOD.detail = 4;
		//_loadedPage.heightMap.BoxFilterHeightMap();
		var textureBmpData:BitmapData = TEXTURE == null ? new BitmapData(2, 2, false, 0x808080) :  new TEXTURE().bitmapData;
		var textureMat:TextureMaterial = new TextureMaterial( new BitmapTextureResource(textureBmpData)  );
		
		_loadedPage.heightMap.BoxFilterHeightMap();
		
		var normalMapper:PlanarDispToNormConverter = new PlanarDispToNormConverter();
		normalMapper.heightMap = _loadedPage.heightMap;
		//_loadedPage.heightMap.reset();
		normalMapper.setDirection("z");
		normalMapper.heightMapMultiplier = 1 / 128;
		normalMapper.setAmplitude(1);
		
		//normalMapper.scale = 1;
		var normalMap:Bitmap = normalMapper.convertToNormalMap();
		normalMap.bitmapData.applyFilter(normalMap.bitmapData, normalMap.bitmapData.rect, new Point(), new BlurFilter(3,3,4) );
		//addChild( normalMap );
		
		
		var tileAtlasMaterial:LODTileAtlasMaterial;
		var standardMaterial:StandardMaterial = new StandardMaterial( new BitmapTextureResource(normalMap.bitmapData), new BitmapTextureResource( normalMap.bitmapData) );
		
		standardMaterial.normalMapSpace = NormalMapSpace.OBJECT;
		standardMaterial.specularPower = 0;
		
		//standardMaterial.glossiness = 0;
		
		var vertexLightMat:VertexLightTextureMaterial = new VertexLightTextureMaterial( new BitmapTextureResource(textureBmpData) );
		var textureMAt:TextureMaterial = new TextureMaterial(new BitmapTextureResource(textureBmpData));

		terrainLOD.loadSinglePage(stage3D.context3D, _loadedPage, standardMaterial, 256*1024 );  //new FillMaterial(0xFF0000, 1)
		// )
		terrainLOD.useLighting = false;
		

		var spotlight:SpotLight = new SpotLight(0xFF0000, .3, 1, 1, .4);
		spotlight.x = terrainLOD.boundBox.minX + (terrainLOD.boundBox.maxX - terrainLOD.boundBox.minX) * .5;
		spotlight.y = terrainLOD.boundBox.minY + (terrainLOD.boundBox.maxY - terrainLOD.boundBox.minY) * .5;
		spotlight.z = terrainLOD.tree.heightMap.Sample(spotlight.x, -spotlight.y) + 128;
		spotlight.lookAt(spotlight.x, spotlight.y, 0);
		spotlight.distance = 999999;
		//scene.addChild(spotlight);
		
		//ambientLight.x = spotlight.x;
		///ambientLight.y = spotlight.y;
		//ambientLight.z = spotlight.z;
		ambientLight.intensity = .4;
		
		directionalLight.x = 0; spotlight.x;
		directionalLight.y = 0; spotlight.y;
		//directionalLight.z = spotlight.z;
		directionalLight.z = terrainLOD.boundBox.maxZ + 1000;
		directionalLight.lookAt(spotlight.x, spotlight.y, 0);
		
		directionalLight.distance = 900000;
		//scene.addChild( new OmniLight(0xFF0000, 1, 2) );
		
		omniLight = new OmniLight(0xCCAA44, 20, 3400);
		omniLight.distance = 1000;
		scene.addChild(omniLight);
		
		camera.farClipping = 900000;
		camera.debug = true;
		camera.addToDebug(Debug.BOUNDS, terrainLOD);
		camera.addToDebug(Debug.CONTENT, spotlight);

		scene.addChild(terrainLOD);


	}
	
	override public function onRenderTick(e:Event):void {
	//	super.onRenderTick(e);
			cameraController.update();
			renderId++;
			if (omniLight) {
				omniLight.x = camera.x;
				omniLight.y = camera.y;
				omniLight.z = camera.z;
			}
			directionalLight.rotationX+=.02;
			camera.render(stage3D);
			//if (terrainLOD) _debugField.text = String( terrainLOD._sampleRect );
		}
	
}
