CSICLANG?=$(LLVM_BIN)/clang
CSICLANGPP?=$(LLVM_BIN)/clang++
LLVMLINK?=$(LLVM_BIN)/llvm-link

all: check-vars check-files instr normal debug

check-vars:
ifndef LLVM_DIR
  $(error LLVM_DIR is undefined - please define LLVM_DIR as the directory containing the source of LLVM, e.g. /whatever/llvm)
endif
ifndef LLVM_BIN
  $(error LLVM_BIN is undefined - please define LLVM_BIN as the directory containing the binaries of LLVM, e.g. /whatever/llvm/build/bin)
endif

check-files:
	@test -s $(LLVM_DIR)/projects/compiler-rt/lib/csi/csirt.c || { echo "LLVM does not contain CSI in projects/compiler-rt! Exiting."; exit 1; }
	@test -s $(LLVM_BIN)/../lib/clang/6.0.0/lib/linux/libclang_rt.csi-x86_64.a || { echo "LLVM does not contain the CSI runtime in the lib folder! Exiting."; exit 1; }

instr: tool.o instr.o
	$(CSICLANGPP) -O3 -g instr.o tool.o  $(LLVM_BIN)/../lib/clang/6.0.0/lib/linux/libclang_rt.csi-x86_64.a -lcilkrts -lpthread -o instr

csirt.bc: $(LLVM_DIR)/projects/compiler-rt/lib/csi/csirt.c
	$(CSICLANG) -O3 -c -emit-llvm -std=c11 $(LLVM_DIR)/projects/compiler-rt/lib/csi/csirt.c -o csirt.bc

normal: test.cpp
	$(CSICLANGPP) -g -fcilkplus -O3 test.cpp -o normal

tool.bc: hooks.cpp hooks2.cpp SeriesParallelDAG.cpp SPComponent.cpp
	$(CSICLANGPP) -O3 -S -emit-llvm hooks.cpp -o tool1.bc
	$(CSICLANGPP) -O3 -S -emit-llvm hooks2.cpp -o tool2.bc
	$(CSICLANGPP) -O3 -S -emit-llvm SeriesParallelDAG.cpp -o tool3.bc
	$(CSICLANGPP) -O3 -S -emit-llvm SPComponent.cpp -o tool4.bc
	$(LLVMLINK) tool1.bc tool2.bc tool3.bc tool4.bc -o tool.bc

tool.o:  hooks.cpp hooks2.cpp SeriesParallelDAG.cpp SPComponent.cpp
	$(CSICLANGPP) -g -O3 -c hooks.cpp -o hooks1.o
	$(CSICLANGPP) -g -O3 -c hooks2.cpp -o hooks2.o
	$(CSICLANGPP) -g -O3 -c SeriesParallelDAG.cpp -o hooks3.o
	$(CSICLANGPP) -g -O3 -c SPComponent.cpp -o hooks4.o
	ld -r hooks1.o hooks2.o hooks3.o hooks4.o -o tool.o

instr.o: tool.bc test.cpp csirt.bc config.txt
	$(CSICLANGPP) -fcilkplus -O3 -c -g -fcsi test.cpp -mllvm -csi-config-mode -mllvm "whitelist" -mllvm -csi-config-filename -mllvm "config.txt" -mllvm -csi-tool-bitcode -mllvm "tool.bc" -mllvm -csi-runtime-bitcode -mllvm "csirt.bc" -o instr.o 

debug: tool.bc test.cpp csirt.bc 
	$(CSICLANGPP) -fcilkplus -g -O3 -S -emit-llvm -fcsi test.cpp -mllvm -csi-tool-bitcode -mllvm "tool.bc" -mllvm -csi-runtime-bitcode -mllvm "csirt.bc"  -o ir.txt 
	$(CSICLANGPP) -fcilkplus -O3 -fverbose-asm -S -masm=intel -fcsi test.cpp -mllvm -csi-tool-bitcode -mllvm "tool.bc" -mllvm -csi-runtime-bitcode -mllvm "csirt.bc"  -o asm.txt
	touch debug

clean:
	rm normal instr *.o *.bc ir.txt asm.txt