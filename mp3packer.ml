(*******************************************************************************
	This file is a part of mp3packer.

	mp3packer is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	mp3packer is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with mp3packer; if not, write to the Free Software
	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*******************************************************************************)

open Mp3read;;
open Mp3queue;;
open Mp3info;;



let version = "1.03-123";;

let padding = Printf.sprintf "mp3packer%s\n" version;;

let usage_head = Printf.sprintf "\nMP3 Packer version %s\nCopyright 2006 Reed \"Omion\" Wilson\nThis program is covered under the GNU GPL.\nSee gpl.txt or mp3packer.html for more information\n" version;;

(*****************)
(* PARSE OPTIONS *)
(*****************)
let min_bitrate_ref = ref 0;;
let delete_begin_ref = ref false;;
let delete_end_ref = ref false;;
let delete_input_ref = ref false;;
let force_overwrite_ref = ref false;;
let only_info_ref = ref false;;
let debug_in_ref = ref false;;
let debug_out_ref = ref false;;
let append_ref = ref "-vbr";;

type io_t = IO_File of string | IO_Dir of string;;
let string_of_io = function
	| IO_File x -> Printf.sprintf "File '%s'" x
	| IO_Dir x -> Printf.sprintf "Dir '%s'" x
;;


(* File name functions *)
let strip_multiple_slashes =
	let regexp = Str.regexp "[/\\\\]+" in
	fun str -> Str.global_replace regexp "/" str
;;
let strip_trailing_slash str =
	let str2 = strip_multiple_slashes str in
	if String.length str2 = 0 then (
		str2
	) else if str2.[String.length str2 - 1] = '/' then (
		String.sub str2 0 (String.length str2 - 1)
	) else (
		str2
	)
;;
let append_before_extension str app =
	(try
		let dot = String.rindex str '.' in
		let before = String.sub str 0 dot in
		let after = String.sub str dot (String.length str - dot) in
		before ^ app ^ after
	with
		Not_found -> str ^ app
	)
;;



let in_name_ref = ref None;;
let out_name_ref = ref None;;

let debug_parse = function
	| "in" -> debug_in_ref := true
	| "out" -> debug_out_ref := true
	| "all" -> (debug_in_ref := true; debug_out_ref := true)
	| _ -> ()
;;

let args = Arg.align [
	("-b", Arg.Int (fun x -> min_bitrate_ref := max 0 x), "# Minimum bitrate allowed for output. Defaults to 0");
	("-t", Arg.Set delete_begin_ref, " Strip non-mp3 data at the beginning (mainly ID3v2 tags)");
	("-s", Arg.Set delete_end_ref, " Strip non-mp3 data at the end (mainly tags)");
	("-a", Arg.Set_string append_ref, "\"-vbr\" Changes the string to append to the filename in certain cases");
	("-X", Arg.Set delete_input_ref, " Delete the input file after successful packing");
	("-f", Arg.Set force_overwrite_ref, " Force overwriting of output files");
	("-i", Arg.Set only_info_ref, " Print info and exit (no processing)");
	("-debug", Arg.String debug_parse, "\"x\" Print a bunch of garbage while processing. x = (in | out | all)")
];;

let find_file x = (try
	Some (Unix.stat x).Unix.st_kind
with
	| Unix.Unix_error _ -> None
);;

Arg.parse args (fun w ->
	let x = strip_trailing_slash w in
	match (!in_name_ref, !out_name_ref, find_file x) with
	| (None, None, None) -> (failwith (Printf.sprintf "'%s' does not exist" x))
	| (Some (IO_File _), None, None) -> out_name_ref := Some (IO_File x)
	| (Some (IO_File _), None, Some Unix.S_REG) -> out_name_ref := Some (IO_File x) (* Output file already exists *)
	| (Some (IO_File _), None, Some Unix.S_DIR) -> out_name_ref := Some (IO_Dir x) (* Use the same name, but in a different directory *)
	| (Some (IO_Dir _), None, None) -> out_name_ref := Some (IO_Dir x) (* Make up a directory *)
	| (Some (IO_Dir _), None, Some Unix.S_REG) -> out_name_ref := Some (IO_File x) (* Directory -> file; not allowed, but catch later *)
	| (Some (IO_Dir _), None, Some Unix.S_DIR) -> out_name_ref := Some (IO_Dir x) (* One dir to another *)
	| (Some _, Some _, _) -> Printf.printf "WARNING: too many arguments; '%s' ignored\n" x
	| (None, _, None) -> Printf.printf "WARNING: '%s' does not exist; ignoring\n" x
	| (None, _, Some Unix.S_REG) -> in_name_ref := Some (IO_File x)
	| (None, _, Some Unix.S_DIR) -> in_name_ref := Some (IO_Dir x)
	| (_, _, Some _) -> (failwith (Printf.sprintf "'%s' is not a file or directory" x))

(*
	| (None, _, _) -> Printf.printf "WARNING: '%s' does not exist; ignoring\n" x
	| (Some Unix.S_REG, None, _) -> in_name_ref := Some (IO_File x)
	| (Some Unix.S_DIR, None, _) -> in_name_ref := Some (IO_Dir x)
	| (Some Unix.S_REG, _, None) -> out_name_ref := Some (IO_File x)
	| (Some Unix.S_DIR, _, None) -> out_name_ref := Some (IO_Dir x)
	| (_, Some _, Some _) -> Printf.printf "WARNING: too many arguments; '%s' ignored\n" x
	| (Some _, _, _) -> (failwith (Printf.sprintf "ERROR: '%s' is not a file or directory\n" x))
*)
) (usage_head);;

