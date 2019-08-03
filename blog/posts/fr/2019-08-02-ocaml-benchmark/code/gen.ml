let data = Array.init (int_of_string @@ Sys.getenv "SIZE") (fun _ -> Random.int 1073741823);;
Printf.printf "open Core_bench " ;
Printf.printf "let data=[|";;
Array.iter (Printf.printf "%d;") data;;
Printf.printf "|];;" ;
Printf.printf "let ht = Hashtbl.create (Array.length data);;" ;
Printf.printf "Array.iter (fun i -> Hashtbl.add ht i (string_of_int i)) data ;;" ;
Printf.printf "let pm = function " ;
Array.iter (fun i -> Printf.printf "|%d->\"%d\"" i i) data ;
Printf.printf "|_->raise Not_found;;" ;
Printf.printf
  "let () =
   Core.Command.run @@ Bench.make_command [
   Bench.Test.create ~name:\"Hash table\"
   (fun () -> Array.iter (fun i -> ignore (Hashtbl.find ht i)) data);
   Bench.Test.create ~name:\"Pattern matching\"
   (fun () -> Array.iter (fun i -> ignore (pm i)) data)
   ]
   "
