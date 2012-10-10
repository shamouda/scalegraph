package org.scalegraph.util;

import x10.util.ArrayBuilder;
import x10.util.Box;
import x10.util.HashMap;
import x10.util.StringBuilder;

import org.scalegraph.graph.PlainGraph;
import test.scalegraph.clustering.Tool;

public class VertexInfo {
	
	public val parent:Place = here;
	public val placeList = Place.places();
	public val IDtoIDX = PlaceLocalHandle.make[HashMap[Long, Int]](Dist.makeUnique(), ()=>new HashMap[Long, Int]());
	public val IDXtoID = PlaceLocalHandle.make[HashMap[Int, Long]](Dist.makeUnique(), ()=>new HashMap[Int, Long]());
	public val inDegree = PlaceLocalHandle.make[HashMap[Int, Int]](Dist.makeUnique(), ()=>new HashMap[Int, Int]());
    public val outDegree = PlaceLocalHandle.make[HashMap[Int, Int]](Dist.makeUnique(), ()=>new HashMap[Int, Int]());
	public val offset = new Array[Int](Place.MAX_PLACES + 1);
	
	public static def make(graph:PlainGraph): VertexInfo {
		//val vertexList = graph.getVertexListDualArrays(Place.MAX_PLACES).preArray;
		val vertexList = graph.getVertexList();
		val vertexInfo = new VertexInfo();
		val gOffset = GlobalRef(vertexInfo.offset);
		val recvArray = PlaceLocalHandle.make[Array[Array[Long]]](Dist.makeUnique(), ()=>new Array[Array[Long]](Place.MAX_PLACES));
		
		finish for(p in Place.places()) async at(p) {
			val sendArray = new Array[ArrayBuilder[Long]](Place.MAX_PLACES, (Int)=>new ArrayBuilder[Long]());
			for(vpt in vertexList | here){
				val vertexID = vertexList(vpt);
				if(vertexID < 0) continue;
				val placeID = vertexInfo.getPlaceID(vertexID);
				sendArray(placeID).add(vertexID);
			}
			for(place in Place.places()) at(place) {
				recvArray()(p.id) = sendArray(place.id).result();
			}
		}
		
		finish for(p in Place.places()) async at(p) {
			var counter:Int = 0;
			for(i in recvArray()){
				for(j in recvArray()(i)){
					val vertexID = recvArray()(i)(j);
					val nInNeighbours = graph.getInNeighbours(vertexID);
                    val nOutNeighbours = graph.getOutNeighbours(vertexID);
					vertexInfo.IDtoIDX().put(vertexID, counter);
					vertexInfo.IDXtoID().put(counter, vertexID);
                    if (nInNeighbours == null) {
                        vertexInfo.inDegree().put(counter, 0);
                    } else {
                        vertexInfo.inDegree().put(counter, nInNeighbours.size);
                    }
                    if (nOutNeighbours == null) {
                        vertexInfo.outDegree().put(counter, 0);
                    } else {
                        vertexInfo.outDegree().put(counter, nOutNeighbours.size);
                    }
					counter++;
				}
			}
			val count = counter;
			at(gOffset) gOffset()(p.id) = count;
		}
		
		for(var i:Int = Place.MAX_PLACES; i >= 1 ; i--){
			vertexInfo.offset(i) = vertexInfo.offset(i - 1);
		}
		vertexInfo.offset(0) = 0;
		for(var i:Int = 1; i <= Place.MAX_PLACES; i++){
			vertexInfo.offset(i) += vertexInfo.offset(i - 1);
		}
		
		return vertexInfo;
	}
	
	public def size(): Int {
		return offset(Place.MAX_PLACES);
	}
	
	public def getVertexCount(placeID:Int): Int {
		return offset(placeID + 1) - offset(placeID);
	}
	
	public def getPlaceID(vertexID:Long): Int {
		return (vertexID % Place.MAX_PLACES as Long) as Int;
	}
	
	public def getPlaceID(vertexIDX:Int): Int {
		var i:Int;
		for(i = Place.MAX_PLACES - 1; i >= 0; i--){
			if(offset(i) <= vertexIDX) break;
		}
		return i;
	}
	
	public def getPlace(vertexID:Long): Place {
		return placeList(getPlaceID(vertexID));
	}
	
	public def getPlace(vertexIDX:Int): Place {
		return placeList(getPlaceID(vertexIDX));
	}
	
	public def getIDX(vertexID:Long): Box[Int] {
		val pid = getPlaceID(vertexID);
		val p = placeList(pid);
		return at(p) {
			var result:Box[Int] = IDtoIDX().get(vertexID);
			if(result != null){
				result = new Box[Int](result() + offset(pid));
			}
			result
		};
	}
	
	public def getIDXFromHere(vertexID:Long): Box[Int] {
		val result:Box[Int] = IDtoIDX().get(vertexID);
		if(result != null){
			return new Box[Int](result() + offset(here.id));
		}else{
			return null;
		}
	}
	
	public def getID(vertexIDX:Int): Box[Long] {
		val pid = getPlaceID(vertexIDX);
		val p = placeList(pid);
		return at(p) {
			val result = IDXtoID().get(vertexIDX - offset(pid));
			result
		};
	}
	
	public def getIDFromHere(vertexIDX:Int): Box[Long] {
		return IDXtoID().get(vertexIDX - offset(here.id));
	}
	
	public def getDegree(vertexIDX:Int): Box[Int] {
		val pid = getPlaceID(vertexIDX);
		val p = placeList(pid);
		return at(p) {
			val result = inDegree().get(vertexIDX - offset(pid))() +
                outDegree().get(vertexIDX - offset(pid))();
			new Box[int](result)
		};
	}
	
	public def getDegreeFromHere(vertexIDX:Int): Box[Int] {
		return new Box[Int](inDegree().get(vertexIDX - offset(here.id))() +
                            outDegree().get(vertexIDX - offset(here.id))());
	}
	
	public def print(){
		Console.OUT.println(placeList);
		Console.OUT.println(offset);
		for(p in Place.places()) at(p) {
			Console.OUT.println("*** " + here + " ***");
			Tool.print(IDtoIDX());
			Console.OUT.println("---");
			Tool.print(IDXtoID());
			Console.OUT.println("---");
			Tool.print(inDegree());
            Tool.print(outDegree());
		}
	}
	
	/*public def toString(): String {
		val builder = new StringBuilder();
		builder.add("---------- IDtoIDX ----------\n");
		builder.add(Tool.toString(IDtoIDX));
		builder.add("---------- IDXtoID ----------\n");
		builder.add(Tool.toString(IDXtoID));
		builder.add("-----------------------------\n");
		return builder.result();
	}*/
}