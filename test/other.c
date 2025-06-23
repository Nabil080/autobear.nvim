#include "unistd.h"

void func()
{
	write(STDOUT_FILENO, "Hello from other func", 21);
}
