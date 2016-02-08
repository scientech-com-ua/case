define_equ_constant:
	add	esi,3
	push	esi
	call	process_equ_constants
	mov	esi,[struc_name]
	mov	ch,10b
      define_preprocessor_constant:
	mov	byte [esi-2],comment_marker
	mov	cl,[esi-1]
	call	add_preprocessor_symbol
	pop	ebx
	mov	ecx,edi
	dec	ecx
	sub	ecx,ebx
	mov	[edx+8],ebx
	mov	[edx+12],ecx
	jmp	line_preprocessed

