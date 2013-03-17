/**
     * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
     * If it is not possible or desirable to put the notice in a particular file, then You may include the notice in a location (such as a LICENSE file in a relevant directory) where a recipient would be likely to look for such a notice.
     * You may add additional accurate notices of copyright ownership.
     *
     * It is desirable to notify that Covered Software was "Powered by AlternativaPlatform" with link to http://www.alternativaplatform.com/ 
     * */

package alternterrainxtras.materials {
	
        import alternativa.engine3d.alternativa3d;
        import alternativa.engine3d.core.Camera3D;
        import alternativa.engine3d.core.DrawUnit;
        import alternativa.engine3d.core.Light3D;
        import alternativa.engine3d.core.Object3D;
        import alternativa.engine3d.core.Renderer;
        import alternativa.engine3d.core.Transform3D;
        import alternativa.engine3d.core.VertexAttributes;
        import alternativa.engine3d.lights.DirectionalLight;
        import alternativa.engine3d.lights.OmniLight;
        import alternativa.engine3d.lights.SpotLight;
        import alternativa.engine3d.materials.A3DUtils;
        import alternativa.engine3d.materials.compiler.Linker;
        import alternativa.engine3d.materials.compiler.Procedure;
        import alternativa.engine3d.materials.compiler.VariableType;
        import alternativa.engine3d.materials.Material;
        import alternativa.engine3d.materials.NormalMapSpace;
        import alternativa.engine3d.materials.TextureMaterial;
        import alternativa.engine3d.objects.Surface;
        import alternativa.engine3d.resources.BitmapTextureResource;
        import alternativa.engine3d.resources.Geometry;
        import alternativa.engine3d.resources.TextureResource;
		import flash.display.BitmapData;

		import alternativa.engine3d.materials.TextureMaterial;
        import avmplus.getQualifiedClassName;

        import flash.display3D.Context3D;
        import flash.display3D.Context3DBlendFactor;
        import flash.display3D.Context3DProgramType;
        import flash.display3D.Context3DVertexBufferFormat;
        import flash.display3D.VertexBuffer3D;
        import flash.utils.Dictionary;
        import flash.utils.getDefinitionByName;

        use namespace alternativa3d;

        /**
         * This modified StandardMaterial fills a surface with varying square bitmap image tiles by looking up a texture from a regular tile sprite-sheet atlas.  Selection of tile is based on a set of uploaded
         * bitmaps containing the information on where to locate the tile in the atlas. The material  also intends to support orthogonal rotation of tiles (ie, rotation tranform index), using the RGB channels respectively).
         * This material is mainly used for opaque tile-based terrain and floors with a variety of pre-built patterns.
         * 
         * @author Glenn 
         */
        public class TileAtlasMaterial extends TextureMaterial  {

            protected static const LIGHT_MAP_BIT:int = 1;
            protected static const GLOSSINESS_MAP_BIT:int = 2;
            protected static const SPECULAR_MAP_BIT:int = 4;
            protected static const OPACITY_MAP_BIT:int = 8;
			private static const WATER_BIT:int = 16;
			
            protected static const NORMAL_MAP_SPACE_OFFSET:int = 4;    // shift value
            protected static const ALPHA_TEST_OFFSET:int = 6;
            protected static const OMNI_LIGHT_OFFSET:int = 8;
            protected static const DIRECTIONAL_LIGHT_OFFSET:int = 11;
            protected static const SPOT_LIGHT_OFFSET:int = 14;
            protected static const SHADOW_OFFSET:int = 17;
            // TODO: remove double cash by transform procedure. It increase speed by 1%
    //        protected static const OBJECT_TYPE_BIT:int = 19;

            protected static var caches:Dictionary = new Dictionary(true);
            protected var cachedContext3D:Context3D;
            protected var programsCache:Dictionary;
            protected var groups:Vector.<Vector.<Light3D>> = new Vector.<Vector.<Light3D>>();
			
			protected var _waterMode:int = 0;
			protected var _useWaterMode:int = 0;
			public var waterLevel:Number = 0;
			
			// integer UV coodrinate offset
			public var uvOffsetX:Number = 0;
			public var uvOffsetY:Number = 0;
			
		// KIL water level fragment shader - waterMode = 1
		private static const kilWaterLevel:Procedure = new Procedure([
			"#c0=cWater",
			"#v0=vPosition",
			"sub t0.z, v0.z, c0.z",
			"kil t0.z"
		], "kilWaterLevel");
            
    static alternativa3d const _passUVProcedure:Procedure = new Procedure(["#v0=vUV", "#v1=vUV1", "#a0=aUV", "#c0=cUVProperties", 
		"mov t0, a0",
		"mul t0.xy, t0.xy, c0.ww",
		"add t0.xy, t0.xy, c0.xy",
		"mov v0, t0",   // integer UV coordinate for tile mapping (diffuse map)
		"mul t0.xy, a0.xy, c0.ww",  
		"add t0.xy, t0.xy, c0.xy", // normalized UV coordinate for normal/light maps
		"mul v1, t0.xy, c0.zz",
		], 
		"passUVProcedure");
                    
                    
            /**
             * @protected
             * Procedure for diffuse map texture atlas with alpha channel and custom per-pixel mipmapping uv offsets
             */
            ///*
           static alternativa3d const getDiffuseProcedure:Procedure = new Procedure([
            
                "#v0=vUV",
                "#v1=vDistance",
                "#s0=sDiffuse",
                "#s1=sTileIndices",    // sample texture index for tile indices
                "#s2=sMipmapOffsets", 
                "#s3=sBlendAtlas", 
                "#c0=cThresholdAlpha",
                "#c1=cTilePaddSize",
                "#c2=cTileFrac",   //       1/ noTilesAcross   u and v directions,    +  tileSizeWidth and tileSizeHeight in UV coordinates within atlas
                "#c3=cF",  //(f=camera.focalLength / resolution,  totalMipmaps, mipmapUVCap, 1)
                "#c4=cAtlasTiles",
                "#c5=c255",  // required to fix fractionals x/255 * 256.
                //"mov t1, c5",  // dummy usage if needed
                "mov t1, v0", 
				"frc t0.xy, t1.xy",
				"sub t1.xy, t1.xy, t0.xy",
				"mul t1.xy, t1.xy, c2.xy",
                "tex t1, t1, s1 <2d,nearest,clamp,nomip>",   // sample t1 tile index lookup
                "mul t1.xyz, t1.xyz, c5.xxx",   // fix fractionals
                "mul t1.xyz, t1.xyz, c5.www",
                // Find t2 transform
                "mul t0.z, t1.z, c4.z",
                "frc t0.w, t0.z",  // right half 4 bits (to split later.)
                "sub t0.z, t0.z, t0.w",
                "mul t0.z, t0.z, c4.w",  // left half 4 bits
                "mul t0.z, t0.z, c4.x",  // split left half of 4 bits
                "frc t1.w, t0.z",   // right half 2 bits  (b)
                "sub t0.z, t0.z, t1.w",
                //"mul t0.z, t0.z, c4.y",  // left half 2 bits  (a)
                // finalise right half of 2 bits ~(b)~ as a value of either: -1, 0, 1, 2
                "mul t1.w, t1.w, c4.x",
                "sub t2.y, t1.w, c3.w",
                // finalise left half of 2 bits ~(a)~ as a value of either: -1, 0, 1, 2
                //"mul t0.z, t0.z, c4.x",
                "sub t2.x, t0.z, c3.w",
    
                "mul t0.w, t0.w, c4.x",  // split right half of 4 bits (finally..)
                "frc t1.w, t0.w",  // right half 2 bits (d)
                "sub t0.w, t0.w, t1.w",  
                //"mul t0.w, t0.w, c4.y",   // left half 2 bits  (c)
                // finalise right half of 2 bits ~(d)~ as a value of either: -1, 0, 1, 2
                "mul t1.w, t1.w, c4.x",
                "sub t2.w, t1.w, c3.w",
                // finalise left half of 2 bits ~(c)~ as a value of either: -1, 0, 1, 2
                //"mul t0.w, t0.w, c4.x",
                "sub t2.z, t0.w, c3.w",
                
                
                "mov t0, v0",  // dummy usage required somehow.
				
                // ------     get normalized tile-based uv offsets with fractionals (t0)
               // "div t0.xy, t0.xy, c2.xy",  
                "frc t0.xy, t0.xy", 
                 // Pseudo-dp2 operations: rotate t0.xy vector by t2 matrix (using a .5 constant for c5.y register)
                 "sub t0.xy, t0.xy, c5.yy",  // from .5 mark
                // /*
                "mul t0.z, t0.x, t2.x",
                "mul t0.w, t0.y, t2.y",
                "add t0.z, t0.z, t0.w",   // result for t0.x transformed.
                
                "mul t0.w, t0.x, t2.z",
                "mul t0.y, t0.y, t2.w",
                "add t0.y, t0.w, t0.y",  // result for t0.y transformed.
                
                "mov t0.x, t0.z",
                //*/
                "add t0.xy, t0.xy, c5.yy",  // end .5 mark
			
                
                // now calculate mipmap level ( t2 can be resued again)
                "mov t2, v1",  
                "div t2.x, t2.z, c3.x",  // Calculate mipmap level manually per pixel  (z >= f) ?  (log(z/f)) : 0;
                "log t2.x, t2.x",   // binary log
                "frc t2.y, t2.x",  // round down
                "sub t2.x, t2.x, t2.y",  
                
                "div t2.x, t2.x, c3.y",   // get uv sample ratio of current mipmap level against total mipmaps
                "mul t2.x, t2.x, c3.z",  // clamp ratio to base uv cap amount
                
                "tex t2, t2, s2 <2d,nearest,clamp,nomip>",  // sample mipmap level offset lookup  // assume t2.zw ignored ?
                "mul t2.y, t2.y, c2.z", // as actual u offset value
                "mul t2.w, t2.z, c2.z",   // this value is either zero or 1*tileSize, depending on t2.z is either zero or 1.
                "add t2.y, t2.y, t2.w",  // last operand should be t2.w (mipmap offset for u)
                
                "mul t2.z, c2.z, t2.x",  // take into consideration tile size reduction due to mipmapping
                "mul t2.w, c2.w, t2.x",
				
				
                "div t0.z, c1.x, t2.x",  // clamp normalized uvs according to mipmap level
				"min t0.z, t0.z, c5.y",
				
				"sub t0.w, c3.w, t0.z",
				"min t0.xy, t0.xy, t0.ww",
				"max t0.xy, t0.xy, t0.zz",
				
                "mul t0.x, t0.x, t2.z",      // normalized tile-based uv offset * tile uv size on atlas . 
                "mul t0.y, t0.y, t2.w",      // normalized tile-based uv offset * tile uv size on atlas . 
				
                "add t0.x, t0.x, t2.y",    // add mipmap offset 
                // t0, t1 reserved!
			
  
                // Find t0-t2.w, from t2.xyz: blend intensities 
                "mul t1.z, t1.y, c4.z",
                "frc t2.w, t1.z",  // right half 4 bits (blend uv tile)
    
                "sub t1.z, t1.z, t2.w",  
                "mul t1.z, t1.z, c4.w",       // the left half of 4 bits (to consider later for the B color sample)
                
                "mul t2.w, t2.w, c4.x", // split right half of 4 bits
                "frc t2.y, t2.w",  // right half of 2 bits (v)  // This seems wrong, the fractional returns a high value!
                "sub t2.w, t2.w, t2.y",
                "mul t2.x, t2.w, c4.y",  // left half of 2 bits (u)
            
                "add t2.xy, t2.xy, t0.xy",
                "tex t2, t2, s3 <2d, linear,clamp, nomip>",  // assume t2.zw ignored
	
              
                ///*   // Run blending for all 3 textures
                "mov t0.w, t2.x",
                "mov t1.w, t2.y",
                "mov t2.w, t2.z",   // derived ratios from t2 isn't normalized! Please check!
                
                // Merge all 3 colors
                //  t1.z and t1.y, will be FREE after unpacking Blue, t1.xy occupied.  t2.xyz occupied. t0-2.w occupied. t0.xy occupied. t0.z is FREE.
                
                // Finalise t2.xyzw output color
                
                // Sample and Add B
                // split left half of 2 bits
                "mul t1.z, t1.z, c4.x",
                "frc t0.z, t1.z",   // v coordinate
                "sub t1.z, t1.z, t0.z",
                "mul t1.z, t1.z, c4.y",   // u coordinate
                
                "add t0.x, t0.x, t1.z", // we need to temporarily sample with t0 first, since t1 must be kept intact for now
                "add t0.y, t0.y, t0.z", 
                "mov t1.y, t2.w",  // required last minute move because t2.w will be cancelled away when sampling with it (check if needed again..)
                
                "tex t2, t0, s0 <2d, linear,clamp, nomip>",   // assumed t0.zw ignored.  t2 only works now, but later need to maintain t2 state for addiitive blending!
                "sub t0.x, t0.x, t1.z",  // (due to lack of registers) hack to restore back original values for t0 variable.
                "sub t0.y, t0.y, t0.z",
                "mul t2.xyz, t2.xyz, t1.yyy",    // the starting t2 value. t2.xyz is locked from now onwards
                
                //t1.y is free, t1.z is free,    t2.w is free
                // move t1.x to t1.z, in order to sample r with t1.xy register, while maintaining reference to t2 color
                "mov t1.z, t1.x",
                
                //  Sample and Add R
                "mul t1.x, t1.z, c4.z",
                "frc t2.w, t1.x",  // right 4 bits (for G sample)
                "sub t1.x, t1.x, t2.w",
                "mul t1.x, t1.x, c4.w",  // left 4 bits (for R sample)
                "mul t1.x, t1.x, c4.x", // split left 4 bits
                "frc t1.y, t1.x",     //  v sample
                "sub t1.x, t1.x, t1.y",
                "mul t1.x, t1.x, c4.y",  // u sample
                "add t1.xy, t1.xy, t0.xy",
                // t2.w must be kep3t!  // t1 will be gone! // t0.xy taken, t0.w taken. t0.z??, t2.xyz must be kept
                "mov t0.z, t2.w",  // required last minute move to ensure t2.w value is maintained for G sample later.
                
                "mov t2.w, t1.w", // required last minute move because t1.w will be cancelled when sampling with it (check again if needed0
                "tex t1, t1, s0 <2d, linear,clamp, nomip>", 
                "mul t1.xyz, t1.xyz, t0.www",
               "add t2.xyz, t2.xyz, t1.xyz",
                
                //  Sample and Add G   
                "mul t1.x, t0.z, c4.x", // split right 4 bits
                "frc t1.y, t1.x",  // v sample
                "sub t1.x, t1.x, t1.y",
                "mul t1.x, t1.x, c4.y",  // u sample
                "add t1.xy, t1.xy, t0.xy", 
                "tex t1, t1, s0 <2d, linear,clamp, nomip>", 
                "mul t1.xyz, t1.xyz, t2.www",
               "add t2.xyz, t2.xyz, t1.xyz",
                
                "mov t2.w, c3.w", //ensure alpha 1
                "mul t2.w, t2.w, c0.w", // multiplied by alpha setting
                
                "mov o0, t2"  
            //    */
            ], "getDiffuseProcedure");
            //*/
            

            /**
             * @protected
             * Procedure for diffuse with opacity map.
             */
            static alternativa3d const getDiffuseOpacityProcedure:Procedure = new Procedure([   // TODO: (if needed).   Most cases i'm dealing with fully opaque textures only.
                 "#v0=vUV",
				 "#v2=vUV1",
                "#v1=vDistance",
                "#s0=sDiffuse",
                "#s1=sTileIndices",    // sample texture index for tile indices
                "#s2=sMipmapOffsets", 
                "#s3=sBlendAtlas", 
				"#s4=sOpacity", 
                "#c0=cThresholdAlpha",
                "#c0=cThresholdAlpha",
                "#c1=cTilePaddSize",
                "#c2=cTileFrac",   //       1/ noTilesAcross   u and v directions,    +  tileSizeWidth and tileSizeHeight in UV coordinates within atlas
                "#c3=cF",  //(f=camera.focalLength / resolution,  totalMipmaps, mipmapUVCap, 1)
                "#c4=cAtlasTiles",
                "#c5=c255",  // required to fix fractionals x/255 * 256.
                //"mov t1, c5",  // dummy usage if needed
                "mov t1, v0", 
				"frc t0.xy, t1.xy",
				"sub t1.xy, t1.xy, t0.xy",
				"mul t1.xy, t1.xy, c2.xy",
                "tex t1, t1, s1 <2d,nearest,clamp,nomip>",   // sample t1 tile index lookup
                "mul t1.xyz, t1.xyz, c5.xxx",   // fix fractionals
                "mul t1.xyz, t1.xyz, c5.www",
                // Find t2 transform
                "mul t0.z, t1.z, c4.z",
                "frc t0.w, t0.z",  // right half 4 bits (to split later.)
                "sub t0.z, t0.z, t0.w",
                "mul t0.z, t0.z, c4.w",  // left half 4 bits
                "mul t0.z, t0.z, c4.x",  // split left half of 4 bits
                "frc t1.w, t0.z",   // right half 2 bits  (b)
                "sub t0.z, t0.z, t1.w",
                //"mul t0.z, t0.z, c4.y",  // left half 2 bits  (a)
                // finalise right half of 2 bits ~(b)~ as a value of either: -1, 0, 1, 2
                "mul t1.w, t1.w, c4.x",
                "sub t2.y, t1.w, c3.w",
                // finalise left half of 2 bits ~(a)~ as a value of either: -1, 0, 1, 2
                //"mul t0.z, t0.z, c4.x",
                "sub t2.x, t0.z, c3.w",
    
                "mul t0.w, t0.w, c4.x",  // split right half of 4 bits (finally..)
                "frc t1.w, t0.w",  // right half 2 bits (d)
                "sub t0.w, t0.w, t1.w",  
                //"mul t0.w, t0.w, c4.y",   // left half 2 bits  (c)
                // finalise right half of 2 bits ~(d)~ as a value of either: -1, 0, 1, 2
                "mul t1.w, t1.w, c4.x",
                "sub t2.w, t1.w, c3.w",
                // finalise left half of 2 bits ~(c)~ as a value of either: -1, 0, 1, 2
                //"mul t0.w, t0.w, c4.x",
                "sub t2.z, t0.w, c3.w",
                
                
                "mov t0, v0",  // dummy usage required somehow.
				
                // ------     get normalized tile-based uv offsets with fractionals (t0)
               // "div t0.xy, t0.xy, c2.xy",  
                "frc t0.xy, t0.xy", 
                 // Pseudo-dp2 operations: rotate t0.xy vector by t2 matrix (using a .5 constant for c5.y register)
                 "sub t0.xy, t0.xy, c5.yy",  // from .5 mark
                // /*
                "mul t0.z, t0.x, t2.x",
                "mul t0.w, t0.y, t2.y",
                "add t0.z, t0.z, t0.w",   // result for t0.x transformed.
                
                "mul t0.w, t0.x, t2.z",
                "mul t0.y, t0.y, t2.w",
                "add t0.y, t0.w, t0.y",  // result for t0.y transformed.
                
                "mov t0.x, t0.z",
                //*/
                "add t0.xy, t0.xy, c5.yy",  // end .5 mark
			
                
                // now calculate mipmap level ( t2 can be resued again)
                "mov t2, v1",  
                "div t2.x, t2.z, c3.x",  // Calculate mipmap level manually per pixel  (z >= f) ?  (log(z/f)) : 0;
                "log t2.x, t2.x",   // binary log
                "frc t2.y, t2.x",  // round down
                "sub t2.x, t2.x, t2.y",  
                
                "div t2.x, t2.x, c3.y",   // get uv sample ratio of current mipmap level against total mipmaps
                "mul t2.x, t2.x, c3.z",  // clamp ratio to base uv cap amount
                
                "tex t2, t2, s2 <2d,nearest,clamp,nomip>",  // sample mipmap level offset lookup  // assume t2.zw ignored ?
                "mul t2.y, t2.y, c2.z", // as actual u offset value
                "mul t2.w, t2.z, c2.z",   // this value is either zero or 1*tileSize, depending on t2.z is either zero or 1.
                "add t2.y, t2.y, t2.w",  // last operand should be t2.w (mipmap offset for u)
                
                "mul t2.z, c2.z, t2.x",  // take into consideration tile size reduction due to mipmapping
                "mul t2.w, c2.w, t2.x",
				
				
                "div t0.z, c1.x, t2.x",  // clamp normalized uvs according to mipmap level
				"min t0.z, t0.z, c5.y",
				
				"sub t0.w, c3.w, t0.z",
				"min t0.xy, t0.xy, t0.ww",
				"max t0.xy, t0.xy, t0.zz",
				
                "mul t0.x, t0.x, t2.z",      // normalized tile-based uv offset * tile uv size on atlas . 
                "mul t0.y, t0.y, t2.w",      // normalized tile-based uv offset * tile uv size on atlas . 
				
                "add t0.x, t0.x, t2.y",    // add mipmap offset 
                // t0, t1 reserved!
			
  
                // Find t0-t2.w, from t2.xyz: blend intensities 
                "mul t1.z, t1.y, c4.z",
                "frc t2.w, t1.z",  // right half 4 bits (blend uv tile)
    
                "sub t1.z, t1.z, t2.w",  
                "mul t1.z, t1.z, c4.w",       // the left half of 4 bits (to consider later for the B color sample)
                
                "mul t2.w, t2.w, c4.x", // split right half of 4 bits
                "frc t2.y, t2.w",  // right half of 2 bits (v)  // This seems wrong, the fractional returns a high value!
                "sub t2.w, t2.w, t2.y",
                "mul t2.x, t2.w, c4.y",  // left half of 2 bits (u)
            
                "add t2.xy, t2.xy, t0.xy",
                "tex t2, t2, s3 <2d, linear,clamp, nomip>",  // assume t2.zw ignored
	
              
                ///*   // Run blending for all 3 textures
                "mov t0.w, t2.x",
                "mov t1.w, t2.y",
                "mov t2.w, t2.z",   // derived ratios from t2 isn't normalized! Please check!
                
                // Merge all 3 colors
                //  t1.z and t1.y, will be FREE after unpacking Blue, t1.xy occupied.  t2.xyz occupied. t0-2.w occupied. t0.xy occupied. t0.z is FREE.
                
                // Finalise t2.xyzw output color
                
                // Sample and Add B
                // split left half of 2 bits
                "mul t1.z, t1.z, c4.x",
                "frc t0.z, t1.z",   // v coordinate
                "sub t1.z, t1.z, t0.z",
                "mul t1.z, t1.z, c4.y",   // u coordinate
                
                "add t0.x, t0.x, t1.z", // we need to temporarily sample with t0 first, since t1 must be kept intact for now
                "add t0.y, t0.y, t0.z", 
                "mov t1.y, t2.w",  // required last minute move because t2.w will be cancelled away when sampling with it (check if needed again..)
                
                "tex t2, t0, s0 <2d, linear,clamp, nomip>",   // assumed t0.zw ignored.  t2 only works now, but later need to maintain t2 state for addiitive blending!
                "sub t0.x, t0.x, t1.z",  // (due to lack of registers) hack to restore back original values for t0 variable.
                "sub t0.y, t0.y, t0.z",
                "mul t2.xyz, t2.xyz, t1.yyy",    // the starting t2 value. t2.xyz is locked from now onwards
                
                //t1.y is free, t1.z is free,    t2.w is free
                // move t1.x to t1.z, in order to sample r with t1.xy register, while maintaining reference to t2 color
                "mov t1.z, t1.x",
                
                //  Sample and Add R
                "mul t1.x, t1.z, c4.z",
                "frc t2.w, t1.x",  // right 4 bits (for G sample)
                "sub t1.x, t1.x, t2.w",
                "mul t1.x, t1.x, c4.w",  // left 4 bits (for R sample)
                "mul t1.x, t1.x, c4.x", // split left 4 bits
                "frc t1.y, t1.x",     //  v sample
                "sub t1.x, t1.x, t1.y",
                "mul t1.x, t1.x, c4.y",  // u sample
                "add t1.xy, t1.xy, t0.xy",
                // t2.w must be kep3t!  // t1 will be gone! // t0.xy taken, t0.w taken. t0.z??, t2.xyz must be kept
                "mov t0.z, t2.w",  // required last minute move to ensure t2.w value is maintained for G sample later.
                
                "mov t2.w, t1.w", // required last minute move because t1.w will be cancelled when sampling with it (check again if needed0
                "tex t1, t1, s0 <2d, linear,clamp, nomip>", 
                "mul t1.xyz, t1.xyz, t0.www",
               "add t2.xyz, t2.xyz, t1.xyz",
                
                //  Sample and Add G   
                "mul t1.x, t0.z, c4.x", // split right 4 bits
                "frc t1.y, t1.x",  // v sample
                "sub t1.x, t1.x, t1.y",
                "mul t1.x, t1.x, c4.y",  // u sample
                "add t1.xy, t1.xy, t0.xy", 
                "tex t1, t1, s0 <2d, linear,clamp, nomip>", 
                "mul t1.xyz, t1.xyz, t2.www",
               "add t2.xyz, t2.xyz, t1.xyz",
                
                "mov t2.w, c3.w", //ensure alpha 1
                "mul t2.w, t2.w, c0.w", // multiplied by alpha setting
              
                "tex t1, v2, s4 <2d, linear,repeat, miplinear>",
                "mul t2.w, t1.x, c0.w",
                "mov o0, t2"
            ], "getDiffuseOpacityProcedure");

            /**
             * @protected
             */
            public static const DISABLED:int = 0;
            /**
             * @protected
             */
            public static const SIMPLE:int = 1;
            /**
             * @protected
             */
            public static const ADVANCED:int = 2;

            /**
             * @protected
             */
            public static var fogMode:int = DISABLED;
            /**
             * @protected
             */
            public static var fogNear:Number = 1000;
            /**
             * @protected
             */
            public static var fogFar:Number = 5000;

            /**
             * @protected
             */
            public static var fogMaxDensity:Number = 1;

            /**
             * @protected
             */
            alternativa3d static var fogColorR:Number = 0xC8/255;
            /**
             * @protected
             */
            alternativa3d static var fogColorG:Number = 0xA2/255;
            /**
             * @protected
             */
            alternativa3d static var fogColorB:Number = 0xC8 / 255;
			
			public static function set fogColor(val:uint):void {
				fogColorR = ((val & 0xFF0000) >> 16) / 255;
				fogColorG = ((val & 0xFF00) >> 8) / 255;
				fogColorB = ((val & 0xFF)) / 255;
			}

            /**
             * @protected
             */
            alternativa3d static var fogTexture:TextureResource;
			
			 
			public var mistMap:TextureResource;   // a fog of war texture
			
			
			public var uvMultiplier:Number = 1;
            

            // inputs : position
            protected static const _passVaryingsProcedure:Procedure = new Procedure([
                "#v0=vPosition",
                "#v1=vViewVector",
                "#c0=cCameraPosition",
                // Pass the position
                "mov v0, i0",
                // Vector  to Camera
                "sub t0, c0, i0",
                "mov v1.xyz, t0.xyz",
                "mov v1.w, c0.w"
            ]);
            
            // inputs : tangent, normal
            protected static const _passTBNRightProcedure:Procedure = getPassTBNProcedure(true);
            protected static const _passTBNLeftProcedure:Procedure = getPassTBNProcedure(false);
            protected static function getPassTBNProcedure(right:Boolean):Procedure {
                var crsInSpace:String = (right) ? "crs t1.xyz, i0, i1" : "crs t1.xyz, i1, i0";
                return new Procedure([
                    "#v0=vTangent",
                    "#v1=vBinormal",
                    "#v2=vNormal",
                    // Calculate binormal
                    crsInSpace,
                    "mul t1.xyz, t1.xyz, i0.w",
                    // Транспонируем матрицу нормалей
                    "mov v0.xyzw, i1.xyxw",
                    "mov v0.x, i0.x",
                    "mov v0.y, t1.x",
                    "mov v1.xyzw, i1.xyyw",
                    "mov v1.x, i0.y",
                    "mov v1.y, t1.y",
                    "mov v2.xyzw, i1.xyzw",
                    "mov v2.x, i0.z",
                    "mov v2.y, t1.z"
                ], "passTBNProcedure");
            }

            // outputs : light, highlight
            protected static const _ambientLightProcedure:Procedure = new Procedure([
                "#c0=cSurface",
                "mov o0, i0",
                "mov o1, c0.xxxx"
            ], "ambientLightProcedure");

            // Set o.w to glossiness
            protected static const _setGlossinessFromConstantProcedure:Procedure = new Procedure([
                "#c0=cSurface",
                "mov o0.w, c0.y"
            ], "setGlossinessFromConstantProcedure");
            // Set o.w to glossiness from texture
            protected static const _setGlossinessFromTextureProcedure:Procedure = new Procedure([
                "#v0=vUV",  // not sure which UV is best
                "#c0=cSurface",
                "#s0=sGlossiness",
                "tex t0, v0, s0 <2d, repeat, linear, miplinear>",
                "mul o0.w, t0.x, c0.y"
            ], "setGlossinessFromTextureProcedure");

            // outputs : normal, viewVector
            protected static const _getNormalAndViewTangentProcedure:Procedure = new Procedure([
                "#v0=vTangent",
                "#v1=vBinormal",
                "#v2=vNormal",
                "#v3=vUV1",
                "#v4=vViewVector",
                "#c0=cAmbientColor",
                "#s0=sBump",
                // Extract normal from the texture
                "tex t0, v3, s0 <2d,repeat,linear,miplinear>",
                "add t0, t0, t0",
                "sub t0.xyz, t0.xyz, c0.www",
                // Transform the normal with TBN
                "nrm t1.xyz, v0.xyz",
                "dp3 o0.x, t0.xyz, t1.xyz",
                "nrm t1.xyz, v1.xyz",
                "dp3 o0.y, t0.xyz, t1.xyz",
                "nrm t1.xyz, v2.xyz",
                "dp3 o0.z, t0.xyz, t1.xyz",
                // Normalization
                "nrm o0.xyz, o0.xyz",
                // Returns normalized vector of view
                "nrm o1.xyz, v4"
            ], "getNormalAndViewTangentProcedure");
            // outputs : normal, viewVector
            protected static const _getNormalAndViewObjectProcedure:Procedure = new Procedure([
                "#v3=vUV1",
                "#v4=vViewVector",
                "#c0=cAmbientColor",
                "#s0=sBump",
                // Extract normal from the texture
                "tex t0, v3, s0 <2d,repeat,linear,miplinear>",
                "add t0, t0, t0",
                "sub t0.xyz, t0.xyz, c0.www",
                // Normalization
                "nrm o0.xyz, t0.xyz",
                // Returns normalized vector of view
                "nrm o1.xyz, v4"
            ], "getNormalAndViewObjectProcedure");

            // Apply specular map color to a flare
            protected static const _applySpecularProcedure:Procedure = new Procedure([
                "#v0=vUV",  // not which which UV is best...
                "#s0=sSpecular",
                "tex t0, v0, s0 <2d, repeat,linear,miplinear>",
                "mul o0.xyz, o0.xyz, t0.xyz"
            ], "applySpecularProcedure");

            //Apply light and flare to diffuse
            // inputs : "diffuse", "tTotalLight", "tTotalHighLight"
            protected static const _mulLightingProcedure:Procedure = new Procedure([
                "#c0=cSurface",  // c0.z - specularPower
                "mul i0.xyz, i0.xyz, i1.xyz",
                "mul t1.xyz, i2.xyz, c0.z",
                "add i0.xyz, i0.xyz, t1.xyz",
                "mov o0, i0"
            ], "mulLightingProcedure");
            
            protected static const passZDistanceProcedure:Procedure = new Procedure([
                "#v1=vDistance",
                "#c0=cZSpace",
                "dp4 t0.z, i0, c0",
                "mov v1, t0.zzzz"
            ], "passZDistanceProcedure" );

            // inputs : position
            protected static const passSimpleFogConstProcedure:Procedure = new Procedure([
                "#v0=vZDistance",
                "#c0=cFogSpace",
                "dp4 t0.z, i0, c0",
                "mov v0, t0.zzzz",
                "sub v0.y, i0.w, t0.z"
            ], "passSimpleFogConst");

            // inputs : color
            protected static const outputWithSimpleFogProcedure:Procedure = new Procedure([
                "#v0=vZDistance",
                "#c0=cFogColor",
                "#c1=cFogRange",
                // Restrict fog factor with the range
                "min t0.xy, v0.xy, c1.xy",
                "max t0.xy, t0.xy, c1.zw",
                "mul i0.xyz, i0.xyz, t0.y",
                "mul t0.xyz, c0.xyz, t0.x",
                "add i0.xyz, i0.xyz, t0.xyz",
                "mov o0, i0"
            ], "outputWithSimpleFog");
			
			private static const MIST_APPLY:Array =   [ "#c0=cFogColor",
                "#s0=sMist",
				"#v0=vUV1",
				"tex t0, v0, s0 <2d, linear,repeat, miplinear>",
				"sub t0.y, c0.w, t0.y",
                "mul i0.xyz, i0.xyz, t0.y",
				"mul t0.xyz, c0.xyz, t0.x",
                "add i0.xyz, i0.xyz, t0.xyz",
				];
			
			protected static const applyWithMistProcedure:Procedure = new Procedure(
				MIST_APPLY.concat()
            , "applyWithMist");
			
			 protected static const outputWithMistProcedure:Procedure = new Procedure(
               MIST_APPLY.concat( "mov o0, i0" )
            , "outputWithMist");

            // inputs : position, projected
            protected static const postPassAdvancedFogConstProcedure:Procedure = new Procedure([
                "#v0=vZDistance",
                "#c0=cFogSpace",
                "dp4 t0.z, i0, c0",
                "mov v0, t0.zzzz",
                "sub v0.y, i0.w, t0.z",
                // Screen x coordinate
                "mov v0.zw, i1.xwxw",
                "mov o0, i1"
            ], "postPassAdvancedFogConst");

            // inputs : color
            protected static const outputWithAdvancedFogProcedure:Procedure = new Procedure([
                "#v0=vZDistance",
                "#c0=cFogConsts",
                "#c1=cFogRange",
                "#s0=sFogTexture",
                // Restrict fog factor with the range
                "min t0.xy, v0.xy, c1.xy",
                "max t0.xy, t0.xy, c1.zw",
                "mul i0.xyz, i0.xyz, t0.y",
                // Calculate fog color
                "mov t1.xyzw, c0.yyzw",
                "div t0.z, v0.z, v0.w",
                "mul t0.z, t0.z, c0.x",
                "add t1.x, t1.x, t0.z",
                "tex t1, t1, s0 <2d, repeat, linear, miplinear>",
                "mul t0.xyz, t1.xyz, t0.x",
                "add i0.xyz, i0.xyz, t0.xyz",
                "mov o0, i0"
            ], "outputWithAdvancedFog");

            // Add lightmap value with light
            protected static const _addLightMapProcedure:Procedure = new Procedure([
                "#v0=vUV1",
                "#s0=sLightMap",
                "tex t0, v0, s0 <2d,repeat,linear,miplinear>",
                "add t0, t0, t0",
                "add o0.xyz, i0.xyz, t0.xyz"
            ], "applyLightMapProcedure");

            
            /**
             * Normal map.
             */
            public var normalMap:TextureResource;

            protected var _normalMapSpace:int = NormalMapSpace.TANGENT_RIGHT_HANDED;
            /**
             * Type of the normal map. Should be defined by constants of   <code>NormalMapSpace</code> class.
             *
             * @default NormalMapSpace.TANGENT
             *
             * @see NormalMapSpace
             */
            public function get normalMapSpace():int {
                return _normalMapSpace;
            }

            /**
             * @protected
             */
            public function set normalMapSpace(value:int):void {
                if (value != NormalMapSpace.TANGENT_RIGHT_HANDED && value != NormalMapSpace.TANGENT_LEFT_HANDED && value != NormalMapSpace.OBJECT) {
                    throw new ArgumentError("Value must be a constant from the NormalMapSpace class");
                }
                _normalMapSpace = value;
            }
			
			public function get waterMode():int 
			{
				return _waterMode;
			}
			
			public function set waterMode(value:int):void 
			{
				_waterMode = value;
				_useWaterMode = value;
			}

            /**
             * Specular map.
             */
            public var specularMap:TextureResource;
            /**
             * Glossiness map.
             */
            public var glossinessMap:TextureResource;

            /**
             * Light map.
             */
            public var lightMap:TextureResource;

            /**
             * Number of the UV-channel for light map.
             */
            //public var lightMapChannel:uint = 0;
            /**
             * Glossiness. Multiplies with  <code>glossinessMap</code> value.
             */
            public var glossiness:Number = 100;

            /**
             * Brightness of a flare. Multiplies with  <code>specularMap</code> value.
             */
            public var specularPower:Number = 1;
            

            /**
             * Creates a new TileAtlasMaterial instance.
             * @param diffuseMap Diffuse map.
             * @param normalMap Normal map.
             * @param specularMap Specular map.
             * @param glossinessMap Glossiness map.
             * @param opacityMap Opacity map.
             */
            
             // texture atlas values
            protected var atlasSheet:BitmapTextureResource;
            protected var tilePaddingPxH:int;
             protected var tilePaddingPxV:int;
            protected var tileSizePx:int;
            protected var tilePaddingU:Number;
            protected var tilePaddingV:Number;
            protected var tileSizeU:Number;
            protected var tileSizeV:Number;

            public var resolution:Number = 1;
            
            protected var tileIndexMaps:Vector.<BitmapTextureResource>;  // lookup tile indices.  Can store multiple lookups for this material, allowing multiple surfaces to use same material.
            protected var normalMaps:Vector.<BitmapTextureResource>;
            protected var lightMaps:Vector.<BitmapTextureResource>;
            public var lookupIndex:int = 0;  // Set this variable directly prior to rendering through this material to change lookup tile index table.
            protected var totalMipmaps:int;
			
            protected var mipmapTable:BitmapTextureResource;
            protected var mipmapUVCap:Number;
            

            protected var blendAtlas:BitmapTextureResource;
            
            public function TileAtlasMaterial(atlasSheet:BitmapTextureResource, blendAtlas:BitmapTextureResource, mipmapTable:BitmapTextureResource, mipmapUVCap:Number, tileIndexMaps:Vector.<BitmapTextureResource>, normalMaps:Vector.<BitmapTextureResource>, lightMaps:Vector.<BitmapTextureResource>, tileSizePx:int, tilePaddingPxH:int=0, tilePaddingPxV:int=-1) {
                
				this.tileIndexMaps = tileIndexMaps;
				 this.normalMaps = normalMaps;  
                 this.lightMaps = lightMaps;
                 this.blendAtlas = blendAtlas;
                 
                 this.mipmapUVCap = mipmapUVCap;
                 this.mipmapTable = mipmapTable;
                 this.totalMipmaps = mipmapUVCap * mipmapTable.data.width;
                
                 if (tilePaddingPxV < 0) tilePaddingPxV = tilePaddingPxH;
                 
                //diffuseMap:TextureResource = null, normalMap:TextureResource = null, specularMap:TextureResource = null, glossinessMap:TextureResource = null, opacityMap:TextureResource = null
                super(atlasSheet, null, 1);  // no opacity map suupport
                
                this.atlasSheet = atlasSheet;
                this.specularMap = specularMap;
                this.glossinessMap = glossinessMap;
                
                this.tileIndexMaps = tileIndexMaps;
                
           
                // todo: clamping to half of pixel uv to 
                tileSizeU = tileSizePx / atlasSheet.data.width;// - .5 * (1/atlasSheet.data.width);  
                tileSizeV = tileSizePx / atlasSheet.data.height;//- .5 * (1/atlasSheet.data.height);
				
				tilePaddingU = 1/tileSizePx;  // actually padding should be .5/dimension for mipmap level zero.
                tilePaddingV = 1/tileSizePx;

                this.tilePaddingPxH = tilePaddingPxH;
                this.tilePaddingPxV = tilePaddingPxV;
                this.tileSizePx = tileSizePx;
				
				
            }

            /**
             * @protected
             */
            override alternativa3d function fillResources(resources:Dictionary, resourceType:Class):void {
                super.fillResources(resources, resourceType);
              
    
                
                  if (mipmapTable != null &&
                        A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(mipmapTable)) as Class, resourceType)) {
                    resources[mipmapTable] = true;
                }
                
                 if (blendAtlas != null &&
                        A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(blendAtlas)) as Class, resourceType)) {
                    resources[blendAtlas] = true;
                }
				
				 if (mistMap != null &&
                        A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(mistMap)) as Class, resourceType)) {
                    resources[mistMap] = true;
                }
				
				

				/*
                if (glossinessMap != null &&
                        A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(glossinessMap)) as Class, resourceType)) {
                    resources[glossinessMap] = true;
                }
                if (specularMap != null &&
                        A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(specularMap)) as Class, resourceType)) {
                    resources[specularMap] = true;
                }
                */
                
                var len:int;
                var i:int;
                var res:TextureResource;
                
                len = tileIndexMaps.length;
                for (i=0; i < len; i++) {
                    res = tileIndexMaps[i];
                    if ( A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(res)) as Class, resourceType)) resources[res] = true;
                }
                    
                
                len = lightMaps.length;
                for (i = 0; i < len; i++) {
                    res = lightMaps[i];
                    if (res == null) continue;
                    if ( A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(res)) as Class, resourceType)) resources[res] = true;
                }
				
				len = normalMaps.length;
                for (i = 0; i < len; i++) {
                    res = normalMaps[i];
                    if (res == null) continue;
                    if ( A3DUtils.checkParent(getDefinitionByName(getQualifiedClassName(res)) as Class, resourceType)) resources[res] = true;
                }
            }



            /**
             * @protected
             */
            alternativa3d function setPassUVProcedureConstants(destination:DrawUnit, vertexLinker:Linker):void {
            }

            // inputs: tNormal", "tViewVector", "shadow", "cAmbientColor"
            // outputs : light, hightlight
            protected function formDirectionalProcedure(procedure:Procedure, index:int, useShadow:Boolean):void {
                var source:Array = [
                    // Position - dirction vector of light
                    "#c0=c" + index + "Position",
                    "#c1=c" + index + "Color",
                    // Calculate half-way vector
                    "add t0.xyz, i1.xyz, c0.xyz",
                    "mov t0.w, c0.w",
                    "nrm t0.xyz,t0.xyz",
                    // Calculate a flare
                    "dp3 t0.w, t0.xyz, i0.xyz",
                    "pow t0.w, t0.w, o1.w",
                    // Calculate light
                    "dp3 t0.x, i0.xyz, c0.xyz",
                    "sat t0.x, t0.x"
                ];
                if (useShadow) {
                    source.push("mul t0.xw, t0.xw, i2.x");
                    source.push("mul t0.xyz, c1.xyz, t0.xxx");
                    source.push("add o0.xyz, t0.xyz, i3.xyz");
                    source.push("mul o1.xyz, c1.xyz, t0.www");
                } else {
                    // Apply calculated values
                    source.push("mul t0.xyz, c1.xyz, t0.xxxx");
                    source.push("add o0, o0, t0.xyz");
                    source.push("mul t0.xyz, c1.xyz, t0.w");
                    source.push("add o1.xyz, o1.xyz, t0.xyz");
                }
                procedure.compileFromArray(source);
            }

            protected function formOmniProcedure(procedure:Procedure, index:int, useShadow:Boolean):void {
    //            fragmentLinker.setInputParams(omniMulShadowProcedure, "tNormal", "tViewVector", "tTotalLight", "cAmbientColor");
                var source:Array = [
                    "#c0=c" + index + "Position",
                    "#c1=c" + index + "Color",
                    "#c2=c" + index + "Radius",
                    "#v0=vPosition"
                ];
                if (useShadow) {
                    // Считаем вектор из точки к свету
                    source.push("sub t0, c0, v0"); // L = lightPos - PointPos
                    source.push("dp3 t0.w, t0.xyz, t0.xyz"); // lenSqr
                    source.push("nrm t0.xyz, t0.xyz"); // L = normalize(L)
                    // Считаем half-way вектор
                    source.push("add t1.xyz, i1.xyz, t0.xyz");
                    source.push("nrm t1.xyz, t1.xyz");
                    // Считаем блик
                    source.push("dp3 t1.w, t1.xyz, i0.xyz");
                    source.push("pow t1.w, t1.w, o1.w");
                    // Считаем расстояние до источника света
                    source.push("sqt t1.x, t0.w"); // len = sqt(lensqr)
                    // Считаем свет
                    source.push("dp3 t0.w, t0.xyz, i0.xyz"); // dot = dot(normal, L)
                    // Считаем затухание
                    source.push("sub t0.x, t1.x, c2.z"); // len = len - atenuationBegin
                    source.push("div t0.y, t0.x, c2.y"); // att = len/radius
                    source.push("sub t0.x, c2.x, t0.y"); // att = 1 - len/radius
                    source.push("sat t0.xw, t0.xw"); // t = max(t, 0)

                    // i3 - ambient
                    // i2 - shadow-test

                    source.push("mul t0.xw,   t0.xwww,   i2.xxxx");
                    source.push("mul t0.xyz, c1.xyz, t0.xxx");     // t = color*t
                    source.push("mul t1.xyz, t0.xyz, t1.w");
                    source.push("add o1.xyz, o1.xyz, t1.xyz");
                    source.push("mul t0.xyz, t0.xyz, t0.www");
                    source.push("add o0.xyz, t0.xyz, i3.xyz");
                } else {
                    // Считаем вектор из точки к свету
                    source.push("sub t0, c0, v0"); // L = lightPos - PointPos
                    source.push("dp3 t0.w, t0.xyz, t0.xyz"); // lenSqr
                    source.push("nrm t0.xyz, t0.xyz"); // L = normalize(L)
                    // Считаем half-way вектор
                    source.push("add t1.xyz, i1.xyz, t0.xyz");
                    source.push("mov t1.w, c0.w");
                    source.push("nrm t1.xyz, t1.xyz");
                    // Считаем блик
                    source.push("dp3 t1.w, t1.xyz, i0.xyz");
                    source.push("pow t1.w, t1.w, o1.w");            //!!!
                    // Считаем расстояние до источника света
                    source.push("sqt t1.x, t0.w"); // len = sqt(lensqr)
                    // Считаем свет
                    source.push("dp3 t0.w, t0.xyz, i0.xyz"); // dot = dot(normal, L)
                    // Считаем затухание
                    source.push("sub t0.x, t1.x, c2.z"); // len = len - atenuationBegin
                    source.push("div t0.y, t0.x, c2.y"); // att = len/radius
                    source.push("sub t0.x, c2.x, t0.y"); // att = 1 - len/radius
                    source.push("sat t0.xw, t0.xw"); // t = max(t, 0)

                    // Перемножаем цвет источника с затуханием
                    source.push("mul t0.xyz, c1.xyz, t0.xxx");     // t = color*t
                    source.push("mul t1.xyz, t0.xyz, t1.w");
                    source.push("add o1.xyz, o1.xyz, t1.xyz");
                    source.push("mul t0.xyz, t0.xyz, t0.www");
                    source.push("add o0.xyz, o0.xyz, t0.xyz");
                }

                procedure.compileFromArray(source);
            }

            /**
             * @param object
             * @param materialKey
             * @param opacityMap
             * @param alphaTest 0:disabled 1:alpha-test 2:contours
             * @param lightsGroup
             * @param directionalLight
             * @param lightsLength
             */
            protected function getProgram(object:Object3D, programs:Array, camera:Camera3D, materialKey:int, opacityMap:TextureResource, alphaTest:int, lightsGroup:Vector.<Light3D>, lightsLength:int, isFirstGroup:Boolean, shadowedLight:Light3D):TileAtlasMaterialProgram {
                // 0 bit - lightmap
                // 1 bit - glossiness map
                // 2 bit - opacity map
                // 3 bit - specular map
                // 4-5 bits - normalMapSpace
                // 6-7 bits - alphaTest
                // 8-10 bits - OmniLight count
                // 11-13 bits - DirectionalLight count
                // 14-16 bits - SpotLight count
                // 17-18 bit - Shadow Type (PCF, SIMPLE, NONE)

                var key:uint = materialKey | (opacityMap != null ? OPACITY_MAP_BIT : 0) | (alphaTest << ALPHA_TEST_OFFSET);
				key |= _useWaterMode > 0 ? WATER_BIT : 0;
				
                var program:TileAtlasMaterialProgram = programs[key];

                if (program == null) {
                    var vertexLinker:Linker = new Linker(Context3DProgramType.VERTEX);
                    var fragmentLinker:Linker = new Linker(Context3DProgramType.FRAGMENT);
                    var i:int;
					
					if (key & WATER_BIT) fragmentLinker.addProcedure(kilWaterLevel);

                    // Merge program using lightsGroup
                    // add property useShadow

                    fragmentLinker.declareVariable("tTotalLight");
                    fragmentLinker.declareVariable("tTotalHighLight");
                    fragmentLinker.declareVariable("tNormal");

                    if (isFirstGroup){
                        fragmentLinker.declareVariable("cAmbientColor", VariableType.CONSTANT);
                        fragmentLinker.addProcedure(_ambientLightProcedure);
                        fragmentLinker.setInputParams(_ambientLightProcedure, "cAmbientColor");
                        fragmentLinker.setOutputParams(_ambientLightProcedure, "tTotalLight", "tTotalHighLight");

                        if (lightMap != null) {
                          //  vertexLinker.addProcedure(_passLightMapUVProcedure);
                            fragmentLinker.addProcedure(_addLightMapProcedure);
                            fragmentLinker.setInputParams(_addLightMapProcedure, "tTotalLight");
                            fragmentLinker.setOutputParams(_addLightMapProcedure, "tTotalLight");
                        }
                    }
                    else{
                        // сбросить tTotalLight tTotalHighLight
                        fragmentLinker.declareVariable("cAmbientColor", VariableType.CONSTANT);
                        fragmentLinker.addProcedure(_ambientLightProcedure);
                        fragmentLinker.setInputParams(_ambientLightProcedure, "cAmbientColor");
                        fragmentLinker.setOutputParams(_ambientLightProcedure, "tTotalLight", "tTotalHighLight");
                    }

                    var positionVar:String = "aPosition";
                    var normalVar:String = "aNormal";
                    var tangentVar:String = "aTangent";
                    vertexLinker.declareVariable(positionVar, VariableType.ATTRIBUTE);
                    vertexLinker.declareVariable(tangentVar, VariableType.ATTRIBUTE);
                    vertexLinker.declareVariable(normalVar, VariableType.ATTRIBUTE);
                    if (object.transformProcedure != null) {
                        positionVar = appendPositionTransformProcedure(object.transformProcedure, vertexLinker);
                    }

                    vertexLinker.addProcedure(_projectProcedure);
                    vertexLinker.setInputParams(_projectProcedure, positionVar);

                    vertexLinker.addProcedure(_passUVProcedure);
                    
                    // add z distance procedure
                    vertexLinker.addProcedure(passZDistanceProcedure);
                    vertexLinker.setInputParams(passZDistanceProcedure, positionVar);
 

                    if (glossinessMap != null) {
                        fragmentLinker.addProcedure(_setGlossinessFromTextureProcedure);
                        fragmentLinker.setOutputParams(_setGlossinessFromTextureProcedure, "tTotalHighLight");
                    } else {
                        fragmentLinker.addProcedure(_setGlossinessFromConstantProcedure);
                        fragmentLinker.setOutputParams(_setGlossinessFromConstantProcedure, "tTotalHighLight");
                    }

                    if (lightsLength > 0 || shadowedLight) {
                        var procedure:Procedure;
                        if (object.deltaTransformProcedure != null) {
                            vertexLinker.declareVariable("tTransformedNormal");
                            procedure = object.deltaTransformProcedure.newInstance();
                            vertexLinker.addProcedure(procedure);
                            vertexLinker.setInputParams(procedure, normalVar);
                            vertexLinker.setOutputParams(procedure, "tTransformedNormal");
                            normalVar = "tTransformedNormal";

                            vertexLinker.declareVariable("tTransformedTangent");
                            procedure = object.deltaTransformProcedure.newInstance();
                            vertexLinker.addProcedure(procedure);
                            vertexLinker.setInputParams(procedure, tangentVar);
                            vertexLinker.setOutputParams(procedure, "tTransformedTangent");
                            tangentVar = "tTransformedTangent";
                        }
                        vertexLinker.addProcedure(_passVaryingsProcedure);
                        vertexLinker.setInputParams(_passVaryingsProcedure, positionVar);
                        fragmentLinker.declareVariable("tViewVector");

                        if (_normalMapSpace == NormalMapSpace.TANGENT_RIGHT_HANDED || _normalMapSpace == NormalMapSpace.TANGENT_LEFT_HANDED) {
                            var nrmProcedure:Procedure = (_normalMapSpace == NormalMapSpace.TANGENT_RIGHT_HANDED) ? _passTBNRightProcedure : _passTBNLeftProcedure;
                            vertexLinker.addProcedure(nrmProcedure);
                            vertexLinker.setInputParams(nrmProcedure, tangentVar, normalVar);
                            fragmentLinker.addProcedure(_getNormalAndViewTangentProcedure);
                            fragmentLinker.setOutputParams(_getNormalAndViewTangentProcedure, "tNormal", "tViewVector");
                        } else {
                            fragmentLinker.addProcedure(_getNormalAndViewObjectProcedure);
                            fragmentLinker.setOutputParams(_getNormalAndViewObjectProcedure, "tNormal", "tViewVector");
                        }
                        if (shadowedLight != null) {
                            var shadowProc:Procedure;
                            if (shadowedLight is DirectionalLight){
                                vertexLinker.addProcedure(shadowedLight.shadow.vertexShadowProcedure, positionVar);
                                shadowProc = shadowedLight.shadow.fragmentShadowProcedure;
                                fragmentLinker.addProcedure(shadowProc);
                                fragmentLinker.setOutputParams(shadowProc, "tTotalLight");

                                var dirMulShadowProcedure:Procedure = new Procedure(null, "lightShadowDirectional");
                                formDirectionalProcedure(dirMulShadowProcedure, 0, true);
                                fragmentLinker.addProcedure(dirMulShadowProcedure);
                                fragmentLinker.setInputParams(dirMulShadowProcedure, "tNormal", "tViewVector", "tTotalLight", "cAmbientColor");
                                fragmentLinker.setOutputParams(dirMulShadowProcedure, "tTotalLight", "tTotalHighLight");
                            }

                            if (shadowedLight is OmniLight){
                                vertexLinker.addProcedure(shadowedLight.shadow.vertexShadowProcedure, positionVar);
                                shadowProc = shadowedLight.shadow.fragmentShadowProcedure;
                                fragmentLinker.addProcedure(shadowProc);
                                fragmentLinker.setOutputParams(shadowProc, "tTotalLight");

                                var omniMulShadowProcedure:Procedure = new Procedure(null, "lightShadowDirectional");
                                formOmniProcedure(omniMulShadowProcedure, 0, true);
                                fragmentLinker.addProcedure(omniMulShadowProcedure);
                                fragmentLinker.setInputParams(omniMulShadowProcedure, "tNormal", "tViewVector", "tTotalLight", "cAmbientColor");
                                fragmentLinker.setOutputParams(omniMulShadowProcedure, "tTotalLight", "tTotalHighLight");
                            }
                        }

                        for (i = 0; i < lightsLength; i++) {
                            var light:Light3D = lightsGroup[i];
                            if (light == shadowedLight && (shadowedLight is DirectionalLight || shadowedLight is OmniLight)) continue;
                            var lightFragmentProcedure:Procedure = new Procedure();
                            lightFragmentProcedure.name = "light" + i.toString();
                            if (light is DirectionalLight) {
                                formDirectionalProcedure(lightFragmentProcedure, i, false);
                                lightFragmentProcedure.name += "Directional";
                            } else if (light is OmniLight) {
                                formOmniProcedure(lightFragmentProcedure, i, false);
                                lightFragmentProcedure.name += "Omni";
                            } else if (light is SpotLight) {
                                lightFragmentProcedure.compileFromArray([
                                    "#c0=c" + i + "Position",
                                    "#c1=c" + i + "Color",
                                    "#c2=c" + i + "Radius",
                                    "#c3=c" + i + "Axis",
                                    "#v0=vPosition",
                                    // Calculate vector from the point to light
                                    "sub t0, c0, v0",// L = pos - lightPos
                                    "dp3 t0.w, t0, t0",// lenSqr
                                    "nrm t0.xyz,t0.xyz",// L = normalize(L)
                                    // Calculate half-way vector
                                    "add t2.xyz, i1.xyz, t0.xyz",
                                    "nrm t2.xyz, t2.xyz",
                                    //Calculate a flare
                                    "dp3 t2.x, t2.xyz, i0.xyz",
                                    "pow t2.x, t2.x, o1.w",
                                    "dp3 t1.x, t0.xyz, c3.xyz", //axisDirDot
                                    "dp3 t0.x, t0, i0.xyz",// dot = dot(normal, L)
                                    "sqt t0.w, t0.w",// len = sqt(lensqr)
                                    "sub t0.w, t0.w, c2.y",// len = len - atenuationBegin
                                    "div t0.y, t0.w, c2.x",// att = len/radius
                                    "sub t0.w, c0.w, t0.y",// att = 1 - len/radius
                                    "sub t0.y, t1.x, c2.w",
                                    "div t0.y, t0.y, c2.z",
                                    "sat t0.xyw,t0.xyw",// t = sat(t)
                                    "mul t1.xyz,c1.xyz,t0.yyy",// t = color*t
                                    "mul t1.xyz,t1.xyz,t0.www",//
                                    "mul t2.xyz, t2.x, t1.xyz",
                                    "add o1.xyz, o1.xyz, t2.xyz",
                                    "mul t1.xyz, t1.xyz, t0.xxx",

                                    "add o0.xyz, o0.xyz, t1.xyz"
                                ]);
                                lightFragmentProcedure.name += "Spot";
                            }
                            fragmentLinker.addProcedure(lightFragmentProcedure);
                            fragmentLinker.setInputParams(lightFragmentProcedure, "tNormal", "tViewVector");
                            fragmentLinker.setOutputParams(lightFragmentProcedure, "tTotalLight", "tTotalHighLight");
                        }
                    }

                    var outputProcedure:Procedure;
                    if (specularMap != null) {
                        fragmentLinker.addProcedure(_applySpecularProcedure);
                        fragmentLinker.setOutputParams(_applySpecularProcedure, "tTotalHighLight");
                        outputProcedure = _applySpecularProcedure;
                    }
					
			

                
                    
                    fragmentLinker.declareVariable("tColor");
                    outputProcedure = opacityMap != null ? getDiffuseOpacityProcedure : getDiffuseProcedure;
                    fragmentLinker.addProcedure(outputProcedure);
                    fragmentLinker.setOutputParams(outputProcedure, "tColor");

                    if (alphaTest > 0) {
                        outputProcedure = alphaTest == 1 ? thresholdOpaqueAlphaProcedure : thresholdTransparentAlphaProcedure;
                        fragmentLinker.addProcedure(outputProcedure, "tColor");
                        fragmentLinker.setOutputParams(outputProcedure, "tColor");
                    }
					
					
					
					
                    fragmentLinker.addProcedure(_mulLightingProcedure, "tColor", "tTotalLight", "tTotalHighLight");
					

				
					if (mistMap != null) {
						fragmentLinker.addProcedure( fogMode !=0 ? applyWithMistProcedure : outputWithMistProcedure, "tColor");
					}

					///*
                    if (fogMode == SIMPLE || fogMode == ADVANCED || mistMap!=null ) {
                       fragmentLinker.setOutputParams(_mulLightingProcedure, "tColor");
                    }
                    if (fogMode == SIMPLE) {
                        vertexLinker.addProcedure(passSimpleFogConstProcedure);
                       vertexLinker.setInputParams(passSimpleFogConstProcedure, positionVar);
                        fragmentLinker.addProcedure(outputWithSimpleFogProcedure);
                        fragmentLinker.setInputParams(outputWithSimpleFogProcedure, "tColor");
                        outputProcedure = outputWithSimpleFogProcedure;
                    } else if (fogMode == ADVANCED) {
                       vertexLinker.declareVariable("tProjected");
                        vertexLinker.setOutputParams(_projectProcedure, "tProjected");
                        vertexLinker.addProcedure(postPassAdvancedFogConstProcedure);
                        vertexLinker.setInputParams(postPassAdvancedFogConstProcedure, positionVar, "tProjected");
                        fragmentLinker.addProcedure(outputWithAdvancedFogProcedure);
                        fragmentLinker.setInputParams(outputWithAdvancedFogProcedure, "tColor");
                        outputProcedure = outputWithAdvancedFogProcedure;
                    }
				//	*/
				

		
					
					
                    fragmentLinker.varyings = vertexLinker.varyings;
                    program = new TileAtlasMaterialProgram(vertexLinker, fragmentLinker, (shadowedLight != null) ? 1 : lightsLength);

                    program.upload(camera.context3D);
                    programs[key] = program;
                }
                return program;
            }

            protected function addDrawUnits(program:TileAtlasMaterialProgram, camera:Camera3D, surface:Surface, geometry:Geometry, opacityMap:TextureResource, lights:Vector.<Light3D>, lightsLength:int, isFirstGroup:Boolean, shadowedLight:Light3D, opaqueOption:Boolean, transparentOption:Boolean, objectRenderPriority:int):void {
               
                
                // Buffers
                var positionBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.POSITION);
                var uvBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.TEXCOORDS[0]);
                var normalsBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.NORMAL);
                var tangentsBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.TANGENT4);

                if (positionBuffer == null || uvBuffer == null) return;
              //  if ((lightsLength > 0 || shadowedLight != null) && (normalsBuffer == null || tangentsBuffer == null)) return;

                var object:Object3D = surface.object;

                // Draw call
                var drawUnit:DrawUnit = camera.renderer.createDrawUnit(object, program.program, geometry._indexBuffer, surface.indexBegin, surface.numTriangles, program);

                // Streams
                drawUnit.setVertexBufferAt(program.aPosition, positionBuffer, geometry._attributesOffsets[VertexAttributes.POSITION], VertexAttributes.FORMATS[VertexAttributes.POSITION]);
                drawUnit.setVertexBufferAt(program.aUV, uvBuffer, geometry._attributesOffsets[VertexAttributes.TEXCOORDS[0]], VertexAttributes.FORMATS[VertexAttributes.TEXCOORDS[0]]);

                // Constants
                object.setTransformConstants(drawUnit, surface, program.vertexShader, camera);
                drawUnit.setProjectionConstants(camera, program.cProjMatrix, object.localToCameraTransform);
				drawUnit.setVertexConstantsFromNumbers(program.cUVProperties, uvOffsetX, uvOffsetY, 1 / tileIndexMaps[lookupIndex].data.width, uvMultiplier);
                 // Set options for a surface. X should be 0.
                 drawUnit.setFragmentConstantsFromNumbers(program.cSurface, 0, glossiness, specularPower, 1);
                drawUnit.setFragmentConstantsFromNumbers(program.cThresholdAlpha, alphaThreshold, 0, 0, alpha);
				if (_useWaterMode > 0) drawUnit.setFragmentConstantsFromNumbers(program.cWater, 0, 0, waterLevel, 1);
              
                // mine constants    
                drawUnit.setFragmentConstantsFromNumbers(program.cTilePaddSize, tilePaddingU, tilePaddingV, camera.focalLength, .5 );  // last values for dummy testing
                // lod constant
                drawUnit.setFragmentConstantsFromNumbers(program.cTileFrac, 1 / tileIndexMaps[lookupIndex].data.width, 1 / tileIndexMaps[lookupIndex].data.height, tileSizeU, tileSizeV);
                // 
                drawUnit.setFragmentConstantsFromNumbers(program.cF, camera.focalLength / resolution, totalMipmaps, mipmapUVCap, 1);
                drawUnit.setFragmentConstantsFromNumbers(program.cAtlasTiles, 4, 0.25, 16, 1 / 16);
                drawUnit.setFragmentConstantsFromNumbers(program.c255, 255, 0.5, uvMultiplier, 1/256);
         

                var light:Light3D;
                var len:Number;
                var transform:Transform3D;
                var rScale:Number;
                var omni:OmniLight;
                var spot:SpotLight;
                var falloff:Number;
                var hotspot:Number;

                if (lightsLength > 0 || shadowedLight != null) {
                    if (_normalMapSpace == NormalMapSpace.TANGENT_RIGHT_HANDED || _normalMapSpace == NormalMapSpace.TANGENT_LEFT_HANDED) {
                        drawUnit.setVertexBufferAt(program.aNormal, normalsBuffer, geometry._attributesOffsets[VertexAttributes.NORMAL], VertexAttributes.FORMATS[VertexAttributes.NORMAL]);
                        drawUnit.setVertexBufferAt(program.aTangent, tangentsBuffer, geometry._attributesOffsets[VertexAttributes.TANGENT4], VertexAttributes.FORMATS[VertexAttributes.TANGENT4]);
                    }
                    drawUnit.setTextureAt(program.sBump, normalMap._texture);
                    

                    var camTransform:Transform3D = object.cameraToLocalTransform;
                    drawUnit.setVertexConstantsFromNumbers(program.cCameraPosition, camTransform.d, camTransform.h, camTransform.l);
					

                    for (var i:int = 0; i < lightsLength; i++) {
                        light = lights[i];
                        if (light is DirectionalLight) {
                            transform = light.lightToObjectTransform;
                            len = Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);

                            drawUnit.setFragmentConstantsFromNumbers(program.cPosition[i], -transform.c/len, -transform.g/len, -transform.k/len, 1);
                            drawUnit.setFragmentConstantsFromNumbers(program.cColor[i], light.red, light.green, light.blue);
                        } else if (light is OmniLight) {
                            omni = light as OmniLight;
                            transform = light.lightToObjectTransform;
                            rScale = Math.sqrt(transform.a*transform.a + transform.e*transform.e + transform.i*transform.i);
                            rScale += Math.sqrt(transform.b*transform.b + transform.f*transform.f + transform.j*transform.j);
                            rScale += Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);
                            rScale /= 3;

                            drawUnit.setFragmentConstantsFromNumbers(program.cPosition[i], transform.d, transform.h, transform.l);
                            drawUnit.setFragmentConstantsFromNumbers(program.cRadius[i], 1, omni.attenuationEnd*rScale - omni.attenuationBegin*rScale, omni.attenuationBegin*rScale);
                            drawUnit.setFragmentConstantsFromNumbers(program.cColor[i], light.red, light.green, light.blue);
                        } else if (light is SpotLight) {
                            spot = light as SpotLight;
                            transform = light.lightToObjectTransform;
                            rScale = Math.sqrt(transform.a*transform.a + transform.e*transform.e + transform.i*transform.i);
                            rScale += Math.sqrt(transform.b*transform.b + transform.f*transform.f + transform.j*transform.j);
                            rScale += len = Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);
                            rScale /= 3;
                            falloff = Math.cos(spot.falloff*0.5);
                            hotspot = Math.cos(spot.hotspot*0.5);

                            drawUnit.setFragmentConstantsFromNumbers(program.cPosition[i], transform.d, transform.h, transform.l);
                            drawUnit.setFragmentConstantsFromNumbers(program.cAxis[i], -transform.c/len, -transform.g/len, -transform.k/len);
                            drawUnit.setFragmentConstantsFromNumbers(program.cRadius[i], spot.attenuationEnd*rScale - spot.attenuationBegin*rScale, spot.attenuationBegin*rScale, hotspot == falloff ? 0.000001 : hotspot - falloff, falloff);
                            drawUnit.setFragmentConstantsFromNumbers(program.cColor[i], light.red, light.green, light.blue);
                        }
                    }
                }

                if (shadowedLight != null) {
                    light = shadowedLight;
                    if (light is DirectionalLight) {
                        transform = light.lightToObjectTransform;
                        len = Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);
                        drawUnit.setFragmentConstantsFromNumbers(program.cPosition[0], -transform.c/len, -transform.g/len, -transform.k/len, 1);
                        drawUnit.setFragmentConstantsFromNumbers(program.cColor[0], light.red, light.green, light.blue);
                    } else if (light is OmniLight) {
                        omni = light as OmniLight;
                        transform = light.lightToObjectTransform;
                        rScale = Math.sqrt(transform.a*transform.a + transform.e*transform.e + transform.i*transform.i);
                        rScale += Math.sqrt(transform.b*transform.b + transform.f*transform.f + transform.j*transform.j);
                        rScale += Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);
                        rScale /= 3;
                        drawUnit.setFragmentConstantsFromNumbers(program.cPosition[0], transform.d, transform.h, transform.l);
                        drawUnit.setFragmentConstantsFromNumbers(program.cRadius[0], 1, omni.attenuationEnd*rScale - omni.attenuationBegin*rScale, omni.attenuationBegin*rScale);
                        drawUnit.setFragmentConstantsFromNumbers(program.cColor[0], light.red, light.green, light.blue);
                    } else if (light is SpotLight) {
                        spot = light as SpotLight;
                        transform = light.lightToObjectTransform;
                        rScale = Math.sqrt(transform.a*transform.a + transform.e*transform.e + transform.i*transform.i);
                        rScale += Math.sqrt(transform.b*transform.b + transform.f*transform.f + transform.j*transform.j);
                        rScale += len = Math.sqrt(transform.c*transform.c + transform.g*transform.g + transform.k*transform.k);
                        rScale /= 3;
                        falloff = Math.cos(spot.falloff*0.5);
                        hotspot = Math.cos(spot.hotspot*0.5);

                        drawUnit.setFragmentConstantsFromNumbers(program.cPosition[0], transform.d, transform.h, transform.l);
                        drawUnit.setFragmentConstantsFromNumbers(program.cAxis[0], -transform.c/len, -transform.g/len, -transform.k/len);
                        drawUnit.setFragmentConstantsFromNumbers(program.cRadius[0], spot.attenuationEnd*rScale - spot.attenuationBegin*rScale, spot.attenuationBegin*rScale, hotspot == falloff ? 0.000001 : hotspot - falloff, falloff);
                        drawUnit.setFragmentConstantsFromNumbers(program.cColor[0], light.red, light.green, light.blue);
                    }
                }

                // Textures

                drawUnit.setTextureAt(program.sDiffuse, diffuseMap._texture);
                drawUnit.setTextureAt(program.sTileIndices, tileIndexMaps[lookupIndex]._texture);
                drawUnit.setTextureAt(program.sMipmapOffsets, mipmapTable._texture);
                drawUnit.setTextureAt(program.sBlendAtlas, blendAtlas._texture);
                
                if (opacityMap != null) {
                    drawUnit.setTextureAt(program.sOpacity, opacityMap._texture);
                }
                if (glossinessMap != null) {
                    drawUnit.setTextureAt(program.sGlossiness, glossinessMap._texture);
                }
                if (specularMap != null) {
                    drawUnit.setTextureAt(program.sSpecular, specularMap._texture);
                }

                if (isFirstGroup) {
                    if (lightMap != null) {
                       // drawUnit.setVertexBufferAt(program.aUV1, geometry.getVertexBuffer(VertexAttributes.TEXCOORDS[lightMapChannel]), geometry._attributesOffsets[VertexAttributes.TEXCOORDS[lightMapChannel]], Context3DVertexBufferFormat.FLOAT_2);
                        drawUnit.setFragmentConstantsFromNumbers(program.cAmbientColor, 0,0,0, 1);
                        drawUnit.setTextureAt(program.sLightMap, lightMap._texture);
                    } else {
                        drawUnit.setFragmentConstantsFromVector(program.cAmbientColor, camera.ambient, 1);
                    }
                }
                else{
                    drawUnit.setFragmentConstantsFromNumbers(program.cAmbientColor, 0,0,0, 1);
                }
                setPassUVProcedureConstants(drawUnit, program.vertexShader);

                if (shadowedLight != null && ((shadowedLight is DirectionalLight)||(shadowedLight is OmniLight))) {
                    shadowedLight.shadow.setup(drawUnit, program.vertexShader, program.fragmentShader, surface);
                }

                // Inititalizing render properties
                if (opaqueOption) {
                    // Use z-buffer within DrawCall, draws without blending
                    if (isFirstGroup){
                        drawUnit.blendSource = Context3DBlendFactor.ONE;
                        drawUnit.blendDestination = Context3DBlendFactor.ZERO;
                        camera.renderer.addDrawUnit(drawUnit, objectRenderPriority >= 0 ? objectRenderPriority : Renderer.OPAQUE);
                    }
                    else{
                        drawUnit.blendSource = Context3DBlendFactor.ONE;
                        drawUnit.blendDestination = Context3DBlendFactor.ONE;
                        camera.renderer.addDrawUnit(drawUnit, objectRenderPriority >= 0 ? objectRenderPriority : Renderer.OPAQUE_OVERHEAD);
                    }
                }
                if (transparentOption){
                    // Do not use z-buffer, draws with blending
                    if (isFirstGroup){
                        drawUnit.blendSource = Context3DBlendFactor.SOURCE_ALPHA;
                        drawUnit.blendDestination = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
                    }
                    else{
                        drawUnit.blendSource = Context3DBlendFactor.SOURCE_ALPHA;
                        drawUnit.blendDestination = Context3DBlendFactor.ONE;
                    }
                    camera.renderer.addDrawUnit(drawUnit, objectRenderPriority >= 0 ? objectRenderPriority : Renderer.TRANSPARENT_SORT);
                }
                
                 var lm:Transform3D = object.localToCameraTransform;
				 //lm.i*camera.m10, lm.j*camera.m10, lm.k*camera.m10, lm.l*camera.m10+camera.m14
                drawUnit.setVertexConstantsFromNumbers(program.vertexShader.getVariableIndex("cZSpace"), lm.i, lm.j, lm.k, lm.l);
                
				///*
               if (fogMode == SIMPLE || fogMode == ADVANCED) {
                   lm = object.localToCameraTransform;
                    var dist:Number = fogFar - fogNear;
                   drawUnit.setVertexConstantsFromNumbers(program.vertexShader.getVariableIndex("cFogSpace"), lm.i/dist, lm.j/dist, lm.k/dist, (lm.l - fogNear)/dist);
                    drawUnit.setFragmentConstantsFromNumbers(program.fragmentShader.getVariableIndex("cFogRange"), fogMaxDensity, 1, 0, 1 - fogMaxDensity);
                }
				//*/
				
               if (fogMode == SIMPLE  || mistMap != null) {
                    drawUnit.setFragmentConstantsFromNumbers(program.fragmentShader.getVariableIndex("cFogColor"), fogColorR, fogColorG, fogColorB, 1);
                }
				
				
				if (mistMap != null) drawUnit.setTextureAt(program.fragmentShader.getVariableIndex("sMist"), mistMap._texture);
			
    ///*    
					if (fogMode == ADVANCED) {
                    if (fogTexture == null) {
                        var bmd:BitmapData = new BitmapData(32, 1, false, 0xFF0000);
                        for (i = 0; i < 32; i++) {
                           bmd.setPixel(i, 0, ((i/32)*255) << 16);
                        }
                        fogTexture = new BitmapTextureResource(bmd);
                        fogTexture.upload(camera.context3D);
                    }
                    var cLocal:Transform3D = camera.localToGlobalTransform;
                    var halfW:Number = camera.view.width/2;
                    var leftX:Number = -halfW*cLocal.a + camera.focalLength*cLocal.c;
                    var leftY:Number = -halfW*cLocal.e + camera.focalLength*cLocal.g;
                    var rightX:Number = halfW*cLocal.a + camera.focalLength*cLocal.c;
                    var rightY:Number = halfW*cLocal.e + camera.focalLength*cLocal.g;
                    // Finding UV
                    var angle:Number = (Math.atan2(leftY, leftX) - Math.PI/2);
                    if (angle < 0) angle += Math.PI*2;
                    var dx:Number = rightX - leftX;
                    var dy:Number = rightY - leftY;
                    var lens:Number = Math.sqrt(dx*dx + dy*dy);
                    leftX /= lens;
                    leftY /= lens;
                    rightX /= lens;
                    rightY /= lens;
                    var uScale:Number = Math.acos(leftX*rightX + leftY*rightY)/Math.PI/2;
                    var uRight:Number = angle/Math.PI/2;
    
                    drawUnit.setFragmentConstantsFromNumbers(program.fragmentShader.getVariableIndex("cFogConsts"), 0.5*uScale, 0.5 - uRight, 0);
                    drawUnit.setTextureAt(program.fragmentShader.getVariableIndex("sFogTexture"), fogTexture._texture);
                }
				
				
			//*/
            }
			

            protected static var lightGroup:Vector.<Light3D> = new Vector.<Light3D>();
            protected static var shadowGroup:Vector.<Light3D> = new Vector.<Light3D>();

        

            /**
             * @protected
             */
            override alternativa3d function collectDraws(camera:Camera3D, surface:Surface, geometry:Geometry, lights:Vector.<Light3D>, lightsLength:int, useShadow:Boolean, objectRenderPriority:int = -1):void {
              
                lightMap =  lookupIndex < lightMaps.length ? lightMaps[ lookupIndex ] : null;
				normalMap = lookupIndex < normalMaps.length ? normalMaps[lookupIndex] : null;
				
                if (diffuseMap == null || normalMap == null || diffuseMap._texture == null || normalMap._texture == null) return;
                // Check if textures uploaded in to the context.
                if (opacityMap != null && opacityMap._texture == null || glossinessMap != null && glossinessMap._texture == null || specularMap != null && specularMap._texture == null || lightMap != null && lightMap._texture == null) return;

                var object:Object3D = surface.object;

                // Buffers
                var positionBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.POSITION);
                var uvBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.TEXCOORDS[0]);
                var normalsBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.NORMAL);
                var tangentsBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.TANGENT4);

                if (positionBuffer == null || uvBuffer == null) return;

                var i:int;
                var light:Light3D;

                if (lightsLength > 0 && (_normalMapSpace == NormalMapSpace.TANGENT_RIGHT_HANDED || _normalMapSpace == NormalMapSpace.TANGENT_LEFT_HANDED)) {
                    if (normalsBuffer == null || tangentsBuffer == null) return;
                }

                // Refresh programs for this context.
                if (camera.context3D != cachedContext3D) {
                    cachedContext3D = camera.context3D;
                    programsCache = caches[cachedContext3D];
                    if (programsCache == null) {
                        programsCache = new Dictionary(false);
                        caches[cachedContext3D] = programsCache;
                    }
                }

                var optionsPrograms:Array = programsCache[object.transformProcedure];
                if (optionsPrograms == null) {
                    optionsPrograms = [];
                    programsCache[object.transformProcedure] = optionsPrograms;
                }

                // Form groups of lights
                var groupsCount:int = 0;
                var lightGroupLength:int = 0;
                var shadowGroupLength:int = 0;
                for (i = 0; i < lightsLength; i++) {
                    light = lights[i];
                    if (light.shadow != null && useShadow) {
                        shadowGroup[int(shadowGroupLength++)] = light;
                    } else {
                        if (lightGroupLength == 6) {
                            groups[int(groupsCount++)] = lightGroup;
                            lightGroup = new Vector.<Light3D>();
                            lightGroupLength = 0;
                        }
                        lightGroup[int(lightGroupLength++)] = light;
                    }
                }
                if (lightGroupLength != 0) {
                    groups[int(groupsCount++)] = lightGroup;
                }

                // Iterate groups
                var materialKey:int;
                var program:TileAtlasMaterialProgram;
                var omniLightCount:int = 0;
                var directionalLightCount:int = 0;
                var spotLightCount:int = 0;

                if (groupsCount == 0 && shadowGroupLength == 0) {
                    // There is only Ambient light on the scene
                    // Form key
                    materialKey = ((lightMap != null) ? LIGHT_MAP_BIT : 0) | ((glossinessMap != null) ? GLOSSINESS_MAP_BIT : 0) | ((specularMap != null) ? SPECULAR_MAP_BIT : 0);

                    if (opaquePass && alphaThreshold <= alpha) {
                        if (alphaThreshold > 0) {
                            // Alpha test
                            // use opacityMap if it is presented
                            program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 1, null, 0, true, null);
                            addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, true, null, true, false, objectRenderPriority);
                        } else {
                            // do not use opacityMap at all
                            program = getProgram(object, optionsPrograms, camera, materialKey, null, 0, null, 0, true, null);
                            addDrawUnits(program, camera, surface, geometry, null, null, 0, true, null, true, false, objectRenderPriority);
                        }
                    }
                    // Transparent pass
                    if (transparentPass && alphaThreshold > 0 && alpha > 0) {
                        // use opacityMap if it is presented
                        if (alphaThreshold <= alpha && !opaquePass) {
                            // Alpha threshold
                            program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 2, null, 0, true, null);
                            addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, true, null, false, true, objectRenderPriority);
                        } else {
                            // There is no Alpha threshold or check z-buffer by previous pass
                            program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 0, null, 0, true, null);
                            addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, true, null, false, true, objectRenderPriority);
                        }
                    }
                } else {
                    var j:int;
                    var isFirstGroup:Boolean = true;
                    for (i = 0; i < groupsCount; i++) {
                        lightGroup = groups[i];
                        lightGroupLength = lightGroup.length;

                        // Group of lights without shadow
                        // Form key
                        materialKey = (isFirstGroup) ? ((lightMap != null) ? LIGHT_MAP_BIT : 0) : 0;
                        materialKey |= (_normalMapSpace << NORMAL_MAP_SPACE_OFFSET) | ((glossinessMap != null) ? GLOSSINESS_MAP_BIT : 0) | ((specularMap != null) ? SPECULAR_MAP_BIT : 0);
                        for (j = 0; j < lightGroupLength; j++) {
                            light = lightGroup[j];
                            if (light is OmniLight) omniLightCount++; else if (light is DirectionalLight) directionalLightCount++; else if (light is SpotLight) spotLightCount++;
                        }
                        materialKey |= omniLightCount << OMNI_LIGHT_OFFSET;
                        materialKey |= directionalLightCount << DIRECTIONAL_LIGHT_OFFSET;
                        materialKey |= spotLightCount << SPOT_LIGHT_OFFSET;

                        // Create program and drawUnit for group
                        // Opaque pass
                        if (opaquePass && alphaThreshold <= alpha) {
                            if (alphaThreshold > 0) {
                                // Alpha test
                                // use opacityMap if it is presented
                                program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 1, lightGroup, lightGroupLength, isFirstGroup, null);
                                addDrawUnits(program, camera, surface, geometry, opacityMap, lightGroup, lightGroupLength, isFirstGroup, null, true, false, objectRenderPriority);
                            } else {
                                // do not use opacityMap at all
                                program = getProgram(object, optionsPrograms, camera, materialKey, null, 0, lightGroup, lightGroupLength, isFirstGroup, null);
                                addDrawUnits(program, camera, surface, geometry, null, lightGroup, lightGroupLength, isFirstGroup, null, true, false, objectRenderPriority);
                            }
                        }
                        // Transparent pass
                        if (transparentPass && alphaThreshold > 0 && alpha > 0) {
                            // use opacityMap if it is presented
                            if (alphaThreshold <= alpha && !opaquePass) {
                                // Alpha threshold
                                program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 2, lightGroup, lightGroupLength, isFirstGroup, null);
                                addDrawUnits(program, camera, surface, geometry, opacityMap, lightGroup, lightGroupLength, isFirstGroup, null, false, true, objectRenderPriority);
                            } else {
                                // There is no Alpha threshold or check z-buffer by previous pass
                                program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 0, lightGroup, lightGroupLength, isFirstGroup, null);
                                addDrawUnits(program, camera, surface, geometry, opacityMap, lightGroup, lightGroupLength, isFirstGroup, null, false, true, objectRenderPriority);
                            }
                        }
                        isFirstGroup = false;
                        lightGroup.length = 0;
                    }

                    if (shadowGroupLength > 0) {
                        // Group of ligths with shadow
                        // For each light we will create new drawUnit
                        for (j = 0; j < shadowGroupLength; j++) {

                            light = shadowGroup[j];
                            // Form key
                            materialKey = (isFirstGroup) ? ((lightMap != null) ? LIGHT_MAP_BIT : 0) : 0;
                            materialKey |= (_normalMapSpace << NORMAL_MAP_SPACE_OFFSET) | ((glossinessMap != null) ? GLOSSINESS_MAP_BIT : 0) | ((specularMap != null) ? SPECULAR_MAP_BIT : 0);
                            materialKey |= light.shadow.type << SHADOW_OFFSET;
                            if (light is OmniLight) materialKey |= 1 << OMNI_LIGHT_OFFSET; else if (light is DirectionalLight) materialKey |= 1 << DIRECTIONAL_LIGHT_OFFSET; else if (light is SpotLight) materialKey |= 1 << SPOT_LIGHT_OFFSET;

                            // Для группы создаем программу и дроуюнит
                            // Opaque pass
                            if (opaquePass && alphaThreshold <= alpha) {
                                if (alphaThreshold > 0) {
                                    // Alpha test
                                    // use opacityMap if it is presented
                                    program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 1, null, 0, isFirstGroup, light);
                                    addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, isFirstGroup, light, true, false, objectRenderPriority);
                                } else {
                                    // do not use opacityMap at all
                                    program = getProgram(object, optionsPrograms, camera, materialKey, null, 0, null, 0, isFirstGroup, light);
                                    addDrawUnits(program, camera, surface, geometry, null, null, 0, isFirstGroup, light, true, false, objectRenderPriority);
                                }
                            }
                            // Transparent pass
                            if (transparentPass && alphaThreshold > 0 && alpha > 0) {
                                // use opacityMap if it is presented
                                if (alphaThreshold <= alpha && !opaquePass) {
                                    // Alpha threshold
                                    program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 2, null, 0, isFirstGroup, light);
                                    addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, isFirstGroup, light, false, true, objectRenderPriority);
                                } else {
                                    // There is no Alpha threshold or check z-buffer by previous pass
                                    program = getProgram(object, optionsPrograms, camera, materialKey, opacityMap, 0, null, 0, isFirstGroup, light);
                                    addDrawUnits(program, camera, surface, geometry, opacityMap, null, 0, isFirstGroup, light, false, true, objectRenderPriority);
                                }
                            }
                            isFirstGroup = false;
                        }
                    }
                    shadowGroup.length = 0;
                }
                groups.length = 0;
            }

            /**
             * @inheritDoc
             */
            override public function clone():Material {
                var res:TileAtlasMaterial = new TileAtlasMaterial(atlasSheet, blendAtlas, mipmapTable, mipmapUVCap, tileIndexMaps, normalMaps, lightMaps, tileSizePx, tilePaddingPxH, tilePaddingPxV);
                res.clonePropertiesFrom(this);
                return res;
            }
			
			

            /**
             * @inheritDoc
             */
            override protected function clonePropertiesFrom(source:Material):void {
                super.clonePropertiesFrom(source);
                var sMaterial:TileAtlasMaterial = TileAtlasMaterial(source);
                glossiness = sMaterial.glossiness;
                specularPower = sMaterial.specularPower;
                _normalMapSpace = sMaterial._normalMapSpace;
                lightMap = sMaterial.lightMap;
              //  lightMapChannel = sMaterial.lightMapChannel;
                resolution = sMaterial.resolution;
            }
        }

	}
	
