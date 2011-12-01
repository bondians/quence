#ifndef __qualifier_h__
#define __qualifier_h__

typedef struct {
	unsigned	encoding : 3,
	          enc_set  : 1,
	          access   : 1,
	          acc_set  : 1,
	          is_array : 1;
} qualifier;

#define auto_encoding   0
#define short_encoding  1
#define byte_encoding   2
#define medium_encoding 3
#define long_encoding   4

#define byte_access     0
#define word_access     1

qualifier parse_qualifier(char *text);
qualifier union_qualifier(qualifier q1, qualifier q2);

#endif
