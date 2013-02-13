package alternterrainxtras.util
{

	import flash.display.BitmapData;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	/**
	 * A tile-based splatterer used for shader. 1 pixel data for 1 tile. Up to 16 tile choices per atlas.
	 * @author Glenn Ko
	 */
	public class BiomePainter32 
	{
		private var atlasTilesAcrossH:int;
		private var atlasTilesAcrossV:int;
		public var errorCount:int = 0;
		
		// Differnet rotations and their reading order (English reading order left to right, top to bottom)
		private static var ROTATIONS:Vector.<int> = getRotations();
		private static var READING_ORDER4:Vector.<uint> = new <uint>[
				0, 1, 2, 3,
				2, 0, 3, 1,
				3, 2, 1, 0,
				1, 3, 0, 2
		];

		
		// RGB reading orders based on different blend scheme
		private static var READING_ORDER_RGB:Vector.<uint> = new <uint>[
				0, 0, 0,   // rrrr  - 1 = (1)
				0, 1, 2,   // rgbb  - 2 = (1x1x2)
				0, 1, 1,   // rggg  - 3 = (1x3)
				0, 0, 1,   // rrgg  - 4 = (2x2)
		];	
		
		private static function getRotations():Vector.<int>   // 90 degree rotation variations
		{
			var vec:Vector.<int> = new Vector.<int>();
			var mat:Matrix = new Matrix();
			vec.push(mat.a, mat.b, mat.c, mat.d);
			
			mat.rotate(.5*Math.PI);
			vec.push(mat.a, mat.b, mat.c, mat.d);
			
			mat.rotate(.5*Math.PI);
			vec.push(mat.a, mat.b, mat.c, mat.d);
			
			mat.rotate(.5*Math.PI);
			vec.push(mat.a, mat.b, mat.c, mat.d);
			
			// 1,0,0,1,  0,1,-1,0,  -1,0,0,-1,   0,-1,1,0
			return vec;
		}
		
		
		public function BiomePainter32(atlasTilesAcrossH:int, atlasTilesAcrossV:int) 
		{
			if (!isValidTileAtlas(atlasTilesAcrossH, atlasTilesAcrossV)) {
				throw new Error("Too many tiles exceeded 16! " + (atlasTilesAcrossH * atlasTilesAcrossV));
			}
			this.atlasTilesAcrossH = atlasTilesAcrossH;
			this.atlasTilesAcrossV = atlasTilesAcrossV;
		}

	public function writeBmpData(data:ByteArray, tileBitmap:Vector.<uint>, tilesAcross:int):void {
		data.writeShort(tilesAcross);
		var len:int = tilesAcross * tilesAcross;
		var color:uint;
		for (var i:int = 0; i < len; i++) {
			color = tileBitmap[i];
			data.writeByte( (color & 0xFF0000) >> 16 );
			data.writeByte( (color & 0xFF00) >> 8 );
			data.writeByte( (color & 0xFF)  );
		}
		//data.writeBytes( bmpData.getPixels( bmpData.rect ), data.position );
	}
	

	
	public function getBmpData(data:ByteArray):BitmapData {
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
		
		
		public function isValidTileAtlas(acrossH:int, acrossV:int):Boolean {
			return (acrossH * acrossV) <= 16;
		}
		
		
		public function getUintFromIndices(ri:uint, gi:uint, bi:uint, ki:uint, ma:int, mb:int, mc:int, md:int):uint {
			// todo later: randomize the kv coordinate
			return getUint( uint(ri % atlasTilesAcrossH) / atlasTilesAcrossH, uint(ri / atlasTilesAcrossH) / atlasTilesAcrossV,
						   uint(gi % atlasTilesAcrossH) / atlasTilesAcrossH, uint(gi / atlasTilesAcrossH) / atlasTilesAcrossV,
						    uint(bi % atlasTilesAcrossH) / atlasTilesAcrossH, uint(bi / atlasTilesAcrossH) / atlasTilesAcrossV,
							 uint(ki % atlasTilesAcrossH) / atlasTilesAcrossH, 0,
							 ma, mb, mc, md);
		}
		
		public function getUintFromIndices2(ri:uint, gi:uint, bi:uint, ki:uint, mi:uint):uint {
			// todo later: randomize the kv coordinate
			var ma:int = ROTATIONS[mi * 4];
			var mb:int = ROTATIONS[mi * 4+1];
			var mc:int = ROTATIONS[mi * 4+2];
			var md:int = ROTATIONS[mi * 4+3];
			return getUintFromIndices(ri, gi, bi, ki, ma,mb,mc,md );
		}
		/**
		 * 
		 * @param	ru	Red texture U coordinate
		 * @param	rv  Red texture V coordinate
		 * @param	gu  Green...
		 * @param	gv
		 * @param	bu  Blue...
		 * @param	bv
		 * @param	ku  Blend texture U coordinate
		 * @param	kv  Blend texture V coordinate
		 * @param	ma  Orthogonal Matrix transforms
		 * @param	mb
		 * @param	mc
		 * @param	md
		 */
		public function getUint(ru:Number, rv:Number, gu:Number, gv:Number,  bu:Number, bv:Number, ku:Number, kv:Number, ma:int, mb:int, mc:int, md:int):uint {
		  ma++; mb++; mc++; md++;
		 
		 if (ku == 0) {
			 kv = 0;
		 }
		 else {
			 kv = Math.floor( Math.random() * 5 );
			 if (kv < 4) {
				kv *= .25;
			 }
			else {
				kv = ku;
				ku = 0;
			}
		 }
    
        return  ( 0xFF000000 | (uint(ru * 4) << 22) | (uint(rv * 4) << 20) |   // Red upper 4
                (uint(gu * 4) << 18) | (uint(gv * 4) << 16) |    // Red lower 4
                (uint(bu * 4) << 14) |  (uint(bv * 4) << 12) |    // Green upper 4
                (uint(ku * 4) << 10) |  (uint(kv * 4) << 8)  |     // Green lower 4
                (uint(ma) << 6)  |   // Blue bits below for rotation transform
                (uint(mb) << 4)  |
                (uint(mc) << 2)  |
                (uint(md)) );  
		}
		
		
		public function getUint16bits(color:uint):uint {  // gets pattern layout for all 4 quad squares under tile in a 16 bit unsigned short
			var r:uint = (color & 0xFF0000) >> 16;
			var g:uint = (color & 0xFF00) >> 8;
			var b:uint = (color & 0xFF);
			
			var ru:uint = (r & 192) >> 6;
			var rv:uint = (r & 48) >> 4;

			var gu:uint = (r & 12) >> 2;
			var gv:uint = (r & 3);
			
			var bu:uint = (g & 192) >> 6;
			var bv:uint = (g & 48) >> 4;
			
			
			//blend index
			var ku:int = (g & 12) >> 2;
			var kv:int = (g & 3);
			if (ku == 0 && kv > 0) {
				ku = kv;
			}
		
			// reading order transform index (0-3)
			var ma:int = (b & 192) >> 6;
			var mb:int = (b & 48) >> 4;
			var mc:int = (b & 12) >> 2;
			var md:int = (b & 3);
			ma--; mb--; mc--; md--;
			var tindex:int = ma === 1 ? 0 : mc === -1 ? 1 : ma === -1 ? 2  : 3;
			
			var readRGB:Vector.<uint> = READING_ORDER_RGB;
			var readSquares:Vector.<uint> = READING_ORDER4;
			
			var u:uint;
			var v:uint;
			var rr:int;
			
			var result:uint = 0xFF000000;
			
			var i:uint;
			
			i = (readSquares[tindex * 4]); if (i > 2) i = 2;
			i = ku * 3 + i ;
			rr = readRGB[i];
			u = rr === 0 ? ru : rr === 1 ? gu : bu;
			v = rr === 0 ? rv : rr === 1 ? gv : bv;
			result |= uint(v * .25 * atlasTilesAcrossV  * atlasTilesAcrossH + u * .25 * atlasTilesAcrossH) << 0;
			
			i = (readSquares[tindex * 4 + 1]); if (i > 2) i = 2;
			i = ku * 3 + i;
			rr = readRGB[i];
			u = rr === 0 ? ru : rr === 1 ? gu : bu;
			v = rr === 0 ? rv : rr === 1 ? gv : bv;
			result |= uint(v * .25 * atlasTilesAcrossV  * atlasTilesAcrossH + u * .25 * atlasTilesAcrossH) << 4;
			
			i = (readSquares[tindex * 4 + 2]); if (i > 2) i = 2;
			i = ku * 3 + i;
			rr = readRGB[i];
			u = rr === 0 ? ru : rr === 1 ? gu : bu;
			v = rr === 0 ? rv : rr === 1 ? gv : bv;
			result |= uint(v * .25 * atlasTilesAcrossV  * atlasTilesAcrossH + u * .25 * atlasTilesAcrossH) << 8;
			
			i = (readSquares[tindex * 4 + 3]); if (i > 2) i = 2;
			i = ku * 3 + i;
			rr = readRGB[i];
			u = rr === 0 ? ru : rr === 1 ? gu : bu;
			v = rr === 0 ? rv : rr === 1 ? gv : bv;
			result |= uint(v * .25 * atlasTilesAcrossV  * atlasTilesAcrossH + u * .25 * atlasTilesAcrossH) << 12;
			
			
			
			return result;
		}
		
		private function getIdentityValue(s1:uint, s2:uint, s3:uint):uint {
			var result:uint = 0xFF000000;
			result |= (s1 << 0);
			result |= (s2 << 4);
			result |= (s3 << 8);
			result |= (s3 << 12);
			return result;
		}
		
		private function identifyTransform(s1:uint, s2:uint, s3:uint, layout16:uint):uint {
			var result:uint;
			
			
				/*
				0, 1, 2, 3,
				2, 0, 3, 1,
				3, 2, 1, 0,
				1, 3, 0, 2
				*/
			result = 0xFF000000;
			result |= (s1 << 0);
			result |= (s2 << 4);
			result |= (s3 << 8);
			result |= (s3 << 12);
			if (result == layout16) return 0;
			
			result = 0xFF000000;
			result |= (s3 << 0);
			result |= (s1 << 4);
			result |= (s3 << 8);
			result |= (s2 << 12);
			if (result == layout16) return 1;
			
			result = 0xFF000000;
			result |= (s3 << 0);
			result |= (s3 << 4);
			result |= (s2 << 8);
			result |= (s1 << 12);
			if (result == layout16) return 2;
			
			result = 0xFF000000;
			result |= (s2 << 0);
			result |= (s3 << 4);
			result |= (s1 << 8);
			result |= (s3 << 12);
			if (result == layout16) return 3;
			

			return 0xFFFFFFFF;
		
		}
		
		private function setUint16bits(result:uint):uint {
			
			var dict:Dictionary = new Dictionary();
			var val:uint;
			var u:Number;
			var v:Number;
			
			var readOrderRGB:Vector.<uint> = READING_ORDER_RGB;
			var readOrderSquares:Vector.<uint> = READING_ORDER4;
			var mValues:Vector.<int> = ROTATIONS;
			var m:int;
	

			// determine blend pattern scheme index to use
			val = result & 0xF;
			if ( dict[val] == null) dict[val] = 1
			else dict[val]++;
			
			val = (result & 0xF0) >> 4;
			if ( dict[val] == null) dict[val] = 1
			else dict[val]++;
			
			val =(result & 0xF00) >> 8;
			if ( dict[val] == null) dict[val] = 1
			else dict[val]++;
			
			val = (result & 0xF000) >> 12;
			if ( dict[val] == null) dict[val] = 1
			else dict[val]++;
			
			var count:int = 0;
			var multiplier:int = 1;
			for (var p:* in dict) {
				multiplier *= dict[p]
				count++;
			}
			
			var unique:int;
			var unique2:int;
			var swapVal:uint;
			var swapVal2:uint;
			var swappables:uint;
			var ti:uint;
			
			if (count != 1) {
				var blendIndex:int = multiplier - 1;
				
				if (blendIndex === 0) {
					throw new Error("This should never happen under count!=1 case!")
				}
				else if (blendIndex === 1) {  //rgbb
					// find unique b
					unique = -1;
					count = 0;
					swappables = 0xFF000000;
					for (p in dict) {
						if (dict[p] === 2) {
							unique = p;		
						}
						else {
							swappables |= (uint(p) << ((count++) << 2)); 
						}
					}
					if (unique < 0) throw new Error("Could not find unique under blend index 1");
					ti = identifyTransform( swapVal=(swappables & 0xF),  swapVal2=((swappables & 0xF0) >> 4), unique, result);
					if (ti ===0xFFFFFFFF) ti = identifyTransform( swapVal=(((swappables & 0xF0) >> 4)), swapVal2=(swappables & 0xF), unique, result);
					if (ti === 0xFFFFFFFF) {
						errorCount++;
						return 0xFFFFFFFF;						
						throw new Error("Could not find valid transform index for blendIndex 1"+":"+getIdentityValue(swapVal, swapVal2, unique) + ", "+result + ", s1:"+swapVal + " s2:"+swapVal2 + " u:"+unique);
					}
					ti *= 4;
					return getUintFromIndices(swapVal, swapVal2, unique, blendIndex, mValues[ti], mValues[ti + 1], mValues[ti + 2], mValues[ti + 3]);
				}
				else if (blendIndex === 2) {  // rggg
					// find unique r and unique g
					unique = -1;
					unique2 = -1;
					count = 0;
					for (p in dict) {
						if (dict[p] === 3) {
							unique2 = p;	
						}
						else if (dict[p] === 1) {
							unique = p;
						}
					}
					if (unique < 0 || unique2 < 0) throw new Error("Could not find uniques under blend index 2");
				
					ti = identifyTransform(unique, unique2, unique2, result);
					//throw new Error(unique + ", " + unique2 + ", "+getIdentityValue(unique, unique2, unique2));
					if (ti === 0xFFFFFFFF) {
						errorCount++;
						return 0xFFFFFFFF;
						throw new Error("Could not find valid transform index for blendIndex 2");
					}
					ti *= 4;
					
					return getUintFromIndices(unique, unique2, 0, blendIndex, mValues[ti], mValues[ti + 1], mValues[ti + 2], mValues[ti + 3]);
				}
				else {  //rrgg
					count = 0;
					swappables = 0xFF000000;
					for (p in dict) {
						swappables |= ( uint(p) << ((count++) << 2) ); 
					}
					ti = identifyTransform( swapVal = (swappables & 0xF), (swappables & 0xF), swapVal2=(((swappables & 0xF0) >> 4)), result);
					if (ti ===0xFFFFFFFF) ti = identifyTransform( swapVal=(((swappables & 0xF0) >> 4)), (((swappables & 0xF0) >> 4)), swapVal2=(swappables & 0xF), result);
					if (ti === 0xFFFFFFFF) {
						errorCount++;
						return 0xFFFFFFFF;
						throw new Error("Could not find valid transform index for blendIndex "+blendIndex+":"+getIdentityValue(swapVal, swapVal, swapVal2) + ", "+result + ", s1:"+swapVal + " s2:"+swapVal2);
					}
					ti *= 4;
					
					return getUintFromIndices(swapVal, swapVal2, 0, blendIndex, mValues[ti], mValues[ti + 1], mValues[ti + 2], mValues[ti + 3]);
				}
			}
			else {  // using all 4s

				v = int(val / atlasTilesAcrossH) / atlasTilesAcrossV;
				u = int(val % atlasTilesAcrossH) / atlasTilesAcrossH;
				return getUint(u, v, u, v, u, v, 0, 0, mValues[0], mValues[1], mValues[2], mValues[3]);
			}
			
			throw new Error("Failed to get valid value case!");
			return 0xFFFFFFFF;
		}
		
		
		

		/**
		 * 
		 * @param	tileMap		The tilemap (reading bitmapdata order for getVector()/setVector() )
		 * @param	tilesAcross  The number of tiles across the tile map
		 * @param	tileIndex   Zero-based tile index indicating what tile to paint (Left-to-right/Top-to-bottom index reading order on atlas)
		 * @param	x			Tile index x location
		 * @param	y			Tile index y location
		 */	
		public function paintToTileMap(tileMap:Vector.<uint>, tilesAcross:int, tileIndex:uint, x:int, y:int):void {
			var xi:int;
			var yi:int;
			
			var val16:uint;
			var testVal:uint;
			// todo: consider wrapping
			
			tileMap[y * tilesAcross + x] = getUintFromIndices(tileIndex, tileIndex, tileIndex, 0, 1, 0, 0, 1);
			
					var lastIndex:int = -1;
			xi = x -1;
			yi = y - 1;
			if (xi >= 0 && xi < tilesAcross && yi >= 0 && yi < tilesAcross) { 
			
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
			//	testVal = setUint16bits(val16);
			//	if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 0!"+tileMap[yi * tilesAcross + xi] + ", "+testVal+", "+lastIndex + ", "+(yi * tilesAcross + xi));
				val16 &= ~(0xF000);
				val16 |= (tileIndex << 12);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			
			}
			
			xi = x;
			yi = y - 1;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
				//testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 1!"+val16 + ", "+lastIndex + ", "+(yi * tilesAcross + xi));
				val16 &= ~(0xFF00);
				val16 |= (tileIndex << 12);
				val16 |= (tileIndex << 8);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x +1;
			yi = y -1;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
				testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 2!");
				val16 &= ~(0xF00);
				val16 |= (tileIndex << 8);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x - 1;
			yi = y;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
				//testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 3!");
				val16 &= ~(0xF0F0);
				val16 |= (tileIndex << 4);
				val16 |= (tileIndex << 12);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x +1;
			yi = y;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
			//	testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 4!");
				val16 &= ~(0xF0F);
				val16 |= tileIndex;
				val16 |= (tileIndex << 8);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x -1;
			yi = y + 1;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
				//testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 5!");
				val16 &= ~(0xF0);
				val16 |= (tileIndex << 4);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x;
			yi = y + 1;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
			//	testVal = setUint16bits(val16);
			//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 6!");
				val16 &= ~(0xFF);
				val16 |= (tileIndex << 4);
				val16 |= (tileIndex);
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
			xi = x + 1;
			yi = y + 1;
			if (xi >= 0 && xi < tilesAcross && yi >=0 && yi < tilesAcross) { 
				val16 = getUint16bits( tileMap[yi * tilesAcross + xi] );
				//testVal = setUint16bits(val16);
				//if (testVal != tileMap[yi * tilesAcross + xi]) throw new Error("MISMATCH 7!");
				val16 &= ~(0xF);
				val16 |= tileIndex;
				
				testVal =  setUint16bits(val16);
				if (testVal != 0xFFFFFFFF) tileMap[yi * tilesAcross + xi] = testVal;
			}
			
	
		}
		
	
	}

}