
CPP = g++
CPPFLAGS = -std=c++0x -g
LINKFLAGS = -lIrrlicht

MAIN=gameroot/coolgameyo

NOBJS := main.o

SRCDIR := coolgameyo
OBJDIR := build

OBJS := $(addprefix $(OBJDIR)/,$(NOBJS))

$(OBJDIR)/%.o : $(SRCDIR)/%.cpp
	$(CPP) $(CPPFLAGS) -c -o $@ $<

$(MAIN): $(OBJS)
	$(CPP) $(CPPFLAGS) $(LINKFLAGS) -o $(MAIN) $(OBJS)

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	mkdir $(OBJDIR)

$(OBJDIR)/main.o: $(SRCDIR)/main.cpp $(SRCDIR)/include.h

.PHONY: clean
clean:
	rm -r $(OBJDIR)
	rm $(MAIN)
