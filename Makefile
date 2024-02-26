mode ?= debug

builddir := build/${mode}

card := ${builddir}/card

# default rule (because it is the first one)
# which is just to make the card executable
all: ${card}

# gather all c files from src/
c_files := $(wildcard src/*.c)
# construct the path for each object file
o_files := $(foreach file,${c_files},${builddir}/$(file:.c=.o))
# construct the path for each dependency file
d_files := $(o_files:.o=.d)

# rule to clean up files we make
# use via `make clean`
clean: 
	-rm -r ${builddir}

# stupid make shit
.PHONY: clean

# if verbose is not set to something other than 'false' 
# on the command line, we suppress echoing commands
verbose ?= false
ifeq (${verbose},false)
	v := @
endif

compiler     := clang
linker       := clang
preprocessor := cpp

compiler_flags := \
	-Iinclude     \
	-Isrc

ifeq (${mode},debug) 
	compiler_flags += -O0 -ggdb3
else ifeq (${mode},release)
	compiler_flags += -O2
endif

linker_flags :=  \
	-Llib          \
	-lluajit_linux \
	-lraylib_linux \
	-lm            \
	-Wl,--export-dynamic

# print a success message
reset := \033[0m
green := \033[0;32m
blue  := \033[0;34m
define print
	@printf "$(green)$(1)$(reset) -> $(blue)$(2)$(reset)\n"
endef


# -----------------------------------------
#  Rules
# -----------------------------------------


# build card executable
${card}: ${o_files}
	${v}${linker} $^ ${linker_flags} -o $@
	@printf "$(blue)$@$(reset)\n"

# generic rule for turning c files into o files
${builddir}/%.o: %.c
	@mkdir -p $(@D) # ensure directories exist
	${v}${compiler} -c $< ${compiler_flags} -o $@
	$(call print,$<,$@)

# generic rule for turn c files into dep files
${builddir}/%.d: %.c
	@mkdir -p $(@D)
	${v}${preprocessor} $< ${compiler_flags} -MM -MT ${builddir}/$*.o -o $@

# include dependency files if they have been generated
-include ${d_files}

# disable make's silly builtin stuff for performance
MAKEFLAGS += --no-builtin-rules
