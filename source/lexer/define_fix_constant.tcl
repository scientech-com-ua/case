define_fix_constant:
	add	edx,5
	add	esi,2
	push	edx
	mov	ch,11b
	jmp	define_preprocessor_constant
