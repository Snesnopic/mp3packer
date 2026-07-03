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




let make_xing xing header_and_side_info =
	let out_ref = ref (xing.xingTagType ^ "\x00\x00\x00\x00") in
	(* frames, bytes, toc, quality *)
	(match xing.xingNumFrames with
		| None -> ()
		| Some x -> (out_ref := !out_ref ^ (packN x); !out_ref.[7] <- Char.chr ((Char.code !out_ref.[7]) lor 0x01))
	);
	(match xing.xingNumBytes with
		| None -> ()
		| Some x -> (out_ref := !out_ref ^ (packN x); !out_ref.[7] <- Char.chr ((Char.code !out_ref.[7]) lor 0x02))
	);
	(match xing.xingTOC with
		| None -> ()
		| Some x -> (
			let toc_string = String.create (Array.length x) in
			Array.iteri (fun i c ->
				toc_string.[i] <- Char.chr (c land 0xFF)
			) x;
			out_ref := !out_ref ^ toc_string;
			!out_ref.[7] <- Char.chr ((Char.code !out_ref.[7]) lor 0x04)
		)
	);
	(match xing.xingQuality with
		| None -> ()
		| Some x -> (out_ref := !out_ref ^ (packN x); !out_ref.[7] <- Char.chr ((Char.code !out_ref.[7]) lor 0x08))
	);
	(match xing.xingLame with
		| None -> (
			let encoder = String.sub (xing.xingEncoder ^ (String.make 20 '\x00')) 0 20 in
			out_ref := !out_ref ^ encoder;
		)
		| Some l -> (
			let encoder = String.sub (xing.xingEncoder ^ (String.make 20 '\x00')) 0 9 in
			out_ref := !out_ref ^ encoder;
			let lame = String.make 25 '#' in
			packBits lame   0  4 l.lameRevision;
			packBits lame   4  4 l.lameVBRMethod;
			packBits lame   8  8 l.lameLowpass;
			let str32 = packN32 (Int32.bits_of_float l.lamePeakAmplitude) in
			String.blit str32 0 lame 2 4; (*Printf.printf "%S\n" (to_hex str32);*)
			packBits lame  48 16 l.lameRGTrack;
			packBits lame  64 16 l.lameRGAlbum;
			packBits lame  80  1 (if l.lameNoGapPrev   then 1 else 0);
			packBits lame  81  1 (if l.lameNoGapNext   then 1 else 0);
			packBits lame  82  1 (if l.lameNSSafeJoint then 1 else 0);
			packBits lame  83  1 (if l.lameNSPsyTune   then 1 else 0);
			packBits lame  84  4 l.lameATHType;
			packBits lame  88  8 l.lameABRBitrate;
			packBits lame  96 12 l.lameDelayStart;
			packBits lame 108 12 l.lameDelayEnd;
			packBits lame 120  2 l.lameSourceFrequency;
			packBits lame 122  1 (if l.lameUnwise then 1 else 0);
			packBits lame 123  3 l.lameStereoMode;
			packBits lame 126  2 l.lameNoiseShaping;
			packBits lame 128  8 l.lameMP3Gain;
			packBits lame 136  2 0; (* Unused *)
			packBits lame 138  3 l.lameSurround;
			packBits lame 141 11 l.lamePreset;
			packBits lame 152  2 0; (* Only 30 bits used *)
			packBits lame 154 30 l.lameMusicLength;
			packBits lame 184 16 l.lameMusicCRC;
			out_ref := !out_ref ^ lame;
(*			Printf.printf "%S\n" (to_hex (header_and_side_info ^ !out_ref));*)
			let crc = Crc.create (header_and_side_info ^ !out_ref) 0 in
			out_ref := !out_ref ^ (packn crc);
		)
	);
	!out_ref
;;



