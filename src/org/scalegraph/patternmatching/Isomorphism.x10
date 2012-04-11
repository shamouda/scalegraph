package org.scalegraph.patternmatching; 
import x10.util.ArrayList;
import x10.util.Pair;
import x10.util.HashMap;
import x10.util.HashSet;

public class Isomorphism {
	
	public def check_isomorphism(val cand_pat:Pattern):Canonicalcode{
		var e:Int=0; //least edge label
		var src_v:Int=0;//least source vertex label
		var dest_v:Int=0;//least destination label
		var ids:ArrayList[Pair[Int,Int]] = new ArrayList[Pair[Int,Int]]();//ids with least labelled edges

		if (cand_pat.get_code_known() == true) {
			return cand_pat.get_canonical_code();
		}
		
		if (cand_pat.size() == 0) {
			assert(false):("ERROR: null patterns are not allowed");
		}
		
		src_v = cand_pat.label(0);  // src_v has the label of the least vertex in dfs walk
			
		for(var j:Int = 0;j<cand_pat.size();j++){
			if(cand_pat.get_matrix()(0,j)==1){
				dest_v = cand_pat.label(j);// dest_v has the label of the second least vertex in dfs walk
				e = cand_pat.get_edge_label(0,j);
				break;
			}
		}
		
		if (dest_v < src_v) {// if dest_v is smaller then src_v,swap. 
			var ch:Int = src_v;
			src_v = dest_v;
			dest_v = ch;
		}
		
		iso_startup(cand_pat, src_v, dest_v, e, ids);

		// Each member of this vector corresponds to a minimal canonical code.
		// At the end of the minimal() method, this vector should have a single
		// element, which is *the* canonical code.
		var new_codes:ArrayList[Canonicalcode] = new ArrayList[Canonicalcode]();
		
		/*! This vector has one-to-one correspondence with the new_codes
		 * vector. Each element in this vector contains the set of edges
		 * that have already been added to the new_code, so that when
		 * we try to extend this new_code we know which edges we should
		 * not try. Each five_tuple in the set is represented in terms 
		 * of the pattern ids.
		 */
		var covered_edges:ArrayList[HashSet[FiveTuple]] = new ArrayList[HashSet[FiveTuple]]();

		
		// Create separate codes for each pair in ids.
		// Each such pair shall have to be tested for isomorphism.
		for(var i:Int=0; i<ids.size(); i++) {

			// Add a minimal edge to new_codes.
			var cc_tuple:FiveTuple = new FiveTuple(0, 1, cand_pat.label(ids(i).first), 
					e, cand_pat.label(ids(i).second));
			var new_cc:Canonicalcode = new Canonicalcode(cc_tuple, ids(i).first, ids(i).second);
			new_codes.add(new_cc);

			// Correspondingly update the covered_edges vector.
			var g_tuple:FiveTuple = new FiveTuple(ids(i).first, ids(i).second, cc_tuple._li,
					cc_tuple._lij, cc_tuple._lj);
			var s:HashSet[FiveTuple] = new HashSet[FiveTuple]();
			s.add(g_tuple);
			covered_edges.add(s);

		}
		
		// Each of the above new codes, which are equivalent are passed to the
		// minimal routine. Minimal routine will add more edges 
		// and remove some of the candidate minimal codes until it comes up 
		// with a single min canonical code.
		minimal(new_codes, covered_edges, cand_pat);
	
		cand_pat.set_code_known(true);
		cand_pat.set_canonical_code(new_codes(0));
		return new_codes(0);
	}
	
