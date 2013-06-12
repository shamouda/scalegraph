package example;

import org.scalegraph.util.tuple.*;
import org.scalegraph.fileread.DistributedReader;
import x10.util.Team;
import org.scalegraph.graph.Graph;
import org.scalegraph.util.Dist2D;
import org.scalegraph.util.Parallel;
import org.scalegraph.graph.DistSparseMatrix;
import org.scalegraph.util.DistMemoryChunk;
import org.scalegraph.util.MemoryChunk;
import org.scalegraph.graph.SparseMatrix;
import org.scalegraph.visitor.LsBfsVisitor;

public class LsBfsVisitorExample {
    
    public static val inputFormat = (s: String) => {
        val items = s.split(" ");        
        return Tuple3[Long, Long, Double] (
                Long.parse(items(0).trim()),
                Long.parse(items(1).trim()),
                0D
        );
    };
    
    public static def main(args: Array[String]) {
        val team = Team.WORLD;
        val fileList = new Array[String](1);
        fileList(0) = args(0);
        
        // Load
        val rawData = DistributedReader.read(team, fileList, inputFormat);

        // Create graph
        val edgeList = rawData.get1();
        val g = new Graph(team, Graph.VertexType.Long, false);
        g.addEdges(edgeList.raw(team.placeGroup()));
        
        // Create dist sparse matrix
        val csr = g.constructDistSparseMatrix(
                                              Dist2D.make1D(team, Dist2D.DISTRIBUTE_COLUMNS),
                                              true,
                                              true);
        // Run bfs
        val handler = (v: Long, pred: Long, isFirstVisit: Boolean, dist: Long) => { 
            Console.OUT.println(pred + " " + v + " " + dist);
            };
        
        val v = LsBfsVisitor.make(csr, handler, 0L);
        v.run();
    }
}