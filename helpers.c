#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

void _dump_array(size_t arr[], size_t count) {
  printf("[");
  for (size_t i = 0; i < count; i++)
    printf(" 0x%zx", arr[i]);
  printf(" ]\n");
  fflush(stdout);
}
