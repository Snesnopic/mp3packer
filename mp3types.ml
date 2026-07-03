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

let to_hex s =
  let result = String.create (2 * String.length s) in
  for i = 0 to String.length s - 1 do
    String.blit (Printf.sprintf "%02X" (int_of_char s.[i])) 0 result (2*i) 2;
  done;
  result;;

(* Used for printing debug stuff *)
let nul = open_out (if Sys.os_type = "Win32" then "NUL" else "/dev/null");;

exception Loop_end;;

type lameTag_t = {
	lameRevision : int;
	lameVBRMethod : int;
	lameLowpass : int;
	lamePeakAmplitude : float;
	lameRGTrack : int;
	lameRGAlbum : int;
	lameNSPsyTune : bool;
	lameNSSafeJoint : bool;
	lameNoGapPrev : bool;
	lameNoGapNext : bool;
	lameATHType : int;
	lameABRBitrate : int;
	lameDelayStart : int;
	lameDelayEnd : int;
	lameNoiseShaping : int;
	lameStereoMode : int;
	lameUnwise : bool;
	lameSourceFrequency : int;
	lameMP3Gain : int;
	lameSurround : int;
	lamePreset : int;
	lameMusicLength : int;
	lameMusicCRC : int
};;
(*type isLame_t = IsLame of lameTag_t | IsNotLame;;*)
type xingTag_t = {
	xingRawTag : string;
	xingTagType : string;
	xingNumFrames : int option; (* No fair having MP3 files longer than 324 days *)
	xingNumBytes : int option; (* No fair having MP3 files larger than 1GB *)
	xingTOC : int array option;
	xingQuality : int option;
	xingEncoder : string;
	xingLame : lameTag_t option;
};;

type sideInfo_t = {
	sideRaw : string; (* The exact value of the side info *)
	sideDataOffset : int; (* How much of the bit reservoir is used *)
	sideDataBits : int; (* How many bits are in this frame *)
};;
(*
type frameContents_t = {
	frameSide : sideInfo_t;
	frameData : string;
};;
*)
(*type frameType_t = FrameXing of xingTag_t | FrameNormal of frameContents_t;;*)

type channel_t = ChannelStereo | ChannelJoint | ChannelDual | ChannelMono;;
let channel_index = [| ChannelStereo ; ChannelJoint ; ChannelDual ; ChannelMono |];;

type mpeg_t = MPEG1 | MPEG2 | MPEG25;;
let mpeg_index = [| MPEG25 ; MPEG25 ; MPEG2 ; MPEG1 |];;

(*type layer_t = Layer1 | Layer2 | Layer3;;*) (* ONLY LAYER 3 IS VALID!!1 *)
type emphasis_t = EmphasisNone | Emphasis5015 | EmphasisInvalid | EmphasisCCITT;;
let emphasis_index = [| EmphasisNone ; Emphasis5015 ; EmphasisInvalid ; EmphasisCCITT |];;

type samplerate_t = S48000 | S44100 | S32000 | S24000 | S22050 | S16000 | S12000 | S11025 | S8000;;
let int_of_samplerate = function
| S48000 -> 48000
| S44100 -> 44100
| S32000 -> 32000
| S24000 -> 24000
| S22050 -> 22050
| S16000 -> 16000
| S12000 -> 12000
| S11025 -> 11025
|  S8000 ->  8000
;;
let float_of_samplerate = function
| S48000 -> 48000.
| S44100 -> 44100.
| S32000 -> 32000.
| S24000 -> 24000.
| S22050 -> 22050.
| S16000 -> 16000.
| S12000 -> 12000.
| S11025 -> 11025.
|  S8000 ->  8000.
;;

type common_t = { (* Store the things which are common to all the frames in a file *)
	common_id : mpeg_t;
	common_bitrate_index : int array;
	common_samplerate_index : samplerate_t array;
	common_samplerate : samplerate_t;
	common_crc : bool;
	common_channel_mode : channel_t;
	common_copyright : bool;
	common_original : bool;
	common_emphasis : emphasis_t;
	common_samples_per_frame : int;
	common_side_info_size : int;
	common_bspfk : float; (* Byte seconds per frame kilobit (surprisingly useful) *)
	common_unpadded_frame_length : int -> int; (* Takes a bitrate and returns the total number of bytes in it *)
};;

