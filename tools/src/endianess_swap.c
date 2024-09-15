#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv) {
	FILE* input = NULL;
	FILE* output = NULL;
	unsigned long size = 0;
	unsigned long itr = 0;
	unsigned char* buffer;

	if(argc != 3)
		return 0;
	input = fopen(argv[1], "rb");
	output = fopen(argv[2], "wb");

	if(!input || !output)
		fprintf(stderr,"could not open file");

	fseek(input, 0, SEEK_END);
	size = ftell(input);
	fseek(input, 0, SEEK_SET);

	buffer = (unsigned char*)malloc(size);

	fread(buffer, 1, size, input);
	fclose(input);

	for(itr = 0; itr < size; itr = itr + 4) {
		fwrite(&buffer[itr + 3], 1, 1, output);
		fwrite(&buffer[itr + 2], 1, 1, output);
		fwrite(&buffer[itr + 1], 1, 1, output);
		fwrite(&buffer[itr + 0], 1, 1, output);
	}

	fclose(output);
	return 0;
}
