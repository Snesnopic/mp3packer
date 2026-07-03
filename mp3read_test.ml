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

let a = new mp3read ~debug:true "./test/API.mp3";;
let a = new mp3read ~debug:true "./test/APE.mp3";;
(*let a = new mp3read ~debug:true "./test/cut01-error0.03.mp3";;*)
(*let a = new mp3read ~debug:true "./test/cut02-unpackable0.03.mp3";;*)
(*let a = new mp3read ~debug:true "./test/himitsu.mp3";;*)
(*let a = new mp3read ~debug:true Sys.argv.(1);;*)
(*a#fill_buffer;;*)
(*a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
a#succ_pos;;
a#print_buffer;;
a#check_buffer_for_header;;
*)
(*
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
a#check_buffer_for_frame;;
*)
a#find_next_frame;;
a#find_next_frame;;
a#find_next_frame;;
(*
match b with
| None -> Printf.printf "NO!"
| _ -> ()
;;
*)