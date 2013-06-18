package examples
{
	import flash.display.Sprite;
	/**
	 * Simple single-page (tile-atlas textured) LOD (1024x1024 tiles) terrain with normal mapping
	 * and water-level clipping.
	 * 
	 * @author Glenn Ko
	 */
	public class TestLODTerrainTileAtlasWater extends Sprite
	{
		
		public function TestLODTerrainTileAtlasWater() 
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
import alternterrainxtras.materials.LODTileAtlasMaterial;
import alternterrainxtras.materials.TileAtlasMaterial;
import alternterrainxtras.util.Mipmaps;
import alternterrainxtras.util.TextureAtlasData;
import flash.events.IEventDispatcher;
import flash.utils.getTimer;


import alternterrain.util.*;
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
	
	private var terrainLOD:TerrainLOD;
	private var _loadedPage:QuadTreePage;
	
	private var omniLight:OmniLight;
	
	[Embed(source="assets/myterrain.tre", mimeType="application/octet-stream")]
	private var TERRAIN_DATA:Class;
	
	[Embed(source="assets/myterrain_normal.jpg")]
	private var NORMAL_MAP:Class;
	
	[Embed(source = "assets/myterrain_biometiles.data", mimeType = "application/octet-stream")]
	private var TILE_MAP:Class;
	
	[Embed(source="assets/edgeblend_mist.png")]
	private var EDGE:Class;
	
	private var _normalMapData:BitmapData;
	
	private var _atlasLoader:TextureAtlasData;
	private var _atlasBlendLoader:TextureAtlasData;
	private var _tileMap :BitmapData;
	private var mipmaps:Mipmaps;
	private var tileAtlasMaterial:LODTileAtlasMaterial;
	
	
	
	
	
	public function MyTemplate(IS_ONLINE:Boolean=false) {
		super();
		
		var loadAliases:LoadAliases = new LoadAliases();
		settings.cameraSpeed = 600;
		settings.cameraSpeedMultiplier = 16;
		settings.viewBackgroundColor = 0x777777;

		
		_normalMapData = new NORMAL_MAP().bitmapData;
		addEventListener(Event.ADDED_TO_STAGE, addedToStage);
	}
	

	private function onURLLoadDone(e:Event):void 
	{
		var data:ByteArray = (e.currentTarget as URLLoader).data;
		processDataAsLoadedPage(data);
	}
	
	private function processDataAsLoadedPage(data:ByteArray):void 
	{
		data.uncompress();
		
		_loadedPage = new QuadTreePage();
		_loadedPage.readExternal(data);
	
	}
	
	private function addedToStage(e:Event=null):void 
	{
		if (e) (e.currentTarget as IEventDispatcher).removeEventListener(e.type, addedToStage);
		
		
			removeEventListener(Event.ADDED_TO_STAGE, addedToStage);
			
			processDataAsLoadedPage( new TERRAIN_DATA() );
		
		var tileMapData:ByteArray = new TILE_MAP();
		tileMapData.uncompress();
		_tileMap = TextureAtlasData.getTileMap(tileMapData);
		
		
		_atlasLoader = new TextureAtlasData(128, 4, 4,  mipmaps = new Mipmaps());
		_atlasLoader.addEventListener(Event.COMPLETE, onDiffuseAtlasLoadDone);
		_atlasLoader.loadURLsFromChars("dfhqnsrckgi", "assets/tribes/tilesets/lushdml/", "jpg");

		
	}
	
	private function onDiffuseAtlasLoadDone(e:Event):void 
	{
		_atlasBlendLoader = new TextureAtlasData(128, 4, 4,mipmaps, true);
		_atlasBlendLoader.addEventListener(Event.COMPLETE, onAssetsLoaded);
		_atlasBlendLoader.loadURLs([
				"assets/tribes/tilesets/blends/rrrr1.png",
				"assets/tribes/tilesets/blends/rgbb1.png",
				"assets/tribes/tilesets/blends/rggg1.png",
				"assets/tribes/tilesets/blends/rrgg1.png",
				
				"assets/tribes/tilesets/blends/rgbb5.png",
				"assets/tribes/tilesets/blends/rgbb2.png",
				"assets/tribes/tilesets/blends/rggg2.png",
				"assets/tribes/tilesets/blends/rrgg2.png",
				
				"assets/tribes/tilesets/blends/rggg5.png",
				"assets/tribes/tilesets/blends/rgbb3.png",
				"assets/tribes/tilesets/blends/rggg3.png",
				"assets/tribes/tilesets/blends/rrgg3.png",
				
				"assets/tribes/tilesets/blends/rrgg5.png",
				"assets/tribes/tilesets/blends/rgbb4.png",
				"assets/tribes/tilesets/blends/rggg4.png",
				"assets/tribes/tilesets/blends/rrgg4.png"		
		]);
	}
	
	private function onAssetsLoaded(e:Event):void {
		addEventListener(VIEW_CREATE, onViewCreate);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onkeyDowN);
		init();
	}
	
	
	private function onkeyDowN(e:KeyboardEvent):void 
	{
		var code:uint = e.keyCode;
		 if (code === Keyboard.TAB) {
			if (terrainLOD) {
				terrainLOD.debug = !terrainLOD.debug;
			}
		}
	}
	
	
	private function onViewCreate(e:Event):void 
	{

		presetup();
		startRendering();
	}
	

	




	
	private function presetup():void 
	{
		
		camera.z = 32*255;
		//	throw new Error(geom.indices.length + ", "+plane.geometry.indices.length);
		camera.rotationZ = -Math.PI * .8;
		cameraController.updateObjectTransform();
		
		
		terrainLOD = new TerrainLOD();
		terrainLOD.detail = .5;


		
	
		
		//_normalMapData = null;
		if (_normalMapData == null) {  	// Create normal map on the fly... (this is processor intensive and restriced to small terrains only...)
			var normalMapper:PlanarDispToNormConverter = new PlanarDispToNormConverter();
			normalMapper.heightMap = _loadedPage.heightMap;
			normalMapper.setDirection("z");
			normalMapper.setAmplitude(1);
			//normalMapper.heightMapMultiplier = 1/128;
			
			var normalMap:Bitmap = normalMapper.convertToNormalMap();
			
			//addChild( normalMap );
			_normalMapData = normalMap.bitmapData;
		}
		
		//_normalMapData.applyFilter(_normalMapData, _normalMapData.rect, new Point(), new BlurFilter(1,1,4) );

		tileAtlasMaterial = new LODTileAtlasMaterial(new BitmapTextureResource(_atlasLoader.data), 
										new BitmapTextureResource(_atlasBlendLoader.data), 
										 new BitmapTextureResource(mipmaps.getMipmapOffsetTable()), mipmaps.mipmapUVCap, 
										 new <BitmapTextureResource>[new BitmapTextureResource(_tileMap)],
										new <BitmapTextureResource>[new BitmapTextureResource(_normalMapData)],
										new <BitmapTextureResource>[null], 128);
		tileAtlasMaterial.specularPower = 0;
		tileAtlasMaterial.glossiness = 0;
		tileAtlasMaterial.mistMap =  new BitmapTextureResource(new EDGE().bitmapData);
		
		tileAtlasMaterial.waterMode = 1;
		tileAtlasMaterial.waterLevel = -20000;

		//tileAtlasMaterial.alphaThreshold = 1;
		
		//TileAtlasMaterial.fogMode = 1;
		TileAtlasMaterial.fogFar = camera.farClipping = 256 * 800;
		TileAtlasMaterial.fogNear = 128 * 256;
		TileAtlasMaterial.fogColor =  settings.viewBackgroundColor;

		terrainLOD.loadSinglePage(stage3D.context3D, _loadedPage, tileAtlasMaterial );  //new FillMaterial(0xFF0000, 1)
		// )
		//terrainLOD.useLighting = false;

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
		ambientLight.intensity = .2;
		
		directionalLight.x = 0; spotlight.x;
		directionalLight.y = 0; spotlight.y;
		//directionalLight.z = spotlight.z;
		directionalLight.z = terrainLOD.boundBox.maxZ + 1000;
		directionalLight.intensity = .3;
		directionalLight.lookAt(spotlight.x, spotlight.y, 0);
		
		directionalLight.distance = 900000;
		//scene.addChild( new OmniLight(0xFF0000, 1, 2) );
		
		omniLight = new OmniLight(0xCCAA44, 20, 3400);
		omniLight.distance = 1000;
		scene.addChild(omniLight);
		
		//camera.farClipping = 900000;
		//camera.debug = true;
		camera.addToDebug(Debug.BOUNDS, terrainLOD);
		camera.addToDebug(Debug.CONTENT, spotlight);

		scene.addChild(terrainLOD);

	}
	

	private var _baseWaterLevelOscillate:Number = 40;
	private var _baseWaterLevel:Number = -20000 + _baseWaterLevelOscillate;
	private var _waterSpeed:Number = 2.0*.001;
	private var _lastTime:int = -1;
	private var _waterOscValue:Number = 0;
	
	override public function onRenderTick(e:Event):void {
	//	super.onRenderTick(e);
			var curTime:int = getTimer();
			
			
			cameraController.update();
			renderId++;
			if (omniLight) {
				omniLight.x = camera.x;
				omniLight.y = camera.y;
				omniLight.z = camera.z;
			}
			directionalLight.rotationX = 2.32;
			camera.render(stage3D);
			//tileAtlasMaterial.waterLevel
			if (_lastTime < 0) _lastTime = curTime;
			var timeElapsed:int = curTime - _lastTime;
			_lastTime = curTime;
			
			_waterOscValue += timeElapsed * _waterSpeed;
			tileAtlasMaterial.waterLevel = _baseWaterLevel + Math.sin(_waterOscValue) * _baseWaterLevelOscillate;
			
			//if (terrainLOD) _debugField.text = String( terrainLOD._sampleRect );
		}
	
}
