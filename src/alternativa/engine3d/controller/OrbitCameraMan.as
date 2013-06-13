package alternativa.engine3d.controller 
{
  import alternativa.engine3d.core.Object3D;
  import alternativa.engine3d.core.RayIntersectionData;
  import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.materials.TextureMaterial;
	import flash.display.InteractiveObject;
    import flash.events.Event;
	import flash.events.IEventDispatcher;
    import flash.events.MouseEvent;
    import flash.geom.Vector3D;
    import flash.utils.Dictionary;
    import alternativa.engine3d.alternativa3d;
    use namespace alternativa3d;
    
    /**
     * Does adjustments to orbit controller for chase-cams/follow target in relation to entire environment
     * and various game-types.
     * 
     * @author Glidias
     */
     public class OrbitCameraMan 
    {

        private var _followTarget:Object3D;
        public var controller:OrbitCameraController;
        
        protected var _preferedZoom:Number;
		public var preferedMinDistance:Number;
        public var maxFadeAlpha:Number = .8;
        public var minFadeAlpha:Number = .2;
        protected var _fadeDistance:Number = 200;
        public var useFadeDistance:Boolean = true;
        
        public var visBufferLength:Number = 0;
        public var preferedAlpha:Number = 1;
        
        public var followAzimuth:Boolean = false;
        public var followPitch:Boolean = false;
        protected static const ORIGIN:Vector3D = new Vector3D();
        protected var scene:Object3D;
        //x:  -45 * (Math.PI / 180)  
        
        public var cameraForward:Vector3D = new Vector3D();
        public var cameraReverse:Vector3D = new Vector3D();
        public var ignoreDict:Dictionary = new Dictionary();
        public var collideOffset:Number = 24;
		
        
        public var threshold:Number = 0.01;
        
		public var alphaSetter:*;

        
        public var instant:Boolean = false;
        public var mouseWheelSensitivity:Number = 30;
        
        public function OrbitCameraMan(camera:Camera3D,  cameraTarget:Object3D, stager:InteractiveObject, scene:Object3D, followTarget:Object3D=null, useMouseWheel:Boolean=false) 
        {
			var controller:OrbitCameraController = new OrbitCameraController(camera, cameraTarget, stager, stager, stager, false, useMouseWheel, mouseWheelHandler);
            this._followTarget = followTarget || (controller._followTarget);
			alphaSetter = new DummyAlpha();
            this.scene = scene;
            this.controller = controller;
            _preferedZoom = controller.getDistance();
            ignoreDict[controller._followTarget] = true;
            controller.minPitch = Math.PI * .5;
			preferedMinDistance = 0;
        }
        
        /*
             _object.x += -Math.sin(_object.rotationZ) * 120;
            _object.y += Math.cos(_object.rotationZ) * 120;
        
            _object.x += forward.x * 120;
            _object.y += forward.y * 120;
            _object.z += forward.z * 120;
        */
        
        public function mouseWheelHandler(e:MouseEvent):void {
            var _lastLength:Number = controller.getDistance();
            _lastLength -= e.delta * mouseWheelSensitivity;
			var minDist:Number = (preferedMinDistance > 0 ? preferedMinDistance : controller.minDistance);
            if (_lastLength < minDist )
            {
                _lastLength = minDist;
            }
            else if (_lastLength > controller.maxDistance)
            {
                _lastLength = controller.maxDistance
            }
            
            preferedZoom = _lastLength;
            
        }
        public function update():void {
            controller.update(); 

            var camera:Camera3D = controller._target;
        
            var camLookAtTarget:Object3D = controller._followTarget;
            if (followAzimuth) _followTarget.rotationZ = camera.rotationZ;
            if (followPitch) _followTarget.rotationX =  camera.rotationX + Math.PI * .5;
            
        
            
            camera.calculateRay(ORIGIN, cameraForward, camera.view._width*.5, camera.view._height*.5);            
        
            cameraReverse.x = -cameraForward.x;
            cameraReverse.y = -cameraForward.y;
            cameraReverse.z = -cameraForward.z;
			cameraReverse.w = _preferedZoom;
            
            var data:RayIntersectionData = getBackRayIntersectionData( new Vector3D(camLookAtTarget.x + cameraForward.x*-threshold, camLookAtTarget.y + cameraForward.y*-threshold, camLookAtTarget.z + cameraForward.z*-threshold) );
			
                _followTarget.visible = true;
            var tarDist:Number = _preferedZoom;
            if (data != null) {
                
                //cameraReverse.normalize();
                data.point = data.object.localToGlobal(data.point);
                tarDist = data.point.subtract( new Vector3D(camLookAtTarget.x, camLookAtTarget.y, camLookAtTarget.z) ).length - collideOffset;
            
                if (tarDist > _preferedZoom) tarDist = _preferedZoom;
                if (tarDist < controller.minDistance) tarDist =  controller.minDistance;
                    
                var limit:Number = (controller.minDistance + visBufferLength);
                _followTarget.visible = tarDist >= limit;
                
                if (useFadeDistance) {
                    limit = (tarDist - limit) / (_preferedZoom - _fadeDistance);
                    if (limit < 1) {
                        limit  = limit < 0 ? 0 : limit;
                        limit = minFadeAlpha + limit * (maxFadeAlpha - minFadeAlpha);
                       alphaSetter.alpha = limit;
                    }
                    else alphaSetter.alpha = preferedAlpha;
                }
                controller.setDistance(tarDist, instant);
                controller.setObjectPosXYZ(camera.x = camLookAtTarget.x +  cameraReverse.x * tarDist,
                camera.y= camLookAtTarget.y +  cameraReverse.y * tarDist,
                camera.z = camLookAtTarget.z +  cameraReverse.z * tarDist);
            
            }
            else  {
                
                controller.setDistance(tarDist, instant);
                if (useFadeDistance) alphaSetter.alpha = preferedAlpha;
            }
            
            
            //*/
            
        }
        
        public function get sceneCollidable():Object3D {
            return scene;
        }
        protected function getBackRayIntersectionData(objPosition:Vector3D):RayIntersectionData 
        {
            return scene.intersectRay( objPosition, cameraReverse);
        }
        
        public function get preferedZoom():Number 
        {
            return _preferedZoom;
        }
        
        public function set preferedZoom(value:Number):void 
        {
            _preferedZoom = value;
            controller.setDistance(value);
            
        }
        
        public function get fadeDistance():Number 
        {
            return _fadeDistance;
        }
        
        public function set fadeDistance(value:Number):void 
        {
            _fadeDistance = value;

        }
        
    }

}

class DummyAlpha {
	
	public var alpha:Number;
	public function DummyAlpha() {
		alpha = 1;
	}
}