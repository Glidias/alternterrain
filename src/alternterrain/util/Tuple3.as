package alternterrain.util 
{
	import flash.geom.Vector3D;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	import flash.utils.IExternalizable;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class Tuple3 extends Vector3D implements IExternalizable
	{
		
		public function Tuple3(x:Number=0, y:Number=0, z:Number=0) 
		{
			super(x,y,z)
		}
		
		/* INTERFACE flash.utils.IExternalizable */
		
		public function writeExternal(output:IDataOutput):void 
		{
			output.writeFloat(x);
			output.writeFloat(y);
			output.writeFloat(z);
			
		}
		
		public function readExternal(input:IDataInput):void 
		{
			x = input.readFloat();
			y = input.readFloat();
			z = input.readFloat();
		}
		
	}

}