all: endianess_swap

endianess_swap: src/endianess_swap.o
	$(CC) $(LDFLAGS) -o endianess_swap src/endianess_swap.o

clean:
	$(RM) endianess_swap src/*.o
