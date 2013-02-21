package terraingen.expander 
{
	import com.bit101.components.ComboBox;
	import com.bit101.components.VBox;
	import flash.display.Sprite;
	/**
	 * The utility is used for quickly creating expanded procedural terrain detail over small grayscaled heightmap image samples, and saving out full resolution heightmap(s) accordingly. The problem with most grayscaled heightmaps is that they can potentially lack detail since the resolution is limited to 0-255 units (epsecially for larger worlds). Thus, this utility can be used to process low-detail heightmaps to produce more natural-looking (bumpier) terrains (by adding detail) and ensure each page sample is seamed smoothly across the edges.
	 * 
	 * Main document class. Run the .swf file under a specific folder location which contains a list of elevation image maps. Select the filters you wish to use accordingly.
	 * 
	 * @author Glenn Ko
	 */
	public class ProceduralExpansion extends Sprite
	{
		private var _cbFileExtension:ComboBox;
		
		
		public function ProceduralExpansion() 
		{
			var uiLayout:VBox = new VBox(this);
			// Parameters:
			// image filename
			// .jpg/.png./.data (resulting filename convention)
			// page-samples across
			// expand sample to fit tiles across
			// filters to apply (smooth edges between terrain)  
			
			
			// marching 2x2 grid
			// for each iteration, 
			
			_cbFileExtension = new ComboBox(uiLayout, 0, 0, "", []);
			//_cbFileExtension.d
		}
		
	}

}