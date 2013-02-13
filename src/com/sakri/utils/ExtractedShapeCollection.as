package com.sakri.utils{
	import __AS3__.vec.Vector;
	import flash.display.Shape;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	
	public class ExtractedShapeCollection{
		
		private var _shapes:Vector.<BitmapData>;
		public function get shapes():Vector.<BitmapData>{return _shapes;}
		public function set shapes(a:Vector.<BitmapData>):void{_shapes=a;}
		
		private var _negative_shapes:Vector.<BitmapData>;
		public function get negative_shapes():Vector.<BitmapData>{return _negative_shapes;}
		public function set negative_shapes(a:Vector.<BitmapData>):void{_negative_shapes=a}
		
		public function get all_shapes():Vector.<BitmapData>{return _shapes.concat(_negative_shapes);}
		public function set all_shapes(a:Vector.<BitmapData>):void{}
		
		public function ExtractedShapeCollection(){
			_shapes=new Vector.<BitmapData>();
			_negative_shapes=new Vector.<BitmapData>();
		}
		
		public function addShape(bmd:BitmapData):void{
			//trace("ExtractedShapeCollection.addShape()");
			_shapes.push(bmd);
		}
		public function addNegativeShape(bmd:BitmapData):void{
			_negative_shapes.push(bmd);
		}
		
		public function dispose():void 
		{
			for each(var shape:BitmapData in _shapes) {
				shape.dispose();
			}
						for each(shape in _negative_shapes) {
				shape.dispose();
			}
		}

	}
}