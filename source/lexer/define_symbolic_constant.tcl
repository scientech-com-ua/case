define_symbolic_constant:
	lods	byte [esi]
	cmp	al,1Ah
	jne	invalid_name
	lods	byte [esi]
	mov	cl,al
	mov	ch,10b
	call	add_preprocessor_symbol
	movzx	eax,byte [esi-1]
	add	esi,eax
	lea	ecx,[edi-1]
	sub	ecx,esi
	mov	[edx+8],esi
	mov	[edx+12],ecx
	jmp	line_preprocessed
