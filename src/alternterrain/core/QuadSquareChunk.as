package alternterrain.core 
{
	import flash.geom.Vector3D;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	import flash.utils.IExternalizable;
	
	import alternativa.engine3d.alternativa3d;
	use namespace alternativa3d;

	
	/**
	 * @author Thatcher Ulrich (tu@tulrich.com)
	 * @author Glenn Ko
	 * Thatcher's lod terrain implementation of QuadSquare, but simplified to support some form of fixed-resolution chunked LOD grids. Basically,
	 * each quad square will comprise of a fixed resolution grid batch of triangles (usually 32x32 patches), instead of a mere handful of 4-8 triangles in a 2x2 quad patch
	 * in the earlier software rendered approach. Vertex tests are removed and simplified with a single highest possible error value for the current chunk.
	 */
	
	public class QuadSquareChunk implements IExternalizable
	{
		public var Child:Vector.<QuadSquareChunk>;
		
		public static var BlockUpdateCount:int = 0;	//xxxxx
		private static var DetailThreshold:Number = 100;

		public var error:int;
		
		// Bounds for frustum culling and error testing.
		public var MinY:int;
		public var MaxY:int;	
		
		// important, please set this up to ensure you can get neighboring entries
		public static var QUADTREE_GRID:Grid_QuadChunkCornerData;
		
		public var 	EnabledFlags:int;	// bit-30, culled,   bits 8-13: culling mask of frustum planes,   bits 0-7: e, n, w, s, ne, nw, sw, se
		public var	SubEnabledCount:Vector.<int>;	// e, s enabled reference counts. [2]
		
		//public var normals:NormMapInfo;   // e,n,w,s - inner and outer edge normals as a result of stitch blending
		
		public var state:TerrainChunkState;
		
		public static var LOD_LVL_MIN:int = 12;

		
		
		public function QuadSquareChunk() 
		{
			MinY = 1.79e+308;
			MaxY = -1.79e+308;

			var	i:int;
			Child = new Vector.<QuadSquareChunk>(4, true);

			EnabledFlags = 0;

			SubEnabledCount = new Vector.<int>(2, true);
			SubEnabledCount[0] = 0;
			SubEnabledCount[1] = 0;
		}
		
		
		
		public function destroy():void {
			for (var i:int = 0; i < 4; i++) {
				if (Child[i] !=null) {
					Child[i].destroy();
					Child[i] = null;
				}
			}
		}
		
		
		
		
	
	
		// ne, nw, sw, se [4]
		public function	SetupCornerData(q:QuadChunkCornerData, cd:QuadChunkCornerData, ChildIndex:int):void
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
			
				break;
			case 1:
				q.xorg = cd.xorg;
				q.zorg = cd.zorg;
				break;

			case 2:
				q.xorg = cd.xorg;
				q.zorg = cd.zorg + half;
				break;

			case 3:
				q.xorg = cd.xorg + half;
				q.zorg = cd.zorg + half;
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
		
	


private function GetNeighbor(dir:int,  cd:QuadChunkCornerData):QuadSquareChunk
// Traverses the tree in search of the quadsquare neighboring this square to the
// specified direction.  0-3 -. { E, N, W, S }.
// Returns NULL if the neighbor is outside the bounds of the tree.
{
	// If we don't have a parent, then we don't have a neighbor.
	// (Actually, we could have inter-tree connectivity at this level
	// for connecting separate trees together.)
	if (cd.Parent == null) {  
		return QUADTREE_GRID ? getNeighborCornerData(cd, dir).Square  :  cd.Square; 
	}
	
	// Find the parent and the child-index of the square we want to locate or create.
	var p:QuadSquareChunk = null;
	
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


		
		
		
private static const STACK:Vector.<int> = new Vector.<int>(32, true);
private function EnableEdgeVertex( index:int,  IncrementCount:Boolean, cd:QuadChunkCornerData):void
// Enable the specified edge vertex.  Indices go { e, n, w, s }.
// Increments the appropriate reference-count if IncrementCount is true.
{
	if ((EnabledFlags & (1 << index)) && !IncrementCount) return;
	
	// Turn on flag and deal with reference count.
	EnabledFlags |= 1 << index;
	if (IncrementCount  && (index == 0 || index == 3)) {
		SubEnabledCount[index & 1]++;
	}

	// Now we need to enable the opposite edge vertex of the adjacent square (i.e. the alias vertex).

	// This is a little tricky, since the desired neighbor node may not exist, in which
	// case we have to create it, in order to prevent cracks.  Creating it may in turn cause
	// further edge vertices to be enabled, propagating updates through the tree.

	// The sticking point is the QuadChunkCornerData list, which
	// conceptually is just a linked list of activation structures.
	// In this function, however, we will introduce branching into
	// the "list", making it in actuality a tree.  This is all kind
	// of obscure and hard to explain in words, but basically what
	// it means is that our implementation has to be properly
	// recursive.

	// Travel upwards through the tree, looking for the parent in common with our desired neighbor.
	// Remember the path through the tree, so we can travel down the complementary path to get to the neighbor.
	var p:QuadSquareChunk = this;
	var pcd:QuadChunkCornerData = cd;
	var	ct:int = 0;
	const stack:Vector.<int>= STACK;  // TODO: Buffer this and check that it's okay!
	for (;;) {
		var	ci:int = pcd.ChildIndex;

		if (pcd.Parent == null || pcd.Parent.Square == null) {

			
		
			
			pcd = QUADTREE_GRID ? getNeighborCornerData(pcd, index) : pcd;
			//if (pcd == null)  return;
			
			p = pcd.Square;
	//	if (p == null) throw new Error("WRR!");
			if (ct > 0) break;
			//else {  // duplicate of below
				index ^= 2;
				p.EnabledFlags |= (1 << index);
				if (IncrementCount  && (index == 0 || index == 3)) {
					p.SubEnabledCount[index & 1]++;
				}
				return;
			//}
		}
		p = pcd.Parent.Square;
		pcd = pcd.Parent;

		var	SameParent:int = ((index - ci) & 2);
		
		ci = ci ^ 1 ^ ((index & 1) << 1);	// Child index of neighbor node.
		stack[ct++] = ci;
		
		
		if (SameParent) break;
	}

	// Get a pointer to our neighbor (create if necessary), by walking down
	// the quadtree from our shared ancestor.
	p = p.EnableDescendant(ct, stack, pcd);
	


	// Finally: enable the vertex on the opposite edge of our neighbor, the alias of the original vertex.
	index ^= 2;
	p.EnabledFlags |= (1 << index);
	if (IncrementCount  && (index == 0 || index == 3)) {
		p.SubEnabledCount[index & 1]++;
	}
}

private function getNeighborCornerData(pcd:QuadChunkCornerData, dir:int):QuadChunkCornerData 
{
	var x:int = pcd.xorg;
	var z:int = pcd.zorg;
	var half:int = (1 << pcd.Level);
	var full :int = (half << 1);
	var ci:int = pcd.ChildIndex;
//	try { 
	if (dir === 0) {  // todo: check sizign and positining
		x += full;
		if (x > QUADTREE_GRID.originX + QUADTREE_GRID.cols * full - full) x = 0;
	}
	else if (dir===1) {
		z -= full;
		if (z < QUADTREE_GRID.originY) {
			z = QUADTREE_GRID.cols * full - full;
		}
	}
	else if (dir === 2) {
		x -= full;
		if (x < QUADTREE_GRID.originX) x = QUADTREE_GRID.cols*full - full;
	}
	else {	
		z += full;
		if (z > QUADTREE_GRID.originY + (QUADTREE_GRID.cols) * full - full) z = 0;
	}
	
	
	//var result:QuadChunkCornerData = ;
	//}
	//catch (e:Error) {
	//	throw new Error("dir:" + dir + ", " + e + ", "+pcd.zorg + ", "+((z-QUADTREE_GRID.originY) >> (pcd.Level+1)) );
	//}
	return QUADTREE_GRID.getCornerData(x, z, pcd.Level);  // todo: check sizing and positinoing
}



private function EnableDescendant( count:int,  path:Vector.<int>, cd:QuadChunkCornerData):QuadSquareChunk
// This function enables the descendant node 'count' generations below
// us, located by following the list of child indices in path[].
// Creates the node if necessary, and returns a pointer to it.
{
	count--;
	var	ChildIndex:int = path[count];

	if ((EnabledFlags & (16 << ChildIndex)) == 0) {
		EnableChild(ChildIndex, cd);
	}
	
	if (count > 0) { // more than 1 index in path, need to recurse until end
		var	q:QuadChunkCornerData = QuadChunkCornerData.create();
		SetupCornerData(q, cd, ChildIndex);
		return Child[ChildIndex].EnableDescendant(count, path, q);
	} else {
		return Child[ChildIndex];
	}
}




private function  EnableChild(index:int, cd:QuadChunkCornerData):void
// Enable the indexed child node.  { ne, nw, sw, se }
// Causes dependent edge vertices to be enabled.
{
	if (cd.Level <= LOD_LVL_MIN) throw new Error("SHOULD not allow!");
	
	if ((EnabledFlags & (16 << index)) == 0) {
		EnabledFlags |= (16 << index);
		EnableEdgeVertex(index, true, cd);
		EnableEdgeVertex((index + 1) & 3, true, cd);
		
	}
}



private function NotifyChildDisable( cd:QuadChunkCornerData, index:int):void
// Marks the indexed child quadrant as disabled.  Deletes the child node
// if it isn't static.
{
				
	//if (cd.Level < 8) throw new Error("FAILED!");
	// Clear enabled flag for the child.

	EnabledFlags &= ~(16 << index);
	
	// Update child enabled counts for the affected edge verts.
	var s:QuadSquareChunk;
	
	if (index & 2) s = this;
	else s = GetNeighbor(1, cd);
	if (s) {
		s.SubEnabledCount[1]--;
	}
	
	if (index == 1 || index == 2) s = GetNeighbor(2, cd);
	else s = this;
	if (s) {
		s.SubEnabledCount[0]--;
	}

	

}

public function	ResetTree():void
// Clear all enabled flags, and delete all non-static child nodes.
{
	for (var i:int = 0; i < 4; i++) {
		if (Child[i]) {
			Child[i].ResetTree();
		}
	}
	EnabledFlags = 0;
	SubEnabledCount[0] = 0;
	SubEnabledCount[1] = 0;
	
}






		



// todo: re-adjust this to get MINIMUM distance to box
public function	BoxTest(x:Number, z:Number, size:Number, miny:Number, maxy:Number, error:Number, camera:Vector3D):Boolean
// Returns true if any vertex within the specified box (origin at x,z,
// edges of length size) with the given error value could be enabled
// based on the given viewer location.
{
	// Find the minimum distance to the box. 
	// Got to check orientation for this...
	var	half:Number = size * 0.5;
	var	dx:Number = Math.abs(x + half - camera.x) - half;
	var	dy:Number =  Math.abs((miny + maxy) * 0.5 - camera.z) - (maxy - miny) * 0.5;  
	var	dz:Number =  Math.abs(z + half - camera.y) - half;
	var	d:Number = dx;
	if (dy > d) d = dy;
	if (dz > d) d = dz;
	
	return (error * DetailThreshold) > d;
}


public function	Update(cd:QuadChunkCornerData,  camera:Vector3D, Detail:Number, culler:ICuller, culling:int):void
// Refresh the vertex enabled states in the tree, according to the
// location of the viewer.  May force creation or deletion of qsquares
// in areas which need to be interpolated.
{
	QuadChunkCornerData.BI = 0;
	DetailThreshold = Detail;
	UpdateAux(cd, camera, 0, culler, culling);
}



public	function UpdateAux(cd:QuadChunkCornerData, camera:Vector3D, CenterError:Number, culler:ICuller, culling:int):void
// Does the actual work of updating enabled states and tree growing/shrinking.
{

	if (culling < 0) return;
	

	// set culling value
	
	BlockUpdateCount++;	//xxxxx

	var	half:int = 1 << cd.Level;
	var	whole:int = half << 1;
	var	s:QuadSquareChunk;

	var succeeded:Boolean = false;
	if (culling >= 0 && cd.Level > LOD_LVL_MIN) {
		
		
		// min LOD level 2^8=256 for tri,  min LOD level for chunk 2^13=8192	 
		

		if ((EnabledFlags & 16) == 0) {
			if ( BoxTest(cd.xorg + half, cd.zorg, half, MinY, MaxY, Child[0].error, camera) ) {
				EnableChild(0, cd);	// ne child.
				succeeded = true;
			}
		}
		
		if ((EnabledFlags & 32) == 0) {
			if ( BoxTest(cd.xorg, cd.zorg, half, MinY, MaxY, Child[1].error, camera)  ) {
				EnableChild(1, cd);	// nw child.er
				succeeded = true;
			}
		}
		if ((EnabledFlags & 64) == 0) {
			if ( BoxTest(cd.xorg, cd.zorg + half, half, MinY, MaxY, Child[2].error, camera)  ) {
				EnableChild(2, cd);	// sw child.
				succeeded = true;
			}
		}
		if ((EnabledFlags & 128) == 0) {
			if ( BoxTest(cd.xorg + half, cd.zorg + half, half, MinY, MaxY, Child[3].error, camera)  ) {
				EnableChild(3, cd);	// se child.
				succeeded = true;
			}
		}
		
		
		
		// Recurse into child quadrants as necessary.
		var	q:QuadChunkCornerData; 
			
		if (EnabledFlags & 32) {
			SetupCornerData(q = QuadChunkCornerData.create(), cd, 1);
			s = Child[1]; 
			s.UpdateAux(q, camera, s.error, culler, culling != 0 ? culler.cullingInFrustum(culling, q.xorg, q.zorg, q.Square.MinY, q.xorg + half, q.zorg + half, q.Square.MaxY) : 0);
		}
		if (EnabledFlags & 16) {
			SetupCornerData(q = QuadChunkCornerData.create(), cd, 0);
			s = Child[0]; 
			s.UpdateAux(q, camera, s.error, culler, culling != 0 ?culler.cullingInFrustum(culling, q.xorg, q.zorg, q.Square.MinY, q.xorg + half, q.zorg + half, q.Square.MaxY) : 0 );		
		}
		if (EnabledFlags & 64) {
			SetupCornerData(q = QuadChunkCornerData.create(), cd, 2);
			s = Child[2]; 
			s.UpdateAux(q, camera, s.error, culler, culling != 0 ?culler.cullingInFrustum(culling, q.xorg, q.zorg, q.Square.MinY, q.xorg + half, q.zorg + half, q.Square.MaxY) : 0 );		
		}
		if (EnabledFlags & 128) {
			SetupCornerData(q = QuadChunkCornerData.create(), cd, 3);
			
			s = Child[3]; 
			s.UpdateAux(q, camera, s.error, culler, culling != 0 ?culler.cullingInFrustum(culling, q.xorg, q.zorg, q.Square.MinY, q.xorg + half, q.zorg + half, q.Square.MaxY) : 0);
		}
		
		
	}

	
	
	var recursable:Boolean = succeeded || BoxTest(cd.xorg, cd.zorg, whole, MinY, MaxY, CenterError, camera);
	// Test for disabling.  East, South, and center.
	///*
	if (!recursable) {
		if ((EnabledFlags & 1) && SubEnabledCount[0] == 0  ) {
			EnabledFlags &= ~1;
			s = GetNeighbor(0, cd);
			if (s) s.EnabledFlags &= ~4;
		}
		if ((EnabledFlags & 8) && SubEnabledCount[1] == 0  ) {
			EnabledFlags &= ~8;
			s = GetNeighbor(3, cd);
			if (s) s.EnabledFlags &= ~2;
		}
		if ( (EnabledFlags & 0xFF) ==0 &&
			cd.Parent != null 
		   )
		{
			// Disable ourself.
			EnabledFlags = 0;
			cd.Parent.Square.NotifyChildDisable(cd.Parent, cd.ChildIndex);	// nb: possibly deletes 'this'.
		}
	}
	//*/
	// EnabledFlags ==0 &&
//	/*
	
	//*/
}

	/* INTERFACE flash.utils.IExternalizable */

	public function readExternal(input:IDataInput):void 
	{
	
		/* #if positiveShortHeightsOnly
			MinY = input.readUnsignedShort();
			MaxY = input.readUnsignedShort();
		*/
		///* #else if positiveNegativeShortHeights
			MinY = input.readShort();
			MaxY = input.readShort();
		//#end if */
		
		error = input.readUnsignedShort();
		input.readBoolean();  // todo: depeciate fully
		//normals =  ? input.readObject() : null;
		if ( input.readBoolean() ) {
			Child[0] = input.readObject();
			Child[1] = input.readObject();
			Child[2] =  input.readObject();
			Child[3] = input.readObject();
		}
	}

	public function writeExternal(output:IDataOutput):void 
	{
		output.writeShort(MinY);
		output.writeShort(MaxY);
		output.writeShort(error);
		output.writeBoolean( false );  // todo: depciate fully
		//if (normals != null) output.writeObject(normals);
		if (Child[0] != null) {
			output.writeBoolean(true);
			output.writeObject(Child[0]);
			output.writeObject(Child[1]);
			output.writeObject(Child[2]);
			output.writeObject(Child[3]);
		}
		else output.writeBoolean(false);
	}



}


}