type header_t = {
	headerCommon : common_t;
(*	headerID : mpeg_t;*)
(*	headerCRC : bool;*)
	headerBitrate : int;
(*	headerSamplerate : int;*)
	headerPadding : bool;
	headerPrivate : bool;
(*	headerChannelMode : channel_t;*)
	headerMS : bool;
	headerIS : bool;
(*	headerCopyright : bool;
	headerOriginal : bool;
	headerEmphasis : emphasis_t;*)
	headerFrameLength : int; (* Frame length in bytes, including header *)
(*	headerByteSecondsPerFrameKilobit : float; (* I actually need this number a few places... *)*)
(*	headerSideInfoSize : int;*)
	(*headerDataType : *)
};;

type frame_t = {
	frameHeader : header_t;
	frameXing : xingTag_t option;
	frameSide : sideInfo_t;
	frameSilent : bool;
	frameData : string;
};;




(* For the queue *)
type frameInTransit_t = {
	transitFrame : int;
	transitHeader : header_t;
	transitSide : string;
	transitData : string;
	transitDataLength : int;
	transitBits : int;
	mutable transitPad : int; (* How much space the current frame should leave at the end *)
};;

type frameOut_t = {
	outFrame : int;
	outHeader : string;
	outSide : string;
	outData : string;
};;

type bitrate_t = {
	bitrateData : int;
	bitrateSize : int;
	bitrateNum : int;
	bitratePadding : bool;
	bitrateIndex : int;
};;























(* Weird padding stuff
		Each CBR MP3 seems to have a cycle of padded and unpadded frames which lasts
		49 frames. Some have a cycle that only lasts 7 frames, but this can be
		expanded to 49. The samplerates that are not a multiple of 11025 have no
		padded frames, whereas the other samplerates have complex patterns
*)
exception Too_many_bytes;;
let padded_frame samplerate bitrate frameno =
	let f = frameno mod 49 in
	match (samplerate, bitrate) with
	| (S44100,  32) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S44100,  40) -> [| false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true |].(f)
	| (S44100,  48) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true |].(f)
	| (S44100,  56) -> [| false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true |].(f)
	| (S44100,  64) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S44100,  80) -> [| false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;true |].(f)
	| (S44100,  96) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S44100, 112) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true |].(f)
	| (S44100, 128) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S44100, 160) -> [| false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S44100, 192) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S44100, 224) -> [| false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true |].(f)
	| (S44100, 256) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S44100, 320) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)

	| (S22050,   8) -> [| false;false;false;false;false;false;false;false;true ;false;false;false;false;false;false;false;true ;false;false;false;false;false;false;false;true ;false;false;false;false;false;false;false;true ;false;false;false;false;false;false;false;true ;false;false;false;false;false;false;false;true |].(f)
	| (S22050,  16) -> [| false;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true |].(f)
	| (S22050,  24) -> [| false;false;true ;false;false;true ;false;false;true ;false;true ;false;false;true ;false;false;true ;false;false;true ;false;true ;false;false;true ;false;false;true ;false;true ;false;false;true ;false;false;true ;false;false;true ;false;true ;false;false;true ;false;false;true ;false;true |].(f)
	| (S22050,  32) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S22050,  40) -> [| false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;false;true ;true ;false;true ;true |].(f)
	| (S22050,  48) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true |].(f)
	| (S22050,  56) -> [| false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true |].(f)
	| (S22050,  64) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S22050,  80) -> [| false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;true |].(f)
	| (S22050,  96) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S22050, 112) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true |].(f)
	| (S22050, 128) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S22050, 144) -> [| false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;false;true ;false;false;false;true |].(f)
	| (S22050, 160) -> [| false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true |].(f)

	| (S11025,   8) -> [| false;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true ;false;false;false;true |].(f)
	| (S11025,  16) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S11025,  24) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true ;false;true ;true ;true |].(f)
	| (S11025,  32) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S11025,  40) -> [| false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;false;true ;false;false;false;true ;false;false;false;true |].(f)
	| (S11025,  48) -> [| false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S11025,  56) -> [| false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true ;false;true ;true ;false;true ;true ;true |].(f)
	| (S11025,  64) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S11025,  80) -> [| false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;true ;false;true |].(f)
	| (S11025,  96) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S11025, 112) -> [| false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;true |].(f)
	| (S11025, 128) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)
	| (S11025, 144) -> [| false;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;false;true ;false;true ;false;true |].(f)
	| (S11025, 160) -> [| false;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true ;false;true ;true ;true ;true ;true ;true ;true ;true ;true |].(f)

	| _ -> false (* All other samplerates, as well as any invalid bitrates *)
;;
