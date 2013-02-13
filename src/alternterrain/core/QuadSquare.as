package alternterrain.core 
{
	/**
	 * ...
	 * @author Glenn Ko
	 */
import alternativa.engine3d.core.Camera3D;
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.alternativa3d;
	import flash.geom.Vector3D;

	use namespace alternativa3d;

	
	/**
	 * @author Thatcher Ulrich (tu@tulrich.com)
	 * @author Glenn Ko
	 * Thatcher's lod terrain implementation. This a a striped down version of his QuadSquare class used to temporarily generate height data
	 * and vertex error-data due to different LOD levels.
	 */
	
	
	 public class QuadSquare
	{
		public var Child:Vector.<QuadSquare>;
		
		// center, e, n, w, s [5]  , vertex heights   
		public	var Vertex:Vector.<int> = new Vector.<int>(5, true);	
		// e, s, children: ne, nw, sw, se  [6]
		public	var errorList:Vector.<int> = new Vector.<int>(6, true); 
		
		// Bounds for frustum culling and error testing.
		public var MinY:int;
		public var MaxY:int;	

		
		public function QuadSquare(pcd:QuadCornerData) 
		{
			pcd.Square = this;
			MinY = 1.79e+308;
			MaxY = -1.79e+308;
			
			// Set static to true if/when this node contains real data, and
			// not just interpolated values.  When static == false, a node
			// can be deleted by the Update() function if none of its
			// vertices or children are enabled.
		
	
			var	i:int;
			
			/*
			for (i = 0; i < 4; i++) {
				Child[i] = NULL;
			}*/
			Child = new Vector.<QuadSquare>(4, true);

		
			
			// Set default vertex positions by interpolating from given corners.
			// Just bilinear interpolation.
			Vertex[0] = 0.25 * (pcd.Verts[0] + pcd.Verts[1] + pcd.Verts[2] + pcd.Verts[3]);
			Vertex[1] = 0.5 * (pcd.Verts[3] + pcd.Verts[0]);
			Vertex[2] = 0.5 * (pcd.Verts[0] + pcd.Verts[1]);
			Vertex[3] = 0.5 * (pcd.Verts[1] + pcd.Verts[2]);
			Vertex[4] = 0.5 * (pcd.Verts[2] + pcd.Verts[3]);
			

			for (i = 0; i < 2; i++) {
				errorList[i] = 0;
			}
			for (i = 0; i < 4; i++) {
				errorList[i+2] = Math.abs((Vertex[0] + pcd.Verts[i]) - (Vertex[i+1] + Vertex[((i+1)&3) + 1])) * 0.25;
			}

			// Compute MinY/MaxY based on corner verts.
			MinY = MaxY = pcd.Verts[0];
			for (i = 0; i < 4; i++) {
				var	y:Number = pcd.Verts[i];
				if (y < MinY) MinY = y;
				if (y > MaxY) MaxY = y;
			}
			
		}
		
		public function calculateYBounds(pcd:QuadCornerData):void {
			MinY = 1.79e+308;
			MaxY = -1.79e+308;
			var	y:Number
			var i:int;
			for (i = 0; i < 4; i++) {
				y = pcd.Verts[i];
				if (y < MinY) MinY = y;
				if (y > MaxY) MaxY = y;
			}
			for (i = 0; i < 5; i++) {
				y = Vertex[i];
				if (y < MinY) MinY = y;
				if (y > MaxY) MaxY = y;
			}
		}
		
		public function destroy():void {
			for (var i:int = 0; i < 4; i++) {
				if (Child[i] !=null) {
					Child[i].destroy();
					Child[i] = null;
				}
			}

			Child = null;
			Vertex = null;
			errorList = null;
		}
	
	
		
	
		//se,sw,nw,ne
		// ne, nw, sw, se [4]
		public function	SetupCornerData(q:QuadCornerData, cd:QuadCornerData, ChildIndex:int):void
		// Fills the given structure with the appropriate corner values for the
		// specified child block, given our own vertex data and our corner
		// vertex data from cd.
		//
		// ChildIndex mapping:
		// +-+-+
		// |1|0|
		// +-+-+
		// |2|3|
		// +-+-+
		//
		// Verts mapping:
		// 1-0
		// | |
		// 2-3
		//
		// Vertex mapping:
		// +-2-+
		// | | |
		// 3-0-1
		// | | |
		// +-4-+
		{
			var	half:int = 1 << cd.Level;

			q.Parent = cd;
			q.Square = Child[ChildIndex];
			q.Level = cd.Level - 1;
			q.ChildIndex = ChildIndex;
			
			switch (ChildIndex) {
			case 0:
				q.xorg = cd.xorg + half;
				q.zorg = cd.zorg;
				q.Verts[0] = cd.Verts[0];
				q.Verts[1] = Vertex[2];
				q.Verts[2] = Vertex[0];
				q.Verts[3] = Vertex[1];
				break;

			case 1:
				q.xorg = cd.xorg;
				q.zorg = cd.zorg;
				q.Verts[0] = Vertex[2];
				q.Verts[1] = cd.Verts[1];
				q.Verts[2] = Vertex[3];
				q.Verts[3] = Vertex[0];
				break;

			case 2:
				q.xorg = cd.xorg;
				q.zorg = cd.zorg + half;
				q.Verts[0] = Vertex[0];
				q.Verts[1] = Vertex[3];
				q.Verts[2] = cd.Verts[2];
				q.Verts[3] = Vertex[4];
				break;

			case 3:
				q.xorg = cd.xorg + half;
				q.zorg = cd.zorg + half;
				q.Verts[0] = Vertex[1];
				q.Verts[1] = Vertex[0];
				q.Verts[2] = Vertex[4];
				q.Verts[3] = cd.Verts[3];
				break;
			}	
		}
		
		


		public function CountNodes():int
		// Debugging function.  Counts the number of nodes in this subtree.
		{
			var count:int = 1;	// Count ourself.

			// Count descendants.
			for (var i:int = 0; i < 4; i++) {
				if (Child[i]) count += Child[i].CountNodes()
				else {
					for (var u:int = 0; u < 4; u++) {
						if (Child[u] != null) throw new Error("NOT dense!");
					}
				}
			}

			return count;
		}
		


	


private function GetNeighbor(dir:int,  cd:QuadCornerData):QuadSquare
// Traverses the tree in search of the QuadSquare neighboring this square to the
// specified direction.  0-3 -. { E, N, W, S }.
// Returns NULL if the neighbor is outside the bounds of the tree.
{
	// If we don't have a parent, then we don't have a neighbor.
	// (Actually, we could have inter-tree connectivity at this level
	// for connecting separate trees together.)
	if (cd.Parent == null) {  
		return cd is QuadCornerDataNeighbor ?  (cd as QuadCornerDataNeighbor).neighbors[dir] != null ? (cd as QuadCornerDataNeighbor).neighbors[dir].Square : null : cd.Square;  // TODO: check, also neighbors[dir] might be optionally null
	}
	
	// Find the parent and the child-index of the square we want to locate or create.
	var p:QuadSquare = null;
	
	var	index:int =  cd.ChildIndex ^ 1 ^ ((dir & 1) << 1);
	var	SameParent:Boolean = ((dir - cd.ChildIndex) & 2) ? true : false;
	
	if (SameParent) {
		p = cd.Parent.Square;
	} else {
		p = cd.Parent.Square.GetNeighbor(dir, cd.Parent);
		if (p == null) return null;
	}
	
	return p.Child[index];
}


public function SampleFromHeightMap(cd:QuadCornerData, hm:HeightMapInfo):void {
	var BlockSize:int = 2 << cd.Level;
	if (cd.xorg > hm.XOrigin + ((hm.XSize + 2) << hm.Scale) ||
	    cd.xorg + BlockSize < hm.XOrigin - (1 << hm.Scale) ||
	    cd.zorg > hm.ZOrigin + ((hm.ZSize + 2) << hm.Scale) ||
	    cd.zorg + BlockSize < hm.ZOrigin - (1 << hm.Scale))
	{
		// This square does not touch the given height array area; no need to modify this square or descendants.
		return;
	}
	
	// Is this enabling on the fly really necessary?
	/*
	if (cd.Parent && cd.Parent.Square) {
		cd.Parent.Square.EnableChild(cd.ChildIndex, cd.Parent);	// causes parent edge verts to be enabled, possibly causing neighbor blocks to be created.
	}
	*/
	
	// todo: optimize by checking real indices rather than unnecessary sampling!
	cd.Verts[0] = hm.Sample( cd.xorg + BlockSize, cd.zorg);
	cd.Verts[1] = hm.Sample( cd.xorg, cd.zorg);
	cd.Verts[2] = hm.Sample( cd.xorg, cd.zorg+BlockSize);
	cd.Verts[3] = hm.Sample( cd.xorg + BlockSize, cd.zorg+BlockSize);
	
	var	i:int
	
	var half:int = 1 << cd.Level;
	var size:int = half << 1;
	
	// Deviate vertex heights based on data sampled from heightmap.
	var	s:Vector.<int> = new Vector.<int>(5,true);
	s[0] = hm.Sample(cd.xorg + half, cd.zorg + half);
	s[1] = hm.Sample(cd.xorg + (half<<1), cd.zorg + half);
	s[2] = hm.Sample(cd.xorg + half, cd.zorg);
	s[3] = hm.Sample(cd.xorg, cd.zorg + half);
	s[4] = hm.Sample(cd.xorg + half, cd.zorg + (half<<1));

	// Modify the vertex heights if necessary, and set the dirty
	// flag if any modifications occur, so that we know we need to
	// recompute error data later.
	for (i = 0; i < 5; i++) {
		//if (s[i] != 0) {
			
			Vertex[i] = s[i];  //+   dont deviate
		//}
	}
}

public function	AddHeightMap(cd:QuadCornerData,  hm:HeightMapInfo ):void
// Sets the height of all samples within the specified rectangular
// region using the given array of floats.  Extends the tree to the
// level of detail defined by (1 << hm.Scale) as necessary.
{
	
	// If block is outside rectangle, then don't bother.
	var BlockSize:int = 2 << cd.Level;
	if (cd.xorg > hm.XOrigin + ((hm.XSize + 2) << hm.Scale) ||
	    cd.xorg + BlockSize < hm.XOrigin - (1 << hm.Scale) ||
	    cd.zorg > hm.ZOrigin + ((hm.ZSize + 2) << hm.Scale) ||
	    cd.zorg + BlockSize < hm.ZOrigin - (1 << hm.Scale))
	{
		// This square does not touch the given height array area; no need to modify this square or descendants.
		return;
	}
	
	// Is this enabling on the fly really necessary?
	/*
	if (cd.Parent && cd.Parent.Square) {
		cd.Parent.Square.EnableChild(cd.ChildIndex, cd.Parent);	// causes parent edge verts to be enabled, possibly causing neighbor blocks to be created.
	}
	*/
	
	// todo: optimize by checking real indices rather than unnecessary sampling!
	cd.Verts[0] = hm.Sample( cd.xorg + BlockSize, cd.zorg);
	cd.Verts[1] = hm.Sample( cd.xorg, cd.zorg);
	cd.Verts[2] = hm.Sample( cd.xorg, cd.zorg+BlockSize);
	cd.Verts[3] = hm.Sample( cd.xorg + BlockSize, cd.zorg+BlockSize);
	
	var	i:int
	
	var half:int = 1 << cd.Level;
	var size:int = half << 1;
	
	// Create and update child nodes.
	for (i = 0; i < 4; i++) {
		var	q:QuadCornerData =  new QuadCornerData(); 
		SetupCornerData(q, cd, i);

		if (cd.Level < hm.Scale) continue;
		
		if (Child[i] == null) {  // && 
			// Create child node w/ current (unmodified) values for corner verts.
			Child[i]  = new QuadSquare(q);
		}
		
		// Recurse.
		//if (Child[i]) {
			Child[i].AddHeightMap(q, hm);
		//}
	}
	
	// Deviate vertex heights based on data sampled from heightmap.
	var	s:Vector.<int> = new Vector.<int>(5,true);
	s[0] = hm.Sample(cd.xorg + half, cd.zorg + half);
	s[1] = hm.Sample(cd.xorg + (half<<1), cd.zorg + half);
	s[2] = hm.Sample(cd.xorg + half, cd.zorg);
	s[3] = hm.Sample(cd.xorg, cd.zorg + half);
	s[4] = hm.Sample(cd.xorg + half, cd.zorg + (half<<1));

	// Modify the vertex heights if necessary, and set the dirty
	// flag if any modifications occur, so that we know we need to
	// recompute error data later.
	for (i = 0; i < 5; i++) {
		//if (s[i] != 0) {
			
			Vertex[i] = s[i];  //+   dont deviate
		//}
	}

	
}
		
private static const STACK:Vector.<int> = new Vector.<int>(32, true);


// Use RecomputerErrorAndLighting()  to get error value to pass into 2nd parameter for this QuadSquare, recurse down to till (not including)
// targetChunkLevel 2^13 = 8192 ...(32*256=8192)  and for each recursion visit, form up a simpler tree of QuadSquareChunks.
public function GetQuadSquareChunk(cd:QuadCornerData, error:int, targetChunkLevel:int=12):QuadSquareChunk {
	if (cd.Level < targetChunkLevel) throw new Error("LOD of current quad square is too fine for target chunk LOD level!");
	
	var chunk:QuadSquareChunk = new QuadSquareChunk();
	chunk.MinY = MinY;
	chunk.MaxY = MaxY;
	chunk.error = error;
	if (cd.Level == targetChunkLevel)  return chunk;
	
	// with starting cd, recurse though entire quad squares till targetChunkLevel to get error value
	//GetSquareChunkAux(cd, 
	var q:QuadCornerData;
	SetupCornerData( q = new QuadCornerData(), cd, 0);
	chunk.Child[0] = GetQuadSquareChunk(q, errorList[0], targetChunkLevel);  
	SetupCornerData( q =  new QuadCornerData(), cd, 1);
	chunk.Child[1] = GetQuadSquareChunk(q, errorList[1],targetChunkLevel);
	SetupCornerData( q =  new QuadCornerData(), cd, 2);
	chunk.Child[2] = GetQuadSquareChunk(q, errorList[2],targetChunkLevel);
	SetupCornerData( q = new QuadCornerData(), cd, 3);
	chunk.Child[3] = GetQuadSquareChunk(q, errorList[3],targetChunkLevel);
	
	return chunk;
}



public	function StaticCullAux(cd:QuadCornerData,  ThresholdDetail:Number,  TargetLevel:int):void
// Check this node and its descendents, and remove nodes which don't contain
// necessary detail.
{
	var	i:int, j:int;
	var	q:QuadCornerData;

	if (cd.Level > TargetLevel) {
		// Just recurse to child nodes.
		for (j = 0; j < 4; j++) {
			if (j < 2) i = 1 - j;
			else i = j;

			if (Child[i]) {
				q = new QuadCornerData();
				SetupCornerData(q, cd, i);
				Child[i].StaticCullAux(q, ThresholdDetail, TargetLevel);
				
			}
		}
		return;
	}

	// We're at the target level.  Check this node to see if it's OK to delete it.
	
	// Check edge vertices to see if they're necessary.
	var	size:Number = 2 << cd.Level;	// Edge length.
	if (Child[0] == null && Child[3] == null && errorList[0] * ThresholdDetail < size) {
		var	s:QuadSquare = GetNeighbor(0, cd);
		if (s == null || (s.Child[1] == null && s.Child[2] == null)) {

			// Force vertex height to the edge value.
			var	y:Number = (cd.Verts[0] + cd.Verts[3]) * 0.5;
			Vertex[1] = y;
			errorList[0] = 0;
			
			// Force alias vertex to match.
			if (s) s.Vertex[3] = y;
			
			
		}
	}

	if (Child[2] == null && Child[3] == null && errorList[1] * ThresholdDetail < size) {
		s= GetNeighbor(3, cd);
		if (s == null || (s.Child[0] == null && s.Child[1] == null)) {
			y = (cd.Verts[2] + cd.Verts[3]) * 0.5;
			Vertex[4] = y;
			errorList[1] = 0;
			
			if (s) s.Vertex[2] = y;
			
			
		}
	}

	// See if we have child nodes.
	var	StaticChildren:Boolean = false;
	for (i = 0; i < 4; i++) {
		if (Child[i]) {
			StaticChildren = true;
		
		}
	}

	// If we have no children and no necessary edges, then see if we can delete ourself.
	if ( !StaticChildren  && cd.Parent != null) {
		var	NecessaryEdges:Boolean = false;
		for (i = 0; i < 4; i++) {
			// See if vertex deviates from edge between corners.
			var	diff:Number = Math.abs(Vertex[i+1] - (cd.Verts[i] + cd.Verts[(i+3)&3]) * 0.5);
			if (diff > 0.00001) {
				NecessaryEdges = true;
			}
		}

		if (!NecessaryEdges) {
			size *= 1.414213562;	// sqrt(2), because diagonal is longer than side.
			if (cd.Parent.Square.errorList[2 + cd.ChildIndex] * ThresholdDetail < size) {
				cd.Parent.Square.Child[cd.ChildIndex].destroy();	// Delete this.
				cd.Parent.Square.Child[cd.ChildIndex] = null;	// Clear the pointer.
			}
		}
	}
}

public function getHighestError(cd:QuadCornerData):Number {
	var	maxerror:Number = 0;
	var	i:int;
	var	y:Number;
	// Measure error of center and edge vertices.


	// Compute error of center vert.
	var	e:Number;
	if (cd.ChildIndex & 1) {
		e = Math.abs(Vertex[0] - (cd.Verts[1] + cd.Verts[3]) * 0.5);
	} else {
		e = Math.abs(Vertex[0] - (cd.Verts[0] + cd.Verts[2]) * 0.5);
	}
	if (e > maxerror) maxerror = e;

	// Initial min/max.
	MaxY = Vertex[0];
	MinY = Vertex[0];

	// Check min/max of corners.
	for (i = 0; i < 4; i++) {
		y = cd.Verts[i];
		if (y < MinY) MinY = y;
		if (y > MaxY) MaxY = y;
	}
	
	// Edge verts.
	e = Math.abs(Vertex[1] - (cd.Verts[0] + cd.Verts[3]) * 0.5);
	if (e > maxerror) maxerror = e;
	errorList[0] = e;
	
	e = Math.abs(Vertex[4] - (cd.Verts[2] + cd.Verts[3]) * 0.5);
	if (e > maxerror) maxerror = e;
	errorList[1] = e;

	// Min/max of edge verts.
	for (i = 0; i < 4; i++) {
		y = Vertex[1 + i];
		if (y < MinY) MinY = y;
		if (y > MaxY) MaxY = y;
	}
	
	return maxerror;

}


///*
 public function RecomputeErrorAndLighting(cd:QuadCornerData):Number 
// Recomputes the error values for this tree.  Returns the
// max error.
// Also updates MinY & MaxY.
// Also computes quick & dirty vertex lighting for the demo.
{
	var	i:int;
	var	y:Number;
	// Measure error of center and edge vertices.
	var	maxerror:Number = 0;

	// Compute error of center vert.
	var	e:Number;
	if (cd.ChildIndex & 1) {
		e = Math.abs(Vertex[0] - (cd.Verts[1] + cd.Verts[3]) * 0.5);
	} else {
		e = Math.abs(Vertex[0] - (cd.Verts[0] + cd.Verts[2]) * 0.5);
	}
	if (e > maxerror) maxerror = e;

	// Initial min/max.
	MaxY = Vertex[0];
	MinY = Vertex[0];

	// Check min/max of corners.
	for (i = 0; i < 4; i++) {
		y = cd.Verts[i];
		if (y < MinY) MinY = y;
		if (y > MaxY) MaxY = y;
	}
	
	// Edge verts.
	e = Math.abs(Vertex[1] - (cd.Verts[0] + cd.Verts[3]) * 0.5);
	if (e > maxerror) maxerror = e;
	errorList[0] = e;
	
	e = Math.abs(Vertex[4] - (cd.Verts[2] + cd.Verts[3]) * 0.5);
	if (e > maxerror) maxerror = e;
	errorList[1] = e;

	// Min/max of edge verts.
	for (i = 0; i < 4; i++) {
		y = Vertex[1 + i];
		if (y < MinY) MinY = y;
		if (y > MaxY) MaxY = y;
	}
	
	// Check child squares.
	for (i = 0; i < 4; i++) {
		
		if (Child[i]) {
			var	q:QuadCornerData = new QuadCornerData();
			SetupCornerData(q, cd, i);
			errorList[i+2] = Child[i].RecomputeErrorAndLighting(q);

			if (Child[i].MinY < MinY) MinY = Child[i].MinY;
			if (Child[i].MaxY > MaxY) MaxY = Child[i].MaxY;
			
	
		} else {
			// Compute difference between bilinear average at child center, and diagonal edge approximation.
			errorList[i+2] = Math.abs((Vertex[0] + cd.Verts[i]) - (Vertex[i+1] + Vertex[((i+1)&3) + 1])) * 0.25;
		}
		if (errorList[i+2] > maxerror) maxerror = errorList[i+2];
	}


	//
	// Compute quickie demo lighting.
	//
	//removed off...not required for this case.

	// The error, MinY/MaxY, and lighting values for this node and descendants are correct now.

	
	return maxerror;
}
//*/

		





}

}