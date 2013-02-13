package atregen.resources 
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	import flash.utils.IExternalizable;
	/**
	 * Island format bundle containing elevation data and other optional information.
	 * @author Glenn Ko
	 */
	public class ISLFormat implements IExternalizable
	{
		
		public var elevation:ByteArray;   // usually for height map or generating of normal maps  (single channeL)
		
		public var biomediffuse:ByteArray;		// usually for diffuse color map   (RGB)
		public var biometiles:ByteArray;		// usually for tile map  (RGB)
		public var slopelighting:ByteArray;  	// usually for lightmap   (Single channel)
		//public var moisture:ByteArray;
		
		public var tilesAcross:int = 0;
		
		public function ISLFormat() 
		{
			
		}
		
		/* INTERFACE flash.utils.IExternalizable */
		
		public function writeExternal(output:IDataOutput):void 
		{
			output.writeShort(tilesAcross);
			
			if (elevation == null) throw new Error("Elevation required!");
			output.writeUnsignedInt(elevation.length);
			output.writeBytes(elevation, 0, elevation.length);
			
			
			output.writeBoolean(biomediffuse != null);
			if (biomediffuse != null) {
				output.writeUnsignedInt(biomediffuse.length);
				output.writeBytes(biomediffuse, 0, biomediffuse.length);
			}
			
			output.writeBoolean(biometiles != null);
			if (biometiles != null) {
				output.writeUnsignedInt(biometiles.length);
				output.writeBytes(biometiles, 0, biometiles.length);
			}
			
			output.writeBoolean(slopelighting != null);
			if (slopelighting != null) {
				output.writeUnsignedInt(slopelighting.length);
				output.writeBytes(slopelighting, 0, slopelighting.length);
			}
		}
		
		public function readExternal(input:IDataInput):void 
		{
			tilesAcross = input.readShort();
			
			elevation = new ByteArray();
			input.readBytes( elevation, 0, input.readUnsignedInt() );
			
			if (input.readBoolean() ) {
				biometiles = new ByteArray();
				input.readBytes( biometiles, 0, input.readUnsignedInt() );
			}
			
			if (input.readBoolean() ) {
				biomediffuse = new ByteArray();
				input.readBytes( biomediffuse, 0, input.readUnsignedInt() );
			}
			
			if (input.readBoolean() ) {
				slopelighting = new ByteArray();
				input.readBytes( slopelighting, 0, input.readUnsignedInt() );
			}
			
		}
		
	}

}