let do_queue ?(debug_in=false) ?(debug_queue=false) ?(min_bitrate=0) ?(delete_beginning_junk=false) ?(delete_end_junk=false) ?(padding="mp3packer\n") in_name out_name =
(*
	let printDebug x = match debug_queue with
		| true  -> Printf.printf x
		| false -> Printf.fprintf nul x
	in
	let printOut x = match debug_out with
		| true  -> Printf.printf x
		| false -> Printf.fprintf nul x
	in
*)
(*
	let printDebug = (
		let h f = (if debug_queue then Printf.printf "%s\n" f) in
		fun a -> Printf.kprintf h a
	) in
	let printOut = (
		let h f = (if debug_out then Printf.printf "%s\n" f) in
		fun a -> Printf.kprintf h a
	) in
*)

	let in_obj = new mp3read ~debug:debug_in in_name in

	let out_file = open_out_bin out_name in
	let output_this = output_string out_file in

	(* The first frame gets all the info about the file *)
	let first_frame = in_obj#find_next_frame in
	(* Get the first data frame *)
	let first_data_frame = match first_frame.frameXing with
		| None -> (if debug_queue then Printf.printf "1st frame is data\n"; first_frame)
		| Some _ -> (if debug_queue then Printf.printf "1st frame is XING; reading another\n"; in_obj#find_next_frame)
	in
	(* k is the common info about the input file *)
	let k = first_frame.frameHeader.headerCommon in
(*
	let out_k = {
		common_id                    = k.common_id                   ;
		common_bitrate_index         = k.common_bitrate_index        ;
		common_samplerate_index      = k.common_samplerate_index     ;
		common_samplerate            = k.common_samplerate           ;
		common_crc                   = false                         ;
		common_channel_mode          = k.common_channel_mode         ;
		common_copyright             = k.common_copyright            ;
		common_original              = k.common_original             ;
		common_emphasis              = k.common_emphasis             ;
		common_samples_per_frame     = k.common_samples_per_frame    ;
		common_side_info_size        = k.common_side_info_size       ;
		common_bspfk                 = k.common_bspfk                ;
		common_unpadded_frame_length = k.common_unpadded_frame_length;
	} in
*)
	(***********************)
	(* Data initialization *)
	(***********************)

	(* An exact bitrate is taken to be dithered according to the table above *)
	(* One more than an exact bitrate is assumed to be always padded *)
	(* Anything larger than the max bitrate will be truncated to a padded max frame *)
	(* Everything else rounds up to the next highest valid bitrate *)
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
			if debug_queue then (
				Printf.printf "   Finding a spot for %d bytes (%d with header)\n" bytes bph;
				flush stdout;
			);
			match !out with
			| None -> raise Too_many_bytes (* No valid frame found! *)
			| Some x -> x
		)
	) in
	(* Returns a valid header given the bitrate info, common settings, and stereo mode *)
	let bitrate_to_header = (
		let template = "\xFF\xFF\xFF\xFF" in
		let pack_head = packBits template in

		pack_head 0 11 0b11111111111;
		pack_head 11 2 (match k.common_id with
			| MPEG1  -> 0b11
			| MPEG2  -> 0b10
			| MPEG25 -> 0b00
		);
		pack_head 13 2 0b01; (* Layer 3 *)
		pack_head 15 1 0b1; (* CRC *)
		pack_head 20 2 (match k.common_samplerate with
			| S44100 | S22050 | S11025 -> 0b00
			| S48000 | S24000 | S12000 -> 0b01
			| S32000 | S16000 |  S8000 -> 0b10
		);
		pack_head 23 1 0b0; (* Privates *)
		pack_head 24 2 (match k.common_channel_mode with
			| ChannelStereo -> 0b00
			| ChannelJoint  -> 0b01
			| ChannelDual   -> 0b10
			| ChannelMono   -> 0b11
		);
		pack_head 28 1 (if k.common_copyright then 1 else 0);
		pack_head 29 1 (if k.common_original then 1 else 0);
		pack_head 30 2 (match k.common_emphasis with
			| EmphasisNone -> 0b00
			| Emphasis5015 -> 0b01
			| EmphasisInvalid -> 0b10 (* Don't die on invalid emphasis because I don't want to bother with that now *)
			| EmphasisCCITT -> 0b11
		);

(*		Printf.printf "%S" (to_hex template);*)
		fun br ms is -> (
			let out_head = String.copy template in
			let pack_head = packBits out_head in
			pack_head 16 4 br.bitrateIndex; (* Bitrate *)
			pack_head 22 1 (if br.bitratePadding then 1 else 0);
			pack_head 26 1 (if ms then 1 else 0);
			pack_head 27 1 (if is then 1 else 0);
			out_head
		)
	) in
	let min_bitrate_now frame = number_to_bitrate min_bitrate frame in

	let update_side_reservoir = (match k.common_id with
		| MPEG1 -> (fun side num ->
			let a = String.copy side in
			packBits a 0 9 num;
			a
		)
		| _ -> (fun side num ->
			let a = String.copy side in
			packBits a 0 8 num;
			a
		)
	) in

	let printBitrate a = Printf.printf "{\n num: %d\n pad: %B\n size: %d\n data: %d\n index: %d\n}\n" a.bitrateNum a.bitratePadding a.bitrateSize a.bitrateData a.bitrateIndex in
