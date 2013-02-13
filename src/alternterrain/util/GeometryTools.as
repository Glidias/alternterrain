package alternterrain.util 
{
	import alternativa.engine3d.core.Object3D;
	import alternativa.engine3d.core.Transform3D;
	import alternativa.engine3d.core.VertexAttributes;
	import alternativa.engine3d.objects.Joint;
	import alternativa.engine3d.objects.Mesh;
	import alternativa.engine3d.objects.Surface;
	import alternativa.engine3d.resources.Geometry;
	import flash.display.BitmapData;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.utils.Dictionary;
	import alternativa.engine3d.alternativa3d;
	use namespace alternativa3d;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class GeometryTools 
	{
		
		public static function displaceGeometry(map:BitmapData, geometry:Geometry, heightMult:Number):void
		{
			var positions:Vector.<Number> = geometry.getAttributeValues(VertexAttributes.POSITION);
			var uvs:Vector.<Number> = geometry.getAttributeValues(VertexAttributes.TEXCOORDS[0]);
			
			var i:int = 0;
			var len:int = positions.length;
			var c:int = 0;
			var channelMult:Number = 1 / 255;
			while ( i < len) {
				var u:Number = uvs[c];
				var v:Number = uvs[c + 1];
				var pixelColor:uint = map.getPixel( int(u * map.width), int(v * map.height) );
				
				pixelColor &= 0x0000FF;
				
				positions[i + 2] =pixelColor * channelMult * heightMult;
				i += 3;
				c += 2;
			}
		
			geometry.setAttributeValues(VertexAttributes.POSITION, positions);
				geometry.calculateNormals();
			//geometry.calculateTangents(0);
			
		}
		
		public static function resetEuler(obj:Object3D):void {
			obj._x = 0;
			obj._y = 0;
			obj._z = 0;
			
			obj._rotationX = 0;
			obj._rotationY = 0;
			obj._rotationZ = 0;
			
			obj._scaleX = 1;
			obj._scaleY = 1;
			obj._scaleZ = 1;
			
			obj.transformChanged = true;
		}
		
		public static function transformGeometry(geometry:Geometry, t:Transform3D):void
		{
			var positions:Vector.<Number> = geometry.getAttributeValues(VertexAttributes.POSITION);
			
			
			var i:int = 0;
			var len:int = positions.length;
			
			
			while ( i < len) {
				var x:Number = positions[i];
				var y:Number = positions[i + 1];
				var z:Number = positions[i + 2];
			
				positions[i] = t.a * x + t.b * y + t.c * z + t.d;
				positions[i + 1] = t.e * x + t.f * y + t.g * z + t.h;
				positions[i + 2] = t.i * x + t.j * y + t.k * z + t.l;
				
				i += 3;
			}
		
			geometry.setAttributeValues(VertexAttributes.POSITION, positions);
				geometry.calculateNormals();
		//	geometry.calculateTangents();
		}
		
		        /**
         * 3つの頂点座標から、Faceを作成し、indices、positionsに各値を登録する
         */
        public static function createTriangle(vertices:Vector.<Vector3D>, uvs:Vector.<Point>,
                                              indices:Vector.<uint>, positions:Vector.<Number>, 
                                              texcoords:Vector.<Number>, reverse:Boolean = false):void {
            if (reverse == false) {
                //三角形用の頂点を登録
                positions.push(vertices[0].x, vertices[0].y, vertices[0].z,
                               vertices[2].x, vertices[2].y, vertices[2].z,
                               vertices[1].x, vertices[1].y, vertices[1].z);
                
                //三角形用のUVを登録
                texcoords.push(uvs[0].x, uvs[0].y,uvs[2].x, uvs[2].y,uvs[1].x, uvs[1].y);
                
            } else {
                //三角形用の頂点を登録
                positions.push(vertices[0].x, vertices[0].y, vertices[0].z,
                               vertices[1].x, vertices[1].y, vertices[1].z,
                               vertices[2].x, vertices[2].y, vertices[2].z);
                
                //三角形用のUVを登録
                texcoords.push(uvs[0].x, uvs[0].y,uvs[1].x, uvs[1].y,uvs[2].x, uvs[2].y);
                
            }
            //Face用indexを登録
            var startIndex:uint = indices.length
            indices.push(startIndex + 0, startIndex + 1, startIndex + 2);
        }
        
        /**
         * 4つの頂点座標から、四角形（2つのFace）を作成し、indices、positions、uvsに各値を登録する
         */
        public static function createSquare(vertices:Vector.<Vector3D>, uvs:Vector.<Point>,
                                            indices:Vector.<uint>, positions:Vector.<Number>, 
                                            texcoords:Vector.<Number>, reverse:Boolean = false):void {
            
            if (reverse == false) {
                positions.push(    vertices[0].x, vertices[0].y, vertices[0].z,
                                vertices[3].x, vertices[3].y, vertices[3].z,
                                vertices[1].x, vertices[1].y, vertices[1].z);
                positions.push(    vertices[1].x, vertices[1].y, vertices[1].z,
                                vertices[3].x, vertices[3].y, vertices[3].z,
                                vertices[2].x, vertices[2].y, vertices[2].z);    
                //三角形用のUVを登録
                texcoords.push(uvs[0].x, uvs[0].y,uvs[3].x, uvs[3].y,uvs[1].x, uvs[1].y);
                texcoords.push(uvs[1].x, uvs[1].y,uvs[3].x, uvs[3].y,uvs[2].x, uvs[2].y);
                                
            } else {
                positions.push(    vertices[0].x, vertices[0].y, vertices[0].z,
                                vertices[1].x, vertices[1].y, vertices[1].z,
                                vertices[3].x, vertices[3].y, vertices[3].z);
                positions.push(    vertices[1].x, vertices[1].y, vertices[1].z,
                                vertices[2].x, vertices[2].y, vertices[2].z,
                                vertices[3].x, vertices[3].y, vertices[3].z);    
                //三角形用のUVを登録
                texcoords.push(uvs[0].x, uvs[0].y,uvs[1].x, uvs[1].y,uvs[3].x, uvs[3].y);
                texcoords.push(uvs[1].x, uvs[1].y, uvs[2].x, uvs[2].y, uvs[3].x, uvs[3].y);
            }
            
            //Face用indexを登録
            var startIndex:uint = indices.length
            indices.push(startIndex + 0, startIndex + 1, startIndex + 2);
            indices.push(startIndex + 3, startIndex + 4, startIndex + 5);
        
        }
        
        /**
         * 指定Meshの法線を作成します
         * @param    mesh
         */
        public static function createNormal(mesh:Mesh):void {
            //法線の有無のチェック
            if (mesh.geometry.hasAttribute(VertexAttributes.NORMAL) == false) {
                var nml:int = VertexAttributes.NORMAL;    
                mesh.geometry.addVertexStream([nml,nml,nml]);
            }
            
            var indices:Vector.<uint> = mesh.geometry.indices;
            var positions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
            var vartices:Vector.<Vector3D> = new Vector.<Vector3D>(positions.length / 3);
            var vNormals:Vector.<Vector3D> = new Vector.<Vector3D>(positions.length / 3);
            
            var i:int;
            var count:uint = positions.length / 3;
            for (i = 0; i < count; i++) {
                vartices[i] = new Vector3D(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
            }
            
            //面法線を求め、頂点法線に代入する
            count = indices.length;
            for (i = 0; i < count; i += 3) {
                var normal:Vector3D = calcNormal(vartices[indices[i]], vartices[indices[i + 1]], vartices[indices[i + 2]]);
                vNormals[indices[i]] = normal;
                vNormals[indices[i + 1]] = normal;
                vNormals[indices[i + 2]] = normal;
            }
            
            var normals:Vector.<Number> = new Vector.<Number>();
            
            count = vNormals.length;
            for (i = 0; i < count; i++) {
                if (vNormals[i]) {
                    normals.push(vNormals[i].x, vNormals[i].y, vNormals[i].z);
                }
            }
            
            mesh.geometry.setAttributeValues(VertexAttributes.NORMAL, normals);
        }
        
        /**
         * 面法線の計算
         * 三つの頂点座標からなる三角ポリゴンの法線を計算し返します
         */
        public static function calcNormal(a:Vector3D, b:Vector3D, c:Vector3D):Vector3D {
            var v1:Vector3D = b.subtract(a);
            var v2:Vector3D = c.subtract(a);
            var v3:Vector3D = v1.crossProduct(v2);
            //var v3:Vector3D = cross(v1,v2);
            v3.normalize();
            return (v3);
        }
        

        
        /**
         * 指定Meshの法線をSmoothShadingにします
         * @param    mesh
         */
        public static function smoothShading(mesh:Mesh,separateSurface:Boolean=false,threshold:Number=0.000001):void {
            
            var indices:Vector.<uint> = mesh.geometry.indices;
            var positions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
            var normals:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.NORMAL);
            
            var vartices:Vector.<Vector3D> = new Vector.<Vector3D>(positions.length / 3);
            var vNormals:Vector.<Vector3D> = new Vector.<Vector3D>(normals.length / 3);
            
            var vertexDictionary:Dictionary = new Dictionary()
            var exVertex:ExtraVertex;
            
            //サーフェースごとに判断する

            for (var s:uint = 0; s < mesh.numSurfaces; s++ ) {
                var side:String = (separateSurface) ? s.toString() : '';
                for (var n:uint = 0; n < mesh.getSurface(s).numTriangles * 3; n++) {
                    var i:uint = indices[n+mesh.getSurface(s).indexBegin];
                    vartices[i] = new Vector3D(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
                    //誤差を丸める
                    vartices[i].x = int(vartices[i].x / threshold) * threshold;
                    vartices[i].y = int(vartices[i].y / threshold) * threshold;
                    vartices[i].z = int(vartices[i].z / threshold) * threshold;                
                    vNormals[i] = new Vector3D(normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]);
                    //誤差を丸める
                    vNormals[i].x = int(vNormals[i].x / threshold) * threshold;
                    vNormals[i].y = int(vNormals[i].y / threshold) * threshold;
                    vNormals[i].z = int(vNormals[i].z / threshold) * threshold;
                    
                    //同じ頂点を集める
                    //ただし、表裏がある場合があるので法線の方向もチェックする
                    if (vertexDictionary[vartices[i].toString()+'_'+side]) {
                        exVertex = vertexDictionary[vartices[i].toString()+'_'+side]
                        if (exVertex.normals[vNormals[i].toString()+'_'+side] == null) {
                            exVertex.normals[vNormals[i].toString()+'_'+side] = vNormals[i];
                        }
                        exVertex.indices.push(i);

                    } else {
                        exVertex = new ExtraVertex(vNormals[i].x, vNormals[i].y, vNormals[i].z);
                        exVertex.normals[vNormals[i].toString()+'_'+side] = vNormals[i];
                        exVertex.indices.push(i)
                        vertexDictionary[vartices[i].toString()+'_'+side] = exVertex
                    }
                }                
                
            }

            //Normalの平均化
            var count:uint = 0;
            for each (exVertex in vertexDictionary) {
                var normalX:Number = 0;
                var normalY:Number = 0;
                var normalZ:Number = 0;
                count = 0
                for each (var normal:Vector3D in exVertex.normals) {
                    normalX += normal.x;
                    normalY += normal.y;
                    normalZ += normal.z;
                    count++
                }
                normal = new Vector3D(normalX / count, normalY / count, normalZ / count);
                normal.normalize();
                count = exVertex.indices.length;
                for (i = 0; i < count; i++) {
                    vNormals[exVertex.indices[i]] = normal;
                }
            }
            count = vNormals.length;
            normals = new Vector.<Number>();
            for (i = 0; i < count; i++) {
                normals.push(vNormals[i].x, vNormals[i].y, vNormals[i].z);
            }
            
            mesh.geometry.setAttributeValues(VertexAttributes.NORMAL, normals);
        }
        
        
        /**
         * 指定MeshのUVをVertexのxyから仮に作成する
         * @param    mesh
         */
        public static function createUv(mesh:Mesh):void {
            if (mesh.geometry.hasAttribute(VertexAttributes.TEXCOORDS[0]) == false) {
                var tex:int = VertexAttributes.TEXCOORDS[0];    
                mesh.geometry.addVertexStream([tex,tex]);
            }
            mesh.calculateBoundBox()
            var width:Number = mesh.boundBox.maxX - mesh.boundBox.minX
            var length:Number = mesh.boundBox.maxZ - mesh.boundBox.minZ
            
            var positions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
            var texcoords:Vector.<Number> = new Vector.<Number>;
            var i:int;
            for (i = 0; i < positions.length; i += 3) {
                texcoords.push((positions[i] - mesh.boundBox.minX) / width, (positions[i + 2] - mesh.boundBox.minZ) / length);
            }

            mesh.geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], texcoords);
        }
        
        
        
        /**
         * 指定MeshのTangentを作成する
         * @param    mesh
         */
        static public function createTangent(mesh:Mesh):void {
            //接線有無のチェック


            
            
            var positions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
            var texcoords:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.TEXCOORDS[0]);
            var normals:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.NORMAL);
            
            var indices:Vector.<uint> = mesh.geometry.indices;
            var vertices:Vector.<Vector3D> = new Vector.<Vector3D>;
            var uvs:Vector.<Point> = new Vector.<Point>;
            var vNormals:Vector.<Vector3D> = new Vector.<Vector3D>;
            
            var i:int;
            for (i = 0; i < positions.length; i += 3) {
                vertices.push(new Vector3D(positions[i], positions[i + 1], positions[i + 2]));
            }
            for (i = 0; i < texcoords.length; i += 2) {
                uvs.push(new Point(texcoords[i], texcoords[i + 1]));
            }
            for (i = 0; i < normals.length; i += 3) {
                vNormals.push(new Vector3D(normals[i], normals[i + 1], normals[i + 2]));
            }
            
            var tangents:Vector.<Number> = calcTangent(mesh.geometry.indices, vertices, uvs, vNormals);
            
            var geometry:Geometry = new Geometry();
            //if (mesh.geometry.hasAttribute(VertexAttributes.TANGENT4) == false) {
            var tan:int = VertexAttributes.TANGENT4;
            var pos:int = VertexAttributes.POSITION;
            var nor:int = VertexAttributes.NORMAL;
            var tex:int = VertexAttributes.TEXCOORDS[0];
            var attribute:Array = [
                pos, pos, pos,
                nor, nor, nor,
                tan, tan, tan, tan,
                tex, tex
            ]
            geometry.addVertexStream(attribute)
            //}                
            geometry.numVertices = mesh.geometry.numVertices
            geometry.indices = mesh.geometry.indices;
            geometry.setAttributeValues(VertexAttributes.POSITION, positions);
            geometry.setAttributeValues(VertexAttributes.NORMAL, normals);
            geometry.setAttributeValues(VertexAttributes.TANGENT4, tangents);
            geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], texcoords);

            mesh.geometry = geometry;
        }
        
        
        /**
         * 複数のMeshを結合し、１つのMeshにします
         * @param    meshs
         * @return
         */
        public static function bindMeshs(meshs:Vector.<Mesh>):Mesh {
            var count:uint = meshs.length;
            
            var indices:Vector.<uint> = new Vector.<uint>();
            var positions:Vector.<Number> = new Vector.<Number>();
            var texcoords:Vector.<Number> = new Vector.<Number>();
            
            var nextIndex:uint = 0;
            var nextPosition:uint = 0;
            var mesh:Mesh = meshs[i];
            var i:int
            var j:int
            for (i = 0; i < count; i++) {
                mesh = meshs[i];
                var tempPositions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
                mesh.matrix.transformVectors(tempPositions, tempPositions);
                positions = positions.concat(tempPositions);
                texcoords = texcoords.concat(mesh.geometry.getAttributeValues(VertexAttributes.TEXCOORDS[0]));
                
                var tempIndices:Vector.<uint> = mesh.geometry.indices;            
                var indexCount:uint = tempIndices.length
                for (j = 0; j < indexCount; j++) {
                    tempIndices[j] += nextIndex;
                }
                indices = indices.concat(tempIndices);
                nextIndex += tempPositions.length/3
            }

            var geometry:Geometry = new Geometry();
            
            var attributes:Array = [];
            attributes[0] = VertexAttributes.POSITION;
            attributes[1] = VertexAttributes.POSITION;
            attributes[2] = VertexAttributes.POSITION;
            attributes[3] = VertexAttributes.TEXCOORDS[0];
            attributes[4] = VertexAttributes.TEXCOORDS[0];
            
            geometry.addVertexStream(attributes);
            
            geometry.numVertices = positions.length/3;
            
            geometry.setAttributeValues(VertexAttributes.POSITION, positions);
            geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], texcoords);
            
            geometry.indices = indices;            
            
            var result:Mesh = new Mesh()
            result.geometry = geometry;
            
            //サーフェースのコピー
            var indexBegin:uint = 0
            for (i = 0; i < count; i++) {
                mesh = meshs[i];
                for (j = 0; j < mesh.numSurfaces; j++) {
                    var surface:Surface = mesh.getSurface(j);
                    result.addSurface(surface.material, surface.indexBegin+indexBegin, surface.numTriangles)
                }
                indexBegin = surface.indexBegin+indexBegin + surface.numTriangles * 3;
            }
            
            //normal再計算
            createNormal(result);
            return result;
        }
        
        
        /**
         * Cylinder、Cone、Dome、RoundMesh等を合成した、MeshのSurfaceを合成します
         * UVのV値のみ更新されます
         * 
         * 頂点情報の高さ(Z座標)で判断します
         * 
         */
        public static function repairRoundSurface(mesh:Mesh):Mesh {
            var positions:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.POSITION);
            var texcoords:Vector.<Number> = mesh.geometry.getAttributeValues(VertexAttributes.TEXCOORDS[0]);
            var count:int = positions.length / 3
            //全体の高さを割り出す
            var minY:Number=0
            var maxY:Number=0
            for (var i:int = 0; i < count; i++) {
                if (minY > positions[i * 3 + 2])
                    minY = positions[i * 3 + 2];
                if (maxY < positions[i * 3 + 2])
                    maxY = positions[i * 3 + 2];
            }
            
            var height:Number = maxY - minY;
            for (i = 0; i < count; i++) {
                texcoords[i * 2 + 1] = (positions[i * 3 + 2] - minY) / height;
            }
            mesh.geometry.setAttributeValues(VertexAttributes.TEXCOORDS[0], texcoords);
            var result:Mesh = new Mesh();
            result.geometry = mesh.geometry
            result.addSurface(null, 0, positions.length / 9);
            return result;
        }
        
        
        /**
         * サーフェースのコピー
         * @param    origin
         * @param    mesh
         */
        public static function copySurface(origin:Mesh, mesh:Mesh):void {
            for (var i:uint = 0; i < origin.numSurfaces; i++) {
                var surface:Surface = origin.getSurface(i);
                mesh.addSurface(surface.material, surface.indexBegin, surface.numTriangles)
            }
        }

        
        /**
         * TANGENT4を再計算
         * @param    indices
         * @param    vertex
         * @param    uvs
         * @param    normals
         * @return
         */
        static public function calcTangent(indices:Vector.<uint>, vertices:Vector.<Vector3D>, uvs:Vector.<Point>, normals:Vector.<Vector3D>):Vector.<Number> {
            var tangent:Vector.<Number> = new Vector.<Number>;
            var numTriangle:int = indices.length / 3;
            var numVertex:int = vertices.length;
            
            var tan1:Vector.<Vector3D> = new Vector.<Vector3D>;
            var tan2:Vector.<Vector3D> = new Vector.<Vector3D>;
            
            var i:int;
            for (i = 0; i < vertices.length; i++) {
                tan1.push(new Vector3D());
                tan2.push(new Vector3D());
            }
            
            var max:int = indices.length;
            for (i = 0; i < max; i += 3) {
                var i1:Number = indices[i];
                var i2:Number = indices[i + 1];
                var i3:Number = indices[i + 2];
                
                var v1:Vector3D = vertices[i1];
                var v2:Vector3D = vertices[i2];
                var v3:Vector3D = vertices[i3];
                
                var w1:Point = uvs[i1];
                var w2:Point = uvs[i2];
                var w3:Point = uvs[i3];
                
                var x1:Number = v2.x - v1.x;
                var x2:Number = v3.x - v1.x;
                var y1:Number = v2.y - v1.y;
                var y2:Number = v3.y - v1.y;
                var z1:Number = v2.z - v1.z;
                var z2:Number = v3.z - v1.z;
                
                var s1:Number = w2.x - w1.x;
                var s2:Number = w3.x - w1.x;
                var t1:Number = w2.y - w1.y;
                var t2:Number = w3.y - w1.y;
                
                var r:Number = 1 / (s1 * t2 - s2 * t1);
                var sdir:Vector3D = new Vector3D((t2 * x1 - t1 * x2) * r, (t2 * y1 - t1 * y2) * r, (t2 * z1 - t1 * z2) * r);
                var tdir:Vector3D = new Vector3D((s1 * x2 - s2 * x1) * r, (s1 * y2 - s2 * y1) * r, (s1 * z2 - s2 * z1) * r);
                
                tan1[i1].incrementBy(sdir);
                tan1[i2].incrementBy(sdir);
                tan1[i3].incrementBy(sdir);
                
                tan2[i1].incrementBy(tdir);
                tan2[i2].incrementBy(tdir);
                tan2[i3].incrementBy(tdir);
            }
            
            for (i = 0; i < numVertex; i++) {
                var n:Vector3D = normals[i];
                var t:Vector3D = tan1[i];
                var tgt:Vector3D = t.subtract(getScaled(n, dot(n, t)));
                tgt.normalize();
                var w:Number = dot(cross(n, t), tan2[i]) < 0 ? -1 : 1;
                tangent.push(tgt.x, tgt.y, tgt.z, w);
            }
            return tangent;
        }
        
        /**
         * 2つのベクトルの内積を返します。
         * (内積：2つのベクトルがどれだけ平行に近いかを示す数値)
         * ・ 1 に近いほど同じ向きで平行
         * ・ 0 に近いほど直角
         * ・-1 に近いほど逆向きで平行
         */
        static public function dot(a:Vector3D, b:Vector3D):Number {
            return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
        }
        
        /**
         * 2つのベクトルの外積を返します。
         * (外積：2つのベクトルで作られる面に垂直なベクトル(=法線)。)
         */
        static public function cross(a:Vector3D, b:Vector3D):Vector3D {
            return new Vector3D((a.y * b.z) - (a.z * b.y), (a.z * b.x) - (a.x * b.z), (a.x * b.y) - (a.y * b.x));
        }
        
        /**
         * スケーリングした新しいベクトルを取得
         * @param    v
         * @param    scale
         * @return
         */
        static public function getScaled(v:Vector3D, scale:Number):Vector3D {
            var sv:Vector3D = v.clone();
            sv.scaleBy(scale);
            return sv;
        }
        
        /**
         * Jointの位置を初期化
         * @param    joints
         */
        public static function JointBindPose(joints:Vector.<Joint>):void {
            var count:uint = joints.length;
            for (var i:uint = 0; i < count; i++) 
            {
                var joint:Joint = joints[i]
                var jointMatrix:Matrix3D = joint.concatenatedMatrix.clone();

                jointMatrix.transpose();
                var jointBindingTransform:Transform3D = new Transform3D();
                jointBindingTransform.initFromVector(jointMatrix.rawData);
                jointBindingTransform.invert();
                var matrixVector:Vector.<Number> = new Vector.<Number>();
                matrixVector.push(jointBindingTransform.a);
                matrixVector.push(jointBindingTransform.b);
                matrixVector.push(jointBindingTransform.c);
                matrixVector.push(jointBindingTransform.d);
                matrixVector.push(jointBindingTransform.e);
                matrixVector.push(jointBindingTransform.f);
                matrixVector.push(jointBindingTransform.g);
                matrixVector.push(jointBindingTransform.h);
                matrixVector.push(jointBindingTransform.i);
                matrixVector.push(jointBindingTransform.j);
                matrixVector.push(jointBindingTransform.k);
                matrixVector.push(jointBindingTransform.l);
                
                joint.setBindPoseMatrix(matrixVector);

            }
        }
		
	}

}
import flash.geom.Vector3D;
import flash.utils.Dictionary;


    /**
     * 頂点に隣接する面法線を収集するクラス
     */

    class ExtraVertex {
        public var vertex:Vector3D;
        public var normals:Dictionary;
        public var indices:Vector.<uint>;
        public function ExtraVertex(x:Number, y:Number, z:Number) {
            vertex = new Vector3D(x, y, z);
            normals = new Dictionary();
            indices = new Vector.<uint>();
        }
        
    }