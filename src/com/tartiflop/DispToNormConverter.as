package com.tartiflop {
	import alternterrain.core.HeightMapInfo;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Vector3D;

	
	
	/**
	 * "Abstract" class for both planar and spherical converters. 
	 */
	public class DispToNormConverter {
		
		
		protected var direction:String = "y";
		protected var amplitude:Number = 8;
		protected var normalMap:Bitmap;
		
		protected var displcamentBitmapData:BitmapData;
		
		public var heightMap:HeightMapInfo;
		public var heightMapMultiplier:Number = 1 / 255;
		
		public function DispToNormConverter() {
		}

		/**
		 * Sets the initial displacement map data.
		 */
		public function setDisplacementMapData(displcamentBitmapData:BitmapData):void {
			this.displcamentBitmapData = displcamentBitmapData; 						
		}

		/**
		 * Sets the direction of the displacement ("x", "y" or "z").
		 */
		public function setDirection(direction:String):void {
			this.direction = direction;
		}
		
		/**
		 * Sets the amplitude factor so that the displacements can be more or less pronounced. 
		 */
		public function setAmplitude(amplitude:Number):void {
			this.amplitude = amplitude;
		}

		/**
		 * Returns the calculated normal map bitmap data.
		 */
		public function getNormalMap():Bitmap {
			return normalMap;
		}

		
		/**
		 * Converts a pixel value into a displacement between 0 and 1. Assumes greyscale data so only uses the blue channel.
		 */
		protected function getDisplacement(displcamentBitmapData:BitmapData, x:int, y:int):Number {
			return heightMap!= null ? heightMap.getData(x,y) * heightMapMultiplier : (displcamentBitmapData.getPixel(x, y) & 0xFF) / 255.0;
		}

		/**
		 * Converts the calculated normal vector into RGB values and sets the pixel value. 
		 * Takes into account the direction of the displacements/phi direction.
		 */
		protected function setNormal(normalBitmapData:BitmapData, x:int, y:int, normal:Vector3D):void {
			normal.normalize();
			
			
			if (direction == "x") {
				var nx:Number = (normal.z / 2) + 0.5;
				var ny:Number = (normal.x / 2) + 0.5;
				var nz:Number = (normal.y / 2) + 0.5;
			
			} else if (direction == "y") {
				nx = (normal.x / 2) + 0.5;
				ny = (normal.z / 2) + 0.5;
				nz = (normal.y / 2) + 0.5;
				
			} else {
				nx = (normal.x / 2) + 0.5;
				ny = (normal.y / 2) + 0.5;
				nz = (normal.z / 2) + 0.5;
				
			}
			var color:int = nx*0xFF << 16 | ny*0xFF << 8 | nz*0xFF;
			
			normalBitmapData.setPixel(x, y, color);	
		}
		
		public function convertToNormalMap():Bitmap {
			return null;
		}

	}
}