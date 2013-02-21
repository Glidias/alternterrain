package alternterrainxtras.util 
{
	/**
	 * Utility to help create a texture atlas of tiles
	 * @author Glenn Ko
	 */
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.geom.Point;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
    
	public class TextureAtlasData extends EventDispatcher {
        private var bakeMipmaps:Boolean;
        private var numTilesHorizontal:int;
        private var numTilesVertical:int;
        private var tileSize:int;
        public var context:LoaderContext = null;
        
        private var loadStack:Array = [];
        
        private var hStride:int;
        public var data:BitmapData;
        private var mipmaps:Mipmaps;
        private var normalizeRGB:Boolean;
        
        public var loadedTextures:int = 0;
        static public var CONTEXT:LoaderContext = null;
        
        
        
        function TextureAtlasData(tileSize:int, numTilesHorizontal:int, numTilesVertical:int, mipmaps:Mipmaps=null, normalizeRGB:Boolean=false ) {
            this.context = CONTEXT;
            this.normalizeRGB = normalizeRGB;
            data = new BitmapData(numTilesHorizontal * tileSize * (mipmaps!=null ?  2 :1), numTilesVertical * tileSize, false, 0);
            this.tileSize = tileSize;
            this.numTilesVertical = numTilesVertical;
            this.numTilesHorizontal = numTilesHorizontal;
            hStride = mipmaps != null ? tileSize * 2 : tileSize;
            
            
            this.mipmaps = mipmaps;
            
        }
		
		public function loadURLsFromChars(chars:String, rootPath:String, ext:String):void {
			var i:int;
			var len:int = chars.length;
			var arr:Array = [];
			for (i = 0; i < len; i++) {
				arr.push(rootPath + chars.charAt(i) + "." + ext);
			}
			loadURLs(arr);
		}
		
		public static function getTileMap(data:ByteArray):BitmapData {
			var tilesAcross:int = data.readShort();
			var bmpData:BitmapData = new BitmapData(tilesAcross, tilesAcross, true, 0);
			
			var color:uint;
			for (var y:int = 0; y < tilesAcross; y++) {
				for (var x:int = 0; x < tilesAcross; x++) {
					color = 0xFF000000;
					color |= (data.readUnsignedByte() << 16);
					color |= (data.readUnsignedByte() << 8);
					color |= data.readUnsignedByte();
					bmpData.setPixel32(x, y, color);
				}
			}
			return bmpData;
		}
        
        public function loadURLs(fileList:Array):void {
            var i:int = fileList.length;
            while (--i > -1) {
                loadStack.push(fileList[i]);
            }

            if (fileList.length > 0) {
                popLoadStack();
            }
        }    
        private function popLoadStack():void {
            var urlRequest:URLRequest = new URLRequest( loadStack.pop() );
            var loader:Loader = new Loader();
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
            loader.load( urlRequest, context);
            
        
        }
        
        private function onIOError(e:IOErrorEvent):void 
        {
            throw new Error("LOAD FAILED");
        }
        
    
        
        private function onLoadComplete(e:Event):void {
            
            var loadInfo:LoaderInfo =  (e.currentTarget as LoaderInfo);
            loadInfo.removeEventListener(e.type, onLoadComplete);
            
            //contentLoaderInfo.content;
            var h:int = int(loadedTextures % numTilesHorizontal);
            var v:int = int(loadedTextures / numTilesHorizontal);
            
            //h * hStride
            var pt:Point = new Point();
            var srcData:BitmapData = (loadInfo.content as Bitmap).bitmapData;
            if (normalizeRGB) {
                for (var x:int = 0; x < srcData.width; x++) {
                    for (var y:int = 0; y < srcData.height; y++) {
                        var c:uint = srcData.getPixel(x, y);
                        var r:uint = ((c  >> 16) & 0xFF);
                        var g:uint = ((c >> 8)  & 0xFF);
                       var b:uint = (c & 0xFF);
                       var t:Number = r + g + b;
                       r = r / t * 255;
                        g = g / t * 255;
                        b = b / t * 255;
                        
                       b -= (r + g + b - 255);  // this won't be too accruate but nvm..
                        //if (r + g + b != 255) throw new Error("WRONG!");
                      
                        
                        srcData.setPixel( x, y, ((r << 16) | (g << 8) | b) );
                    }
                }
                
            }
            pt.x = h * hStride;
            pt.y = v * tileSize;
            data.copyPixels(srcData, srcData.rect, pt);
            
            pt.x += tileSize;
            if (mipmaps != null) {
                mipmaps.texture = srcData;
                mipmaps.pasteMipmaps( data, pt);
            }
            
            loadedTextures++;
        
            if (loadStack.length > 0) {
                
                dispatchEvent( new ProgressEvent(ProgressEvent.PROGRESS, false, false, loadInfo.bytesLoaded * loadStack.length) );
                popLoadStack();
            }
            else {
                dispatchEvent( new Event(Event.COMPLETE) ); 
            }
        }
        
    }

}