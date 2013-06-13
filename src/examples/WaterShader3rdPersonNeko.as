package examples
{
	import alternativa.engine3d.controller.OrbitCameraController;
	import alternativa.engine3d.controller.OrbitCameraMan;
	import alternativa.engine3d.controllers.SimpleObjectController;
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.RayIntersectionData;
	import alternativa.engine3d.core.Renderer;
	import alternativa.engine3d.core.Resource;
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.core.View;
	import alternativa.engine3d.lights.AmbientLight;
	import alternativa.engine3d.lights.DirectionalLight;
	import alternativa.engine3d.loaders.ParserCollada;
	import alternativa.engine3d.materials.FillMaterial;
	import alternativa.engine3d.materials.Material;
	import alternativa.engine3d.materials.NormalMapSpace;
	import alternativa.engine3d.materials.StandardTerrainMaterial2;
	import alternativa.engine3d.materials.TextureZClipMaterial;
	import alternativa.engine3d.materials.TextureMaterial;
	import alternativa.engine3d.objects.Mesh;
	import alternativa.engine3d.objects.SkyBox;
	import alternativa.engine3d.primitives.Box;
	import alternativa.engine3d.primitives.Plane;
	import alternativa.engine3d.resources.BitmapTextureResource;
	import alternterrain.core.QuadTreePage;
	import alternterrain.objects.TerrainLOD;
	import alternterrain.resources.LoadAliases;
	import com.bit101.components.CheckBox;
	import eu.nekobit.alternativa3d.materials.WaterMaterial;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.events.KeyboardEvent;
	import flash.geom.Vector3D;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import com.bit101.components.HSlider;
	import com.bit101.components.InputText;
	import com.bit101.components.Style;
	import com.bit101.components.Window;
	import com.bit101.utils.MinimalConfigurator;
	
	import flash.display.Sprite;
	import flash.display.Stage3D;
	import flash.display.StageAlign;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.display3D.Context3DRenderMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import alternativa.engine3d.alternativa3d;
	use namespace alternativa3d;
	
	/**
	 * Integrating LOD terrain with water.
	 * 
	 * @author Varnius  http://nekobit.puslapiai.lt/water-material-for-alternativa3d/
	 * @author Glidias	LOD terrain on water
	 */
	[SWF(width="1100", height="600", frameRate="60")]
	public class WaterShader3rdPersonNeko extends Sprite
	{
		public var scene:Object3D = new Object3D();
		private var stage3D:Stage3D;
		private var camera:Camera3D;
		private var controller:SimpleObjectController;
		
		public var raycastImpl:RaycastImpl;
		
		// Embeds
		
		[Embed(source="assets/water/sand.png")]
		static private const Ground:Class;
		
		[Embed(source="assets/water/plated-metal.png")]
		static private const PlatedMetal:Class;
		
		[Embed("assets/water/teapot.DAE", mimeType="application/octet-stream")]
		static private const Teapot:Class;		
		
		[Embed(source="assets/water/normal1.png")]
		static private const Normal1:Class;
		
		// Skybox
		
		private var sb:SkyBox;
		[Embed(source="assets/water/skybox/top.png")]
		static private const SBTop:Class;
		[Embed(source="assets/water/skybox/bottom.png")]
		static private const SBBottom:Class;
		[Embed(source="assets/water/skybox/front.png")]
		static private const SBFront:Class;
		[Embed(source="assets/water/skybox/back.png")]
		static private const SBBack:Class;
		[Embed(source="assets/water/skybox/left.png")]
		static private const SBLeft:Class;
		[Embed(source="assets/water/skybox/right.png")]
		static private const SBRight:Class;
		
		static public const START_LOD:Number = 1;
		
		private var _normalMapData:BitmapData;
		private var settings:TemplateSettings = new TemplateSettings();
		
		
		[Embed(source="assets/myterrain.tre", mimeType="application/octet-stream")]
		private var TERRAIN_DATA:Class;
		
		[Embed(source="assets/myterrain_normal.jpg")]
		private var NORMAL_MAP:Class;
		
		[Embed(source="assets/edgeblend_mist.png")]
		private var EDGE:Class;
		
		private var crosshair:DisplayObject;
		
		public function WaterShader3rdPersonNeko()
		{
			addEventListener(Event.ADDED_TO_STAGE, addedInit);
			OrbitCameraController;
			OrbitCameraMan;
		}
		
		private function addedInit(e:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, addedInit);
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			var loadAliases:LoadAliases = new LoadAliases();
			settings.cameraSpeed = 2100;
			settings.cameraSpeedMultiplier = 14;
			settings.viewBackgroundColor = 0x86a1b8;

			
			_normalMapData = new NORMAL_MAP().bitmapData;

			processDataAsLoadedPage( new TERRAIN_DATA() );
			
			stage3D = stage.stage3Ds[0];
			stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreated);
			stage3D.requestContext3D(Context3DRenderMode.AUTO);
			
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			
			crosshair = new CrossHair();
			crosshair.x = stage.stageWidth * .5;
			crosshair.y = stage.stageHeight * .5;
			addEventListener(Event.RESIZE, onStageResize);
			
			tileTrace = new Box(16, 16, 3344, 1, 1, 1, false, new FillMaterial(0xFFFF00, .4) );
			

		}
		
		private function onStageResize(e:Event):void 
		{
			crosshair.x = stage.stageWidth * .5;
			crosshair.y = stage.stageHeight * .5;
		}
		
		private function onKeyDown(e:KeyboardEvent):void 
		{
			if (e.keyCode === Keyboard.F) {
				
				var origin:Vector3D = new Vector3D();
				var direction:Vector3D = new Vector3D();
				camera.calculateRay(origin, direction, camera.view.width * .5, camera.view.height * .5);
		
		
				var data:RayIntersectionData = raycastImpl.intersectRay(origin, direction);
				
				if (data != null) {
					data.point = data.object.localToGlobal(data.point);
					obstacle.x = data.point.x //+ 200;
					obstacle.y = data.point.y //+ 200;
					obstacle.z = data.point.z //- 200;
					obstacleMat.color = data.time != 0 ? 0xFF0000 : 0x0000FF;
				}
				else {	
					obstacle.x = origin.x + direction.x*1512;
					obstacle.y = origin.y + direction.y*1512;
					obstacle.z =origin.z + direction.z*1512;
					obstacleMat.color = 0xFFFFFF;
				}
			}
			else if (e.keyCode === Keyboard.TAB) {
				terrainLOD.debug = !terrainLOD.debug;
			}
			else if (e.keyCode === Keyboard.B) {
				
				for each(var item:Object3D in _traceTiles) {
					scene.removeChild(item);
				}
				
				_traceTiles.length = 0;
			}
		}
		
		private function traceRayPoints():void 
		{
			/*
			for (var i:int = 0; i < terrainLOD.tracedTiles.length; i++) {
						var tile:Object3D = tileTrace.clone();
						_traceTiles.push(tile);
						var pos:Vector3D = terrainLOD.localToGlobal( new Vector3D(terrainLOD.tracedTiles[i].x, terrainLOD.tracedTiles[i].y, terrainLOD.tracedTiles[i].z) );
						tile.x = pos.x;
						tile.y = pos.y;
						tile.z = pos.z;
						//uploadResources(tile.getResources());
						scene.addChild(tile);
					}
					*/
		}
		
		private function traceTiles():void {
			
		}
		
			private function processDataAsLoadedPage(data:ByteArray):void 
	{
		data.uncompress();
		
		_loadedPage = new QuadTreePage();
		_loadedPage.readExternal(data);
	
	}
		
		private var waterLevel:Number =  -20000;
		public var reflectClipOffset:Number = 0;
				
		private function onContext3DCreated(e:Event):void			
		{
			// Container
			
			// Camera
			camera = new Camera3D(1, 256*1024);
			camera.x = -315*256;
			camera.y = -315*256;
			camera.z = waterLevel + 66400;
			camera.rotationX = -1.595;
			camera.rotationZ = -0.6816;
			camera.view = new View(stage.stageWidth, stage.stageHeight);
			camera.view.antiAlias = 4;
			camera.diagramAlign = "left";
			camera.diagramHorizontalMargin = 5;
			camera.diagramVerticalMargin = 5;
			addChild(camera.view);
			addChild(camera.diagram);
			camera.view.hideLogo();			
			scene.addChild(camera);
			addChild(crosshair);
			
			uploadResources( tileTrace.getResources() );
			
			// Controller
			controller = new SimpleObjectController(stage, teapotContainer, settings.cameraSpeed, settings.cameraSpeedMultiplier);
			//controller.unbindAll();
			controller.mouseSensitivity = 0;
			//controller.
			controller.stopMouseLook();
			
			// Skybox
			// create skybox textures
			var topres:BitmapTextureResource = new BitmapTextureResource(new SBTop().bitmapData);			
			var top:TextureMaterial = new TextureMaterial(topres);
			var bottomres:BitmapTextureResource = new BitmapTextureResource(new SBBottom().bitmapData);
			var bottom:TextureMaterial = new TextureMaterial(bottomres);
			var frontres:BitmapTextureResource = new BitmapTextureResource(new SBFront().bitmapData);
			var front:TextureMaterial = new TextureMaterial(frontres);
			var backres:BitmapTextureResource = new BitmapTextureResource(new SBBack().bitmapData);
			var back:TextureMaterial = new TextureMaterial(backres);
			var leftres:BitmapTextureResource = new BitmapTextureResource(new SBLeft().bitmapData);
			var left:TextureMaterial = new TextureMaterial(leftres);
			var rightres:BitmapTextureResource = new BitmapTextureResource(new SBRight().bitmapData);
			var right:TextureMaterial = new TextureMaterial(rightres);			
			topres.upload(stage3D.context3D);
			bottomres.upload(stage3D.context3D);
			leftres.upload(stage3D.context3D);
			rightres.upload(stage3D.context3D);
			frontres.upload(stage3D.context3D);
			backres.upload(stage3D.context3D);		
			var fogMat:FillMaterial = new FillMaterial(settings.viewBackgroundColor);
			sb = new SkyBox(camera.farClipping*10,fogMat,fogMat,fogMat,fogMat, fogMat,fogMat,0.005);  //left,right,front,back,bottom,top
			sb.geometry.upload(stage3D.context3D);
			scene.addChild(sb);
			
			var groundTextureResource:BitmapTextureResource = new BitmapTextureResource(new Ground().bitmapData);
			var ground:TextureMaterial = new TextureMaterial(groundTextureResource);
			var uvs:Vector.<Number> = new <Number>[
				0,30,0,0,30,30,30,0 
			];
			
			// Reflective plane
			var normalRes:BitmapTextureResource = new BitmapTextureResource(new Normal1().bitmapData);
			waterMaterial = new WaterMaterial(normalRes, normalRes);
			plane = new Plane(1024*256, 1024*256, 1, 1, false, false, null, waterMaterial);
			plane.geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], uvs);			
			plane.z = waterLevel;
			uploadResources(plane.getResources());
			scene.addChild(plane);			
			waterMaterial.forceRenderPriority = Renderer.SKY + 1;
			
			// Underwater plane with ground texture
			/*
			underwaterPlane = new Plane(80000, 80000, 1, 1, false, false, null, ground);
			underwaterPlane.z = -1000;
			underwaterPlane.geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], uvs);
			uploadResources(underwaterPlane.getResources());
			scene.addChild(underwaterPlane);
			hideFromReflection.push(underwaterPlane);
			*/
			
			  //Lightを追加
           var  ambientLight:AmbientLight = new AmbientLight(0xFFFFFF);
            ambientLight.intensity = 0.4;
            scene.addChild(ambientLight);
            
            //Lightを追加
           var  directionalLight:DirectionalLight = new DirectionalLight(0xFFFFFF);
            //手前右上から中央へ向けた指向性light
            directionalLight.x = 100;
            directionalLight.y = -100;
            directionalLight.z = 100;
            directionalLight.lookAt(0, 0, 0);
			directionalLight.intensity = .7;
            scene.addChild(directionalLight);
			
			
			// TerrainLOD
			terrainLOD = new TerrainLOD();
			terrainLOD.setUpdateRadius(512);
			//terrainLOD.debug = true;
			terrainLOD.detail = START_LOD;
			terrainLOD.waterLevel = waterLevel;
			raycastImpl = new RaycastImpl(terrainLOD);
			
			standardMaterial = new StandardTerrainMaterial2(groundTextureResource , new BitmapTextureResource( _normalMapData), null, null  );
			standardMaterial.uvMultiplier2 = 1 / 1;
			//throw new Error([standardMaterial.opaquePass, standardMaterial.alphaThreshold, standardMaterial.transparentPass]);
			//standardMaterial.transparentPass = false;
			standardMaterial.normalMapSpace = NormalMapSpace.OBJECT;
			standardMaterial.specularPower = 0;
			standardMaterial.glossiness = 0;
			//standardMaterial.mistMap = new BitmapTextureResource(new EDGE().bitmapData);
			StandardTerrainMaterial2.fogMode = 0;
			StandardTerrainMaterial2.fogFar =  256 * 800;
			StandardTerrainMaterial2.fogNear = 256 * 32;
			StandardTerrainMaterial2.fogColor = settings.viewBackgroundColor;
			standardMaterial.waterLevel = waterLevel;
			standardMaterial.waterMode = 1;
			//standardMaterial.tileSize = 512;
			standardMaterial.pageSize = _loadedPage.heightMap.RowWidth - 1;
		

			terrainLOD.loadSinglePage(stage3D.context3D, _loadedPage, standardMaterial);  //new FillMaterial(0xFF0000, 1)
			var hWidth:Number = terrainLOD.boundBox.maxX * .5;
			terrainLOD.x -= hWidth;
			terrainLOD.y += hWidth;

		uploadResources(terrainLOD.getResources());
			scene.addChild(terrainLOD);
			//	hideFromReflection.push(terrainLOD);
			

		// Move camera to a position on terrain
		camera.z = _loadedPage.heightMap.Sample(camera.x - terrainLOD.x, -(camera.y - terrainLOD.y)) ;
		if (camera.z < waterLevel) camera.z = waterLevel;
		camera.z += 100;	
		controller.updateObjectTransform();
		
		
		
			
			
			// Teapot	 (there's a problem with including teapot in the scene). DOesn't work with other objects!
			////*
			scene.addChild(teapotContainer);
			var parser:ParserCollada = new ParserCollada();
			parser.parse(XML(new Teapot()));
			teapot = parser.getObjectByName("static_teapot") as Mesh;
			teapotContainer.x = camera.x;
			teapotContainer.z = camera.z;
			teapotContainer.y = camera.y;
		//	teapot.x = 1500;
		//	teapot.z = -500;
		var res:BitmapTextureResource = new BitmapTextureResource(new PlatedMetal().bitmapData);
			teapotMaterial = new TextureZClipMaterial(res);
			teapotMaterial.alphaThreshold = .9;
			teapot.setMaterialToAllSurfaces(currentTeapotMaterial=teapotMaterial );//new TextureMaterial(res) 			currentTeapotMaterial.alphaThreshold = .3;
			teapotMaterial.waterLevel = waterLevel;
			uploadResources(teapot.getResources());
			teapotContainer.addChild(teapot);
			teapot.boundBox = null;
			teapotContainer.boundBox = null;

			//*/
		//	scene.removeChild(terrainLOD);
			// Uncomment and see how this affects rendered reflection
			///*
			 obstacle = new Box(400,400,400,1,1,1,false, obstacleMat = new FillMaterial(0xFF000F, .5));
			obstacle.x = terrainLOD.x + terrainLOD.boundBox.minX; 
			obstacle.y = terrainLOD.y + terrainLOD.boundBox.minY;
			obstacle.z = waterLevel;
			
			uploadResources(obstacle.getResources());		
			scene.addChild(obstacle);
			
			//*/
			
			// GUI
			createGUI();			
						
			 // -- Player-Specific stuff for Client	 
			 // TODO: look at object could be higher!
            thirdPerson = new OrbitCameraMan(camera, teapotContainer, stage, raycastImpl, null, true); 
            //thirdPerson.controller.easingSeparator  = 12;
            thirdPerson.preferedZoom = 3500;
            thirdPerson.controller.minDistance = 40;
			thirdPerson.preferedMinDistance = 550;
			thirdPerson.fadeDistance = thirdPerson.preferedMinDistance-1;
			thirdPerson.minFadeAlpha = 0;
            thirdPerson.controller.maxDistance =8000;
            //thirdPerson.controller.minAngleLatitude = 5;  // LEFT HANDED SYSTEM with thumb being latitude
            thirdPerson.controller.minAngleLatitude = -85;  // pitch up
            thirdPerson.controller.maxAngleLatidude = 75;  // pitch down
            thirdPerson.followAzimuth = true;
		
			thirdPerson.alphaSetter = currentTeapotMaterial;
            thirdPerson.useFadeDistance = true;
            thirdPerson.maxFadeAlpha = 1;
			
			// Render loop
			stage.addEventListener(Event.ENTER_FRAME, think);
			stage.addEventListener(Event.RESIZE, onResize);

			
		}
		
		private function onResize(e:Event):void
		{
			camera.view.width = stage.stageWidth;
			camera.view.height = stage.stageHeight;
			
			if(optionsWindow)
				optionsWindow.x = stage.stageWidth - optionsWindow.width - 5;
		}
		
		private var waterMaterial:WaterMaterial;
		private var plane:Plane;
		private var teapot:Mesh;
		private var underwaterPlane:Plane;
		private var teapotContainer:Object3D = new Object3D();
		
		// todo: some custom culling method to make up for absence of clipping planes?
		private var hideFromReflection:Vector.<Object3D> = new Vector.<Object3D>();
		
		public var _baseWaterLevelOscillate:Number =  80;
		public var _baseWaterLevel:Number = waterLevel;// -20000 + _baseWaterLevelOscillate;
		public var _waterSpeed:Number = 0;// 2.0 * .001;
		public var clipReflection:Boolean = true;
		public var teapotMaterial:TextureZClipMaterial;
		private var _lastTime:int = -1;
		private var _waterOscValue:Number = 0;
	
		private function think(e:Event):void
		{
			var curTime:int = getTimer();
			
			
			//optionsWindow.title = String(new Vector3D(camera.x, camera.y, camera.z));
			
			camera.startTimer();	
			
			controller.update();
			var object:Object3D = controller.object;
			if (object._x  < terrainLOD._x + terrainLOD.boundBox.minX) {
				object.x = terrainLOD._x + terrainLOD.boundBox.minX;
			}
			else if (object._x  > terrainLOD._x + terrainLOD.boundBox.maxX) {
				object.x = terrainLOD._x + terrainLOD.boundBox.maxX;
			}
			if (object._y  < terrainLOD._y + terrainLOD.boundBox.minY) {
				object.y = terrainLOD._y + terrainLOD.boundBox.minY;
			}
			else if (object._y  > terrainLOD._y + terrainLOD.boundBox.maxY) {
				object.y = terrainLOD._y + terrainLOD.boundBox.maxY;
			}
			
			var xPos:int = int(object._x - terrainLOD._x);
			var yPos:int = int( -object._y + terrainLOD._y);
			
			var hLimit:Number = _loadedPage.heightMap.Sample(xPos, yPos);
			if (hLimit < waterLevel) {
				hLimit = waterLevel;
				hLimit -= 144 + 50;
			}
			hLimit += 144;
			//if (object.z < hLimit) {
				object._z = hLimit;		
				controller.updateObjectTransform();
			//}
			
			
			 thirdPerson.update();
			//teapot.rotationZ -= 0.02;
			
			//teapotContainer.rotationZ = camera.rotationZ + .5* Math.PI;
				//teapotContainer.x = camera.x;
		//	teapotContainer.z = camera.z;
		//	teapotContainer.y = camera.y;
			
			
				if (_lastTime < 0) _lastTime = curTime;
			var timeElapsed:int = curTime - _lastTime;
	
			_waterOscValue += timeElapsed * _waterSpeed;
			
			 waterLevel = _baseWaterLevel + Math.sin(_waterOscValue) * (_waterSpeed != 0 ? _baseWaterLevelOscillate : 0);
			
			var waterLocalPos:Vector3D = teapot.globalToLocal(new Vector3D(0, 0, waterLevel));
			 teapotMaterial.waterLevel =  waterLocalPos.z - reflectClipOffset; 
			plane.z = waterLevel;
			
			standardMaterial.waterLevel = waterLevel - reflectClipOffset;
			terrainLOD.waterLevel = waterLevel - reflectClipOffset;
			
	
			//standardMaterial.waterLevel = terrainLOD.waterLevel = waterLevel - perturbReflectiveBy.value * 200;
			waterMaterial.update(stage3D, camera, plane, hideFromReflection);
			camera.stopTimer();
			
			// Update teapot rotation		
			///*
		//	teapotContainer.rotationZ = 0.5;
	
			//*/
	
			
			 teapotMaterial.waterLevel =  waterLocalPos.z; 
			standardMaterial.waterLevel  = waterLevel;
			terrainLOD.waterLevel = waterLevel;
			

			camera.render(stage3D);
			
				_lastTime = curTime;
		
		}
		

	
		public function onReflectClipOffsetChange(e:Event):void {
			reflectClipOffset = (e.currentTarget).value;
		}
		public function onTerrainLODChange(e:Event):void {
			terrainLOD.detail = (e.currentTarget).value;
		}
		
		public function onWaterLevelChange(e:Event):void {
			_baseWaterLevel = (e.currentTarget).value;
			
		}
		public function onWaterSpeedChange(e:Event):void {
			_waterSpeed = (e.currentTarget).value / 1000;
			
		}
		public function onWaterAmpChange(e:Event):void {
			_baseWaterLevelOscillate = (e.currentTarget).value;
			
		}
		private function uploadResources(resources:Vector.<Resource>):void
		{
			for each(var res:Resource in resources)
			{
				if(!res.isUploaded)
				{
					res.upload(stage3D.context3D);
				}				
			}
		}
		
		/*---------------------
		GUI
		---------------------*/
		
		private var guiContainer:Sprite = new Sprite();
		private var  view:XML =
			<comps>			
				<!-- Console -->
				<Window id="options" title="Options (TAB-toggle debugview, F-cast ray test, MouseWheel-adjust zoom)" x="695" y="5" width="400" height="320" draggable="true" hasMinimizeButton="true">
					<VBox left="15" right="15" top="50" bottom="15" spacing="15">
						<HBox bottom="5" left="5" right="5">
							<Label text="Water tint color RGB:" />
							<InputText id="waterColorR" />
							<InputText id="waterColorG" />
							<InputText id="waterColorB" />
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water tint amount:" />
							<HSlider id="tintSlider" minimum="0.0" maximum="1.0" event="change:onTintChange"/>
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water Fresnel multiplier:" />
							<HSlider id="fresnelSlider" minimum="0.0" maximum="1.0" event="change:onFresnelCoefChange"/>
							<CheckBox label="Show teapot" selected="true" event="change:onTeapotVisChange" />
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water Reflection (fresnel -1) multiplier:" />
							<HSlider id="reflectionMultiplierSlider" minimum="0.0" maximum="1.0" event="change:onFresnelCoefChange"/>
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water Perturb reflection:" />
							<HSlider id="perturbReflectiveSlider" minimum="0.0" maximum="0.5" event="change:onPerturbChange"/>
							<Label text="Clip offset:" />
							<HSlider id="Reflect clip offset" value={reflectClipOffset} minimum="0" maximum="800" event="change:onReflectClipOffsetChange"/>
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water Perturb refraction by:" />
							<HSlider id="perturbRefractiveSlider" minimum="0.0" maximum="0.5" event="change:onPerturbChange"/>
						</HBox>
						<HBox bottom="0" left="5" right="5" alignment="middle">
							<Label text="Tide Speed/Amplitude" />
							<HSlider id="waterSpeed" value={_waterSpeed*1000} minimum="0" maximum="5" event="change:onWaterSpeedChange"/>
							<HSlider id="waterAmp" value={_baseWaterLevelOscillate} minimum="0" maximum="256" event="change:onWaterAmpChange"/>
						</HBox>
						<HBox bottom="5" left="5" right="5" alignment="middle">
							<Label text="Water Level / Terrain LOD" />
							<HSlider id="waterLevel" value={_baseWaterLevel} minimum="-20000" maximum="0" event="change:onWaterLevelChange"/>
							<HSlider id="terrainLOD" value={START_LOD} minimum={START_LOD} maximum="30" event="change:onTerrainLODChange"/>
						</HBox>
						
						<PushButton label="Enter full screen" event="click:onFSButtonClicked"/>
					</VBox>
				</Window>
			</comps>;
		
		private var waterColorR:InputText;
		private var waterColorG:InputText;
		private var waterColorB:InputText;
		private var fresnelSlider:HSlider;
		private var reflectionMultiplierSlider:HSlider;
		private var perturbReflectiveBy:HSlider;
		private var perturbRefractiveBy:HSlider;
		private var tintAmount:HSlider;
		private var optionsWindow:Window;		
		private var _loadedPage:QuadTreePage;
		private var standardMaterial:StandardTerrainMaterial2;
		private var terrainLOD:TerrainLOD;
		private var obstacle:Box;
		private var obstacleMat:FillMaterial;
		private var tileTrace:Box;
		private var _traceTiles:Vector.<Object3D> = new Vector.<Object3D>();
		private var thirdPerson:OrbitCameraMan;
		private var currentTeapotMaterial:Material;


		
		private function createGUI():void
		{		
			// Style
			Style.setStyle(Style.DARK);
			
			stage.addChild(guiContainer);
			guiContainer.addEventListener(MouseEvent.MOUSE_DOWN, stopPropagation);
			var minco:MinimalConfigurator = new MinimalConfigurator(this);
			minco.parseXML(view);
			
			
			// Get refs
			waterColorR = (minco.getCompById("waterColorR") as InputText);
			waterColorG = (minco.getCompById("waterColorG") as InputText);
			waterColorB = (minco.getCompById("waterColorB") as InputText);
			fresnelSlider = (minco.getCompById("fresnelSlider") as HSlider);
			reflectionMultiplierSlider = (minco.getCompById("reflectionMultiplierSlider") as HSlider);			
			perturbReflectiveBy = (minco.getCompById("perturbReflectiveSlider") as HSlider);
			perturbRefractiveBy = (minco.getCompById("perturbRefractiveSlider") as HSlider);
			tintAmount = (minco.getCompById("tintSlider") as HSlider);
			optionsWindow = (minco.getCompById("options") as Window);
			guiContainer.addChild(optionsWindow);
			
			// Set defaults
			waterColorR.text = String(waterMaterial.waterColorR);
			waterColorG.text = String(waterMaterial.waterColorG);
			waterColorB.text = String(waterMaterial.waterColorB);
			fresnelSlider.value = waterMaterial.fresnelMultiplier;
			reflectionMultiplierSlider.value = waterMaterial.reflectionMultiplier;
			perturbReflectiveBy.value = waterMaterial.perturbReflectiveBy;
			perturbRefractiveBy.value = waterMaterial.perturbRefractiveBy;
			tintAmount.value = waterMaterial.waterTintAmount;
			
			// Add change listeners for tfs
			waterColorR.addEventListener(Event.CHANGE, onWaterColorChange);
			waterColorG.addEventListener(Event.CHANGE, onWaterColorChange);
			waterColorB.addEventListener(Event.CHANGE, onWaterColorChange);
		}
		
		private function stopPropagation(e:MouseEvent):void 
		{
			e.stopPropagation();
		}
		
		/*---------------------
		GUI event handlers
		---------------------*/
		
		public function onWaterColorChange(e:Event):void
		{
			waterMaterial.waterColorR = parseFloat(waterColorR.text);
			waterMaterial.waterColorG = parseFloat(waterColorG.text);
			waterMaterial.waterColorB = parseFloat(waterColorB.text);
		}
		
		public function onTeapotVisChange(e:Event):void {
			teapot.visible = (e.currentTarget as CheckBox).selected;
		}
		
		public function onFresnelCoefChange(e:Event):void
		{
			waterMaterial.fresnelMultiplier = fresnelSlider.value;
			waterMaterial.reflectionMultiplier = reflectionMultiplierSlider.value;
		}	
		
		public function onPerturbChange(e:Event):void
		{
			waterMaterial.perturbReflectiveBy = perturbReflectiveBy.value;
			waterMaterial.perturbRefractiveBy = perturbRefractiveBy.value;
		}
		
		public function onTintChange(e:Event):void
		{
			waterMaterial.waterTintAmount = tintAmount.value;
		}
		
		public function onFSButtonClicked(e:Event):void
		{
			stage.displayState = StageDisplayState.FULL_SCREEN;			
		}
	}
}
import alternativa.engine3d.core.Object3D;
import alternativa.engine3d.core.RayIntersectionData;
import alternterrain.objects.TerrainLOD;
import flash.display.Sprite;
import flash.filters.DropShadowFilter;
import flash.geom.Vector3D;

