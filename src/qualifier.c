#include "qualifier.h"

qualifier parse_qualifier(char *text) {
	qualifier q = {auto_encoding, byte_access};

	if(text++[0] == '.') {
		char c;

		while (c = text++[0]) {
			switch (c) {
				case 'S':
				case 's':
					q.encoding = short_encoding;
					q.enc_set = 1;
					break;
				case 'Y':
				case 'y':
					q.encoding = byte_encoding;
					q.enc_set = 1;
					break;
				case 'M':
				case 'm':
					q.encoding = medium_encoding;
					q.enc_set = 1;
					break;
				case 'L':
				case 'l':
					q.encoding = long_encoding;
					q.enc_set = 1;
					break;
				case 'B':
				case 'b':
					q.access = byte_access;
					q.acc_set = 1;
					break;
				case 'W':
				case 'w':
					q.access = word_access;
					q.acc_set = 1;
					break;
				default:
					yyerror("invalid character in dot-qualifier");
					break;
			}
		}
	}

	return q;
}

qualifier union_qualifier(qualifier q1, qualifier q2) {
	q1.encoding |= q2.encoding;
	q1.access |= q2.access;
	q1.enc_set |= q2.enc_set;
	q1.acc_set |= q2.acc_set;

	return q1;
}
