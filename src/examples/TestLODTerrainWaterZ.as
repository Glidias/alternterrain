package examples
{
	import flash.display.Sprite;
	/**
	 * Simple single-page (non-textured) LOD (1024x1024 tiles) terrain with normal map texture, 
	 * 
	 * -with-
	 * 
	 * Water-level fragment shader clipping and forced render priorities with Skybox/water textures. 
	 * This is allows one to keep the current z-buffer.
	 * 
	 * @author Glenn Ko
	 */
	public class TestLODTerrainWaterZ extends Sprite
	{
		
		public function TestLODTerrainWaterZ() 
		{
			addChild( new MyTemplate( root.loaderInfo.url.slice(0, ("http://").length) === "http://" ) );
		}
		
	}
	

}


import alternativa.engine3d.core.Debug;
import alternativa.engine3d.core.Renderer;
import alternativa.engine3d.core.VertexAttributes;
import alternativa.engine3d.lights.OmniLight;
import alternativa.engine3d.lights.SpotLight;
import alternativa.engine3d.materials.FillMaterial;
import alternativa.engine3d.materials.NormalMapSpace;
import alternativa.engine3d.materials.StandardMaterial;
import alternativa.engine3d.materials.StandardTerrainMaterial;
import alternativa.engine3d.materials.TextureMaterial;
import alternativa.engine3d.materials.VertexLightTextureMaterial;
import alternativa.engine3d.objects.Mesh;
import alternativa.engine3d.objects.SkyBox;
import alternativa.engine3d.objects.WireFrame;
import alternativa.engine3d.primitives.Box;
import alternativa.engine3d.primitives.Plane;
import alternativa.engine3d.resources.BitmapTextureResource;
import alternativa.engine3d.resources.Geometry;
import alternterrain.core.*;
import alternterrain.objects.*;
import alternterrain.resources.InstalledQuadTreePages;
import alternterrain.resources.LoadAliases;
import com.nodename.Delaunay.Edge;
import flash.events.IEventDispatcher;

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
	
	private var heightMapTest:HeightMapInfo;
	private var terrainLOD:TerrainLOD;
	private var _loadedPage:QuadTreePage;
	
	private var omniLight:OmniLight;
	
	[Embed(source="assets/myterrain.tre", mimeType="application/octet-stream")]
	private var TERRAIN_DATA:Class;
	
	[Embed(source="assets/myterrain_normal.jpg")]
	private var NORMAL_MAP:Class;
	
	[Embed(source="assets/edgeblend_mist.png")]
	private var EDGE:Class;
	
	private var _normalMapData:BitmapData;
	private var waterLevel:Number;

	
	public function MyTemplate(IS_ONLINE:Boolean=false) {
		super();
		
		var loadAliases:LoadAliases = new LoadAliases();
		settings.cameraSpeed = 600;
		settings.cameraSpeedMultiplier = 16;
		settings.viewBackgroundColor = 0x3BB9FF;

		
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
		
		processDataAsLoadedPage( new TERRAIN_DATA() );
		
	
		addEventListener(VIEW_CREATE, onViewCreate);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onkeyDowN)
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

		
		if (_normalMapData == null) {  	// Create normal map on the fly... (this is processor intensive and restriced to small terrains only...)
			var normalMapper:PlanarDispToNormConverter = new PlanarDispToNormConverter();
			normalMapper.heightMap = _loadedPage.heightMap;
			normalMapper.setDirection("z");
			normalMapper.setAmplitude(1);
			
			var normalMap:Bitmap = normalMapper.convertToNormalMap();
			
			
			//addChild( normalMap );
			_normalMapData = normalMap.bitmapData;
		}
		//_normalMapData.applyFilter(_normalMapData, _normalMapData.rect, new Point(), new BlurFilter(1,1,4) );

		
		//new BitmapTextureResource(new EDGE().bitmapData)
		var standardMaterial:StandardTerrainMaterial = new StandardTerrainMaterial( new BitmapTextureResource(_normalMapData), new BitmapTextureResource( _normalMapData), null, null  );
		standardMaterial.transparentPass = true;
		//standardMaterial.opaquePass = false;
		standardMaterial.alphaThreshold = 1;
		
		//throw new Error([standardMaterial.opaquePass, standardMaterial.alphaThreshold, standardMaterial.transparentPass]);
		//standardMaterial.transparentPass = false;
		standardMaterial.normalMapSpace = NormalMapSpace.OBJECT;
		standardMaterial.specularPower = 0;
		standardMaterial.glossiness = 0;
		standardMaterial.mistMap = new BitmapTextureResource(new EDGE().bitmapData);

		StandardTerrainMaterial.fogMode = 1;
		StandardTerrainMaterial.fogFar = camera.farClipping = 256 * 800;
		StandardTerrainMaterial.fogNear = 256 * 32;
		StandardTerrainMaterial.fogColor = settings.viewBackgroundColor;
		

		terrainLOD.loadSinglePage(stage3D.context3D, _loadedPage, standardMaterial, 256*1024 );  //new FillMaterial(0xFF0000, 1)
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
		
		camera.nearClipping = 16;
	//	camera.farClipping = 900000;
		//camera.debug = true;
		camera.addToDebug(Debug.BOUNDS, terrainLOD);
		camera.addToDebug(Debug.CONTENT, spotlight);

	
		
			waterLevel = -20000;
			standardMaterial.waterLevel = waterLevel;
				
			standardMaterial.waterMode = 1;
						
			var waterMat:StandardTerrainMaterial = new StandardTerrainMaterial( new BitmapTextureResource(new BitmapData(4, 4, false, 0x0000FF)), new BitmapTextureResource(new BitmapData(4, 4, false, 0x0000FF)) );
			waterMat.mistMap = standardMaterial.mistMap;
		
			waterMat.forceRenderPriority = Renderer.SKY + 1;
			/*
				waterMat.opaquePass = false;
			waterMat.transparentPass = true;
			waterMat.alphaThreshold = 2;
			waterMat.alpha = 1;
			*/

			var waterPlane:Plane = new Plane(terrainLOD.boundBox.maxX, terrainLOD.boundBox.maxX, 1, 1, false, false, null,waterMat );
			waterPlane.x = terrainLOD.boundBox.maxX * .5;
			waterPlane.y = -terrainLOD.boundBox.maxX * .5;
			waterPlane.z = waterLevel;
			
			/*
				var skyMat:FillMaterial = new FillMaterial(settings.viewBackgroundColor, 1);
				var skybox:SkyBox = new SkyBox(camera.farClipping,skyMat,skyMat,skyMat,skyMat,skyMat,skyMat);
				scene.addChild(skybox);
			*/
				
			scene.addChild(waterPlane);
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
			directionalLight.rotationX = 2.32;
			camera.render(stage3D);
			//if (terrainLOD) _debugField.text = String( terrainLOD._sampleRect );
		}
	
}