(*
	printBitrate (number_to_bitrate 127 0);
	printBitrate (number_to_bitrate 127 1);
	printBitrate (number_to_bitrate 127 2);
	printBitrate (number_to_bitrate 127 3);
	printBitrate (bytes_to_bitrate (416  - 36));
	printBitrate (bytes_to_bitrate (417  - 36));
	printBitrate (bytes_to_bitrate (418  - 36));
	printBitrate (bytes_to_bitrate (1042 - 36));
	printBitrate (bytes_to_bitrate (1044 - 36));
	printBitrate (bytes_to_bitrate (1045 - 36));
	printBitrate (bytes_to_bitrate 1046);
	failwith "12345";
*)

	(* Make room for the beginning data, if it is to be saved *)
	if not delete_beginning_junk then (
		if debug_queue then Printf.printf "Writing the first %d bytes to the output file\n" in_obj#first_mp3_byte;
		let in_temp = open_in_bin in_name in
		let length = in_obj#first_mp3_byte in
		let str = String.create length in
		really_input in_temp str 0 length;
		output_this str;
		close_in in_temp;
	);

	(* Make room for the LAME/XING header *)
	let (xing_bitrate, xing_pos, output_is_lame, xing_header_and_side_info) = (
		let is_lame = (match first_frame.frameXing with
			| None -> false
			| Some xing -> (match xing.xingLame with
				| None -> false
				| Some lame -> true
			)
		) in
		let min_lame_bitrate = bytes_to_bitrate (if is_lame then 156 else 140) in
		let bitrate = max (min_bitrate_now 0) min_lame_bitrate in
		output_this (bitrate_to_header bitrate false false);
		output_this (String.make k.common_side_info_size '\x00');
		let xing_header_and_side_info = (bitrate_to_header bitrate false false) ^ (String.make k.common_side_info_size '\x00') in
		let wheresit = pos_out out_file in
		output_this (String.make bitrate.bitrateData '\x00');
		if debug_queue then Printf.printf "XING frame located at %d\n" wheresit;
		(bitrate, wheresit, is_lame, xing_header_and_side_info)
	) in

	(* The input queue is where a frame goes until it's been determined that a super-sized frame can't affect it *)
	let iQ = List2.create () in
	(* The output queue is where the frames go to get packed together for output *)
	let oQ = List2.create () in

	(* Reservoir initialization *)
	let max_reservoir_size = match k.common_id with
		| MPEG1 -> 511
		|   _   -> 255
	in
	let reservoir = Buffer.create 1000 in
	let o_res_ref = ref 0 in (* How many bytes to seek to write the output frame's data *)

	let max_data_per_frame = match k.common_id with
		| MPEG1 -> k.common_unpadded_frame_length 320 + 1 - 4 - k.common_side_info_size
		|   _   -> k.common_unpadded_frame_length 160 + 1 - 4 - k.common_side_info_size
	in
	if debug_queue then Printf.printf "Max %d bytes of data per frame\n" max_data_per_frame;
(*	let large_frame_size = max_data_per_frame + max_reservoir_size in*)

	(*****************)
	(* INFORMATIONAL *)
	(*****************)
	(* Largest and smallest bitrates used *)
	let max_frame_used_ref = ref {
		bitrateData = 0;
		bitrateSize = 0;
		bitrateNum = 0;
		bitratePadding = false;
		bitrateIndex = 0
	} in
	let min_frame_used_ref = ref {
		bitrateData = 500000;
		bitrateSize = 500000;
		bitrateNum = 500000;
		bitratePadding = true;
		bitrateIndex = 15
	} in
	let total_frames_ref = ref 0 in
	let total_frame_bytes_ref = ref xing_bitrate.bitrateSize in

	let frame_locations = Hashtbl.create (match first_frame.frameXing with
		| None -> (in_obj#length / 418) (* Assume a 128kbps file *)
		| Some xing -> (match xing.xingNumFrames with
			| None -> (in_obj#length / 418) (* Again with thi 128 *)
			| Some y -> y
		)
	) in

	(* Make the initial frame filled with whatever padding is *)
	let frame_template = (
		let a = String.create max_data_per_frame in
		let rec pad_at pos = (
			if pos >= max_data_per_frame - String.length padding then (
				(* Last one *)
				String.blit padding 0 a pos (max_data_per_frame - pos)
			) else (
				String.blit padding 0 a pos (String.length padding);
				pad_at (pos + String.length padding)
			)
		) in
		pad_at 0;
		a
	) in

	(********************************************************************************)
	(* 3333333333333333333333333333333333333333333333333333333333333333333333333333 *)
	(* WRITE DATA WRITE DATA WRITE DATA WRITE DATA WRITE DATA WRITE DATA WRITE DATA *)
	(********************************************************************************)
	(* Writes the first frame of the output queue if the bit reservoir doesn't need it *)
	let rec write_first_output () = (
		let cdr_bytes = List2.fold (fun soFar gnu -> soFar + String.length gnu.outData) (0 - String.length (List2.head oQ).outData) oQ in
		if debug_queue then Printf.printf "  There are %d bytes after the first frame in oQ\n" cdr_bytes;
		if debug_queue then Printf.printf "  Reservoir is %d bytes\n" !o_res_ref;
		if cdr_bytes >= !o_res_ref then (
			let out_frame = List2.take_first oQ in
			if debug_queue then Printf.printf "   Writing frame %d to location %d!\n" out_frame.outFrame (pos_out out_file);
			Hashtbl.add frame_locations out_frame.outFrame (pos_out out_file);
			output_this out_frame.outHeader;
			output_this out_frame.outSide;
			output_this out_frame.outData;

			(* Update info *)
			total_frames_ref := !total_frames_ref + 1;
			total_frame_bytes_ref := !total_frame_bytes_ref + String.length out_frame.outHeader + String.length out_frame.outSide + String.length out_frame.outData;

			if not (List2.is_empty oQ) then (
				ignore (write_first_output ());
			);
			true
		) else (
			if debug_queue then Printf.printf "   Not enough\n";
			false
		)
	) in

	(******************************************************************************)
	(* 22222222222222222222222222222222222222222222222222222222222222222222222222 *)
	(* IQ -> OQ   IQ -> OQ   IQ -> OQ   IQ -> OQ   IQ -> OQ   IQ -> OQ   IQ -> OQ *)
	(******************************************************************************)

	let rec output_first_with_padding ?(output_everything=false) () = (

		(* What if a really big frame was added next (max_data_per_frame + max_reservoir_size)? *)
(*		let next_required_ref = ref max_reservoir_size in*)
		let last_checked_ref = ref ~-1 in

		let enough_bytes = if output_everything then (
			last_checked_ref := 666;
			if debug_queue then Printf.printf "  USURPED!\n";
			true
		) else (
(*
			(try
				List2.rev_iteri (fun i transit_now ->
					last_checked_ref := i;
					if transit_now.transitDataLength + !next_required_ref > max_data_per_frame then (
						next_required_ref := min max_reservoir_size (transit_now.transitDataLength + !next_required_ref - max_data_per_frame);
						if debug_queue then Printf.printf "  Frame %d(%d) WOULD have %d bytes too many in it\n" transit_now.transitFrame i !next_required_ref;
					) else (
						if debug_queue then Printf.printf "  Frame %d(%d) WOULD have enough room to absorb the changes\n" transit_now.transitFrame i;
						raise Loop_end;
						next_required_ref := 0;
					)
				) iQ
			with
				| Loop_end -> ()
			);
*)
(*			let bytes_free = List2.fold (fun so_far next -> so_far + max_data_per_frame - next.transitDataLength) ((List2.head iQ).transitDataLength - max_data_per_frame) iQ in*)
(*			let bytes_free = List2.fold (fun so_far next -> so_far + max_data_per_frame - next.transitDataLength) ((List2.head iQ).transitDataLength + (List2.head iQ).transitPad - max_data_per_frame) iQ in*)

			let iQhead = List2.head iQ in
			let bytes_used = List2.fold (fun so_far next -> so_far + next.transitDataLength) ( ~- (iQhead.transitDataLength + iQhead.transitPad)) iQ in
			let bytes_max = (List2.length iQ - 1) * max_data_per_frame in
			let bytes_free = bytes_max - bytes_used in

			if debug_queue then Printf.printf " %d bytes free\n" bytes_free;
			bytes_free >= max_reservoir_size
		) in

(*		if debug_queue then Printf.printf " Last checked frame %d\n" !last_checked_ref;*)
(*		if !last_checked_ref <> 0 then ( *)
		if enough_bytes then (
			let t_frame = List2.take_first iQ in
			if debug_queue then Printf.printf "  Taking frame %d out of the input queue!\n" t_frame.transitFrame;

			let data_ref = ref t_frame.transitData in
			o_res_ref := min max_reservoir_size !o_res_ref;
			let side = update_side_reservoir t_frame.transitSide !o_res_ref in
			if !o_res_ref = 0 || String.length !data_ref = 0 then (
				(* Just output the data to the current frame *)
			) else (
				(* Find the first frame *)
				if debug_queue then Printf.printf "  Finding frame for storing data\n";
				let rec find_first_frame fnum res = (
					(* Note that this function counts BACKWARDS from -1 *)
					if debug_queue then Printf.printf "   Need %d bytes on frame %d\n" res fnum;
					let frame = List2.nth oQ fnum in
					let len = String.length frame.outData in
					if len < res then (
						if debug_queue then Printf.printf "    But frame only has %d bytes\n" len;
						find_first_frame (pred fnum) (res - len)
					) else (
						if debug_queue then Printf.printf "    This is the frame (%d bytes, offset %d)!\n" len (len - res);
						(fnum, len - res)
					)
				) in
				let (first_frame, offset) = find_first_frame ~-1 !o_res_ref in
				let offset_ref = ref offset in
				(try for write_frame = first_frame to ~-1 do
					let this_frame = List2.nth oQ write_frame in
					let write_bytes = min (String.length !data_ref) (String.length this_frame.outData - !offset_ref) in

					if write_bytes = 0 then raise Loop_end;

					if debug_queue then Printf.printf "   Writing %d bytes to frame %d\n" write_bytes write_frame;
					String.blit !data_ref 0 this_frame.outData !offset_ref write_bytes;

					(* Adjust the lengths to fit the smaller amount of data *)
					data_ref := String.sub !data_ref write_bytes (String.length !data_ref - write_bytes);
					o_res_ref := !o_res_ref - write_bytes;
					if debug_queue then Printf.printf "    %d more bytes, with %d in reservoir\n" (String.length !data_ref) !o_res_ref;

					(* Only the first frame written to should have an offset. All the other frames will be written to starting at the beginning *)
					offset_ref := 0;
				done with Loop_end -> ());
			);



			let size = String.length !data_ref + t_frame.transitPad in
			let optimal_bitrate = bytes_to_bitrate size in
			let minimum_bitrate = min_bitrate_now t_frame.transitFrame in
			if debug_queue then Printf.printf "   Optimal frame is %spadded %dkbps\n" (if optimal_bitrate.bitratePadding then "  " else "un") optimal_bitrate.bitrateNum;
			if debug_queue then Printf.printf "   Minimum frame is %spadded %dkbps\n" (if minimum_bitrate.bitratePadding then "  " else "un") minimum_bitrate.bitrateNum;
			let bitrate = max optimal_bitrate minimum_bitrate in
			let header = bitrate_to_header bitrate t_frame.transitHeader.headerMS t_frame.transitHeader.headerIS in
			if debug_queue then Printf.printf "  Making %dkbps frame with %d bytes for %d bytes\n" bitrate.bitrateNum bitrate.bitrateData size;

			max_frame_used_ref := max !max_frame_used_ref bitrate;
			min_frame_used_ref := min !min_frame_used_ref bitrate;

			let out_frame = {
				outFrame = t_frame.transitFrame;
				outHeader = header;
				outSide = side;
				outData = String.sub frame_template 0 bitrate.bitrateData;
			} in
			String.blit !data_ref 0 out_frame.outData 0 (String.length !data_ref);
			o_res_ref := !o_res_ref + bitrate.bitrateData - String.length !data_ref;

			if !o_res_ref > max_reservoir_size then (
				if debug_queue then Printf.printf "   %d BYTES WASTED\n" (!o_res_ref - max_reservoir_size);
				o_res_ref := max_reservoir_size
			);

			List2.append oQ out_frame;
(*			if debug_queue then Printf.printf "   head: %S\n   side: %S\n   data: %S" (to_hex out_frame.outHeader) (to_hex out_frame.outSide) (to_hex out_frame.outData);*)
			if debug_queue then Printf.printf "  New reservoir %d\n" !o_res_ref;

			(* Recurse! *)
			if not (List2.is_empty iQ) then (
				ignore (output_first_with_padding ~output_everything:output_everything ());
			);

			true
		) else (
			false
		)
	) in



	(***********************************************************************************)
	(* 1111111111111111111111111111111111111111111111111111111111111111111111111111111 *)
	(* MAIN LOOP MAIN LOOP MAIN LOOP MAIN LOOP MAIN LOOP MAIN LOOP MAIN LOOP MAIN LOOP *)
	(***********************************************************************************)
	let frame_inky_ref = ref 0 in
	let frame_ref = ref first_data_frame in
	let next_update_ref = ref 0 in
	let next_update_percent_ref = ref 0 in
	let file_length = in_obj#length in
	(try while true do (* Until the file ends *)
		if debug_queue then Printf.printf "Frame %d\n" !frame_inky_ref;

		if in_obj#pos > !next_update_ref && not debug_queue then (
			Printf.printf "\r%2d%% done on frame %d" !next_update_percent_ref !frame_inky_ref;
			flush stdout;
			next_update_percent_ref := !next_update_percent_ref + 1;
			next_update_ref := int_of_float (float_of_int file_length *. float_of_int !next_update_percent_ref *. 0.01);
		);

		(* Trim the reservoir *)
		if Buffer.length reservoir > max_reservoir_size then (
			if debug_queue then Printf.printf " Trimmed %d bytes from the input reservoir\n" (Buffer.length reservoir - max_reservoir_size);
			let temp = Buffer.sub reservoir (Buffer.length reservoir - max_reservoir_size) max_reservoir_size in
			Buffer.clear reservoir;
			Buffer.add_string reservoir temp;
		);

		(************************************)
		(* First, figure out the frame data *)
		(************************************)
		Buffer.add_string reservoir !frame_ref.frameData;
		if debug_queue then (
(*			Printf.printf " Reservoir %S\n" (to_hex (Buffer.contents reservoir));*)
			Printf.printf " Frame starts at %d (%d from the start)\n" !frame_ref.frameSide.sideDataOffset (Buffer.length reservoir - String.length !frame_ref.frameData - !frame_ref.frameSide.sideDataOffset);
			Printf.printf " Data has length %d bits\n" !frame_ref.frameSide.sideDataBits;
			Printf.printf "  That's %d bytes\n" ((!frame_ref.frameSide.sideDataBits + 7) / 8);
		);

		let buffer_offset = Buffer.length reservoir - String.length !frame_ref.frameData - !frame_ref.frameSide.sideDataOffset in
		let data_length = (!frame_ref.frameSide.sideDataBits + 7) / 8 in

		(* Make the underrun preventer *)
		let data_string = if buffer_offset < 0 then (
			(* Invalid MP3! Oh noes! *)
			if data_length + buffer_offset < 0 then (
				(* The ENTIRE frame is before the beginning of the buffer *)
				Printf.printf "\nBuffer underflow; all of frame %d is before the beginning of the buffer\n" !frame_inky_ref;
				String.make data_length '\x00'
			) else (
				Printf.printf "\nBuffer underflow; added %d zeros to the beginning of frame %d\n" (~- buffer_offset) !frame_inky_ref;
				(String.make (~- buffer_offset) '\x00') ^ (Buffer.sub reservoir 0 (data_length + buffer_offset))
			)
		) else (
			Buffer.sub reservoir buffer_offset data_length
		) in

		if !frame_ref.frameSilent then (
			if debug_queue then (
				Printf.printf " SILENT FRAME!\n";
				Printf.printf " Buffer offset: %d\n" buffer_offset;
				Printf.printf " Data length: %d\n" data_length;
				Printf.printf " Added the following data to the queue:\n";
				Printf.printf "  Side: %S\n" (to_hex !frame_ref.frameSide.sideRaw);
				Printf.printf "  Data: %S\n" (to_hex data_string);
				Printf.printf "  Bits: %d\n" !frame_ref.frameSide.sideDataBits;
			);

			let this_transit = {
				transitFrame = !frame_inky_ref;
				transitHeader = !frame_ref.frameHeader;
				transitSide = String.make (String.length !frame_ref.frameSide.sideRaw) '\x00';
				transitData = "";
				transitDataLength = 0;
				transitBits = 0;
				transitPad = 0;
			} in

			List2.append iQ this_transit;
			if debug_queue then Printf.printf " Frame %d added to the queue\n" this_transit.transitFrame;
		) else (
			if debug_queue then (
				Printf.printf " Buffer offset: %d\n" buffer_offset;
				Printf.printf " Data length: %d\n" data_length;
				Printf.printf " Added the following data to the queue:\n";
				Printf.printf "  Side: %S\n" (to_hex !frame_ref.frameSide.sideRaw);
				Printf.printf "  Data: %S\n" (to_hex data_string);
				Printf.printf "  Bits: %d\n" !frame_ref.frameSide.sideDataBits;
			);

			let this_transit = {
				transitFrame = !frame_inky_ref;
				transitHeader = !frame_ref.frameHeader;
				transitSide = !frame_ref.frameSide.sideRaw;
				transitData = data_string;
				transitDataLength = data_length;
				transitBits = !frame_ref.frameSide.sideDataBits;
				transitPad = 0;
			} in

			List2.append iQ this_transit;
			if debug_queue then Printf.printf " Frame %d added to the queue\n" this_transit.transitFrame;
		);

		(**********************************************************************)
		(* If the frame's too large, pad the previous frames to accomodate it *)
		(**********************************************************************)
(*		let get_required_reservoir transit_now = max 0 (transit_now.transitDataLength + transit_now.transitPad - max_data_per_frame) in*)

		let next_required_ref = ref 0 in
		(try
			List2.rev_iter (fun transit_now ->
				transit_now.transitPad <- !next_required_ref;
				if transit_now.transitDataLength + transit_now.transitPad > max_data_per_frame then (
					if debug_queue then Printf.printf "  Frame %d has too much data in it\n" transit_now.transitFrame;
					next_required_ref := transit_now.transitDataLength + transit_now.transitPad - max_data_per_frame;
				) else (
					if debug_queue then Printf.printf "  Frame %d has enough room to absorb the changes\n" transit_now.transitFrame;
					raise Loop_end
				)
			) iQ
		with
			| Loop_end -> ()
		);

		if debug_queue then Printf.printf " Queue now has %d frames in it\n" (List2.length iQ);
		if debug_queue then (
			List2.iter (fun x -> Printf.printf "  %5d - %4d %d\n" x.transitFrame (String.length x.transitData) x.transitPad) iQ
		);

		let add_output = output_first_with_padding () in

		(**********************************************************************)
		(* Now see if the queue has enough extra bits to absorb a large frame *)
		(**********************************************************************)
		if debug_queue then Printf.printf " Something was out? %B\n" add_output;
		if add_output then (
			ignore (write_first_output ())
		);
(*		if add_output then failwith "AOTNEHU";*)
(*		if add_output then parse_output_queue ();*)

(*		if !frame_inky_ref >= 96 then raise Not_found;*)

		frame_inky_ref := succ !frame_inky_ref;
		frame_ref := in_obj#find_next_frame;
	done with
		| End_of_file -> (
			if debug_queue then (
				Printf.printf "END OF FILE\n"
			) else (
				Printf.printf "\r100%% done with %d frames\n" !frame_inky_ref
			);
			(* Write all the input frames to the output queue *)
			while not (List2.is_empty iQ) do
(*				ignore (output_first ~ignore_large:true ())*)
				ignore (output_first_with_padding ~output_everything:true ());
			done;
			(* Reset the bit reservoir and output the frames *)
			o_res_ref := 0;
			ignore (write_first_output ());

			(* Write the output data, if it is to be saved *)
			if not delete_beginning_junk then (
				if debug_queue then Printf.printf "Writing the last %d bytes to the file starting on %d\n" (in_obj#length - in_obj#last_mp3_byte - 1) (in_obj#last_mp3_byte + 1);
				let in_temp = open_in_bin in_name in
				let length = in_obj#length - in_obj#last_mp3_byte - 1 in
				let str = String.create length in
				seek_in in_temp (in_obj#last_mp3_byte + 1);
				really_input in_temp str 0 length;
				output_this str;
				close_in in_temp;
			);
			let total_bytes_written = pos_out out_file in

			if debug_queue then (
				Printf.printf "Bitrate range:\n";
				printBitrate !min_frame_used_ref;
				printBitrate !max_frame_used_ref;
				Printf.printf " MP3 data range [%d - %d]\n" in_obj#first_mp3_byte in_obj#last_mp3_byte;
				Printf.printf " Wrote %d bytes in %d frames\n" !total_frame_bytes_ref !total_frames_ref;
				Printf.printf "Frame positions:\n";
			);
			for a = 0 to !total_frames_ref do
				try (
					if debug_queue then Printf.printf " %5d = %d\n" a (Hashtbl.find frame_locations a)
				) with
				| Not_found -> ()
			done;

			let toc = Array.init 100 (fun percent ->
				let frame = min (!total_frames_ref - 1) (percent * !total_frames_ref / 100) in
				let pos = try (
					Hashtbl.find frame_locations frame
				) with
					| Not_found -> 0
				in
				(* Do floating-point math because the numbers can get pretty big *)
(*				let frac = int_of_float (float_of_int pos *. 256. /. (float_of_int !total_frame_bytes_ref)) in*)
				let frac = int_of_float (float_of_int pos *. 256. /. (float_of_int total_bytes_written)) in
				if debug_queue then Printf.printf " %d = %d\n" percent frac;
				frac
			) in
			(* Not using the frame_locations hash any more *)
			Hashtbl.clear frame_locations;
			let out_xing = (match (output_is_lame, first_frame.frameXing) with
				| (false, None) -> { (* Make up my own XING frame *)
					xingRawTag = ""; (* Unknown *)
					xingTagType = (if !min_frame_used_ref.bitrateNum = !max_frame_used_ref.bitrateNum then "Info" else "Xing");
					xingNumFrames = Some !total_frames_ref;
					xingNumBytes = Some !total_frame_bytes_ref;
					xingTOC = Some toc;
					xingQuality = None;
					xingEncoder = padding;
					xingLame = None
				}
				| (false, Some x) -> { (* Use parts of the old XING frame *)
					xingRawTag = "";
					xingTagType = (if !min_frame_used_ref.bitrateNum = !max_frame_used_ref.bitrateNum then "Info" else "Xing");
					xingNumFrames = Some !total_frames_ref;
					xingNumBytes = Some !total_frame_bytes_ref;
					xingTOC = Some toc;
					xingQuality = x.xingQuality;
					xingEncoder = x.xingEncoder;
					xingLame = None
				}
				| (true, None) -> { (* Make up my own LAME tag *)
					xingRawTag = ""; (* Unknown *)
					xingTagType = (if !min_frame_used_ref.bitrateNum = !max_frame_used_ref.bitrateNum then "Info" else "Xing");
					xingNumFrames = Some !total_frames_ref;
					xingNumBytes = Some !total_frame_bytes_ref;
					xingTOC = Some toc;
					xingQuality = None;
					xingEncoder = padding;
					xingLame = Some {
						lameRevision = 1;
						lameVBRMethod = 0;
						lameLowpass = 0;
						lamePeakAmplitude = 0.0;
						lameRGTrack = 0;
						lameRGAlbum = 0;
						lameNSPsyTune = false;
						lameNSSafeJoint = false;
						lameNoGapPrev = false;
						lameNoGapNext = false;
						lameATHType = 0;
						lameABRBitrate = min 255 !min_frame_used_ref.bitrateNum;
						lameDelayStart = 576; (* Assume there's a 576 sample delay on both ends *)
						lameDelayEnd = 576;
						lameNoiseShaping = 0;
						lameStereoMode = (match k.common_channel_mode with
							| ChannelStereo -> 1
							| ChannelJoint -> 3
							| ChannelDual -> 2
							| ChannelMono -> 0
						);
						lameUnwise = true; (* Better to say a good one's bad than say a bad one's good *)
						lameSourceFrequency = 1; (* Most things come from a CD *)
						lameMP3Gain = 0;
						lameSurround = 0;
						lamePreset = 0;
						lameMusicLength = 0;
						lameMusicCRC = 0;
					}
				}
				| (true, Some x) -> (match x.xingLame with
					| None -> { (* Use the XING part of the tag, and make up the LAME part *)
						xingRawTag = "";
						xingTagType = (if !min_frame_used_ref.bitrateNum = !max_frame_used_ref.bitrateNum then "Info" else "Xing");
						xingNumFrames = Some !total_frames_ref;
						xingNumBytes = Some !total_frame_bytes_ref;
						xingTOC = Some toc;
						xingQuality = x.xingQuality;
						xingEncoder = x.xingEncoder;
						xingLame = Some {
							lameRevision = 1;
							lameVBRMethod = 0;
							lameLowpass = 0;
							lamePeakAmplitude = 0.0;
							lameRGTrack = 0;
							lameRGAlbum = 0;
							lameNSPsyTune = false;
							lameNSSafeJoint = false;
							lameNoGapPrev = false;
							lameNoGapNext = false;
							lameATHType = 0;
							lameABRBitrate = min 255 !min_frame_used_ref.bitrateNum;
							lameDelayStart = 576; (* Assume there's a 576 sample delay on both ends *)
							lameDelayEnd = 576;
							lameNoiseShaping = 0;
							lameStereoMode = (match k.common_channel_mode with
								| ChannelStereo -> 1
								| ChannelJoint -> 3
								| ChannelDual -> 2
								| ChannelMono -> 0
							);
							lameUnwise = true; (* Better to say a good one's bad than say a bad one's good *)
							lameSourceFrequency = 1; (* Most things come from a CD *)
							lameMP3Gain = 0;
							lameSurround = 0;
							lamePreset = 0;
							lameMusicLength = 0;
							lameMusicCRC = 0;
						}
					}
					| Some l -> { (* Use the old LAME tag *)
						xingRawTag = "";
						xingTagType = (if !min_frame_used_ref.bitrateNum = !max_frame_used_ref.bitrateNum then "Info" else "Xing");
						xingNumFrames = Some !total_frames_ref;
						xingNumBytes = Some !total_frame_bytes_ref;
						xingTOC = Some toc;
						xingQuality = x.xingQuality;
						xingEncoder = x.xingEncoder;
						xingLame = Some l
					}
				)
			) in
			let xing_string = make_xing out_xing xing_header_and_side_info in
			if debug_queue then Printf.printf "XING tag:\n%S\n" (to_hex xing_string);
			seek_out out_file xing_pos;
			if debug_queue then Printf.printf " Writing XING tag at %d\n" xing_pos;
			output_this xing_string;
		)
		| x -> raise x
	); (* Bending the rules for parentheses, but that's OK *)
;;
