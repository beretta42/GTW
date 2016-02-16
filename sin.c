#include <stdio.h>
#include <math.h>


int main(){
	float i;
	float f;
	for( i=1; i<91; i++ ){
		f=sinf(i/57.296);
		printf("\t.db\t%.0f\n", rint(f*128) );
		
	}
   
}
