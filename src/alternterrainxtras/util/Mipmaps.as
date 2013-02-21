package alternterrainxtras.util 
{
	import flash.display.BitmapData;
	import flash.filters.ConvolutionFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	/**
	 * Utility to help create/bake mipmaps.
	 * @author Glenn Ko
	 */
	public class Mipmaps {
        public var mipMap:Vector.<BitmapData>;
        private var _texture:BitmapData;
        public var numMaps:int = 0;
        public var mipmapUVCap:Number = 1;
        
            static private const filter:ConvolutionFilter = new ConvolutionFilter(2, 2, [1, 1, 1, 1], 4, 0, false, true);
            static private const matrix:Matrix = new Matrix(0.5, 0, 0, 0.5);
            static private const rect:Rectangle = new Rectangle();
            static private const point:Point = new Point();
            
        public function Mipmaps(texture:BitmapData = null):void {
            if (texture != null) this.texture = texture;
        }
        
            public function calculateMipMaps():void {
                point.x = 0;
                point.y = 0;
                
                mipMap = new Vector.<BitmapData>();
                numMaps = 0;
                mipMap[numMaps] = _texture;
                numMaps++;
                if (_texture.width % 2 > 0 || _texture.height % 2 > 0) {
                    throw new Error("Texture must be base2 size");
                }
                matrix.identity();
                matrix.a = 0.5;
                matrix.d = 0.5;
                filter.preserveAlpha = !_texture.transparent;
                var bmp:BitmapData = (_texture.width*_texture.height > 16777215) ? _texture.clone() : new BitmapData(_texture.width, _texture.height, _texture.transparent);
                var current:BitmapData = _texture;
                rect.x = 0;
                rect.y = 0;
                rect.width = _texture.width;
                rect.height = _texture.height;
                
                while (rect.width % 2 == 0 && rect.height % 2 == 0) {
                    
                  bmp.applyFilter(current, rect, point, filter);
                  // bmp.copyPixels(current, rect, point)
                    rect.width /= 2;
                    rect.height /= 2;
                    current = new BitmapData(rect.width, rect.height, _texture.transparent, 0);
                    current.draw(bmp, matrix, null, null, null, false);
                
                    mipMap[numMaps] = current;
                    numMaps++;
                }
				
                bmp.dispose();
            }
            
            public function getMipmapOffsetTable():BitmapData {
                if (numMaps == 0) throw new Error("No mipmaps found!");
                var tileSizePx:int = _texture.width;
                var w:int = isPower2(numMaps) ? numMaps :  (1 << ( Math.round( Math.log( numMaps) * Math.LOG2E ) ) ); 
                var r:int = 255;    // tilesize ratio  (1, .5, .25)
                var g:int = 0;    // u offset as a ratio of tile size  
                var b:int = 0;  // whether there is a base u offset ratio of tilesizePx
                var t:int = tileSizePx;
                var bmpData:BitmapData = new BitmapData( w, 1, false, RGBToHex(r, g, b) );
                mipmapUVCap = numMaps / w;
                
                var offset:int = 0;
                for (var i:int = 1; i < numMaps; i++) {
                    r = int ( mipMap[i].width / tileSizePx * 256 );  // as a ratio of base tile size
                    t >>= 1;
                    
                 
                    g = int( offset / tileSizePx * 256 );
                    offset += t;
                    b = 255;
                    //if (i == 2) throw new Error([r, g, b]);

                    bmpData.setPixel(i, 0, RGBToHex(r, g, b) );
                }
                while ( i < bmpData.width) {
                    bmpData.setPixel(i, 0, RGBToHex(r, g, b) );
                
                    i++;
                }
                return bmpData;
            }
            
            public function pasteMipmaps(dest:BitmapData, destPt:Point):void {
                if (numMaps == 0) throw new Error("No mipmaps found!");
                var p:Point = point;
                var r:Rectangle = rect;
                
                p.x = destPt.x;
                p.y = destPt.y;
                r.x = 0;
                r.y = 0;
                r.width = _texture.width;
                r.height = _texture.height;
                for (var i:int = 1; i < numMaps; i++) {
                    var src:BitmapData = mipMap[i];
                    r.width *= .5;
                    r.height *= .5;
                    dest.copyPixels(src, r, p);
                    p.x += r.width;
                  
                }
				src = mipMap[numMaps - 1];
				dest.copyPixels(src, r, p);
                
				
            }
            
            private function RGBToHex(r:int, g:int, b:int):uint
            {
            var hex:uint =  ( r << 16 ) | ( g << 8 ) | b;

            return hex;
            }
            
            public function isPower2(x:int):Boolean {
                return (!((~0) ^ (~x + 1)));
            }
            
            public function get texture():BitmapData 
            {
                return _texture;
            }
            
            public function set texture(value:BitmapData):void 
            {
                _texture = value;
                calculateMipMaps();
            }
        
        
    }

}