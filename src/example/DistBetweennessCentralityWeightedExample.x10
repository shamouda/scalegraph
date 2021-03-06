/* 
 *  This file is part of the ScaleGraph project (http://scalegraph.org).
 * 
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 * 
 *  (C) Copyright ScaleGraph Team 2011-2012.
 */

package example;

import x10.util.Team;

import org.scalegraph.api.BetweennessCentrality;
import org.scalegraph.graph.Graph;
import org.scalegraph.graph.GraphGenerator;
import org.scalegraph.io.CSV;
import org.scalegraph.io.NamedDistData;
import org.scalegraph.util.random.Random;
import org.scalegraph.util.tuple.Tuple3;

public class DistBetweennessCentralityWeightedExample {

    public static def main(args: Array[String]) {
        
        // Generate RMAT graph
        val scale = 10;
        val edgeFactor = 8;
        val weightName = "weight";
        val rnd = new Random(2, 3);
        val edgeList = GraphGenerator.genRMAT(scale, edgeFactor, 0.45, 0.15, 0.15, rnd);
        val g = Graph.make(edgeList);
        
        // Generate edge weight
        val weight = GraphGenerator.genRandomEdgeValue(scale, edgeFactor, rnd);
        g.setEdgeAttribute[Double](weightName, weight);
                
        // Create API instnace, since we would like to specify parameters
        val bc = new BetweennessCentrality();
        bc.directed = true;
        bc.weighted = true;
        bc.exactBc = false;
        bc.source = [0L as Long];
        
        // Call API
        val result = bc.execute(g);
        
        // Write result in CSV format
        CSV.write("bc-%d", new NamedDistData(["bc" as String], [result as Any]), true);

    }
}