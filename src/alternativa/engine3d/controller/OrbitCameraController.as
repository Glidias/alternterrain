package alternativa.engine3d.controller {
	

	import alternativa.engine3d.controllers.SimpleObjectController;
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
    import flash.events.IEventDispatcher;

    import flash.display.DisplayObjectContainer;
    import flash.display.InteractiveObject;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageQuality;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.events.MouseEvent;
    import flash.geom.Vector3D;
    import flash.ui.Keyboard;
    import flash.ui.Mouse;
    import flash.ui.MouseCursor;

    /**
     * GeoCameraController は 3D オブジェクトの周りに配置することのできるコントローラークラスです。
     * 緯度・経度で配置することができます。
     *
     * @author narutohyper
     * @author clockmaker
     *
     * @see http://wonderfl.net/c/fwPU
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     */
    
   public class OrbitCameraController extends SimpleObjectController
    {

        //----------------------------------------------------------
        //
        //   Static Property 
        //
        //----------------------------------------------------------

        /** 中心と方向へ移動するアクションを示す定数です。 */
        public static const ACTION_FORWARD:String = "actionForward";

        /** 中心と反対方向へ移動するアクションを示す定数です。 */
        public static const ACTION_BACKWARD:String = "actionBackward";

        /** イージングの終了判断に用いるパラメーターです。0〜0.2で設定し、0に近いほどイージングが残されます。 */
        private static const ROUND_VALUE:Number = 0.1;
        
        
        private var _lockRotationZ:Boolean = false;
		private var _mouseWheelHandler:Function;
        

        //----------------------------------------------------------
        //
        //   Constructor 
        //
        //----------------------------------------------------------

        /**
         * 新しい GeoCameraController インスタンスを作成します。
         * @param targetObject    コントローラーで制御したいオブジェクトです。
         * @param mouseDownEventSource    マウスダウンイベントとひもづけるオブジェクトです。
         * @param mouseUpEventSource    マウスアップイベントとひもづけるオブジェクトです。推奨は stage です。
         * @param keyEventSource    キーダウン/キーマップイベントとひもづけるオブジェクトです。推奨は stage です。
         * @param useKeyControl    キーコントロールを使用するか指定します。
         * @param useMouseWheelControl    マウスホイールコントロールを使用するか指定します。
         */
        public function OrbitCameraController(
            targetObject:Camera3D,
            followTarget:Object3D,
            mouseDownEventSource:InteractiveObject,
            mouseUpEventSource:InteractiveObject,
            keyEventSource:InteractiveObject,
            useKeyControl:Boolean = true,
            useMouseWheelControl:Boolean = true, mouseWheelHandler:Function=null
            )
        {
            _target = targetObject;
            _followTarget = followTarget;

            super(mouseDownEventSource, targetObject, 0, 3, mouseSensitivity);
            super.mouseSensitivity = 0;
            super.unbindAll();
            super.accelerate(true);

            this._mouseDownEventSource = mouseDownEventSource;
            this._mouseUpEventSource = mouseUpEventSource;
            this._keyEventSource = keyEventSource;

            _mouseDownEventSource.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
            _mouseUpEventSource.addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
    
            // マウスホイール操作
			_mouseWheelHandler = mouseWheelHandler;
			
            if (useMouseWheelControl)
            {
                _mouseDownEventSource.addEventListener(MouseEvent.MOUSE_WHEEL, (_mouseWheelHandler=mouseWheelHandler || this.mouseWheelHandler));
            }

            // キーボード操作
            if (useKeyControl)
            {
                _keyEventSource.addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
                _keyEventSource.addEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
            }
        }
        
        public function reset():void {
            _angleLongitude = 0;
            _lastLongitude = 0;
            _angleLatitude = 0;
        //    _mouseMove = false;
            if (useHandCursor)
                Mouse.cursor = MouseCursor.AUTO;
            
        }

        //----------------------------------------------------------
        //
        //   Property 
        //
        //----------------------------------------------------------

        //--------------------------------------
        // easingSeparator 
        //--------------------------------------

        private var _easingSeparator:Number = 1.5;

        /**
         * イージング時の現在の位置から最後の位置までの分割係数
         * フレームレートと相談して使用
         * 1〜
         * 正の整数のみ。0 を指定しても 1 になります。
         * 1 でイージング無し。数値が高いほど、遅延しぬるぬるします
         */
        public function set easingSeparator(value:uint):void
        {
            if (value)
            {
                _easingSeparator = value;
            }
            else
            {
                _easingSeparator = 1;
            }
        }
        /** Camera から、中心までの最大距離です。デフォルト値は 2000 です。 */
        public var maxDistance:Number = 2000;

        /** Camera から、中心までの最小距離です。デフォルト値は 200 です。 */
        public var minDistance:Number = 200;

        //--------------------------------------
        // mouseSensitivityX 
        //--------------------------------------

        private var _mouseSensitivityX:Number = -1;

        /**
         * マウスの X 方向の感度
         */
        public function set mouseSensitivityX(value:Number):void
        {
            _mouseSensitivityX = value;
        }

        //--------------------------------------
        // mouseSensitivityY 
        //--------------------------------------

        private var _mouseSensitivityY:Number = 1;

        /**
         * マウスの Y 方向の感度
         */
        public function set mouseSensitivityY(value:Number):void
        {
            _mouseSensitivityY = value;
        }

        public var multiplyValue:Number = 10;

        //--------------------------------------
        // needsRendering 
        //--------------------------------------

        private var _needsRendering:Boolean;

        /**
         * レンダリングが必要かどうかを取得します。
         * この値は update() メソッドが呼び出されたタイミングで更新されます。
         *
         * @see GeoCameraController.update
         */
        public function get needsRendering():Boolean
        {
            return _needsRendering;
        }

        //--------------------------------------
        // pitchSpeed 
        //--------------------------------------

        private var _pitchSpeed:Number = 5;

        /**
         * 上下スピード
         * 初期値は5(px)
         */
        public function set pitchSpeed(value:Number):void
        {
            _pitchSpeed = value
        }

        public var useHandCursor:Boolean = true;

        //--------------------------------------
        // yawSpeed 
        //--------------------------------------

        private var _yawSpeed:Number = 5;

        /**
         * 回転スピード
         * 初期値は5(度)
         */
        public function set yawSpeed(value:Number):void
        {
            _yawSpeed = value * Math.PI / 180;
        }

        /**
         * Zoomスピード
         * 初期値は5(px)
         */
        public function set zoomSpeed(value:Number):void
        {
            _distanceSpeed = value;
        }
        
        public function get lockRotationZ():Boolean 
        {
            return _lockRotationZ;
        }
        
        public function set lockRotationZ(value:Boolean):void 
        {
            _lockRotationZ = value;
        }
        
        public function get followTarget():Object3D 
        {
            return _followTarget;
        }
        
        public function get angleLatitude():Number 
        {
            return _angleLatitude;
        }
        
        public function set angleLatitude(value:Number):void 
        {
            _angleLatitude = value;
            _lastLatitude = value;
        }
        
        public function get angleLongitude():Number 
        {
            return _angleLongitude;
        }
        
        public function set angleLongitude(value:Number):void 
        {
            _angleLongitude = value;
            _lastLongitude = value;
        }
        
        public function get minAngleLatitude():Number 
        {
            return _minAngleLatitude;
        }
        
        public function set minAngleLatitude(value:Number):void 
        {
            _minAngleLatitude = value;
        }
        
        public function get maxAngleLatidude():Number 
        {
            return _maxAngleLatidude;
        }
        
        public function set maxAngleLatidude(value:Number):void 
        {
            _maxAngleLatidude = value;
        }
        


        private var _minAngleLatitude:Number = -Number.MAX_VALUE;
        private var _maxAngleLatidude:Number = Number.MAX_VALUE;

        private var _angleLatitude:Number = 0;
        private var _angleLongitude:Number = 0;
        private var _distanceSpeed:Number = 5;
        private var _keyEventSource:InteractiveObject;
        private var _lastLatitude:Number = 0;
        private var _lastLength:Number = 700;
        private var _lastLongitude:Number = _angleLongitude;
        private var _lastLookAtX:Number = _lookAtX;
        private var _lastLookAtY:Number = _lookAtY;
        private var _lastLookAtZ:Number = _lookAtZ;
        private var _length:Number = 700;
        private var _lookAtX:Number = 0;
        private var _lookAtY:Number = 0;
        private var _lookAtZ:Number = 0;
        private var _mouseDownEventSource:InteractiveObject;
        private var _mouseMove:Boolean;
        private var _mouseUpEventSource:InteractiveObject;
        private var _mouseX:Number;
        private var _mouseY:Number;
        private var _oldLatitude:Number;
        private var _oldLongitude:Number;
        private var _pitchDown:Boolean;
        private var _pitchUp:Boolean;
        private var _taregetDistanceValue:Number = 0;
        private var _taregetPitchValue:Number = 0;
        private var _taregetYawValue:Number = 0;
        public var _target:Camera3D
        private var _yawLeft:Boolean;
        private var _yawRight:Boolean;
        private var _zoomIn:Boolean;
        private var _zoomOut:Boolean;
        public var _followTarget:Object3D;

        //----------------------------------------------------------
        //
        //   Function 
        //
        //----------------------------------------------------------

        /**
         * 自動的に適切なキーを割り当てます。
         */
        public function bindBasicKey():void
        {
            bindKey(Keyboard.LEFT, SimpleObjectController.ACTION_YAW_LEFT);
            bindKey(Keyboard.RIGHT, SimpleObjectController.ACTION_YAW_RIGHT);
            bindKey(Keyboard.DOWN, SimpleObjectController.ACTION_PITCH_DOWN);
            bindKey(Keyboard.UP, SimpleObjectController.ACTION_PITCH_UP);
            bindKey(Keyboard.PAGE_UP, OrbitCameraController.ACTION_BACKWARD);
            bindKey(Keyboard.PAGE_DOWN, OrbitCameraController.ACTION_FORWARD);
        }

        /** 上方向に移動します。 */
        public function pitchUp():void
        {
            _taregetPitchValue = _pitchSpeed * multiplyValue;
        }

        /** 下方向に移動します。 */
        public function pitchDown():void
        {
            _taregetPitchValue = _pitchSpeed * -multiplyValue;
        }

        /** 左方向に移動します。 */
        public function yawLeft():void
        {
            _taregetYawValue = _yawSpeed * multiplyValue;
        }

        /** 右方向に移動します。 */
        public function yawRight():void
        {
            _taregetYawValue = _yawSpeed * -multiplyValue;
        }

        /** 中心へ向かって近づきます。 */
        public function moveForeward():void
        {
            _taregetDistanceValue -= _distanceSpeed * multiplyValue;
        }

        /** 中心から遠くに離れます。 */
        public function moveBackward():void
        {
            _taregetDistanceValue += _distanceSpeed * multiplyValue;
        }

        /**
         *　@inheritDoc
         */
        override public function bindKey(keyCode:uint, action:String):void
        {
            switch (action)
            {
                case ACTION_FORWARD:
                    keyBindings[keyCode] = toggleForward;
                    break
                case ACTION_BACKWARD:
                    keyBindings[keyCode] = toggleBackward;
                    break
                case ACTION_YAW_LEFT:
                    keyBindings[keyCode] = toggleYawLeft;
                    break
                case ACTION_YAW_RIGHT:
                    keyBindings[keyCode] = toggleYawRight;
                    break
                case ACTION_PITCH_DOWN:
                    keyBindings[keyCode] = togglePitchDown;
                    break
                case ACTION_PITCH_UP:
                    keyBindings[keyCode] = togglePitchUp;
                    break
            }
            //super.bindKey(keyCode, action)
        }

        /**
         * 下方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function togglePitchDown(value:Boolean):void
        {
            _pitchDown = value
        }

        /**
         * 上方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function togglePitchUp(value:Boolean):void
        {
            _pitchUp = value
        }

        /**
         * 左方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function toggleYawLeft(value:Boolean):void
        {
            _yawLeft = value;
        }

        /**
         * 右方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function toggleYawRight(value:Boolean):void
        {
            _yawRight = value;
        }

        /**
         * 中心方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function toggleForward(value:Boolean):void
        {
            _zoomIn = value;
        }

        /**
         * 中心と反対方向に移動し続けるかを設定します。
         * @param value    true の場合は移動が有効になります。
         */
        public function toggleBackward(value:Boolean):void
        {
            _zoomOut = value;
        }

        private var testLook:Vector3D = new Vector3D();
        /**
         * @inheritDoc
         */
        override public function update():void
        {
            const RADIAN:Number = Math.PI / 180;
            var oldAngleLatitude:Number = _angleLatitude;
            var oldAngleLongitude:Number = _angleLongitude;
            var oldLengh:Number = _lastLength;

            //CameraZoom制御
            if (_zoomIn)
            {
                _lastLength -= _distanceSpeed;
            }
            else if (_zoomOut)
            {
                _lastLength += _distanceSpeed;
            }

            // ズーム制御
            if (_taregetDistanceValue != 0)
            {
                _lastLength += _taregetDistanceValue;
                _taregetDistanceValue = 0;
            }

            if (_lastLength < minDistance)
            {
                _lastLength = minDistance;
            }
            else if (_lastLength > maxDistance)
            {
                _lastLength = maxDistance;
            }
            if (_lastLength - _length)
            {
                _length += (_lastLength - _length) / _easingSeparator;
            }

            if (Math.abs(_lastLength - _length) < ROUND_VALUE)
            {
                _length = _lastLength;
            }

            //Camera回転制御
            if (_mouseMove)
            {
                _lastLongitude = _oldLongitude + (_mouseDownEventSource.mouseX - _mouseX) * _mouseSensitivityX
            }
            else if (_yawLeft)
            {
                _lastLongitude += _yawSpeed;
            }
            else if (_yawRight)
            {
                _lastLongitude -= _yawSpeed;
            }

            if (_taregetYawValue)
            {
                _lastLongitude += _taregetYawValue;
                _taregetYawValue = 0;
            }

            if (_lastLongitude - _angleLongitude)
            {
                _angleLongitude += (_lastLongitude - _angleLongitude) / _easingSeparator;
            }

            if (Math.abs(_lastLatitude - _angleLatitude) < ROUND_VALUE)
            {
                _angleLatitude = _lastLatitude;
            }

            //CameraZ位置制御
            if (_mouseMove)
            {
                _lastLatitude = _oldLatitude + (_mouseDownEventSource.mouseY - _mouseY) * _mouseSensitivityY;
            }
            else if (_pitchDown)
            {
                _lastLatitude -= _pitchSpeed;
            }
            else if (_pitchUp)
            {
                _lastLatitude += _pitchSpeed;
            }

            if (_taregetPitchValue)
            {
                _lastLatitude += _taregetPitchValue;
                _taregetPitchValue = 0;
            }

            _lastLatitude = Math.max(-89.9, Math.min(_lastLatitude, 89.9));

            if (_lastLatitude - _angleLatitude)
            {
                _angleLatitude += (_lastLatitude - _angleLatitude) / _easingSeparator;
            }
            if (Math.abs(_lastLongitude - _angleLongitude) < ROUND_VALUE)
            {
                _angleLongitude = _lastLongitude;
            }
            
            
            if (_angleLatitude < _minAngleLatitude) _angleLatitude = _minAngleLatitude;
            if (_angleLatitude > _maxAngleLatidude) _angleLatitude = _maxAngleLatidude;
            

            var vec3d:Vector3D = this.translateGeoCoords(_angleLatitude, _angleLongitude, _length);
                testLook.x = _followTarget.x;
                testLook.y = _followTarget.y;
                testLook.z = _followTarget.z;
            //    testLook = _followTarget.localToGlobal(testLook);
    
            _target.x = testLook.x + vec3d.x;
            _target.y = testLook.y + vec3d.y;
            _target.z = testLook.z + vec3d.z;

            //lookAt制御
            if (_lastLookAtX - _lookAtX)
            {
                _lookAtX += (_lastLookAtX - _lookAtX) / _easingSeparator;
            }

            if (_lastLookAtY - _lookAtY)
            {
                _lookAtY += (_lastLookAtY - _lookAtY) / _easingSeparator;
            }

            if (_lastLookAtZ - _lookAtZ)
            {
                _lookAtZ += (_lastLookAtZ - _lookAtZ) / _easingSeparator;
            }
            
        

            //super.update()
            updateObjectTransform();
            
            
            
            lookAtXYZ(_lookAtX + testLook.x, _lookAtY + testLook.y, _lookAtZ + testLook.z);
            
    

            _needsRendering = oldAngleLatitude != _angleLatitude
                || oldAngleLongitude != _angleLongitude
                || oldLengh != _length;
        }

        /** @inheritDoc */
        override public function startMouseLook():void
        {
            // 封印
        }

        /** @inheritDoc */
        override public function stopMouseLook():void
        {
            // 封印
        }

        /**
         * Cameraの向く方向を指定します。
         * lookAtやlookAtXYZとの併用は不可。
         * @param x
         * @param y
         * @param z
         * @param immediate    trueで、イージングしないで変更
         */
        public function lookAtPosition(x:Number, y:Number, z:Number, immediate:Boolean = false):void
        {
            if (immediate)
            {
                _lookAtX = x
                _lookAtY = y
                _lookAtZ = z
            }
            _lastLookAtX = x
            _lastLookAtY = y
            _lastLookAtZ = z
        }

        /**
         * 経度を設定します。
         * @param value    0で、正面から中央方向(lookAtPosition)を見る
         * @param immediate    trueで、イージングしないで変更
         */
        public function setLongitude(value:Number, immediate:Boolean = false):void
        {
            if (immediate)
            {
                _angleLongitude = value;
            }
            _lastLongitude = value;
        }

        /**
         * 緯度を設定します。
         * @param value    0で、正面から中央方向(lookAtPosition)を見る
         * @param immediate    trueで、イージングしないで変更
         */
        public function setLatitude(value:Number, immediate:Boolean = false):void
        {
            if (immediate)
            {
                _angleLatitude = value;
            }
            _lastLatitude = value;

        }

        /**
         * Cameraから、targetObjectまでの距離を設定します。
         * @param value    Cameraから、targetObjectまでの距離
         * @param immediate trueで、イージングしないで変更
         */
        public function setDistance(value:Number, immediate:Boolean = false):void
        {
            if (immediate)
            {
                _length = value;
            }
            _lastLength = value;
        }
        
        public function getDistance():Number {
            return _length;
        }

        /**
         * オブジェクトを使用不可にしてメモリを解放します。
         */
        public function dispose():void
        {
            // イベントの解放
            if (_mouseDownEventSource)
                _mouseDownEventSource.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);

            // マウスホイール操作
            if (_mouseDownEventSource)
                _mouseDownEventSource.removeEventListener(MouseEvent.MOUSE_WHEEL, _mouseWheelHandler);

            // キーボード操作
            if (_keyEventSource)
            {
                _keyEventSource.removeEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
                _keyEventSource.removeEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
            }

            // プロパティーの解放
            _easingSeparator = 0;
            maxDistance = 0;
            minDistance = 0;
            _mouseSensitivityX = 0;
            _mouseSensitivityY = 0;
            multiplyValue = 0;
            _needsRendering = false;
            _pitchSpeed = 0;
            useHandCursor = false;
            _yawSpeed = 0;
            _angleLatitude = 0;
            _angleLongitude = 0;
            _distanceSpeed = 0;
            _keyEventSource = null;
            _lastLatitude = 0;
            _lastLength = 0;
            _lastLongitude = 0;
            _lastLookAtX = 0;
            _lastLookAtY = 0;
            _lastLookAtZ = 0;
            _length = 0;
            _lookAtX = 0;
            _lookAtY = 0;
            _lookAtZ = 0;
            _mouseDownEventSource = null;
            _mouseMove = false;
            _mouseUpEventSource = null;
            _mouseX = 0;
            _mouseY = 0;
            _oldLatitude = 0;
            _oldLongitude = 0;
            _pitchDown = false;
            _pitchUp = false;
            _taregetDistanceValue = 0;
            _taregetPitchValue = 0;
            _taregetYawValue = 0;
            _target = null;
            _yawLeft = false;
            _yawRight = false;
            _zoomIn = false;
            _zoomOut = false;
        }

        protected function mouseDownHandler(event:Event):void
        {
            _oldLongitude = _lastLongitude;
            _oldLatitude = _lastLatitude;
            _mouseX = _mouseDownEventSource.mouseX;
            _mouseY = _mouseDownEventSource.mouseY;
            _mouseMove = true;

            if (useHandCursor)
                Mouse.cursor = MouseCursor.HAND;

        
        }

        protected function mouseUpHandler(event:Event):void
        {
            if (!_mouseMove) return;
            
            if (useHandCursor)
                Mouse.cursor = MouseCursor.AUTO;

            _mouseMove = false;
            
        }
        
        

        private function keyDownHandler(event:KeyboardEvent):void
        {
            for (var key:String in keyBindings)
            {
                if (String(event.keyCode) == key)
                {
                    keyBindings[key](true)
                }
            }
        }

        private function keyUpHandler(event:KeyboardEvent = null):void
        {
            for (var key:String in keyBindings)
            {
                keyBindings[key](false)
            }
        }

        private function mouseWheelHandler(event:MouseEvent):void
        {

            _lastLength -= event.delta * 20;
            if (_lastLength < minDistance)
            {
                _lastLength = minDistance
            }
            else if (_lastLength > maxDistance)
            {
                _lastLength = maxDistance
            }
        }

        /**
         * 経度と緯度から位置を算出します。
         * @param latitude    緯度
         * @param longitude    経度
         * @param radius    半径
         * @return 位置情報
         */
        private function translateGeoCoords(latitude:Number, longitude:Number, radius:Number):Vector3D
        {
            const latitudeDegreeOffset:Number = 90;
            const longitudeDegreeOffset:Number = -90;

            latitude = Math.PI * latitude / 180;
            longitude = Math.PI * longitude / 180;

            latitude -= (latitudeDegreeOffset * (Math.PI / 180));
            longitude -= (longitudeDegreeOffset * (Math.PI / 180));

            var x:Number = radius * Math.sin(latitude) * Math.cos(longitude);
            var y:Number = radius * Math.cos(latitude);
            var z:Number = radius * Math.sin(latitude) * Math.sin(longitude);

            return new Vector3D(x, z, y);
        }
    }
}