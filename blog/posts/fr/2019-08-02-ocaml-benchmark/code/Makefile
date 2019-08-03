OCAMLOPT=ocamlfind ocamlopt -package core -package core_bench -thread -linkpkg

all:
	@ SIZE=10 $(MAKE) bench
	@ SIZE=100 $(MAKE) bench
	@ SIZE=1000 $(MAKE) bench
	@ SIZE=2500 $(MAKE) bench
	@ SIZE=5000 $(MAKE) bench
	@ SIZE=7500 $(MAKE) bench
	@ SIZE=10000 $(MAKE) bench

bench:
	@echo [SIZE = $(SIZE)]
	@ocaml gen.ml > bench.ml
	@$(OCAMLOPT) -o bench.exe bench.ml
	@./bench.exe

clean:
	rm -f *.cm* *.o *~ bench.ml bench.exe
