/**
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 * If it is not possible or desirable to put the notice in a particular file, then You may include the notice in a location (such as a LICENSE file in a relevant directory) where a recipient would be likely to look for such a notice.
 * You may add additional accurate notices of copyright ownership.
 *
 * It is desirable to notify that Covered Software was "Powered by AlternativaPlatform" with link to http://www.alternativaplatform.com/ 
 * */

package alternterrain.materials {

	import alternativa.engine3d.alternativa3d;
	import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.DrawUnit;
	import alternativa.engine3d.core.Light3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.Renderer;
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.materials.compiler.Linker;
	import alternativa.engine3d.materials.compiler.Procedure;
	import alternativa.engine3d.materials.compiler.VariableType;
	import alternativa.engine3d.materials.Material;
	import alternativa.engine3d.objects.Surface;
	import alternativa.engine3d.resources.Geometry;

	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.VertexBuffer3D;
	import flash.utils.Dictionary;

	use namespace alternativa3d;

	/**
	 * The materiall fills surface with 2 checkboard colors based on repeating uv coordinates (ie. >1 uv coordinates).
	 *
	 */
	public class CheckboardFillMaterial extends Material {
		
		private static var caches:Dictionary = new Dictionary(true);
		private var cachedContext3D:Context3D;
		private var programsCache:Dictionary;

		private static var outColorProcedure:Procedure = new Procedure([
			"#v0=vUV",
			"#c0=cColor", 
			"#c1=cColor2",
			"#c2=cStuff",
			"frc t0.xy, v0.xy",
			"sub t0.xy, v0.xy, t0.xy",
			"mul t0.xy, c2.xy, t0.xy",
			"frc t0.xy, t0.xy",
			"mul t0.xy, t0.xy, c2.ww",
			"sub t0.x, t0.x, t0.y",
			"abs t0.x, t0.x",
			"sge t0.w, t0.x, c2.z",
			"slt t0.z, t0.x, c2.z",
			
			"mul t1.xyzw, c1.xyzw, t0.wwww", //  t1 calculation for c1
			"mul t0.xyzw, c0.xyzw, t0.zzzz",  // final t0 calculation for c0
			"add t1.xyzw, t1.xyzw, t0.xyzw",
			"mov o0, t1"
		], "outColorProcedure");
		/**
		 * Transparency
		 */
		
		private var red:Number;
		private var green:Number;
		private var blue:Number;
		
		private var red2:Number;
		private var green2:Number;
		private var blue2:Number;
		
		static alternativa3d const _passUVProcedure:Procedure = new Procedure(["#v0=vUV", "#a0=aUV", "mov v0, a0"], "passUVProcedure");
		
		/**
		 * Color.
		 */
		public function get color():uint {
			return (red*0xFF << 16) + (green*0xFF << 8) + blue*0xFF;
		}
		
		public function get color2():uint {
			return (red2*0xFF << 16) + (green2*0xFF << 8) + blue2*0xFF;
		}

		/**
		 * @private
		 */
		public function set color(value:uint):void {
			red = ((value >> 16) & 0xFF)/0xFF;
			green = ((value >> 8) & 0xFF)/0xFF;
			blue = (value & 0xff)/0xFF;
		}
		
		public function set color2(value:uint):void {
			red2 = ((value >> 16) & 0xFF)/0xFF;
			green2 = ((value >> 8) & 0xFF)/0xFF;
			blue2 = (value & 0xff)/0xFF;
		}

		/**
		 * 
		 * @param	color
		 * @param	color2
		 */
		public function CheckboardFillMaterial(color:uint = 0x777777, color2:uint=0x333333) {
			this.color = color;
			this.color2 = color2;
		}

		private function setupProgram(object:Object3D):CheckboardFillMaterialProgram {
			var vertexLinker:Linker = new Linker(Context3DProgramType.VERTEX);
			var positionVar:String = "aPosition";
			vertexLinker.declareVariable(positionVar, VariableType.ATTRIBUTE);
			if (object.transformProcedure != null) {
				positionVar = appendPositionTransformProcedure(object.transformProcedure, vertexLinker);
			}
			vertexLinker.addProcedure(_projectProcedure);
			vertexLinker.setInputParams(_projectProcedure, positionVar);
			vertexLinker.addProcedure(_passUVProcedure);

			var fragmentLinker:Linker = new Linker(Context3DProgramType.FRAGMENT);
			fragmentLinker.addProcedure(outColorProcedure);
			fragmentLinker.varyings = vertexLinker.varyings;
			return new CheckboardFillMaterialProgram(vertexLinker, fragmentLinker);
		}

		/**
		 * @private 
		 */
		override alternativa3d function collectDraws(camera:Camera3D, surface:Surface, geometry:Geometry, lights:Vector.<Light3D>, lightsLength:int, useShadow:Boolean, objectRenderPriority:int = -1):void {
			var object:Object3D = surface.object;
			// Strams
			var positionBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.POSITION);
			var uvBuffer:VertexBuffer3D = geometry.getVertexBuffer(VertexAttributes.TEXCOORDS[0]);
			// Check validity
			if (positionBuffer == null || uvBuffer == null) return;
			// Program

			// Renew program cache for this context
			if (camera.context3D != cachedContext3D) {
				cachedContext3D = camera.context3D;
				programsCache = caches[cachedContext3D];
				if (programsCache == null) {
					programsCache = new Dictionary();
					caches[cachedContext3D] = programsCache;
				}
			}

			var program:CheckboardFillMaterialProgram = programsCache[object.transformProcedure];
			if (program == null) {
				program = setupProgram(object);
				program.upload(camera.context3D);
				programsCache[object.transformProcedure] = program;
			}
			// Drawcall
			var drawUnit:DrawUnit = camera.renderer.createDrawUnit(object, program.program, geometry._indexBuffer, surface.indexBegin, surface.numTriangles, program);
			// Streams
			drawUnit.setVertexBufferAt(program.aPosition, positionBuffer, geometry._attributesOffsets[VertexAttributes.POSITION], VertexAttributes.FORMATS[VertexAttributes.POSITION]);
			drawUnit.setVertexBufferAt(program.aUV, uvBuffer, geometry._attributesOffsets[VertexAttributes.TEXCOORDS[0]], VertexAttributes.FORMATS[VertexAttributes.TEXCOORDS[0]]);
			// Constants
			object.setTransformConstants(drawUnit, surface, program.vertexShader, camera);
			drawUnit.setProjectionConstants(camera, program.cProjMatrix, object.localToCameraTransform);
			drawUnit.setFragmentConstantsFromNumbers(program.cColor, red, green, blue, 1);
			drawUnit.setFragmentConstantsFromNumbers(program.cColor2, red2, green2, blue2, 1);
			drawUnit.setFragmentConstantsFromNumbers(program.cStuff, 0.5, 0.5, 1, 2);

			camera.renderer.addDrawUnit(drawUnit, objectRenderPriority >= 0 ? objectRenderPriority : Renderer.OPAQUE);
			
		}

		/**
		 * @inheritDoc 
		 */
		override public function clone():Material {
			var res:CheckboardFillMaterial = new CheckboardFillMaterial(color, color2);
			res.clonePropertiesFrom(this);
			return res;
		}

	}
}

import alternativa.engine3d.materials.ShaderProgram;
import alternativa.engine3d.materials.compiler.Linker;

import flash.display3D.Context3D;

class CheckboardFillMaterialProgram extends ShaderProgram {

	public var aPosition:int = -1;
	public var aUV:int = -1;
	public var cProjMatrix:int = -1;
	public var cColor:int = -1;
	public var cColor2:int = -1;
	public var cStuff:int = -1;

	public function CheckboardFillMaterialProgram(vertex:Linker, fragment:Linker) {
		super(vertex, fragment);
	}

	override public function upload(context3D:Context3D):void {
		super.upload(context3D);

		aPosition =  vertexShader.findVariable("aPosition");
		aUV =  vertexShader.findVariable("aUV");
		cProjMatrix = vertexShader.findVariable("cProjMatrix");
		cColor = fragmentShader.findVariable("cColor");
		cColor2 = fragmentShader.findVariable("cColor2");
		cStuff = fragmentShader.findVariable("cStuff");
	}
}