import alternativa.engine3d.materials.ShaderProgram;
    import alternativa.engine3d.materials.compiler.Linker;

    import flash.display3D.Context3D;

    class TileAtlasMaterialProgram extends ShaderProgram {

        public var aPosition:int = -1;
        public var aUV:int = -1;
      //  public var aUV1:int = -1;
        public var aNormal:int = -1;
        public var aTangent:int = -1;
        public var cProjMatrix:int = -1;
        public var cCameraPosition:int = -1;
		public var cUVProperties:int = -1;
		
        public var cAmbientColor:int = -1;
        public var cSurface:int = -1;
        public var cThresholdAlpha:int = -1;
        public var sDiffuse:int = -1;
        public var sOpacity:int = -1;
        public var sBump:int = -1;
        public var sGlossiness:int = -1;
        public var sSpecular:int = -1;
        public var sLightMap:int = -1;

        public var cPosition:Vector.<int>;
        public var cRadius:Vector.<int>;
        public var cAxis:Vector.<int>;
        public var cColor:Vector.<int>;
        
        public var cF:int = -1;
        public var cAtlasTiles:int = -1;
		public var cWater:int = -1;
        
        public var cTilePaddSize:int = -1;  
        public var cTileFrac:int = -1;
        public var sTileIndices:int = -1;
        public var c255:int = -1;  
        public var sMipmapOffsets:int = -1;
        public var sBlendAtlas:int = -1;




        public function TileAtlasMaterialProgram(vertex:Linker, fragment:Linker, numLigths:int) {
            super(vertex, fragment);

            cPosition = new Vector.<int>(numLigths);
            cRadius = new Vector.<int>(numLigths);
            cAxis = new Vector.<int>(numLigths);
            cColor = new Vector.<int>(numLigths);
            
            
        }

        override public function upload(context3D:Context3D):void {
            super.upload(context3D);

            aPosition = vertexShader.findVariable("aPosition");
            aUV = vertexShader.findVariable("aUV");
          // aUV1 = vertexShader.findVariable("aUV1");
            aNormal = vertexShader.findVariable("aNormal");
            aTangent = vertexShader.findVariable("aTangent");
            cProjMatrix = vertexShader.findVariable("cProjMatrix");
            cCameraPosition = vertexShader.findVariable("cCameraPosition");
			cUVProperties = vertexShader.findVariable("cUVProperties");

            cAmbientColor = fragmentShader.findVariable("cAmbientColor");
            cSurface = fragmentShader.findVariable("cSurface");
            cThresholdAlpha = fragmentShader.findVariable("cThresholdAlpha");
			cWater = fragmentShader.findVariable("cWater");
            sDiffuse = fragmentShader.findVariable("sDiffuse"); 
            sOpacity = fragmentShader.findVariable("sOpacity");
            sBump = fragmentShader.findVariable("sBump");
            sGlossiness = fragmentShader.findVariable("sGlossiness");
            sSpecular = fragmentShader.findVariable("sSpecular");
            sLightMap = fragmentShader.findVariable("sLightMap");
            sTileIndices = fragmentShader.findVariable("sTileIndices");
            sMipmapOffsets = fragmentShader.findVariable("sMipmapOffsets");
            sBlendAtlas = fragmentShader.findVariable("sBlendAtlas");
            
            cTilePaddSize = fragmentShader.findVariable("cTilePaddSize");  // u padding, v padding on atlas.   u and v tile sizes + padding on atlas.
            cTileFrac = fragmentShader.findVariable("cTileFrac");  // u and v recriprocal fractionals for tile index map,   u and v tile sizes on atlas
            cF = fragmentShader.findVariable("cF");
             cAtlasTiles = fragmentShader.findVariable("cAtlasTiles");    
            c255 = fragmentShader.findVariable("c255"); 
            
            var count:int = cPosition.length;
            for (var i:int = 0; i < count; i++) {
                cPosition[i] = fragmentShader.findVariable("c" + i + "Position");
                cRadius[i] = fragmentShader.findVariable("c" + i + "Radius");
                cAxis[i] = fragmentShader.findVariable("c" + i + "Axis");
                cColor[i] = fragmentShader.findVariable("c" + i + "Color");
            }

        }
    }
        
	
        