	private def iso_startup(var cand_pat:Pattern,var src_v:Int,var dest_v:Int,var e:Int,var ids:ArrayList[Pair[Int,Int]]):void{
		
		var swaped:Boolean = false;
		
		for(var i:Int = 0;i < cand_pat.get_matrix().getSize();i++){
			for(var j:Int = 0;j < i;j++){
				if(cand_pat.get_matrix()(i,j) == 1){
					var edge:Pair[Int,Int] = Pair(i,j);
					swaped=false;
					var v1:Int = cand_pat.label(edge.first); 
					var v2:Int = cand_pat.label(edge.second);
					var this_edge:Int =  cand_pat.get_edge_label(edge.first, edge.second);
					if (v1 > v2) {
						val x = v1;
						v1= v2;
						v2 = x;
						swaped=true;
					}
					if(v1 > src_v){// v1 should not sourece vartex
						continue;
					}
					if(v1 < src_v){ // new source vertex found
						ids = new ArrayList[Pair[Int,Int]]();
						src_v = v1; dest_v = v2; e = this_edge;
						if(src_v == dest_v){
							ids.add(Pair(edge.second, edge.first));     
							ids.add(edge);
						}
						else {
							if(swaped == true){
								ids.add(Pair(edge.second, edge.first));
							}
							else{
								ids.add(edge);
							}
						}
						continue;
					}
					if (v1 == src_v) { // if v1 may be source vartex
						var e2:Int = this_edge;
						if (e2 > e) continue;
						if (e2 < e) { // new edge label found
							ids = new ArrayList[Pair[Int,Int]]();
							e = e2;
							dest_v = v2;
							if (src_v == dest_v) {
								ids.add(Pair(edge.second, edge.first));     
								ids.add(edge);
							}
							else {
								if (swaped == true){
									ids.add(Pair(edge.second, edge.first));
								}
								else{
									ids.add(edge);
								}
							}
						}
						if (e2 == e) { // if e2 may be edge label of least label set
							if (v2 > dest_v) continue;
							if (v2 < dest_v) {  // new destination vertex found
								ids.clear(); 
								dest_v = v2;
								if (src_v == dest_v) {
									ids.add(Pair(edge.second, edge.first));     
									ids.add(edge);
								}
								else {
									if (swaped == true){
										ids.add(Pair(edge.second, edge.first));
									}
									else
										ids.add(edge);
								}
							}
							else {  // all identically match
								if (src_v == dest_v) {
									ids.add(Pair(edge.second, edge.first));     
									ids.add(edge);
								}
								else {
									if (swaped == true){
										ids.add(Pair(edge.second, edge.first));
									}
									else{
										ids.add(edge);
									}
								}
							}
						}
					}
					
				}				
			}
			
		}
		
	}
			
			
	private def minimal(var new_codes:ArrayList[Canonicalcode],var covered_edges:ArrayList[HashSet[FiveTuple]],var cand_pat:Pattern):void{
		var go_ahead:Boolean = true;
		
		// When none of the candidate codes can be extended,
		// its time to stop.
		while(go_ahead) {
			
			var orig_sz:Int = new_codes.size();
			var ret:Boolean = false;
			
			for(var i:Int = 0;i < orig_sz; i++) {
				var did_extend:Boolean = extend(new_codes, covered_edges, cand_pat, i);
				ret = (ret | did_extend);				
			}
			
			// Even if one of the extend() succeeds then go_ahead.
			go_ahead = ret;
			
			// Check if there is one (or more) that is minimal. Remove the others.
			// check_minimality(new_codes, covered_edges);
			//
			
			// deleate codes that is not actually minimal from candidate codes
			for(var i:Int=0; i < new_codes.size()-1; i++) {
				for(var j:Int=i+1; j < new_codes.size();) {
					
					if(new_codes(i) < new_codes(j)) {
						// deleate new_codes(j)
						if(j != new_codes.size()-1){
							var cc:Canonicalcode = new_codes.getLast();
							var ft:HashSet[FiveTuple] = covered_edges.getLast();
							
							new_codes(j) = cc;
							covered_edges(j) = ft;
						}
						new_codes.removeLast();
						covered_edges.removeLast();	
					}
					else if(new_codes(j) < new_codes(i)){
						// deleate new_codes(i);
						var cc:Canonicalcode = new_codes.getLast();
						var ft:HashSet[FiveTuple] = covered_edges.getLast();
						
						new_codes(i) = cc;
						covered_edges(i) = ft;
						
						new_codes.removeLast();
						covered_edges.removeLast();
						
						j=i+1;
					}
					else {
						j++;
					}
				}
				
			}
		}
	}
	
	private def extend(var new_codes:ArrayList[Canonicalcode],var covered_edges:ArrayList[HashSet[FiveTuple]],var cand_pat:Pattern,var idx:Int):Boolean{
		// extend new codes till all edges are covered
		
		// Denotes, if last edge in new_code was a fwd edge.
		var is_last_fwd:Boolean = (new_codes(idx).getCode().getLast()._i < new_codes(idx).getCode().getLast()._j);
		
		// If last edge is forward, last_vid=_j, otherwise 
		// last_vid = _i. 
		// This is the vid to which edge shall be added.
		var last_vid:Int;
		if(is_last_fwd){
			last_vid = new_codes(idx).getCode().getLast()._j;
		}
		else{
			last_vid = new_codes(idx).getCode().getLast()._i;
		}
		var g_src_id:Int=new_codes(idx).gid(last_vid);
		var g_src_lbl:Int = cand_pat.label(g_src_id);
		
		// This is the set of candidate edges, from g_src_id.
		var cand_edges:ArrayList[FiveTuple] = new ArrayList[FiveTuple]();
		
		// This is required for the forward edges. Since new
		// forward edges are not present in the canonical code
		// the gid() method returns -1. But we need the gid to
		// put it in covered_edges. So need to save it.
		var cid_gid_map:HashMap[Int,Int] = new HashMap[Int,Int]();
		
		// Negative ids are assigned so that they can be used 
		// with cid_gid_map. This is ultimately used to assign
		// gid at a later point.
		var curr_fwd_cid:Int = -1;
		
		do {
			curr_fwd_cid = -1;
			cid_gid_map.clear();
			for(var i:Int = 0;i < cand_pat.size();i++){
				if(cand_pat.get_matrix()(g_src_id,i) == 1){
					var g_dest_id:Int = i;
					var g_dest_lbl:Int = cand_pat.label(g_dest_id);
					var g_e_lbl:Int = cand_pat.get_edge_label(g_src_id,g_dest_id);
					
					// The call to cid returns -1 if the g_dest_id
					// is not in new_codes[idx]. Which means that
					// g_dest_id has not been added to the canonical code.
					var c_dest_id:Int = new_codes(idx).cid(g_dest_id);
					if (c_dest_id == -1) {
						c_dest_id = curr_fwd_cid;
						cid_gid_map.put(curr_fwd_cid,g_dest_id);
						curr_fwd_cid--;
					}
					
										
					
					
					
				}
			}
			
			
			
			
		}while(false);
		
		
		// not implemented yet
		assert(false):"not implemented yet";
		return false;
	}
	
	/*
	private def check_minimality(var new_codes:ArrayList[Canonicalcode],var covered_edges:ArrayList[ArrayList[FiveTuple]]){
		assert(false):"not implemented yet";
	   // not implemented yet
		
		
	}
	 * */
	
}