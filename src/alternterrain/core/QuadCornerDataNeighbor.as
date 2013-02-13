package alternterrain.core 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	/**
	 * ...
	 * @author Glidias
	 */
	public class QuadCornerDataNeighbor extends QuadCornerData
	{
		public var neighbors:Vector.<QuadCornerData> = new Vector.<QuadCornerData>(4, true);
		
		// optional (store related heightmap info)
		public var heightMap:HeightMapInfo;
		
		public function QuadCornerDataNeighbor() 
		{
			
		}
		
		public function setNeighbourQuads(array:QuadCornerData, array1:QuadCornerData, array2:QuadCornerData, array3:QuadCornerData):void 
		{
			neighbors[0] = array;
			neighbors[1] = array1;
			neighbors[2] = array2;
			neighbors[3] = array3;
		}
		
	
		

		
		public static function create3x3WithBitmapData(bmpData:BitmapData, heightMult:Number, heightMin:Number, testCont:DisplayObjectContainer=null):Vector.<QuadCornerDataNeighbor> {
		
			if ( int(bmpData.width / 3) !=  bmpData.width / 3  || int(bmpData.height / 3) !=  bmpData.height / 3  ) {
			
				throw new Error("Dimensions not divisible by 3!");
			}
			
			const cellWidth:int = bmpData.width / 3 + 2;
			const cellHeight:int = bmpData.height / 3 + 2;
			const baseWidth:int = bmpData.width / 3;
			const baseHeight:int = bmpData.height / 3;
	
			
			var vec:Vector.<QuadCornerDataNeighbor> = new Vector.<QuadCornerDataNeighbor>(9, true);
			var temp:BitmapData = new BitmapData(cellWidth, cellHeight, false, 0);
		
			const rect:Rectangle = new Rectangle();
		
			var count:int = 0;
			var qd:QuadCornerDataNeighbor;
			const point:Point = new Point();
			for (var v:int = 0; v < 3; v++) {
				for (var u:int = 0; u < 3; u++) {
					count++;
					temp.fillRect(temp.rect, 0);
					
					// BASE
					rect.x = u * baseWidth;
					rect.y = v * baseHeight;  
					rect.width = baseWidth;
					rect.height = baseHeight;
					point.x = 1;
					point.y = 1;
					temp.copyPixels(bmpData, rect, point);
					
					
					// LEFT EDGE
					///*
					point.x = 0;
					point.y = 1;
					rect.x = u * baseWidth - 1; 
					rect.x = rect.x < 0 ? bmpData.width-1 : rect.x >= bmpData.width ? 0 : rect.x;
					rect.y = v * baseHeight; 
			
	
					rect.width = 1;
					rect.height = baseHeight;
					weldBorderBmpData(bmpData, rect, temp, point, 1);
					//*/
					

					// RIGHT EDGE
				//	/*
					point.x = cellWidth -1;
					point.y = 1;
					rect.x = u * baseWidth + baseWidth; 
					rect.x = rect.x < 0 ? bmpData.width-1 : rect.x >= bmpData.width ? 0 : rect.x;
					rect.y = v * baseHeight; 
				
					
					rect.width = 1;
					rect.height = baseHeight;
					weldBorderBmpData(bmpData, rect, temp, point, -1);
					//*/
								
					
					// TOP EDGE
				//	/*
					
					point.x = 1;
					point.y = 0;
					rect.x = u * baseWidth; 
					rect.y = v * baseHeight - 1; 
					rect.y = rect.y < 0 ? bmpData.height-1 : rect.y >= bmpData.height ? 0 : rect.y;
					
					
					rect.width = baseWidth;
					rect.height = 1;
					weldBorderBmpData(bmpData, rect, temp, point, 1);
					//*/
					
					
					// BOTTOM EDGE
					///*
					point.x = 1;
					point.y = cellHeight - 1;
					rect.x = u * baseWidth; 
					rect.y = v * baseHeight + baseHeight; 
					rect.y = rect.y < 0 ? bmpData.height-1 : rect.y >= bmpData.height ? 0 : rect.y;
					
	
					
					rect.width = baseWidth;
					rect.height = 1;
					weldBorderBmpData(bmpData, rect, temp, point, -1);
				//	*/
				
					// Top left
					point.x = u * baseWidth; 
					point.y = v * baseHeight;
					temp.setPixel(0, 0, getAverageColors(bmpData, [point.x, point.y,   point.x - 1, point.y -1,   point.x -1, point.y, point.x, point.y - 1]) );
					
					// Bottom left
					point.x = u * baseWidth; 
					point.y = v * baseHeight + baseHeight - 1;
					temp.setPixel(0, cellHeight - 1, getAverageColors(bmpData, [point.x, point.y,   point.x - 1, point.y +1,   point.x -1, point.y, point.x, point.y + 1]) );
					
					// Top-right
					point.x = u * baseWidth + baseWidth - 1; 
					point.y = v * baseHeight;
					temp.setPixel(cellWidth - 1, 0, getAverageColors(bmpData, [point.x, point.y,   point.x + 1, point.y -1,   point.x +1, point.y,  point.x, point.y - 1]) );
					
					// Bottom-right
					point.x = u * baseWidth + baseWidth - 1; 
					point.y = v * baseHeight + baseHeight - 1; 
					temp.setPixel(cellWidth - 1, cellHeight - 1, getAverageColors(bmpData, [point.x, point.y,   point.x + 1, point.y +1,   point.x +1, point.y,  point.x, point.y + 1]) );

					vec[v * 3 + u] = qd = QuadCornerData.createRoot( 0, 0, (cellWidth-1)* 256, true ) as QuadCornerDataNeighbor;
					qd.Square.AddHeightMap( qd, qd.heightMap=HeightMapInfo.createFromBmpData(temp, 0, 0, heightMult, heightMin) );
					qd.Square.RecomputeErrorAndLighting(qd);
					//return vec;
				}
				
			}
			
			//
			link9NeighbourQuads(vec);
		//	temp.dispose();
			return vec;
		}

		
		private static function weldBorderBmpData(srcBmpData:BitmapData, rect:Rectangle, destBmpData:BitmapData, destPt:Point, delta:int):void {
			var limit:int = rect.width > 1 ? rect.width : rect.height;
			var xi:int = rect.width > 1 ? 1 : 0;
			var yi:int = rect.width > 1 ? 0 : 1;
			var xii:int = xi == 0 ? delta : 0;
			var yii:int = yi == 0 ? delta : 0;
			
			
			
			var x:int = rect.x;
			var y:int = rect.y;
			var xp:int = destPt.x;
			var yp:int = destPt.y;
			var r:int;
			var g:int;
			var b:int;
			var r2:int;
			var g2:int;
			var b2:int;
			var color:int; 
			var color2:int;
			for (var i:int = 0; i < limit; i++) {
				var ox:int = x + xii;
				var oy:int = y + yii;
				//if (xi + yi != 1) throw new Error("Mismatch22!");
				//if (Math.abs(xii + yii) != 1) throw new Error("Mismatch33!");
				ox = ox < 0 ? srcBmpData.width-1 : ox >= srcBmpData.width ? 0 :ox;
				oy = oy < 0 ? srcBmpData.height-1 : oy >= srcBmpData.height ? 0 : oy;
				


				color = srcBmpData.getPixel(x, y);
				r = color >> 16 & 0xFF;
				g = color >> 8 & 0xFF;
				b = color & 0xFF;
				
			
				
				color2 = srcBmpData.getPixel(ox, oy);
				r2 = color2 >> 16 & 0xFF;
				g2 = color2 >> 8 & 0xFF;
				b2 = color2 & 0xFF;
				
				r = (r + r2) / 2;
				g = (g + g2) / 2;
				b = (b + b2) / 2;
				color = (r << 16) | (g << 8) | b;
				destBmpData.setPixel(xp, yp, color );
				x += xi;
				y += yi;
				xp += xi;
				yp += yi;
			}
		}
		
		private static function getAverageColors(srcBmpData:BitmapData, positions:Array):uint {
			var numPos:int = positions.length / 2;
			var x:int;
			var y:int;
			var color:int;
			var r:int;
			var g:int;
			var b:int;
			var rValues:Array = [];
			var gValues:Array = [];
			var bValues:Array = [];
			for (var i:int = 0; i < numPos; i++) {
				x = positions[i*2];
				y = positions[i*2 + 1];
				x = x < 0 ? srcBmpData.width-1 : x >= srcBmpData.width ? 0 :x;
				y = y < 0 ? srcBmpData.height-1 : y >= srcBmpData.height ? 0 : y;
				color = srcBmpData.getPixel(x, y);
				r = color >> 16 & 0xFF;
				g = color >> 8 & 0xFF;
				b = color & 0xFF;
				rValues.push(r);
				gValues.push(g);
				bValues.push(b);
			}
			
			r = 0;
			g = 0;
			b = 0;
			for (i = 0; i < numPos; i++) {
				r += rValues[i];
				g += rValues[i];
				b+= rValues[i];
			}
			r= r / numPos;
			g=g / numPos;
			b = b / numPos;
			color = (r << 16) | (g << 8) | b;
			return color;	
			
		}
		
		

		
		public static function link9NeighbourQuads(vec:Vector.<QuadCornerDataNeighbor>):void {
			vec[0].setNeighbourQuads(vec[1], vec[6], vec[2], vec[3]);
			
			vec[1].setNeighbourQuads(vec[2], vec[7], vec[0], vec[4]);
			
			vec[2].setNeighbourQuads(vec[0], vec[8], vec[1], vec[5]);
			
			vec[3].setNeighbourQuads(vec[4], vec[0], vec[5], vec[6]);
			
			vec[4].setNeighbourQuads(vec[5], vec[1], vec[3], vec[7]);
				
			vec[5].setNeighbourQuads(vec[3], vec[2], vec[4], vec[8]);
					
			vec[6].setNeighbourQuads(vec[7], vec[3], vec[8], vec[0]);
						
			vec[7].setNeighbourQuads(vec[8], vec[4], vec[6], vec[1]);
							
			vec[8].setNeighbourQuads(vec[6], vec[5], vec[7], vec[2]);
		}


		public static function get9NeighbourQuads(arr:*):Vector.<QuadCornerDataNeighbor> {
			var vec:Vector.<QuadCornerDataNeighbor> = new Vector.<QuadCornerDataNeighbor>(9, true);
			for (var i:int = 0; i < 9; i++) {
				vec[i] = (arr[i] as INeighbourQuad).getQuad();
			}
			return vec;
		}
		
		
	}

}