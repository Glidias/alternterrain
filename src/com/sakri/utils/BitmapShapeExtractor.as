package com.sakri.utils{
	
	//import flash.display.BitmapData;
	import __AS3__.vec.Vector;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.geom.Rectangle;
	import flash.utils.Timer;

	
	import flash.display.BitmapData;
	import flash.display.BitmapDataChannel;
	import flash.geom.Matrix;
	import flash.geom.Point;
	
	/**
	 * The BitmapShapeExtractor accepts a bitmapdata, and attempts to extract
	 * all 'transparency defined shapes' within. ExtractShapes returns an instance
	 * of ShapesList, containing all discovered "positive" and "negative" shapes.
	 * If the source bitmapData contains no transparency, it is returned unchanged.
	 * 
	 * @author Sakri Rosenstrom
	 * @email sakri.rosenstrom@gmail.com
	 * 	 
	 */
	public class BitmapShapeExtractor extends EventDispatcher {
		
	
//	import flash.display.BitmapData;		
		private static var TEMP_DATA:BitmapData;
		
		public static function extractShapes2(source_bmd:BitmapData, extraction_color:uint = 0xFF000000):ExtractedShapeCollection {
			if (TEMP_DATA == null || TEMP_DATA.width != source_bmd.width || TEMP_DATA.height  != source_bmd.height) {
				if (TEMP_DATA) TEMP_DATA.dispose();
				TEMP_DATA = new BitmapData(source_bmd.width, source_bmd.height, true, 0);
			}
			TEMP_DATA.fillRect(TEMP_DATA.rect, 0);
			
			TEMP_DATA.threshold(source_bmd, source_bmd.rect, new Point(), "!=", extraction_color, 0, 0xFF0000FF, true);
			return extractShapes(TEMP_DATA, extraction_color);
		}
		
		public static function extractShapes2Async(source_bmd:BitmapData, extraction_color:uint = 0xFF000000):BitmapShapeExtractor {
			if (TEMP_DATA == null || TEMP_DATA.width != source_bmd.width || TEMP_DATA.height  != source_bmd.height) {
				if (TEMP_DATA) TEMP_DATA.dispose();
				TEMP_DATA = new BitmapData(source_bmd.width, source_bmd.height, true, 0);
			}
			TEMP_DATA.fillRect(TEMP_DATA.rect, 0);
			
			TEMP_DATA.threshold(source_bmd, source_bmd.rect, new Point(), "!=", extraction_color, 0, 0xFF0000FF, true);
			var me:BitmapShapeExtractor = new BitmapShapeExtractor();
			
			me.extractShapesAsync(TEMP_DATA, extraction_color);
			
			return me;
		}
		
		public static function extractShapes(source_bmd:BitmapData,extraction_color:uint=0xFF000000):ExtractedShapeCollection{
			//trace("BitmapShapeExtractor.extractShapes()");
			var extracted:ExtractedShapeCollection=new ExtractedShapeCollection();
			
			//create copy of image with only 2 colors : 0xFFFF0000 (red) and 0x00000000 (transparent), these are the "positive shapes"
			var positive_two_color:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0x00);
			positive_two_color.draw(source_bmd);
			positive_two_color=BitmapDataUtil.toMonoChrome(positive_two_color,0xFFFF0000);
			
			if(!BitmapDataUtil.containsTransparentPixels(source_bmd)){
				extracted.addShape(positive_two_color);
				
				return extracted;//no transparent pixels found, so the original bitmap is returned
			}			

			//copies all transparency from positive_two_color into the red channel, creating an inverse for discovering the "negative shapes"
			var temp:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0xFF0000FF);
			temp.draw(positive_two_color);
			var negative_two_color:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0xFFFF0000);
			negative_two_color.copyChannel(temp,positive_two_color.rect,new Point(),BitmapDataChannel.BLUE,BitmapDataChannel.ALPHA);

			extracted.shapes=extractShapesFromMonochrome(positive_two_color);
			extracted.negative_shapes=extractShapesFromMonochrome(negative_two_color);
			return extracted;
		}
		
		public  function extractShapesAsync(source_bmd:BitmapData,extraction_color:uint=0xFF000000):void {
			//trace("BitmapShapeExtractor.extractShapes()");
			
			
			//create copy of image with only 2 colors : 0xFFFF0000 (red) and 0x00000000 (transparent), these are the "positive shapes"
			var positive_two_color:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0x00);
			positive_two_color.draw(source_bmd);
			positive_two_color=BitmapDataUtil.toMonoChrome(positive_two_color,0xFFFF0000);
			
			if(!BitmapDataUtil.containsTransparentPixels(source_bmd)){
				extracted.addShape(positive_two_color);
				
				return;//no transparent pixels found, so the original bitmap is returned
			}		

			//copies all transparency from positive_two_color into the red channel, creating an inverse for discovering the "negative shapes"
			var temp:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0xFF0000FF);
			temp.draw(positive_two_color);
			var negative_two_color:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0xFFFF0000);
			negative_two_color.copyChannel(temp,positive_two_color.rect,new Point(),BitmapDataChannel.BLUE,BitmapDataChannel.ALPHA);

			extractShapesFromMonochromeAsync(positive_two_color, extracted.shapes);
			extractShapesFromMonochromeAsync(negative_two_color, extracted.negative_shapes);
			return;
		}
		
		
		
		//same as extractShapes, except the source image is doubled in size to prevent any "single pixel lines"
		//refactor... this violates DRY a wee little bit
		public static function extractShapesDoubleSize(source_bmd:BitmapData,extraction_color:uint=0xFF000000):ExtractedShapeCollection{
			//trace("BitmapShapeExtractor.extractShapesDoubleSize()");
			var extracted:ExtractedShapeCollection=new ExtractedShapeCollection();
			
			//create copy of image with only 2 colors : 0xFFFF0000 (red) and 0x00000000 (transparent)			
			var mono_chrome:BitmapData=new BitmapData(source_bmd.width,source_bmd.height,true,0x00);
			mono_chrome.draw(source_bmd);
			mono_chrome=BitmapDataUtil.toMonoChrome(mono_chrome,0xFFFF0000);
			
			//double in size, this removes any "single pixel lines", these are the "positive shapes"
			var positive_two_color:BitmapData=new BitmapData(source_bmd.width*2,source_bmd.height*2,true,0x00);
			var m:Matrix=new Matrix();
			m.scale(2,2);
			positive_two_color.draw(mono_chrome,m);
			positive_two_color=BitmapDataUtil.toMonoChrome(positive_two_color,0xFFFF0000);
			mono_chrome.dispose();
			mono_chrome=null;
			
			if(!BitmapDataUtil.containsTransparentPixels(source_bmd)){
				extracted.addShape(positive_two_color);
				
				return extracted;//no transparent pixels found, so the original bitmap is returned
			}			

			//copies all transparency from positive_two_color into the red channel, creating an inverse for discovering the "negative shapes"
			var temp:BitmapData=new BitmapData(positive_two_color.width,positive_two_color.height,true,0xFF0000FF);
			temp.draw(positive_two_color);
			var negative_two_color:BitmapData=new BitmapData(positive_two_color.width,positive_two_color.height,true,0xFFFF0000);
			negative_two_color.copyChannel(temp,positive_two_color.rect,new Point(),BitmapDataChannel.BLUE,BitmapDataChannel.ALPHA);

			extracted.shapes=extractShapesFromMonochrome(positive_two_color);
			extracted.negative_shapes=extractShapesFromMonochrome(negative_two_color);
			return extracted;
		}
		
		private var scan_y:uint;
		private var bmd:BitmapData;
		public var extracted:ExtractedShapeCollection = new ExtractedShapeCollection();
		private var found:Vector.<BitmapData>;
		private var timer:Timer = new Timer(30, 0);
		
		public function BitmapShapeExtractor() {
			timer.addEventListener(TimerEvent.TIMER, extractShapeFromMonochromeAsync_iterate);
			
		}
		
		protected  function extractShapesFromMonochromeAsync(bmd:BitmapData, found:Vector.<BitmapData>):void {
			scan_y = 0;
			this.bmd = bmd
			this.found = found;
		
			timer.start();
		}
		
		protected function extractShapeFromMonochromeAsync_iterate(e:Event):void {
			var non_trans:Point;;
			non_trans=BitmapDataUtil.getFirstNonTransparentPixel(bmd,scan_y);
			if (non_trans == null) return;
			bmd.floodFill(non_trans.x, non_trans.y, 0xFF0000FF);//fill with blue
			
			var copy_bmd:BitmapData = new BitmapData(bmd.width, bmd.height, true, 0xFFFF0000);
			
			
			copy_bmd.copyChannel(bmd,bmd.rect,new Point(),BitmapDataChannel.BLUE, BitmapDataChannel.ALPHA);
				bmd.floodFill(non_trans.x,non_trans.y,0x00000000);//fill with blue
				found.push(copy_bmd);
				scan_y = non_trans.y;
				
				if (scan_y >= bmd.height) {
					
					timer.stop();
					dispatchEvent( new Event(Event.COMPLETE) );
					// time to break
				}
		}
		
		protected static function extractShapesFromMonochrome(bmd:BitmapData):Vector.<BitmapData>{
			var scan_y:uint=0;
			var non_trans:Point;
			var found:Vector.<BitmapData>=new Vector.<BitmapData>();
			var copy_bmd:BitmapData;
			var iterations:uint=0;
			while(scan_y<bmd.height){
				non_trans=BitmapDataUtil.getFirstNonTransparentPixel(bmd,scan_y);
				if(non_trans==null)return found;
				bmd.floodFill(non_trans.x, non_trans.y, 0xFF0000FF);//fill with blue
		
				copy_bmd=new BitmapData(bmd.width,bmd.height,true,0xFFFF0000);
				copy_bmd.copyChannel(bmd,bmd.rect,new Point(),BitmapDataChannel.BLUE, BitmapDataChannel.ALPHA);
				bmd.floodFill(non_trans.x,non_trans.y,0x00000000);//fill with blue
				found.push(copy_bmd);
				scan_y=non_trans.y;
				iterations++;
				//if(iterations>10)break;
			}
			return found;
		}

	}
}