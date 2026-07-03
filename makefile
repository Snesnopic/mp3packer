mp3packer: crc.cmx list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.cmx mp3queue.cmx mp3packer.ml
	ocamlopt -o mp3packer unix.cmxa str.cmxa crc.cmx list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.cmx mp3queue.cmx mp3packer.ml



mp3read.cmx: mp3types.cmx pack.cmx mp3read.ml
	ocamlopt -c mp3types.cmx pack.cmx mp3read.ml

mp3queue.cmx: list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3queue.ml
	ocamlopt -c list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3queue.ml

mp3info.cmx: list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.ml
	ocamlopt -c list2.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.ml

crc.cmx: crc.ml
	ocamlopt -c crc.ml

pack.cmx: pack.ml
	ocamlopt -c pack.ml

mp3types.cmx: mp3types.ml
	ocamlopt -c mp3types.ml



mp3read_test: mp3types.cmx crc.cmx pack.cmx mp3read.cmx mp3read_test.ml
	ocamlopt -o mp3read_test str.cmxa mp3types.cmx crc.cmx pack.cmx mp3read.cmx mp3read_test.ml
	mp3read_test

mp3queue_test: list2.cmx mp3types.cmx crc.cmx pack.cmx mp3read.cmx mp3queue.cmx mp3queue_test.ml
	ocamlopt -o mp3queue_test list2.cmx mp3types.cmx crc.cmx pack.cmx mp3read.cmx mp3queue.cmx mp3queue_test.ml
	mp3queue_test

mp3info_test: list2.cmx crc.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.cmx mp3info_test.ml
	ocamlopt -o mp3info_test list2.cmx crc.cmx mp3types.cmx pack.cmx mp3read.cmx mp3info.cmx mp3info_test.ml
	mp3info_test




## Lists ##
list2.cmx: list2.ml list2.mli
	ocamlopt list2.mli
	ocamlopt -c list2.ml

list2_test: list2.cmx list2_test.ml
	ocamlopt -o list2_test list2.cmx list2_test.ml
	list2_test


clean:
	del /s /q /f .\*.exe
	del /s /q /f .\*.obj
	del /s /q /f .\*.cmi
	del /s /q /f .\*.cmx
	del /s /q /f .\*.cmo
	del /s /q /f .\*.cma
	del /s /q /f .\*.cmxa
	del /s /q /f .\*.lib
	del /s /q /f .\*.asm
