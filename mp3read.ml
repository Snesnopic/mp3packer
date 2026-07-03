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
open Pack;;



class mp3read ?(debug = false) inFile =
	let vastness = 32768 in (* Min buffer size *)
	let too_vast = 2 * vastness in
(*
	let printDebug x = match debug with
		| true  -> Printf.printf x
		| false -> Printf.fprintf nul x
	in
*)
	object(o)
		val handle = open_in_bin inFile
		val buffer = Buffer.create vastness
		val mutable bufferOffset = 0 (* Which byte the start of the buffer represents in the file *)
		val mutable bufferPos = 0 (* Like Perl's pos() function; keeps track of where we are in the buffer *)
		val bitstream = Buffer.create 511
		val mutable frameNumber = 0
		val xingtag : (xingTag_t option) = None

		val mutable valid = false
		val mutable k = {
			common_id = MPEG1;
			common_bitrate_index = [| |];
			common_samplerate_index = [| |];
			common_samplerate = S44100;
			common_crc = false;
			common_channel_mode = ChannelStereo;
			common_copyright = false;
			common_original = false;
			common_emphasis = EmphasisNone;
			common_samples_per_frame = 1152;
			common_side_info_size = 0;
			common_bspfk = 0.0;
			common_unpadded_frame_length = (fun x -> 0);
		}

		val mutable first_frame_start = max_int
		val mutable last_frame_end = 0

		val mutable xing_found = false

		(****************************************************)
		(* Removes the buffer up to the bufferPos character *)
		(****************************************************)
		method clean_buffer = (
			if bufferPos > 0 then (
				if debug then Printf.printf "clean_buffer %d bytes\n" bufferPos;
				let tempString = Buffer.sub buffer bufferPos (Buffer.length buffer - bufferPos) in
				Buffer.clear buffer;
				Buffer.add_string buffer tempString;
				bufferOffset <- bufferOffset + bufferPos;
				bufferPos <- 0;
			)
		)

		(************************************************)
		(* Fills the buffer with another vastness bytes *)
		(************************************************)
		method fill_buffer = (
			let bytesLeft = (in_channel_length handle) - bufferOffset - (Buffer.length buffer) in
			if debug then Printf.printf "fill_buffer with %d bytes (%d bytes left)\n" (min bytesLeft vastness) bytesLeft;
			if bytesLeft = 0 then raise End_of_file; (* No more to fill! *)
			Buffer.add_channel buffer handle (min bytesLeft vastness);
			if bufferPos > too_vast then o#clean_buffer;
		)

		(***************************************************************************)
		(* Ensures that there are at least num bytes after the bufferPos character *)
		(***************************************************************************)
		method ensure_bytes num = (
			if debug then Printf.printf "ensure_bytes %d\n" num;
			(* Will exit when the specified amount has been reached, or an End_of_file is generated *)
			while bufferPos + num > Buffer.length buffer do
				if debug then Printf.printf " Fill buffer!\n";
				o#fill_buffer;
			done
		)

		(************************)
		(* Increments bufferPos *)
		(************************)
		method succ_pos = (
			if debug then Printf.printf "succ_pos to %d\n" (succ bufferPos);
			o#ensure_bytes 1;
			bufferPos <- succ bufferPos
		)

		(*******************************************************************************)
		(* Returns the header if the specified string is the beginning of an MP3 frame *)
		(*******************************************************************************)
		method  is_valid_header ?(offset = 0) str = (
			if String.length str < 4 + offset || offset < 0 then None else (
				if debug then Printf.printf "is_valid_header on %S\n" (to_hex (String.sub str 0 4));
				if offset <> 0 then if debug then Printf.printf " at offset %d" offset;
				if debug then Printf.printf " Enough letters\n";
				let a = Char.code str.[0 + offset] in
				let b = Char.code str.[1 + offset] in
				let c = Char.code str.[2 + offset] in
				let d = Char.code str.[3 + offset] in
				if a <> 255 || b < 224 then (if debug then Printf.printf " SYNC'S BROKEN\n"; None) else (
					(* First byte must be a 0xFF, second must be 0b111????? *)
					if debug then Printf.printf " Sync's right\n";

					try (
						let frame_id = mpeg_index.(b lsr 3 land 3) in
						if b lsr 3 land 3 = 1 then raise Not_found;
						let (samples_per_frame, bitrate_index, samplerate_index) = (match (valid, frame_id) with
							| (true, x) when x = k.common_id -> (k.common_samples_per_frame, k.common_bitrate_index, k.common_samplerate_index)
							| (true, x) -> raise Not_found
							| (false, MPEG1 ) -> (1152, [| 0;32;40;48;56;64;80;96;112;128;160;192;224;256;320 |], [| S44100;S48000;S32000 |])
							| (false, MPEG2 ) -> ( 576, [| 0; 8;16;24;32;40;48;56; 64; 80; 96;112;128;144;160 |], [| S22050;S24000;S16000 |])
							| (false, MPEG25) -> ( 576, [| 0; 8;16;24;32;40;48;56; 64; 80; 96;112;128;144;160 |], [| S11025;S12000; S8000 |])
						) in
						if debug then Printf.printf " Frame ID's right (MPEG%s)\n" (match frame_id with MPEG1 -> "1" | MPEG2 -> "2" | _ -> "25");

						if b lsr 1 land 3 <> 1 then raise Not_found; (* Layer 1 and 2 are no good *)
						if debug then Printf.printf " Layer 3\n";

						let frame_crc = (b land 1 = 0) in (* CRC is present if this is a 1! *)
						if debug then Printf.printf " CRC present? %B\n" frame_crc;

						let frame_bitrate = bitrate_index.(c lsr 4 land 15) in
						if frame_bitrate = 0 then raise Not_found;
						if debug then Printf.printf " Frame bitrate: %d\n" frame_bitrate;

						let frame_samplerate = samplerate_index.(c lsr 2 land 3) in

						if debug then Printf.printf " Frame samplerate: %d\n" (int_of_samplerate frame_samplerate);

						let frame_padding = (c land 2 = 2) in
						let frame_private = (c land 1 = 1) in
						if debug then Printf.printf " Padded? %B\n Private? %B\n" frame_padding frame_private;

						let frame_channel_mode = channel_index.(d lsr 6 land 3) in
						if debug then Printf.printf " %s\n" (match frame_channel_mode with ChannelStereo -> "ChannelStereo" | ChannelJoint -> "ChannelJoint" | ChannelDual -> "ChannelDual" | ChannelMono -> "ChannelMono");

						let frame_ms = (d land 32 = 32) in
						let frame_is = (d land 16 = 16) in
						if debug then Printf.printf " MS? %B\n IS? %B\n" frame_ms frame_is;

						let frame_copyright = (d land 8 = 8) in
						let frame_original = (d land 4 = 4) in
						let frame_emphasis = emphasis_index.(d land 3) in
						if frame_emphasis = EmphasisInvalid then raise Not_found;

						if valid then (
							if (
								frame_crc <> k.common_crc ||
								frame_samplerate <> k.common_samplerate ||
								frame_channel_mode <> k.common_channel_mode ||
								frame_copyright <> k.common_copyright ||
								frame_original <> k.common_original ||
								frame_emphasis <> k.common_emphasis
							) then raise Not_found
						) else (
							valid <- true;

							k <- {
								common_id = frame_id;
								common_bitrate_index = bitrate_index;
								common_samplerate_index = samplerate_index;
								common_samplerate = frame_samplerate;
								common_crc = frame_crc;
								common_channel_mode = frame_channel_mode;
								common_copyright = frame_copyright;
								common_original = frame_original;
								common_emphasis = frame_emphasis;
								common_samples_per_frame = samples_per_frame;
								common_side_info_size = (match (frame_id, frame_channel_mode) with
									| (MPEG1, ChannelMono) -> 17
									| (  _  , ChannelMono) -> 9
									| (MPEG1,      _     ) -> 32
									| (  _  ,      _     ) -> 17
								);
								common_bspfk = float_of_int (samples_per_frame * 125) /. float_of_samplerate frame_samplerate;
								common_unpadded_frame_length = (if int_of_samplerate frame_samplerate < 32000
									then (fun x -> 72000 * x / int_of_samplerate frame_samplerate)
									else (fun x -> 144000 * x / int_of_samplerate frame_samplerate)
								);
							};

						);

						(* Now find out the frame size for this frame *)
						let frame_size = k.common_unpadded_frame_length frame_bitrate + (if frame_padding then 1 else 0) in

						Some {
							headerCommon = k;
							headerBitrate = frame_bitrate;
							headerPadding = frame_padding;
							headerPrivate = frame_private;
							headerMS = frame_ms;
							headerIS = frame_is;
							headerFrameLength = frame_size;
						};
					) with
					| _ -> (if debug then Printf.printf " SOMETHING WENT WRONG\n"; None) (* If anything went wrong, there's no header here *)
				)
			)
		)

		(*******************************************************************)
		(* Does the is_valid_header for the current location in the buffer *)
		(*******************************************************************)
		method check_buffer_for_header = (
			if debug then Printf.printf "check_buffer_for_header at %d\n" bufferPos;
			o#ensure_bytes 4;
			o#is_valid_header (Buffer.sub buffer bufferPos 4)
		)

		(******************************************************************************************)
		(* Similar to check_buffer_for_header, but returns the entire frame and updates bufferPos *)
		(******************************************************************************************)
		method check_buffer_for_frame = (
			if debug then Printf.printf "check_buffer_for_frame at %d (%d)\n" bufferPos (bufferPos + bufferOffset);
			let this_frame_start = bufferPos + bufferOffset in
			match o#check_buffer_for_header with
			| None -> (
				bufferPos <- succ bufferPos;
				None (* No header found, therefore no frame found *)
			)
			| Some head -> (
				o#ensure_bytes head.headerFrameLength; (* Make sure there's enough room for the frame *)
				let rawFrame = Buffer.sub buffer bufferPos head.headerFrameLength in
				bufferPos <- bufferPos + head.headerFrameLength;
				if debug then Printf.printf " Found a valid header\n";

				(* Update the frame extents *)
				first_frame_start <- min first_frame_start this_frame_start;
				last_frame_end <- bufferPos + bufferOffset - 1;
				if debug then Printf.printf "  [%d %d]\n" first_frame_start last_frame_end;

				let side = String.sub rawFrame (if k.common_crc then 6 else 4) k.common_side_info_size in
				let rest = String.sub rawFrame (if k.common_crc then (6 + k.common_side_info_size) else (4 + k.common_side_info_size)) (String.length rawFrame - k.common_side_info_size - (if k.common_crc then 6 else 4)) in
				if debug then Printf.printf " Side info %S\n" side;
				if debug then Printf.printf " Frame     %S\n" rest;

				(* Find out the position and length of the frame's data *)
				let (offset, bits) = match (k.common_id, k.common_channel_mode) with
					| (MPEG1, ChannelMono) -> (
						let off = unpackBits side 0 9 in
						if debug then Printf.printf "  Offset %d\n" off;
						let g1 = unpackBits side 18 12 in
						let g2 = unpackBits side 77 12 in
						if debug then Printf.printf "  Lengths %d,%d\n" g1 g2;
						(off, g1 + g2)
					)
					| (MPEG1, _) -> ( (* Stereo MPEG1, by far the most common *)
						let off = unpackBits side 0 9 in
						if debug then Printf.printf "  Offset %d\n" off;
						let g1 = unpackBits side  20 12 in
						let g2 = unpackBits side  79 12 in
						let g3 = unpackBits side 138 12 in
						let g4 = unpackBits side 197 12 in
						if debug then Printf.printf "  Lengths %d,%d,%d,%d\n" g1 g2 g3 g4;
						(off, g1 + g2 + g3 + g4)
					)
					| (_, ChannelMono) -> (
						let off = unpackBits side 0 8 in
						if debug then Printf.printf "  Offset %d\n" off;
						let g1 = unpackBits side  9 12 in
						if debug then Printf.printf "  Lengths %d\n" g1;
						(off, g1)
					)
					| (_, _) -> (
						let off = unpackBits side 0 8 in
						if debug then Printf.printf "  Offset %d\n" off;
						let g1 = unpackBits side 10 12 in
						let g2 = unpackBits side 73 12 in
						if debug then Printf.printf "  Lengths %d,%d\n" g1 g2;
						(off, g1 + g2)
					)
				in

				(* Find out if the frame is silent *)
				let frame_silent = match (k.common_id, k.common_channel_mode) with
					| (MPEG1, ChannelMono) -> (
						let big1 = unpackBits side 30 9 in
						let big2 = unpackBits side 89 9 in
						let gain1 = unpackBits side 39 8 in
						let gain2 = unpackBits side 98 8 in
						let sfc1 = unpackBits side  47 4 in
						let sfc2 = unpackBits side 106 4 in
						let wind1 = unpackBits side  52 22 in
						let wind2 = unpackBits side 111 22 in
						big1 = 0 && big2 = 0 (*&& gain1 = 0 && gain2 = 0*) && sfc1 = 0 && sfc2 = 0 && wind1 = 0 && wind2 = 0
					)
					| (MPEG1, _) -> (
						let big1 = unpackBits side  32 9 in
						let big2 = unpackBits side  91 9 in
						let big3 = unpackBits side 150 9 in
						let big4 = unpackBits side 209 9 in
						let gain1 = unpackBits side  41 8 in
						let gain2 = unpackBits side 100 8 in
						let gain3 = unpackBits side 159 8 in
						let gain4 = unpackBits side 218 8 in
						let sfc1 = unpackBits side  49 4 in
						let sfc2 = unpackBits side 108 4 in
						let sfc3 = unpackBits side 167 4 in
						let sfc4 = unpackBits side 226 4 in
						let wind1 = unpackBits side  54 22 in
						let wind2 = unpackBits side 113 22 in
						let wind3 = unpackBits side 172 22 in
						let wind4 = unpackBits side 231 22 in
						big1 = 0 && big2 = 0 && big3 = 0 && big4 = 0 (*&& gain1 = 0 && gain2 = 0 && gain3 = 0 && gain4 = 0*) && sfc1 = 0 && sfc2 = 0 && sfc3 = 0 && sfc4 = 0 && wind1 = 0 && wind2 = 0 && wind3 = 0 && wind4 = 0
					)
					| (_, ChannelMono) -> (
						let big1 = unpackBits side 21 9 in
						let gain1 = unpackBits side 30 8 in
						let sfc1 = unpackBits side 38 4 in
						let wind1 = unpackBits side 43 22 in
						big1 = 0 (*&& gain1 = 0*) && sfc1 = 0 && wind1 = 0
					)
					| (_, _) -> (
						let big1 = unpackBits side 22 9 in
						let big2 = unpackBits side 85 9 in
						let gain1 = unpackBits side 31 8 in
						let gain2 = unpackBits side 94 8 in
						let sfc1 = unpackBits side  39 4 in
						let sfc2 = unpackBits side 102 4 in
						let wind1 = unpackBits side  44 22 in
						let wind2 = unpackBits side 107 22 in
						big1 = 0 && big2 = 0 (*&& gain1 = 0 && gain2 = 0*) && sfc1 = 0 && sfc2 = 0 && wind1 = 0 && wind2 = 0
					)
				in
				if frame_silent && debug then Printf.printf " Frame is silent!\n";

				(* Find an XING tag *)
				try (
					if xing_found then raise Not_found; (* There shouldn't be two XING frames in a file *)
					let rec count_zeros rawFrame now num = (
						if now >= String.length rawFrame || rawFrame.[now] <> '\x00'
							then num
							else count_zeros rawFrame (succ now) (succ num)
					) in
					let num_zeros = count_zeros rawFrame 6 0 in
					if num_zeros < 7 || num_zeros > 32 then raise Not_found;
					if num_zeros + 10 > String.length rawFrame then raise Not_found; (* The frame is not large enough to have an XING tag in it *)
					let tag_type = String.sub rawFrame (num_zeros + 6) 4 in
					if tag_type <> "Xing" && tag_type <> "Info" then raise Not_found;
					if debug then Printf.printf " Looks like an %S frame\n" tag_type;

					let tag_guts = String.sub rawFrame (num_zeros + 10) (String.length rawFrame - num_zeros - 10) in

					(* Read the XING tag *)
					if String.length tag_guts < 4 then raise Not_found;
					if String.sub tag_guts 0 3 <> "\x00\x00\x00" then raise Not_found; (* The 3 MSB of the flag field are always 0 *)

					(* XING flags *)
					let flags = Char.code tag_guts.[3] in
					if flags > 15 then raise Not_found; (* There are only 4 flags defined *)
					let tag_pos_ref = ref 4 in (* Where we are in the tag *)
					let flag_frames_ref = ref None in (* If the number of frames is stored, this will be "ref Some #" *)
					let flag_bytes_ref = ref None in
					let flag_toc_ref = ref None in
					let flag_quality_ref = ref None in
					if flags land 1 = 1 then (
						if !tag_pos_ref + 4 > String.length tag_guts then raise Not_found;
						if debug then Printf.printf "  Found %d frames\n" (unpackN tag_guts !tag_pos_ref);
						flag_frames_ref := Some (unpackN tag_guts !tag_pos_ref);
						tag_pos_ref := !tag_pos_ref + 4;
					);
					if flags land 2 = 2 then (
						if !tag_pos_ref + 4 > String.length tag_guts then raise Not_found;
						if debug then Printf.printf "  Found %d bytes\n" (unpackN tag_guts !tag_pos_ref);
						flag_bytes_ref := Some (unpackN tag_guts !tag_pos_ref);
						tag_pos_ref := !tag_pos_ref + 4;
					);
					if flags land 4 = 4 then (
						if !tag_pos_ref + 100 > String.length tag_guts then raise Not_found;
						if debug then Printf.printf "  Found TOC\n";
						flag_toc_ref := Some (Array.init 100 (fun i -> Char.code tag_guts.[!tag_pos_ref + i]));
						tag_pos_ref := !tag_pos_ref + 100;
					);
					if flags land 8 = 8 then (
						if !tag_pos_ref + 4 > String.length tag_guts then raise Not_found;
						if debug then Printf.printf "  Found quality %d\n" (unpackN tag_guts !tag_pos_ref);
						flag_quality_ref := Some (unpackN tag_guts !tag_pos_ref);
						tag_pos_ref := !tag_pos_ref + 4;
					);

					let from_name = !tag_pos_ref in (* Used for the CRC calculation *)

					(* Encoder name *)
					if !tag_pos_ref + 20 > String.length tag_guts then raise Not_found;
					let encoder_20 = String.sub tag_guts !tag_pos_ref 20 in
					if debug then Printf.printf "  Encoder %S\n" encoder_20;
					tag_pos_ref := !tag_pos_ref + 20;

					(* Check to see if it's a LAME tag *)
					let lame_part = String.sub tag_guts !tag_pos_ref (String.length tag_guts - !tag_pos_ref) in
					let lame_zeros = count_zeros lame_part 0 0 in
					if debug then Printf.printf "  %d zeros at beginning of LAME part\n" lame_zeros;
					
					(* Check the Lame CRC *BEFORE* parsing the info; if the CRC doesn't match up then assume it's regular XING *)
					(* (num_zeros is the position of the "Xing" or "Info" tags counting from byte 6) *)
					let crc_ok = (
						let tag_crc = unpackn lame_part 14 in
						if debug then Printf.printf "  Tag CRC: %d\n" tag_crc;
						let crc_string = String.sub rawFrame 0 (num_zeros + 10 + from_name + 34) in
						let crc = Crc.create crc_string 0 in
						if debug then Printf.printf "   ACTUAL tag CRC: %d\n" crc;
						crc = tag_crc
					) in

					if crc_ok && lame_zeros < String.length lame_part && String.length lame_part >= 16 then (
						(* LAME part of the tag is non-zero, and there are at least 16 bytes left, which implies that there is LAME data present *)
						if debug then Printf.printf "   That means it's LAME!\n";

						(* Re-read the 20-byte encoder string, as some of it is used for LAME thingies *)
						let encoder_9       = String.sub encoder_20 0 9 in
						let rg_max_int      =  unpackN32 encoder_20 11 in
						let rg_track        =  unpackn encoder_20 15 in
						let rg_album        =  unpackn encoder_20 17 in
						let lame_flags      =  unpackC encoder_20 19 in
						let abr_bitrate     =  unpackC lame_part 0 in
						let padding1        =  unpackC lame_part 1 in
						let padding2        =  unpackC lame_part 2 in
						let padding3        =  unpackC lame_part 3 in
						let lame_misc       =  unpackC lame_part 4 in
						let mp3_gain        =  unpackC lame_part 5 in
						let preset_bytes    =  unpackn lame_part 6 in
						let music_length    =  unpackN lame_part 8 in
						let music_crc       =  unpackn lame_part 12 in
						let tag_crc         =  unpackn lame_part 14 in

						if debug then (
							Printf.printf "   Encoder's actually %S\n" encoder_9;
							Printf.printf "   Tag revision %d\n" ((unpackC encoder_20 9) lsr 4);
							Printf.printf "   VBR method %d\n" ((unpackC encoder_20 9) land 0x0F);
							Printf.printf "   Lowpass %d\n" (unpackC encoder_20 10);
							Printf.printf "   RG Max:   %ld = %g\n" rg_max_int (Int32.float_of_bits rg_max_int);
							Printf.printf "   RG Track: %d\n" rg_track;
							Printf.printf "   RG Album: %d\n" rg_album;
							Printf.printf "   LAME lame_NSpsy      : %B\n" (lame_flags land  16 <> 0);
							Printf.printf "   LAME lame_NSsj       : %B\n" (lame_flags land  32 <> 0);
							Printf.printf "   LAME lame_nogap_next : %B\n" (lame_flags land  64 <> 0);
							Printf.printf "   LAME lame_nogap_prev : %B\n" (lame_flags land 128 <> 0);
							Printf.printf "   ATH type %d\n" (lame_flags land 15);
							Printf.printf "   ABR bitrate %d\n" abr_bitrate;
							Printf.printf "   %d off the front; %d off the end\n" ((padding1 lsl 4) lor (padding2 lsr 4)) (((padding2 land 15) lsl 8) lor padding3);
							Printf.printf "   Noise %d, Stereo %d, Unwise %B, source freq %d\n" (lame_misc land 3) (lame_misc lsr 2 land 7) ((lame_misc land 32 <> 0)) (lame_misc lsr 6);
							Printf.printf "   MP3 Gain: %d\n" mp3_gain;
							Printf.printf "   Surround %d, preset %d\n" (preset_bytes lsr 11 land 7) (preset_bytes land 2047);
							Printf.printf "   Music takes up %d bytes\n" music_length;
							Printf.printf "   Music CRC: %d\n" music_crc;
							Printf.printf "   Tag CRC: %d\n" tag_crc;
						);

						Some {
							frameHeader = head;
							frameXing = Some {
								xingRawTag = tag_type ^ tag_guts;
								xingTagType = tag_type;
								xingNumFrames = !flag_frames_ref;
								xingNumBytes = !flag_bytes_ref;
								xingTOC = !flag_toc_ref;
								xingQuality = !flag_quality_ref;
								xingEncoder = encoder_9;
								xingLame = Some {
									lameRevision        = ((unpackC encoder_20 9) lsr 4);
									lameVBRMethod       = ((unpackC encoder_20 9) land 0x0F);
									lameLowpass         = (unpackC encoder_20 10);
									lamePeakAmplitude   = Int32.float_of_bits rg_max_int;
									lameRGTrack         = rg_track;
									lameRGAlbum         = rg_album;
									lameNSPsyTune       = (lame_flags land  16 <> 0);
									lameNSSafeJoint     = (lame_flags land  32 <> 0);
									lameNoGapPrev       = (lame_flags land 128 <> 0);
									lameNoGapNext       = (lame_flags land  64 <> 0);
									lameATHType         = lame_flags land 15;
									lameABRBitrate      = abr_bitrate;
									lameDelayStart      = (padding1 lsl 4) lor (padding2 lsr 4);
									lameDelayEnd        = ((padding2 land 15) lsl 8) lor padding3;
									lameNoiseShaping    = lame_misc land 3;
									lameStereoMode      = lame_misc lsr 2 land 7;
									lameUnwise          = (lame_misc land 32 <> 0);
									lameSourceFrequency = lame_misc lsr 6;
									lameMP3Gain         = mp3_gain;
									lameSurround        = preset_bytes lsr 11 land 7;
									lamePreset          = preset_bytes land 2047;
									lameMusicLength     = music_length;
									lameMusicCRC        = music_crc;
								};
							};
							frameSide = {
								sideRaw = side;
								sideDataOffset = offset;
								sideDataBits = bits;
							};
							frameSilent = false; (* Even though the frame is actually silent, setting this to true will usurp the XING writer *)
							frameData = rest;
						}
					) else (
						if debug then Printf.printf "   Not LAME enough\n";
(*
						Some {
							frameHeader = head;
							frameContents = FrameXing {
								xingRawTag = tag_type ^ tag_guts;
								xingTagType = tag_type;
								xingNumFrames = !flag_frames_ref;
								xingNumBytes = !flag_bytes_ref;
								xingTOC = !flag_toc_ref;
								xingQuality = !flag_quality_ref;
								xingEncoder = encoder_20;
								xingIsLame = None;
							}
						}
*)
						Some {
							frameHeader = head;
							frameXing = Some {
								xingRawTag = tag_type ^ tag_guts;
								xingTagType = tag_type;
								xingNumFrames = !flag_frames_ref;
								xingNumBytes = !flag_bytes_ref;
								xingTOC = !flag_toc_ref;
								xingQuality = !flag_quality_ref;
								xingEncoder = encoder_20;
								xingLame = None;
							};
							frameSide = {
								sideRaw = side;
								sideDataOffset = offset;
								sideDataBits = bits;
							};
							frameSilent = false;
							frameData = rest;
						}
					);
				) with
				| Not_found -> (
					(* Not an XING frame *)
					if debug then Printf.printf " Not an XING frame\n";

					Some {
						frameHeader = head;
						frameXing = None;
						frameSide = {
							sideRaw = side;
							sideDataOffset = offset;
							sideDataBits = bits;
						};
						frameSilent = frame_silent;
						frameData = rest;
					}
				)
			)
		)

		method find_next_frame = (
			let rec guts () = (
				(* A recursive function which calls check_buffer_for_frame until a frame has been found *)
				match o#check_buffer_for_frame with
				| None -> guts ()
				| Some x -> x
			) in
			guts ()
		)

		method first_mp3_byte = first_frame_start
		method last_mp3_byte = last_frame_end
		method length = in_channel_length handle
		method pos = bufferOffset + bufferPos

		method print_buffer = (
			if debug then Printf.printf "Buffer:\n%S\n" (to_hex (Buffer.contents buffer))
		)
	end;;



(*
## Side info:
# 9/17/32 BYTES = 136/256 bits
# 9: main_data_begin (8 for MPEG2)
# ?: private_bits
# 4: SCFI Band
# 59: Side Information Granule
#  12: part2_3 length (main data for this channel, granule in bits)
#  9: Big values
#  8: Global gain
#  4: Scalefactor compress (9 for MPEG2)
#  1: Window switch flag
#   if 1:
#    2: Block type
#    1: Mix block flag
#    5x2: Table Select [region]
#    3x3: sub_block_gain [window]
#   if 0:
#    5x3: Table select [region]
#    4: Region 0 count
#    3: Region 1 count
#  1: Pre flag (NOT FOR MPEG2)
#  1: Scale factor scale
#  1: Count1 table select

# MPEG1 mono:
# [9 main data] [5 privates] [4 SCFI] [59 Gr0] [59 Gr1]
# (18 - 30) (77 - 89)
# MPEG1 stereo:
# [9 main data] [3 privates] [4 SCFI0] [4 SCFI1] [59 Gr0ch1] [59 Gr0ch2] [59 Gr1ch1] [59 Gr1ch2]
# 20 79 138 197
# MPEG2 mono:
# [8 main data] [1 privates] [63 Gr*]
# (9 - 21)
# MPEG2 stereo:
# [8 main data] [2 privates] [63 Gr*ch1] [63 Gr*ch2]
# (10 - 22) (73 - 85)
*)