class TemplateSettings {
	public var cameraSpeedMultiplier:Number = 3;
	public var cameraSpeed:Number = 100;
	public var cameraSensitivity:Number = 1;
	public var viewBackgroundColor:uint;
	
}

class CrossHair extends Sprite {
    public function CrossHair() {
        graphics.lineStyle(1, 0xDDEE44, 1);
        graphics.moveTo(0, -2);
        graphics.lineTo(0, -6);
        
        graphics.moveTo(0, 2);
        graphics.lineTo(0, 6);
        
        graphics.moveTo(2, 0);
        graphics.lineTo(6, 0);
        
        graphics.moveTo(-2, 0);
        graphics.lineTo( -6, 0);
        
        filters = [new DropShadowFilter(1,45,0,1,0,0,1,1,false,false, false)];
    }
}

import alternativa.engine3d.alternativa3d;
use namespace alternativa3d;
	
class RaycastImpl extends Object3D {
	

	private var childOrigin:Vector3D = new Vector3D();
	private var childDirection:Vector3D = new Vector3D();
	private var terrainLOD:TerrainLOD;
	
	public var ddaMaxRange:Number = 8912;
	
	public function RaycastImpl(terrainLOD:TerrainLOD) {
		this.terrainLOD = terrainLOD;
		
		transformChanged = false;
	}
				
