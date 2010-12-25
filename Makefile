
CPP = g++
CPPFLAGS = -std=c++0x -g
LINKFLAGS = -lIrrlicht

MAIN=gameroot/coolgameyo

NOBJS := main.o Block.o Chunk.o Game.o Sector.o Tile.o \
    Util.o World.o WorldGenerator.o 

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

$(OBJDIR)/main.o: $(SRCDIR)/main.cpp $(SRCDIR)/include.h $(SRCDIR)/os.h \
 $(SRCDIR)/Game.h $(SRCDIR)/World.h $(SRCDIR)/Sector.h \
 $(SRCDIR)/Chunk.h $(SRCDIR)/Block.h $(SRCDIR)/Tile.h \
 $(SRCDIR)/WorldGenerator.h
$(OBJDIR)/Block.o: $(SRCDIR)/Block.cpp $(SRCDIR)/Block.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h $(SRCDIR)/Tile.h $(SRCDIR)/Util.h $(SRCDIR)/Sector.h \
 $(SRCDIR)/Chunk.h $(SRCDIR)/WorldGenerator.h
$(OBJDIR)/Chunk.o: $(SRCDIR)/Chunk.cpp $(SRCDIR)/Chunk.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h $(SRCDIR)/Block.h $(SRCDIR)/Tile.h $(SRCDIR)/Util.h \
 $(SRCDIR)/Sector.h
$(OBJDIR)/Game.o: $(SRCDIR)/Game.cpp $(SRCDIR)/Game.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h $(SRCDIR)/World.h $(SRCDIR)/Sector.h \
 $(SRCDIR)/Chunk.h $(SRCDIR)/Block.h $(SRCDIR)/Tile.h \
 $(SRCDIR)/WorldGenerator.h
$(OBJDIR)/Sector.o: $(SRCDIR)/Sector.cpp $(SRCDIR)/Sector.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h $(SRCDIR)/Chunk.h $(SRCDIR)/Block.h $(SRCDIR)/Tile.h \
 $(SRCDIR)/Util.h
$(OBJDIR)/Tile.o: $(SRCDIR)/Tile.cpp $(SRCDIR)/Tile.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h
$(OBJDIR)/UDPSocket.o: $(SRCDIR)/UDPSocket.cpp $(SRCDIR)/UDPSocket.h \
 $(SRCDIR)/include.h $(SRCDIR)/os.h
$(OBJDIR)/Util.o: $(SRCDIR)/Util.cpp $(SRCDIR)/Util.h $(SRCDIR)/Sector.h \
 $(SRCDIR)/include.h $(SRCDIR)/os.h $(SRCDIR)/Chunk.h \
 $(SRCDIR)/Block.h $(SRCDIR)/Tile.h
$(OBJDIR)/World.o: $(SRCDIR)/World.cpp $(SRCDIR)/World.h $(SRCDIR)/include.h \
 $(SRCDIR)/os.h $(SRCDIR)/Sector.h $(SRCDIR)/Chunk.h \
 $(SRCDIR)/Block.h $(SRCDIR)/Tile.h $(SRCDIR)/WorldGenerator.h \
 $(SRCDIR)/Game.h $(SRCDIR)/Util.h
$(OBJDIR)/WorldGenerator.o: $(SRCDIR)/WorldGenerator.cpp \
 $(SRCDIR)/WorldGenerator.h $(SRCDIR)/include.h $(SRCDIR)/os.h \
 $(SRCDIR)/Tile.h

.PHONY: clean
clean:
	rm -r $(OBJDIR)
	rm $(MAIN)
