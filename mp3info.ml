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

open Mp3types;;
open Mp3read;;
open Pack;;

(* Giving in to the imperative side of the Force *)
let (+=) a b = (a := !a + b);;

let do_info ?(debug_in=false) ?(debug_info=false) in_name =
(*	let t1 = Sys.time () in*)
	let in_obj = new mp3read ~debug:debug_in in_name in
	
	let printDebug = (
		let h f = (if debug_info then Printf.printf "%s\n" f) in
		fun a -> Printf.kprintf h a
	) in
	
	let first_frame = in_obj#find_next_frame in
	let first_data_frame = match first_frame.frameXing with
		| None -> (printDebug "1st frame is data"; first_frame)
		| Some _ -> (printDebug "1st frame is Xing; read another"; in_obj#find_next_frame)
	in
	
	let k = first_frame.frameHeader.headerCommon in

	let max_reservoir_size = match k.common_id with
		| MPEG1 -> 511
		|   _   -> 255
	in
	
	(* OUTPUT DATA INITIALIZATION *)
	let bQ = List2.create () in (* Bitrate queue *)
	let bH = Hashtbl.create 28 in (* Frame bitrate hashtable *)
	let total_frame_size_ref = ref 0 in
	let	total_data_bits_ref = ref 0 in
	let total_data_bytes_ref = ref 0 in
	let most_bits_per_frame_ref = ref 0 in
	let frame_inky_ref = ref 0 in
	let frame_ref = ref first_data_frame in
	let next_update_ref = ref 0 in
	let next_update_percent_ref = ref 0 in
	let file_length = in_obj#length in
	(try while true do
		if in_obj#pos > !next_update_ref then (
			Printf.printf "\r%2d%% done on frame %d" !next_update_percent_ref !frame_inky_ref;
			flush stdout;
			next_update_percent_ref += 1;
			next_update_ref := int_of_float (float_of_int file_length *. float_of_int !next_update_percent_ref *. 0.01);
		);
		total_frame_size_ref += !frame_ref.frameHeader.headerFrameLength;
		total_data_bits_ref += !frame_ref.frameSide.sideDataBits;
		total_data_bytes_ref += (!frame_ref.frameSide.sideDataBits + 7) lsr 3;
		List2.append bQ ((!frame_ref.frameSide.sideDataBits + 7) lsr 3);
		most_bits_per_frame_ref := max !most_bits_per_frame_ref !frame_ref.frameSide.sideDataBits;
		let current = (!frame_ref.frameHeader.headerBitrate, !frame_ref.frameHeader.headerPadding) in
		(match Hashtbl.mem bH current with
			| false -> Hashtbl.add bH current (ref 1)
			| true -> (Hashtbl.find bH current) += 1
		);
		
		(* Next frame *)
		frame_ref := in_obj#find_next_frame;
		frame_inky_ref += 1;
	done with
		| End_of_file -> (
			Printf.printf "\r";
			let p = (
				let h f = (Printf.printf "%s\n" f) in
				fun a -> Printf.kprintf h a
			) in
			p "INFO:                                           ";
			p " %s layer 3" (match k.common_id with
				| MPEG1 -> "MPEG1"
				| MPEG2 -> "MPEG2"
				|   _   -> "MPEG2.5"
			);
			p " %d frames" (!frame_inky_ref + 1);
			p " %d Hz" (int_of_samplerate k.common_samplerate);
			p " %f frames per second" (125.0 /. k.common_bspfk);
			let sec = (k.common_bspfk *. (float_of_int (!frame_inky_ref + 1) *. 0.008)) in (* 0.008 = 1 / 125 *)
			p " %f seconds" sec;
			
			let kilobitPerSecondByte = 1.0 /. (k.common_bspfk *. float_of_int (!frame_inky_ref + 1)) in
			let total_mp3_data = (!total_data_bytes_ref + (!frame_inky_ref + 1) * (4 + k.common_side_info_size)) in
			
			p " %d bytes in file (%f kbps)" in_obj#length (float_of_int in_obj#length *. kilobitPerSecondByte);
			p " %d bytes in MP3 frames (%f kbps) = current bitrate" !total_frame_size_ref (float_of_int !total_frame_size_ref *. kilobitPerSecondByte);
			p " %d bits of payload data (%f kbps)" !total_data_bits_ref (float_of_int !total_data_bits_ref *. kilobitPerSecondByte *. 0.125);
			p " %d bytes of payload data (%f kbps)" !total_data_bytes_ref (float_of_int !total_data_bytes_ref *. kilobitPerSecondByte);
			p " %d bits wasted from partially-full bytes (%f kbps)" (!total_data_bytes_ref lsl 3 - !total_data_bits_ref) (float_of_int (!total_data_bytes_ref lsl 3 - !total_data_bits_ref) *. kilobitPerSecondByte *. 0.125);
			p " %d bytes of MP3 data (%f kbps) = minimum bitrate possible" total_mp3_data (float_of_int total_mp3_data *. kilobitPerSecondByte);
			p " %d bytes of padding (%f kbps)" (!total_frame_size_ref - total_mp3_data) (float_of_int (!total_frame_size_ref - total_mp3_data) *. kilobitPerSecondByte);
			p " %d bytes outside MP3 frames (%f kbps)" (in_obj#length - !total_frame_size_ref) (float_of_int (in_obj#length - !total_frame_size_ref) *. kilobitPerSecondByte);
			
			p " Bitrate distribution:";
			Array.iter (fun br ->
				let unpadded = try !(Hashtbl.find bH (br, false)) with _ -> 0 in
				let   padded = try !(Hashtbl.find bH (br,  true)) with _ -> 0 in
				if unpadded <> 0 || padded <> 0 then (
					p "  %3d: %d,%d" br unpadded padded
				);
			) k.common_bitrate_index;
			
			p " Largest frame uses %d bits = %d bytes = %f kbps" !most_bits_per_frame_ref ((!most_bits_per_frame_ref + 7) lsr 3) (float_of_int !most_bits_per_frame_ref *. 0.125 /. k.common_bspfk);

			(***********************************)
			(* Figure out smallest CBR bitrate *)
			(***********************************)
			let (number_to_bitrate, bytes_to_bitrate) = (
				let (max_bitrate, lists) = match k.common_id with
					| MPEG1 -> (320, [(1, 32);(2, 40);(3, 48);(4, 45);(5, 64);(6, 80);(7, 96);(8,112);(9,128);(10,160);(11,192);(12,224);(13,256);(14,320)])
					|   _   -> (160, [(1,  8);(2, 16);(3, 24);(4, 32);(5, 40);(6, 48);(7, 56);(8, 64);(9, 80);(10, 96);(11,112);(12,128);(13,144);(14,160)])
				in
				(fun num i ->
					let exact = List.exists (fun (_,a) -> a = num) lists in (* Did the caller specify an exact bitrate? *)
					let exactP1 = List.exists (fun (_,a) -> a + 1 = num) lists in (* Did the caller specify 1 more than an exact bitrate? *)
					let over = (num > max_bitrate) in (* Is the caller Way Out There? *)
					let padded = match (exact, exactP1 || over) with
						| ( true,  _  ) -> padded_frame k.common_samplerate num i
						| (false, true) -> true
						| (false,false) -> false
					in
					let (index,real_bitrate) = try (List.find (fun (_,a) -> num <= a + 1) lists) with Not_found -> (14,max_bitrate) in
					let unpad_length = k.common_unpadded_frame_length real_bitrate in
					let pad_add = if padded then 1 else 0 in
					{
						bitrateNum = real_bitrate;
						bitratePadding = padded;
						bitrateSize = unpad_length + pad_add;
						bitrateData = unpad_length + pad_add - 4 - k.common_side_info_size;
						bitrateIndex = index
					}
				), (fun bytes ->
					let bph = bytes + 4 + k.common_side_info_size in (* bytes plus header *)
					let out = ref None in
					List.iter (fun (index, real_bitrate) ->
						match !out with
						| Some _ -> ()
						| None -> (
							let bytes_unpadded = k.common_unpadded_frame_length real_bitrate in
							if bytes_unpadded >= bph then (
								(* OK without padding *)
								out := Some {
									bitrateNum = real_bitrate;
									bitratePadding = false;
									bitrateSize = bytes_unpadded;
									bitrateData = bytes_unpadded - 4 - k.common_side_info_size;
									bitrateIndex = index
								}
							) else if bytes_unpadded + 1 >= bph then (
								(* Needs padding *)
								out := Some {
									bitrateNum = real_bitrate;
									bitratePadding = true;
									bitrateSize = bytes_unpadded + 1;
									bitrateData = bytes_unpadded + 1 - 4 - k.common_side_info_size;
									bitrateIndex = index
								}
							) (* else keep going *)
						)
					) lists;
					if debug_info then (
						Printf.printf "   Finding a spot for %d bytes (%d)\n" bytes bph;
						flush stdout
					);
					match !out with
					| None -> raise Too_many_bytes (* No valid frame found! *)
					| Some x -> x
				)
			) in

			let check_bitrate br_index = (
				let br_num = k.common_bitrate_index.(br_index) in
				let res_ref = ref 0 in
				let br_unpadded_bytes = k.common_unpadded_frame_length k.common_bitrate_index.(br_index) - 4 - k.common_side_info_size in
				let br_padded_bytes = br_unpadded_bytes + 1 in
				if debug_info then p "  %d (%d) %d" br_index k.common_bitrate_index.(br_index) br_unpadded_bytes;
				let find_padded_frame = padded_frame k.common_samplerate br_num in
				try (
					List2.iteri (fun i bytes ->
						res_ref := min !res_ref max_reservoir_size;
(*						let max_bytes = number_to_bitrate bytes i in*)
						let max_frame_data = if find_padded_frame i then br_padded_bytes else br_unpadded_bytes in
						if debug_info then p "   %5d = %d %d (%d)" i bytes max_frame_data !res_ref;
						res_ref := !res_ref + max_frame_data - bytes;
						if !res_ref < 0 then ( (* ERREUR! *)
							raise Loop_end;
						)
					) bQ;
					true
				) with
				| Loop_end -> false
			) in

			let rec check_bitrate_rec now last = (
				if now > last then (
					k.common_bitrate_index.(Array.length k.common_bitrate_index - 1)
				) else (
					match (check_bitrate now, now = last) with
					| (false, false) -> check_bitrate_rec (now + 1) last
					| (false, true) -> k.common_bitrate_index.(Array.length k.common_bitrate_index - 1)
					| (true, _) -> k.common_bitrate_index.(now)
				)
			) in
(*
			for br_index = (bytes_to_bitrate (!most_bits_per_frame_ref lsr 3 - max_reservoir_size - 1)).bitrateIndex to Array.length k.common_bitrate_index - 1 do
			done;
*)
			let min_cbr_br = check_bitrate_rec (bytes_to_bitrate (!most_bits_per_frame_ref lsr 3 - max_reservoir_size - 1)).bitrateIndex (Array.length k.common_bitrate_index - 2) in
			p " Smallest bitrate for CBR is %d" min_cbr_br;

(*			Printf.printf "TIME: %f\n" (Sys.time () -. t1);*)

		)
	);
;;