	override public function intersectRay(origin:Vector3D, direction:Vector3D):RayIntersectionData {
		
			if (terrainLOD.transformChanged) terrainLOD.composeTransforms();
					
			var child:Object3D = terrainLOD;
			childOrigin.x = child.inverseTransform.a*origin.x + child.inverseTransform.b*origin.y + child.inverseTransform.c*origin.z + child.inverseTransform.d;
			childOrigin.y = child.inverseTransform.e*origin.x + child.inverseTransform.f*origin.y + child.inverseTransform.g*origin.z + child.inverseTransform.h;
			childOrigin.z = child.inverseTransform.i*origin.x + child.inverseTransform.j*origin.y + child.inverseTransform.k*origin.z + child.inverseTransform.l;
			childDirection.x = child.inverseTransform.a*direction.x + child.inverseTransform.b*direction.y + child.inverseTransform.c*direction.z;
			childDirection.y = child.inverseTransform.e*direction.x + child.inverseTransform.f*direction.y + child.inverseTransform.g*direction.z;
			childDirection.z = child.inverseTransform.i * direction.x + child.inverseTransform.j * direction.y + child.inverseTransform.k * direction.z;
			
			var waterData:RayIntersectionData = terrainLOD.intersectRayWater(childOrigin, childDirection);
			var data:RayIntersectionData = direction.w <= ddaMaxRange ? terrainLOD.intersectRayDDA(childOrigin, childDirection) : terrainLOD.intersectRay(childOrigin, childDirection);
			
			if (data != null || waterData != null) {
				//if (waterData) throw new Error(waterData.time + ", "+childOrigin + ", "+childDirection);
				if (data != null) {
					// TODO: time in TerrainLOD is a bit wrong at the moment. Need to check. FOr now, use this temp dotProduct fix!
					data.time = (data.point.x - childOrigin.x) * direction.x + (data.point.y - childOrigin.y) * direction.y + (data.point.z - childOrigin.z) * direction.z;
				}
				return data != null ? waterData == null || data.time < waterData.time ? data : waterData : waterData;
			}
			return null;
			
	}
	
}
    