(* Now see what the user wants *)
let do_base = if !only_info_ref then (
	(* In order to generalize the do_base function, just ignore the second string if user only wants info *)
	fun a b -> do_info ~debug_in:(!debug_in_ref) ~debug_info:(!debug_out_ref) a
) else (
	do_queue ~debug_in:(!debug_in_ref) ~debug_queue:(!debug_out_ref) ~min_bitrate:(!min_bitrate_ref) ~delete_beginning_junk:(!delete_begin_ref) ~delete_end_junk:(!delete_end_ref) ~padding:padding
);;
let do_a_file fin1 fout1 =
	let fin = strip_multiple_slashes fin1 in
	let fout = strip_multiple_slashes fout1 in
	if !only_info_ref then (
		Printf.printf "*** '%s'\n" fin
	) else (
		Printf.printf "*** '%s' -> '%s'\n" fin fout
	);
	(match (find_file fin, find_file fout, !force_overwrite_ref) with
		| (None, _, _) -> Printf.printf " WARNING: file '%s' does not exist; ignoring\n" fin
		| (Some Unix.S_REG, None, _) -> do_base fin fout
		| (Some Unix.S_REG, Some Unix.S_REG, true) -> do_base fin fout
		| (Some Unix.S_REG, Some Unix.S_REG, false) -> (
			Printf.printf "Do you really want to overwrite '%s'? (y/n)\n" fout;
			let answer = read_line () in
			if String.length answer > 0 && (answer.[0] = 'y' || answer.[0] = 'Y') then (
				do_base fin fout
			) else (
				Printf.printf "Skipping file...\n"
			)
		)
		| _ -> Printf.printf "WARNING: Invalid mapping from '%s' to '%s'\n" fin fout
	)
;;

	

(*
  IN  OUT Info 
	mp3 mp3 N | Simple file -> file
	mp3 DIR N | Put the file in the output dir
	mp3  .  N | assume the output file has whatever "-a" is set to
	DIR mp3 N | NO!
	DIR DIR N | Do all the files in the input dir and stick them in the output dir
	DIR  .  N | Append "-a" to the input dir's name, and output the files there
	 .  mp3 N | NO!
	 .  DIR N | NO!
	 .   .  N | Display usage
	mp3 ??? Y | Display info about the file
	DIR ??? Y | Display info about all files in the dir
	 .  ??? Y | Display usage
*)

if !debug_in_ref || !debug_out_ref then (
	match (!in_name_ref, !out_name_ref, !only_info_ref) with
	| (Some (IO_File x), Some (IO_File y), false) -> Printf.printf "mp3 mp3 N\n"
	| (Some (IO_File x), Some (IO_Dir  y), false) -> Printf.printf "mp3 DIR N\n"
	| (Some (IO_File x), None            , false) -> Printf.printf "mp3  .  N\n"
	| (Some (IO_Dir  x), Some (IO_File y), false) -> Printf.printf "DIR mp3 N\n"
	| (Some (IO_Dir  x), Some (IO_Dir  y), false) -> Printf.printf "DIR DIR N\n"
	| (Some (IO_Dir  x), None            , false) -> Printf.printf "DIR  .  N\n"
	| (None            , Some (IO_File y), false) -> Printf.printf " .  mp3 N\n"
	| (None            , Some (IO_Dir  y), false) -> Printf.printf " .  DIR N\n"
	| (None            , None            , false) -> Printf.printf " .   .  N\n"
	| (Some (IO_File x),         _       , true ) -> Printf.printf "mp3 ??? Y\n"
	| (Some (IO_Dir  x),         _       , true ) -> Printf.printf "DIR ??? Y\n"
	| (None            ,         _       , true ) -> Printf.printf " .  ??? Y\n"
);;

(match (!in_name_ref, !out_name_ref, !only_info_ref) with
	| (Some (IO_File x), Some (IO_File y), false) -> do_a_file x y
	| (Some (IO_File x), Some (IO_Dir  y), false) -> (do_a_file x (Filename.concat (y) (Filename.basename x)))
	| (Some (IO_File x), None            , false) -> (do_a_file x (append_before_extension x !append_ref))
	| (Some (IO_Dir  x), Some (IO_File y), false) -> (failwith "Can't output a directory to a file")
	| (Some (IO_Dir  x), Some (IO_Dir  y), false) -> (failwith "Directories not supported yet")
	| (Some (IO_Dir  x), None            , false) -> (failwith "Directories not supported yet")
	| (None            , Some (IO_File y), false) -> (failwith "This REALLY shouldn't happen... (1)")
	| (None            , Some (IO_Dir  y), false) -> (failwith "This REALLY shouldn't happen... (2)")
	| (None            , None            , false) -> (Arg.usage args ("ERROR: No input given\n" ^ usage_head))
	| (Some (IO_File x),         _       , true ) -> (do_a_file x "")
	| (Some (IO_Dir  x),         _       , true ) -> (failwith "Directories not supported yet")
	| (None            ,         _       , true ) -> (Arg.usage args ("ERROR: No input given\n" ^ usage_head))
(*	| (Some (IO_File x), _, true) -> do_a_file x "" (* Only info *)*)
);;
